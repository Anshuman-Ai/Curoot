"""Telemetry Pydantic models for the telemetry_events table."""

from __future__ import annotations

from typing import Any, Dict, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class TelemetryEvent(BaseModel):
    """Represents a single telemetry event from a supply chain node."""

    node_id: str = Field(..., description="ID of the supply chain node")
    organization_id: str = Field(..., description="ID of the organisation")
    event_type: str = Field(
        "status_update",
        description="Type of event: status_update, location_update, crisis",
    )
    payload: Dict[str, Any] = Field(
        default_factory=dict,
        description="Event payload containing status, location, or crisis data",
    )


class TelemetryEventResponse(BaseModel):
    """Response model for telemetry event queries."""

    id: str
    node_id: str
    organization_id: str
    event_type: str
    payload: Dict[str, Any]
    recorded_at: Optional[str] = None
