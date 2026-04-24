"""
Pydantic models for Module 2.4 — Zero-Knowledge Abstraction.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class AbstractedPayload(BaseModel):
    """
    Sanitized representation of an upstream exception.
    Strips supplier identity, location, and specific disruption details.
    """
    status: str = "Delayed"
    reason: str = "Upstream Exception"
    delay_hours: float
    severity: str
    abstracted_at: datetime = Field(default_factory=datetime.utcnow)


class DownstreamAlert(BaseModel):
    """
    Database model for cross-org alert tracking.
    """
    id: Optional[UUID] = None
    source_org_id: UUID
    target_org_id: UUID
    target_node_id: UUID
    abstracted_payload: Dict[str, Any]
    created_at: Optional[datetime] = None


class CascadeResult(BaseModel):
    """
    Summary of the propagation process.
    """
    source_node_id: UUID
    partners_notified: int
    delay_propagated_hours: float
