"""
Modules 2.6A & 2.6B — Insights Engine + Tradeoffs Calculator.

InsightsEngine  (2.6A): generates reroute suggestions when a node is disrupted.
TradeoffsEngine (2.6B): computes a precise 4-axis comparison between two nodes.
"""

from __future__ import annotations

import logging
import math
import time
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple
from uuid import UUID

import httpx

from app.core.config import settings
from app.db.supabase import get_supabase_client
from app.models.tradeoffs import (
    MetricResult,
    RerouteSuggestion,
    TradeoffAnalysisResponse,
    TradeoffRequest,
)
from app.utils.rate_limiter import rate_limiter

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Carbon emission constants (kg CO₂ per tonne-km)  — hardcoded per spec
# ---------------------------------------------------------------------------
EMISSION_FACTORS_KG_CO2_PER_TONNE_KM: Dict[str, float] = {
    "road": 0.062,
    "sea": 0.008,
    "air": 0.602,
    "rail": 0.022,
    "multimodal": 0.040,
}
AVG_SHIPMENT_WEIGHT_TONNES = 20.0  # default if not in telemetry

# Rerouting cost surcharge constant
_REROUTE_COST_PER_KM_USD = 0.12
# Average truck speed for time fallback
_AVG_SPEED_KMH = 80.0


# ===========================================================================
# 2.6A — Insights Engine
# ===========================================================================


class InsightsEngine:
    """
    Generates human-readable reroute suggestions when a node is flagged
    by Module 2.5A and pushes them to the Flutter canvas overlay.
    """

    async def generate_reroute_suggestion(
        self, disrupted_node_id: UUID, org_id: UUID
    ) -> List[RerouteSuggestion]:
        """
        1. Fetch all alternative paths in the 1-Hop graph for the org.
        2. For each alternative, compute time delta via OpenRouteService (or Haversine).
        3. Rank by lowest latency, then lowest carbon.
        4. Return a list of RerouteSuggestion objects.
        """
        supabase = get_supabase_client()

        # Fetch the disrupted node
        node_resp = (
            supabase.table("supply_chain_nodes")
            .select("*")
            .eq("id", str(disrupted_node_id))
            .eq("organization_id", str(org_id))
            .maybe_single()
            .execute()
        )
        disrupted_node = node_resp.data
        if not disrupted_node:
            logger.warning("Disrupted node %s not found for org %s", disrupted_node_id, org_id)
            return []

        # Fetch 1-hop alternative nodes (same node_type, same org, not deleted, not the disrupted one)
        alts_resp = (
            supabase.table("supply_chain_nodes")
            .select("*")
            .eq("organization_id", str(org_id))
            .eq("node_type", disrupted_node.get("node_type", ""))
            .neq("id", str(disrupted_node_id))
            .is_("deleted_at", "null")
            .limit(10)
            .execute()
        )
        alternatives = alts_resp.data or []

        suggestions: List[RerouteSuggestion] = []
        for alt in alternatives:
            try:
                suggestion = await self._build_suggestion(disrupted_node, alt)
                suggestions.append(suggestion)
            except Exception as exc:  # noqa: BLE001
                logger.warning("Error building suggestion for alt %s: %s", alt.get("id"), exc)

        # Rank: lowest time_saved_hours desc (most saved first), then lowest carbon_delta
        suggestions.sort(key=lambda s: (-s.time_saved_hours, s.carbon_delta_kg))
        return suggestions

    async def push_insight_to_canvas(
        self, node_id: UUID, org_id: UUID, suggestions: List[RerouteSuggestion]
    ) -> None:
        """
        Writes insights to disruption_alerts (alert_type='insight') and
        broadcasts to org:{org_id}:canvas-insights for Flutter overlay.
        """
        if not suggestions:
            return

        supabase = get_supabase_client()
        payload: Dict[str, Any] = {
            "suggestions": [s.model_dump() for s in suggestions],
            "generated_at": datetime.now(timezone.utc).isoformat(),
        }
        row = {
            "organization_id": str(org_id),
            "node_id": str(node_id),
            "edge_id": None,
            "alert_type": "insight",
            "severity": "low",
            "payload": payload,
        }

        t0 = time.monotonic()
        result = supabase.table("disruption_alerts").insert(row).execute()
        duration_ms = int((time.monotonic() - t0) * 1000)
        insight_id = result.data[0]["id"]
        logger.info(
            "Wrote canvas insight",
            extra={
                "action": "push_insight_to_canvas",
                "org_id": str(org_id),
                "node_id": str(node_id),
                "insight_id": insight_id,
                "duration_ms": duration_ms,
            },
        )

        # Broadcast to canvas-insights channel
        supabase.channel(f"org:{org_id}:canvas-insights").send(
            type="broadcast",
            event="insight",
            payload={
                "insight_id": insight_id,
                "node_id": str(node_id),
                "suggestions": payload["suggestions"],
            },
        )

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    async def _build_suggestion(
        self, disrupted: Dict[str, Any], alt: Dict[str, Any]
    ) -> RerouteSuggestion:
        d_coords = _extract_coords(disrupted)
        a_coords = _extract_coords(alt)

        time_saved_h, confidence = await _calc_time_delta_hours(d_coords, a_coords)
        carbon_delta = _calc_carbon_delta_kg(
            d_coords, a_coords,
            disrupted.get("transport_mode", "road"),
            alt.get("transport_mode", "road"),
        )
        alt_name = alt.get("name") or alt.get("id", "unknown")
        suggestion_text = (
            f"Reroute via {alt_name} saves ~{abs(time_saved_h):.0f}h"
            if time_saved_h > 0
            else f"Alternative via {alt_name} (+{abs(time_saved_h):.0f}h, lower risk)"
        )
        return RerouteSuggestion(
            suggestion_text=suggestion_text,
            time_saved_hours=time_saved_h,
            carbon_delta_kg=carbon_delta,
            confidence=confidence,
            alternative_node_id=UUID(alt["id"]),
        )


