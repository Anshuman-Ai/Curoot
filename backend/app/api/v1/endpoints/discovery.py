"""
Module 2.3 — Node Discovery & Onboarding Search.

POST /api/v1/discovery/search

Tri-Layer Pull:
  Tier 1: Active Platform Network (supply_chain_nodes for org)
  Tier 2: Community Ecosystem (template_nodes from community_templates)
  Tier 3: External Fallback (OpenStreetMap Nominatim)

Includes in-memory LRU cache for Tier 3 results (M2 fix — SRS §2.3 Phase 2).
"""

from __future__ import annotations

import logging
import time
from collections import OrderedDict
from typing import Optional

from fastapi import APIRouter
from app.models.discovery import DiscoverySearchRequest, DiscoverySearchResponse, DiscoveryNode
from app.db.supabase import get_supabase_client
import httpx

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/discovery", tags=["discovery"])


# ── M2 Fix: LRU Cache for Tier 3 external search results ─────────────────
# SRS §2.3 Phase 2 specifies caching up to 2 alternatives locally.

class _ExternalSearchCache:
    """Thread-safe LRU cache for OSM search results with TTL."""
    
    def __init__(self, max_size: int = 100, ttl_seconds: int = 3600):
        self._cache: OrderedDict[str, tuple[float, list]] = OrderedDict()
        self._max_size = max_size
        self._ttl = ttl_seconds

    def get(self, key: str) -> Optional[list]:
        if key in self._cache:
            ts, data = self._cache[key]
            if time.monotonic() - ts < self._ttl:
                self._cache.move_to_end(key)
                return data
            else:
                del self._cache[key]
        return None

    def put(self, key: str, data: list) -> None:
        if key in self._cache:
            self._cache.move_to_end(key)
        self._cache[key] = (time.monotonic(), data)
        while len(self._cache) > self._max_size:
            self._cache.popitem(last=False)


_osm_cache = _ExternalSearchCache(max_size=200, ttl_seconds=3600)


@router.post("/search", response_model=DiscoverySearchResponse)
async def search_nodes(request: DiscoverySearchRequest):
    supabase = get_supabase_client()
    results = []

    # Tier 1: Active Nodes (Query supply_chain_nodes for this org)
    try:
        t1_resp = supabase.table("supply_chain_nodes") \
            .select("id, name, node_type, status") \
            .eq("organization_id", request.organization_id) \
            .ilike("name", f"%{request.query}%") \
            .is_("deleted_at", "null") \
            .execute()
        
        for row in t1_resp.data or []:
            results.append(DiscoveryNode(
                id=str(row.get("id")),
                label=row.get("name") or "Unknown",
                tier=1,
                type=row.get("node_type", "supplier"),
                status=row.get("status", "active")
            ))
    except Exception as e:
        logger.warning("Tier 1 search error: %s", e)

    # Tier 2: Community Nodes (Query template_nodes)
    try:
        t2_resp = supabase.table("template_nodes") \
            .select("id, name, node_type") \
            .ilike("name", f"%{request.query}%") \
            .execute()
            
        for row in t2_resp.data or []:
            results.append(DiscoveryNode(
                id=f"tpl_{row.get('id')}",
                label=row.get("name") or "Community Node",
                tier=2,
                type=row.get("node_type", "supplier"),
                status="pending"
            ))
    except Exception as e:
        logger.warning("Tier 2 search error: %s", e)

    # Tier 3: External (OpenStreetMap Nominatim) — with LRU cache (M2 fix)
    cache_key = f"{request.query.lower().strip()}:{request.radius}"
    cached = _osm_cache.get(cache_key)
    
    if cached is not None:
        logger.debug("Tier 3 cache HIT for query '%s'", request.query)
        results.extend(cached)
    else:
        tier3_results = []
        try:
            async with httpx.AsyncClient() as client:
                osm_url = (
                    f"https://nominatim.openstreetmap.org/search"
                    f"?q={request.query}&format=json&limit=2"
                )
                osm_resp = await client.get(
                    osm_url,
                    headers={"User-Agent": "Curoot-App/1.0"},
                    timeout=10.0,
                )
                if osm_resp.status_code == 200:
                    osm_data = osm_resp.json()
                    for i, item in enumerate(osm_data):
                        node = DiscoveryNode(
                            id=f"osm_{item.get('osm_id', i)}",
                            label=item.get("display_name", "OSM Node").split(',')[0],
                            tier=3,
                            type="unverified",
                            status="pending",
                            lat=float(item.get("lat") or 0.0),
                            lon=float(item.get("lon") or 0.0)
                        )
                        tier3_results.append(node)
        except Exception as e:
            logger.warning("Tier 3 search error: %s", e)
        
        # Cache the results (even if empty, to avoid repeated failed lookups)
        _osm_cache.put(cache_key, tier3_results)
        results.extend(tier3_results)

    return DiscoverySearchResponse(results=results)
