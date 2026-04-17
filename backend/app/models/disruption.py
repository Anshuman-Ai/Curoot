"""
Pydantic models for Module 2.5A — Physical Disruption Detection.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Literal
from uuid import UUID

from pydantic import BaseModel, Field


class DisruptionEvent(BaseModel):
    """Represents a single physical disruption event detected from an external source."""

    id: UUID
    source: Literal["open_meteo", "gdelt", "manual"]
    lat: float
    lon: float
    radius_km: float
    severity: Literal["low", "medium", "high", "critical"]
    alert_type: str  # "weather", "geopolitical", "traffic", "port_closure"
    description: str
    detected_at: datetime
    affected_node_ids: List[UUID] = Field(default_factory=list)
    affected_edge_ids: List[UUID] = Field(default_factory=list)
    raw_payload: Dict[str, Any]  # stored as JSONB in disruption_alerts


class IntersectedAsset(BaseModel):
    """An asset (node or edge) that falls within a disruption's geographic radius."""

    asset_id: UUID
    asset_type: Literal["node", "edge"]
    distance_from_epicenter_km: float


class ScanResult(BaseModel):
    """Summary returned after a full disruption scan for one organisation."""

    org_id: UUID
    scanned_at: datetime
    nodes_scanned: int
    alerts_generated: int
    alert_ids: List[UUID] = Field(default_factory=list)


class DisruptionBroadcastPayload(BaseModel):
    """Payload pushed over Supabase Realtime to the Flutter frontend."""

    alert_id: UUID
    node_ids: List[UUID] = Field(default_factory=list)
    edge_ids: List[UUID] = Field(default_factory=list)
    severity: str
    alert_type: str
    timestamp: datetime