# ===========================================================================
# 2.6B — Tradeoffs Engine
# ===========================================================================


class TradeoffsEngine:
    """
    Computes a 4-axis tradeoff comparison between a disrupted node and
    a candidate alternative, persists the result, and returns the full analysis.
    """

    async def compute_tradeoff(
        self,
        current_node_id: UUID,
        alternative_node_id: UUID,
        org_id: UUID,
        disruption_alert_id: UUID,
    ) -> TradeoffAnalysisResponse:
        """
        Step 1: Fetch both nodes.
        Step 2: Calculate all 4 metrics.
        Step 3: Write TradeoffAnalysis + 4 TradeoffMetric rows.
        Step 4: Return full analysis object.
        """
        supabase = get_supabase_client()

        # Step 1 — fetch both nodes (RLS enforced)
        current = await _fetch_node(supabase, current_node_id, org_id)
        alternative = await _fetch_node(supabase, alternative_node_id, org_id)

        logger.info(
            "Computing tradeoff",
            extra={
                "action": "compute_tradeoff",
                "org_id": str(org_id),
                "current_node_id": str(current_node_id),
                "alternative_node_id": str(alternative_node_id),
            },
        )

        # Step 2 — calculate all 4 metrics
        financial = await self._calc_financial_delta(current, alternative)
        time_m = await self._calc_time_delta(current, alternative)
        carbon = await self._calc_carbon_delta(current, alternative)
        reliability = await self._calc_reliability_delta(current, alternative, org_id)

        metrics = [financial, time_m, carbon, reliability]

        # Determine overall recommendation
        improvements = sum(1 for m in metrics if m.is_improvement)
        if improvements >= 3:
            recommendation = "switch"
            confidence = 0.85 + (improvements - 3) * 0.05
        elif improvements == 2:
            recommendation = "investigate"
            confidence = 0.60
        else:
            recommendation = "stay"
            confidence = 0.75

        analysis_id = uuid.uuid4()
        created_at = datetime.now(timezone.utc)

        # Step 3 — write to DB in a transaction-like sequence
        t0 = time.monotonic()
        analysis_row = {
            "id": str(analysis_id),
            "organization_id": str(org_id),
            "current_node_id": str(current_node_id),
            "alternative_node_id": str(alternative_node_id),
            "disruption_alert_id": str(disruption_alert_id),
            "initiated_by": str(org_id),
            "overall_recommendation": recommendation,
            "recommendation_confidence": confidence,
            "created_at": created_at.isoformat(),
        }
        supabase.table("tradeoff_analyses").insert(analysis_row).execute()

        metric_rows = [
            {
                "analysis_id": str(analysis_id),
                "metric_type": m.metric_type,
                "current_value": m.current_value,
                "alternative_value": m.alternative_value,
                "delta": m.delta,
                "unit": m.unit,
            }
            for m in metrics
        ]
        supabase.table("tradeoff_metrics").insert(metric_rows).execute()

        duration_ms = int((time.monotonic() - t0) * 1000)
        logger.info(
            "Wrote tradeoff analysis",
            extra={
                "action": "compute_tradeoff",
                "analysis_id": str(analysis_id),
                "org_id": str(org_id),
                "recommendation": recommendation,
                "duration_ms": duration_ms,
            },
        )

        # Step 4 — return full response
        return TradeoffAnalysisResponse(
            analysis_id=analysis_id,
            org_id=org_id,
            current_node_id=current_node_id,
            alternative_node_id=alternative_node_id,
            disruption_alert_id=disruption_alert_id,
            metrics=metrics,
            overall_recommendation=recommendation,
            recommendation_confidence=min(1.0, confidence),
            created_at=created_at,
        )

    # ------------------------------------------------------------------
    # Axis 1 — Financial Cost
    # ------------------------------------------------------------------

    async def _calc_financial_delta(
        self, current: Dict[str, Any], alternative: Dict[str, Any]
    ) -> MetricResult:
        """
        Base: telemetry_events average cost (last 90 days).
        Rerouting surcharge: distance_delta_km × $0.12/km.
        """
        supabase = get_supabase_client()

        cur_cost = await _avg_telemetry_cost(supabase, UUID(current["id"]))
        alt_cost = await _avg_telemetry_cost(supabase, UUID(alternative["id"]))

        cur_coords = _extract_coords(current)
        alt_coords = _extract_coords(alternative)
        dist_delta = _haversine_km(*cur_coords, *alt_coords) if (cur_coords and alt_coords) else 0.0
        reroute_surcharge = dist_delta * _REROUTE_COST_PER_KM_USD

        alt_total = alt_cost + reroute_surcharge
        delta = alt_total - cur_cost

        return MetricResult(
            metric_type="financial",
            current_value=round(cur_cost, 2),
            alternative_value=round(alt_total, 2),
            delta=round(delta, 2),
            unit="USD",
            is_improvement=delta < 0,
        )

    # ------------------------------------------------------------------
    # Axis 2 — Time / Latency
    # ------------------------------------------------------------------

    async def _calc_time_delta(
        self, current: Dict[str, Any], alternative: Dict[str, Any]
    ) -> MetricResult:
        """
        Primary: OpenRouteService distance matrix API.
        Fallback: Haversine ÷ average speed constant.
        """
        cur_coords = _extract_coords(current)
        alt_coords = _extract_coords(alternative)

        cur_hours, alt_hours = await _ors_travel_time_hours(cur_coords, alt_coords)
        delta = alt_hours - cur_hours

        return MetricResult(
            metric_type="time",
            current_value=round(cur_hours, 2),
            alternative_value=round(alt_hours, 2),
            delta=round(delta, 2),
            unit="hours",
            is_improvement=delta < 0,
        )

    # ------------------------------------------------------------------
    # Axis 3 — Carbon Footprint (ESG)
    # ------------------------------------------------------------------

    async def _calc_carbon_delta(
        self, current: Dict[str, Any], alternative: Dict[str, Any]
    ) -> MetricResult:
        """
        Carbon = distance_km × emission_factor × avg_shipment_weight_tonnes.
        Uses transport_mode from node record; falls back to 'road'.
        """
        cur_coords = _extract_coords(current)
        alt_coords = _extract_coords(alternative)

        cur_dist = _haversine_km(*cur_coords, 0.0, 0.0) if cur_coords else 0.0
        alt_dist = _haversine_km(*alt_coords, 0.0, 0.0) if alt_coords else 0.0

        cur_mode = (current.get("transport_mode") or "road").lower()
        alt_mode = (alternative.get("transport_mode") or "road").lower()

        ef_cur = EMISSION_FACTORS_KG_CO2_PER_TONNE_KM.get(cur_mode, EMISSION_FACTORS_KG_CO2_PER_TONNE_KM["multimodal"])
        ef_alt = EMISSION_FACTORS_KG_CO2_PER_TONNE_KM.get(alt_mode, EMISSION_FACTORS_KG_CO2_PER_TONNE_KM["multimodal"])

        cur_carbon = cur_dist * ef_cur * AVG_SHIPMENT_WEIGHT_TONNES
        alt_carbon = alt_dist * ef_alt * AVG_SHIPMENT_WEIGHT_TONNES
        delta = alt_carbon - cur_carbon

        return MetricResult(
            metric_type="carbon",
            current_value=round(cur_carbon, 3),
            alternative_value=round(alt_carbon, 3),
            delta=round(delta, 3),
            unit="kg CO2",
            is_improvement=delta < 0,
        )

    # ------------------------------------------------------------------
    # Axis 4 — Historical Reliability
    # ------------------------------------------------------------------

    async def _calc_reliability_delta(
        self,
        current: Dict[str, Any],
        alternative: Dict[str, Any],
        org_id: UUID,
    ) -> MetricResult:
        """
        Queries telemetry_events for both nodes over the last 90 days.
        on_time_rate = COUNT(status='on_time') / COUNT(*) × 100
        """
        supabase = get_supabase_client()
        cur_rate = await _on_time_rate(supabase, UUID(current["id"]), org_id)
        alt_rate = await _on_time_rate(supabase, UUID(alternative["id"]), org_id)
        delta = alt_rate - cur_rate

        return MetricResult(
            metric_type="reliability",
            current_value=round(cur_rate, 2),
            alternative_value=round(alt_rate, 2),
            delta=round(delta, 2),
            unit="%",
            is_improvement=delta > 0,
        )


