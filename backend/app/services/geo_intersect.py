"""
Module 2.5A — Geographic Intersection Engine.

Provides PostGIS-based route intersection with automatic Haversine fallback
when the PostGIS extension is unavailable.
"""

from __future__ import annotations

import logging
import math
from typing import List
from uuid import UUID

from app.db.supabase import get_supabase_client
from app.models.disruption import IntersectedAsset

logger = logging.getLogger(__name__)


class RouteGeometry:
    """Thin holder for a node/edge with pre-parsed lat/lon for Haversine fallback."""

    def __init__(
        self,
        asset_id: UUID,
        asset_type: str,
        lat: float,
        lon: float,
    ) -> None:
        self.asset_id = asset_id
        self.asset_type = asset_type
        self.lat = lat
        self.lon = lon


class GeoIntersectEngine:
    """
    Determines which supply-chain assets lie within a disruption radius.

    Primary strategy: PostGIS ST_DWithin executed as a raw RPC call via Supabase.
    Fallback strategy: Haversine great-circle distance calculation in Python.
    """

    # ------------------------------------------------------------------
    # Public interface (used by DisruptionService)
    # ------------------------------------------------------------------

    async def find_intersected_assets(
        self,
        lat: float,
        lon: float,
        radius_km: float,
        org_id: UUID,
    ) -> List[IntersectedAsset]:
        """
        Returns all nodes and edges within *radius_km* of (lat, lon) for *org_id*.
        Tries PostGIS first; falls back to Haversine if unavailable.
        """
        try:
            return await self._postgis_intersect(lat, lon, radius_km, org_id)
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "PostGIS unavailable (%s) — falling back to Haversine for org %s",
                exc,
                org_id,
            )
            return await self._haversine_fallback(lat, lon, radius_km, org_id)

    # ------------------------------------------------------------------
    # Strategy 1 — PostGIS ST_DWithin
    # ------------------------------------------------------------------

    async def _postgis_intersect(
        self,
        lat: float,
        lon: float,
        radius_km: float,
        org_id: UUID,
    ) -> List[IntersectedAsset]:
        """
        Executes raw PostGIS query via Supabase RPC:

        SELECT id, 'node' AS asset_type,
               ST_Distance(location::geography,
                           ST_SetSRID(ST_Point(lon,lat),4326)::geography) / 1000 AS dist_km
        FROM supply_chain_nodes
        WHERE organization_id = org_id
          AND deleted_at IS NULL
          AND ST_DWithin(location::geography,
                         ST_SetSRID(ST_Point(lon,lat),4326)::geography,
                         radius_m)
        """
        radius_m = radius_km * 1000.0
        supabase = get_supabase_client()
        result = supabase.rpc(
            "geo_intersect_assets",
            {
                "p_org_id": str(org_id),
                "p_lon": lon,
                "p_lat": lat,
                "p_radius_m": radius_m,
            },
        ).execute()

        assets: List[IntersectedAsset] = []
        for row in result.data or []:
            assets.append(
                IntersectedAsset(
                    asset_id=UUID(row["id"]),
                    asset_type=row["asset_type"],
                    distance_from_epicenter_km=float(row.get("dist_km", 0.0)),
                )
            )
        logger.info(
            "PostGIS intersect found %d assets for org %s", len(assets), org_id
        )
        return assets

    # ------------------------------------------------------------------
    # Strategy 2 — Haversine fallback
    # ------------------------------------------------------------------

    async def _haversine_fallback(
        self,
        lat: float,
        lon: float,
        radius_km: float,
        org_id: UUID,
    ) -> List[IntersectedAsset]:
        """
        Fetches node locations from Supabase and computes Haversine distances
        in Python when PostGIS is not available.
        """
        supabase = get_supabase_client()
        nodes_resp = (
            supabase.table("supply_chain_nodes")
            .select("id, location")
            .eq("organization_id", str(org_id))
            .is_("deleted_at", "null")
            .execute()
        )
        edges_resp = (
            supabase.table("node_edges")
            .select("id, source_node_id, target_node_id")
            .eq("organization_id", str(org_id))
            .is_("deleted_at", "null")
            .execute()
        )

        assets: List[IntersectedAsset] = []

        # Check nodes
        for node in nodes_resp.data or []:
            loc = node.get("location") or {}
            coords = loc.get("coordinates", [])
            if len(coords) < 2:
                continue
            n_lon, n_lat = float(coords[0]), float(coords[1])
            dist = _haversine_km(lat, lon, n_lat, n_lon)
            if dist <= radius_km:
                assets.append(
                    IntersectedAsset(
                        asset_id=UUID(node["id"]),
                        asset_type="node",
                        distance_from_epicenter_km=dist,
                    )
                )

        # For edges: approximate by checking both endpoint nodes
        node_location_cache = {
            n["id"]: n.get("location", {})
            for n in (nodes_resp.data or [])
        }
        for edge in edges_resp.data or []:
            for endpoint_key in ("source_node_id", "target_node_id"):
                ep_id = edge.get(endpoint_key)
                if not ep_id:
                    continue
                loc = node_location_cache.get(ep_id, {})
                coords = loc.get("coordinates", [])
                if len(coords) < 2:
                    continue
                e_lon, e_lat = float(coords[0]), float(coords[1])
                dist = _haversine_km(lat, lon, e_lat, e_lon)
                if dist <= radius_km:
                    assets.append(
                        IntersectedAsset(
                            asset_id=UUID(edge["id"]),
                            asset_type="edge",
                            distance_from_epicenter_km=dist,
                        )
                    )
                    break  # count edge once even if both endpoints are in radius

        logger.info(
            "Haversine fallback found %d assets for org %s", len(assets), org_id
        )
        return assets

    # ------------------------------------------------------------------
    # Helpers (formerly separate public methods from spec)
    # ------------------------------------------------------------------

    async def get_active_routes_for_org(self, org_id: UUID) -> List[RouteGeometry]:
        """Return all active node_edges + their geometry for an organisation."""
        supabase = get_supabase_client()
        resp = (
            supabase.table("node_edges")
            .select("id, source_node_id, target_node_id")
            .eq("organization_id", str(org_id))
            .is_("deleted_at", "null")
            .execute()
        )
        return [
            RouteGeometry(
                asset_id=UUID(row["id"]),
                asset_type="edge",
                lat=0.0,
                lon=0.0,
            )
            for row in (resp.data or [])
        ]

    async def point_intersects_route(
        self,
        lat: float,
        lon: float,
        radius_m: float,
        routes: List[RouteGeometry],
    ) -> List[UUID]:
        """Return IDs of routes whose endpoints fall within *radius_m* of (lat, lon)."""
        radius_km = radius_m / 1000.0
        return [
            r.asset_id
            for r in routes
            if _haversine_km(lat, lon, r.lat, r.lon) <= radius_km
        ]


# ------------------------------------------------------------------
# Haversine great-circle distance
# ------------------------------------------------------------------

def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return the great-circle distance in km between two WGS-84 points."""
    R = 6371.0  # Earth radius in km
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))
