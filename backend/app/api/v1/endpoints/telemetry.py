"""
Telemetry Endpoints — Record and query telemetry events.

These endpoints write to the telemetry_events table for time-series tracking
of node status changes, location updates, and crisis events.
"""

from __future__ import annotations

import logging
import uuid
from typing import Any, Dict, List

from fastapi import APIRouter, HTTPException, Query

from app.db.supabase import get_supabase_client
from app.models.telemetry import TelemetryEvent, TelemetryEventResponse

router = APIRouter(prefix="/telemetry", tags=["telemetry"])
logger = logging.getLogger(__name__)


@router.post("/events", response_model=Dict[str, Any])
async def record_telemetry_event(event: TelemetryEvent):
    """Record a telemetry event to the telemetry_events table."""
    try:
        supabase = get_supabase_client()
        row = {
            "id": str(uuid.uuid4()),
            "node_id": event.node_id,
            "organization_id": event.organization_id,
            "event_type": event.event_type,
            "payload": event.payload,
        }
        supabase.table("telemetry_events").insert(row).execute()
        return {"status": "success", "event_id": row["id"]}
    except Exception as exc:
        logger.error("Failed to record telemetry event: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to record telemetry event")


@router.get("/events", response_model=List[TelemetryEventResponse])
async def get_telemetry_events(
    node_id: str = Query(..., description="Node ID to query events for"),
    limit: int = Query(50, ge=1, le=500, description="Max events to return"),
):
    """Query telemetry events for a specific node, ordered by most recent."""
    try:
        supabase = get_supabase_client()
        resp = (
            supabase.table("telemetry_events")
            .select("*")
            .eq("node_id", node_id)
            .order("recorded_at", desc=True)
            .limit(limit)
            .execute()
        )
        return resp.data or []
    except Exception as exc:
        logger.error("Failed to query telemetry events: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to query telemetry events")