# ===========================================================================
# Module-level singletons
# ===========================================================================

insights_engine = InsightsEngine()
tradeoffs_engine = TradeoffsEngine()


# ===========================================================================
# Shared private helpers
# ===========================================================================


def _extract_coords(node: Dict[str, Any]) -> Tuple[float, float]:
    """Return (lat, lon) from a supply_chain_node record's GeoJSON location field."""
    import json
    loc = node.get("location") or {}
    if isinstance(loc, str):
        try:
            loc = json.loads(loc)
        except Exception:
            loc = {}
    coords = loc.get("coordinates", [])
    if len(coords) >= 2:
        return float(coords[1]), float(coords[0])  # GeoJSON is [lon, lat]
    return (0.0, 0.0)


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in km."""
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * R * math.asin(math.sqrt(max(0.0, a)))


async def _ors_travel_time_hours(
    cur_coords: Tuple[float, float],
    alt_coords: Tuple[float, float],
) -> Tuple[float, float]:
    """
    Tries OpenRouteService matrix API for both nodes.
    Falls back to Haversine ÷ average road speed on failure.
    """
    if not settings.OPENROUTE_KEY:
        logger.warning("OPENROUTE_KEY not set — using Haversine fallback for time calc")
        return _haversine_time_hours(cur_coords), _haversine_time_hours(alt_coords)

    await rate_limiter.acquire("openrouteservice")
    url = f"{settings.OPENROUTE_BASE_URL}/v2/matrix/driving-hv"
    # Use (0,0) as a dummy destination; in production supply real destination coords
    locations = [
        [cur_coords[1], cur_coords[0]],
        [alt_coords[1], alt_coords[0]],
        [0.0, 0.0],  # placeholder destination
    ]
    body = {
        "locations": locations,
        "metrics": ["duration"],
        "sources": [0, 1],
        "destinations": [2],
    }
    headers = {
        "Authorization": settings.OPENROUTE_KEY,
        "Content-Type": "application/json",
    }

    t0 = time.monotonic()
    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            resp = await client.post(url, json=body, headers=headers)
            resp.raise_for_status()
            duration_ms = int((time.monotonic() - t0) * 1000)
            logger.info(
                "ORS matrix response",
                extra={"action": "_ors_travel_time_hours", "status": resp.status_code, "duration_ms": duration_ms},
            )
            data = resp.json()
            durations = data.get("durations", [])
            cur_seconds = float((durations[0] or [None])[0] or 0.0)
            alt_seconds = float((durations[1] or [None])[0] or 0.0)
            return cur_seconds / 3600.0, alt_seconds / 3600.0
        except httpx.HTTPError as exc:
            logger.warning("ORS request failed: %s — falling back to Haversine", exc)
            return _haversine_time_hours(cur_coords), _haversine_time_hours(alt_coords)


def _haversine_time_hours(coords: Tuple[float, float]) -> float:
    """Approximate travel time in hours from origin (0,0) at AVG_SPEED_KMH."""
    dist = _haversine_km(0.0, 0.0, *coords)
    return dist / _AVG_SPEED_KMH


async def _calc_time_delta_hours(
    d_coords: Tuple[float, float],
    a_coords: Tuple[float, float],
) -> Tuple[float, float]:
    """Return (time_saved_hours, confidence)."""
    cur_h, alt_h = await _ors_travel_time_hours(d_coords, a_coords)
    saved = cur_h - alt_h
    confidence = 0.85 if saved != 0.0 else 0.50
    return saved, confidence


def _calc_carbon_delta_kg(
    d_coords: Tuple[float, float],
    a_coords: Tuple[float, float],
    d_mode: str,
    a_mode: str,
) -> float:
    """Carbon delta (kg CO₂) between disrupted and alternative routes."""
    ef_d = EMISSION_FACTORS_KG_CO2_PER_TONNE_KM.get(d_mode.lower(), 0.040)
    ef_a = EMISSION_FACTORS_KG_CO2_PER_TONNE_KM.get(a_mode.lower(), 0.040)
    dist_d = _haversine_km(0.0, 0.0, *d_coords)
    dist_a = _haversine_km(0.0, 0.0, *a_coords)
    carbon_d = dist_d * ef_d * AVG_SHIPMENT_WEIGHT_TONNES
    carbon_a = dist_a * ef_a * AVG_SHIPMENT_WEIGHT_TONNES
    return round(carbon_a - carbon_d, 3)


async def _avg_telemetry_cost(supabase: Any, node_id: UUID) -> float:
    """Average cost_usd from telemetry_events for the past 90 days."""
    try:
        ninety_days_ago = (datetime.now(timezone.utc) - __import__('datetime').timedelta(days=90)).isoformat()
        resp = (
            supabase.table("telemetry_events")
            .select("cost_usd")
            .eq("node_id", str(node_id))
            .gte("recorded_at", ninety_days_ago)
            .execute()
        )
        data = getattr(resp, "data", []) or []
        values = [float(r["cost_usd"]) for r in data if r.get("cost_usd") is not None]
        return sum(values) / len(values) if values else 0.0
    except Exception:  # noqa: BLE001
        return 0.0


async def _on_time_rate(supabase: Any, node_id: UUID, org_id: UUID) -> float:
    """on_time_rate = COUNT(status='on_time') / COUNT(*) × 100 for last 90 days."""
    try:
        ninety_days_ago = (datetime.now(timezone.utc) - __import__('datetime').timedelta(days=90)).isoformat()
        all_resp = (
            supabase.table("telemetry_events")
            .select("id, status", count="exact")
            .eq("node_id", str(node_id))
            .eq("organization_id", str(org_id))
            .gte("recorded_at", ninety_days_ago)
            .execute()
        )
        all_data = getattr(all_resp, "data", []) or []
        total = getattr(all_resp, "count", 0) or len(all_data)
        if total == 0:
            return 100.0  # no data → assume reliable

        on_time_resp = (
            supabase.table("telemetry_events")
            .select("id", count="exact")
            .eq("node_id", str(node_id))
            .eq("organization_id", str(org_id))
            .eq("status", "on_time")
            .gte("recorded_at", ninety_days_ago)
            .execute()
        )
        on_time_data = getattr(on_time_resp, "data", []) or []
        on_time = getattr(on_time_resp, "count", 0) or len(on_time_data)
        return (on_time / total) * 100.0
    except Exception:  # noqa: BLE001
        return 100.0


async def _fetch_node(supabase: Any, node_id: UUID, org_id: UUID) -> Dict[str, Any]:
    """Fetch a supply_chain_node record with RLS enforcement. Raises on not-found."""
    resp = (
        supabase.table("supply_chain_nodes")
        .select("*")
        .eq("id", str(node_id))
        .eq("organization_id", str(org_id))
        .maybe_single()
        .execute()
    )
    if getattr(resp, "data", None) is None:
        raise ValueError(f"Node {node_id} not found for org {org_id}")
    return resp.data
