"""
Module 2.5A — Physical Disruption Detection Service.

Polls Open-Meteo for severe weather events, cross-references disruption
geographic bounding boxes against active routing edges/nodes via PostGIS,
writes disruption_alerts rows, and broadcasts via Supabase Realtime.
"""

from __future__ import annotations

import logging
import time
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from uuid import UUID

import httpx

from app.core.config import settings
from app.db.supabase import get_supabase_client
from app.models.disruption import (
    DisruptionBroadcastPayload,
    DisruptionEvent,
    IntersectedAsset,
    ScanResult,
)
from app.services.geo_intersect import GeoIntersectEngine
from app.services.webhooks import AlertBroadcaster
from app.utils.rate_limiter import rate_limiter

logger = logging.getLogger(__name__)

# WMO weather codes that represent severe weather
_SEVERE_WEATHER_CODES = {75, 77, 82, 95, 99}

# Radius in km for the default disruption scan
_DEFAULT_RADIUS_KM = 50


class DisruptionService:
    """
    Orchestrates physical disruption detection for a single organisation.

    Data flow:
        fetch_weather_disruptions → geo_intersect_check
        → write_disruption_alert → broadcast_alert
    """

    def __init__(self) -> None:
        self._geo_engine = GeoIntersectEngine()
        self._broadcaster = AlertBroadcaster()

    # ------------------------------------------------------------------
    # Public scan orchestrator
    # ------------------------------------------------------------------

    async def run_disruption_scan(self, org_id: UUID) -> ScanResult:
        """
        Full pipeline for *org_id*:
          1. Fetch all active node locations from Supabase.
          2. For every node, call Open-Meteo and collect disruption events.
          3. For each event, geo-intersect to find affected assets.
          4. Write alerts and broadcast.

        Returns a ScanResult summarising how many alerts were generated.
        """
        scan_start = time.monotonic()
        logger.info(
            "Starting disruption scan",
            extra={"org_id": str(org_id), "action": "run_disruption_scan"},
        )

        supabase = get_supabase_client()
        # RLS: always include organization_id
        response = (
            supabase.table("supply_chain_nodes")
            .select("id, location, status")
            .eq("organization_id", str(org_id))
            .is_("deleted_at", "null")
            .execute()
        )
        nodes = response.data or []
        nodes_scanned = len(nodes)
        alert_ids: List[UUID] = []

        for node in nodes:
            node_id = UUID(node["id"])
            location = node.get("location") or {}
            # location is stored as GeoJSON Point: {"type":"Point","coordinates":[lon,lat]}
            coords = location.get("coordinates", [])
            if len(coords) < 2:
                continue
            lon, lat = float(coords[0]), float(coords[1])

            try:
                disruptions = await self.fetch_weather_disruptions(lat, lon, _DEFAULT_RADIUS_KM)
            except Exception as exc:  # noqa: BLE001
                logger.warning(
                    "Weather fetch failed for node %s: %s", node_id, exc,
                    extra={"org_id": str(org_id), "action": "fetch_weather_disruptions"},
                )
                continue

            for disruption in disruptions:
                try:
                    affected = await self.geo_intersect_check(disruption, org_id)
                    if not affected:
                        continue
                    alert_id = await self.write_disruption_alert(disruption, affected, org_id)
                    await self.broadcast_alert(alert_id, org_id)
                    alert_ids.append(alert_id)
                except Exception as exc:  # noqa: BLE001
                    logger.error(
                        "Error processing disruption %s: %s", disruption.id, exc,
                        extra={"org_id": str(org_id), "action": "process_disruption"},
                    )

        duration_ms = int((time.monotonic() - scan_start) * 1000)
        logger.info(
            "Disruption scan complete",
            extra={
                "org_id": str(org_id),
                "action": "run_disruption_scan",
                "nodes_scanned": nodes_scanned,
                "alerts_generated": len(alert_ids),
                "duration_ms": duration_ms,
            },
        )
        return ScanResult(
            org_id=org_id,
            scanned_at=datetime.now(timezone.utc),
            nodes_scanned=nodes_scanned,
            alerts_generated=len(alert_ids),
            alert_ids=alert_ids,
        )

    # ------------------------------------------------------------------
    # Step 1 — Fetch weather disruptions from Open-Meteo
    # ------------------------------------------------------------------

    async def fetch_weather_disruptions(
        self, lat: float, lon: float, radius_km: int
    ) -> List[DisruptionEvent]:
        """
        Calls Open-Meteo /forecast with hourly weather_code.
        Flags WMO codes 75, 77, 82, 95, 99 as severe weather events.
        Returns structured DisruptionEvent objects with severity score.
        """
        await rate_limiter.acquire("openmeteo")
        url = f"{settings.OPENMETEO_BASE_URL}/forecast"
        params = {
            "latitude": lat,
            "longitude": lon,
            "hourly": "weather_code",
            "forecast_days": 1,
            "timezone": "UTC",
        }

        t0 = time.monotonic()
        async with httpx.AsyncClient(timeout=10.0) as client:
            try:
                resp = await client.get(url, params=params)
                resp.raise_for_status()
                duration_ms = int((time.monotonic() - t0) * 1000)
                logger.info(
                    "Open-Meteo response",
                    extra={
                        "action": "fetch_weather_disruptions",
                        "url": url,
                        "status": resp.status_code,
                        "duration_ms": duration_ms,
                    },
                )
                data = resp.json()
            except httpx.HTTPError as exc:
                logger.warning("Open-Meteo request failed: %s", exc)
                return []

        hourly = data.get("hourly", {})
        codes: List[int] = hourly.get("weather_code", [])
        times: List[str] = hourly.get("time", [])

        events: List[DisruptionEvent] = []
        for ts_str, code in zip(times, codes):
            if code not in _SEVERE_WEATHER_CODES:
                continue
            severity = _wmo_code_to_severity(code)
            event = DisruptionEvent(
                id=uuid.uuid4(),
                source="open_meteo",
                lat=lat,
                lon=lon,
                radius_km=float(radius_km),
                severity=severity,
                alert_type="weather",
                description=_wmo_code_description(code),
                detected_at=datetime.fromisoformat(ts_str).replace(tzinfo=timezone.utc),
                raw_payload={"weather_code": code, "forecast_time": ts_str},
            )
            events.append(event)

        return events

    # ------------------------------------------------------------------
    # Step 2 — Geo-intersect check
    # ------------------------------------------------------------------

    async def geo_intersect_check(
        self, disruption: DisruptionEvent, org_id: UUID
    ) -> List[IntersectedAsset]:
        """
        Executes PostGIS query against node_edges and supply_chain_nodes.
        Falls back to Haversine if PostGIS is unavailable.
        Returns list of IntersectedAsset objects for writing.
        """
        return await self._geo_engine.find_intersected_assets(
            lat=disruption.lat,
            lon=disruption.lon,
            radius_km=disruption.radius_km,
            org_id=org_id,
        )

    # ------------------------------------------------------------------
    # Step 3 — Write alert to Supabase
    # ------------------------------------------------------------------

    async def write_disruption_alert(
        self,
        disruption: DisruptionEvent,
        affected_assets: List[IntersectedAsset],
        org_id: UUID,
    ) -> UUID:
        """
        Writes a row to disruption_alerts.
        At least one of node_id / edge_id must be non-null per integrity rule.
        """
        node_ids = [str(a.asset_id) for a in affected_assets if a.asset_type == "node"]
        edge_ids = [str(a.asset_id) for a in affected_assets if a.asset_type == "edge"]

        # Use first node or edge as the FK anchor (table allows nullable, but one must exist)
        node_id: Optional[str] = node_ids[0] if node_ids else None
        edge_id: Optional[str] = edge_ids[0] if (not node_ids and edge_ids) else None

        payload: Dict[str, Any] = {
            **disruption.raw_payload,
            "all_affected_node_ids": node_ids,
            "all_affected_edge_ids": edge_ids,
            "source": disruption.source,
            "description": disruption.description,
            "lat": disruption.lat,
            "lon": disruption.lon,
            "radius_km": disruption.radius_km,
        }

        row = {
            "organization_id": str(org_id),
            "node_id": node_id,
            "edge_id": edge_id,
            "alert_type": disruption.alert_type,
            "severity": disruption.severity,
            "payload": payload,
            "created_at": disruption.detected_at.isoformat(),
        }

        t0 = time.monotonic()
        supabase = get_supabase_client()
        result = supabase.table("disruption_alerts").insert(row).execute()
        duration_ms = int((time.monotonic() - t0) * 1000)

        alert_id = UUID(result.data[0]["id"])
        logger.info(
            "Wrote disruption alert",
            extra={
                "action": "write_disruption_alert",
                "alert_id": str(alert_id),
                "org_id": str(org_id),
                "duration_ms": duration_ms,
            },
        )
        return alert_id

    # ------------------------------------------------------------------
    # Step 4 — Broadcast via Supabase Realtime
    # ------------------------------------------------------------------

    async def broadcast_alert(self, alert_id: UUID, org_id: UUID) -> None:
        """
        Fires Supabase Realtime broadcast on channel: org:{org_id}:alerts
        Flutter frontend listens and flashes affected nodes RED.
        """
        supabase = get_supabase_client()
        # Read the alert back to build the full payload
        result = (
            supabase.table("disruption_alerts")
            .select("*")
            .eq("id", str(alert_id))
            .eq("organization_id", str(org_id))
            .single()
            .execute()
        )
        row = result.data
        payload_data = row.get("payload", {})

        broadcast_payload = DisruptionBroadcastPayload(
            alert_id=alert_id,
            node_ids=[UUID(n) for n in payload_data.get("all_affected_node_ids", [])],
            edge_ids=[UUID(e) for e in payload_data.get("all_affected_edge_ids", [])],
            severity=row.get("severity", "low"),
            alert_type=row.get("alert_type", "weather"),
            timestamp=datetime.now(timezone.utc),
        )

        await self._broadcaster.broadcast_disruption(org_id, broadcast_payload)


# ------------------------------------------------------------------
# Private helpers
# ------------------------------------------------------------------

def _wmo_code_to_severity(code: int) -> str:
    """Map WMO weather code to severity level."""
    if code in {99}:
        return "critical"
    if code in {95}:
        return "high"
    if code in {82}:
        return "medium"
    return "low"  # 75, 77


def _wmo_code_description(code: int) -> str:
    """Human-readable description for flagged WMO codes."""
    descriptions = {
        75: "Heavy snowfall",
        77: "Snow grains",
        82: "Violent rain shower",
        95: "Thunderstorm",
        99: "Thunderstorm with heavy hail",
    }
    return descriptions.get(code, f"Severe weather (WMO code {code})")
