"""
Heartbeat Module (SRS §2.7) — Pydantic Models.

Covers:
  - Magic Link generation / validation
  - Supplier chat messages + NLP-parsed updates
  - Dark Node scoring
  - OEM dispatch messages
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# 2.7.1 — Magic Link
# ---------------------------------------------------------------------------

class MagicLinkCreate(BaseModel):
    """Request body to generate a magic link for one or more nodes."""
    node_ids: List[str] = Field(..., min_length=1, description="Node IDs to generate links for")
    organization_id: str = Field(..., description="OEM organization ID")
    expiry_days: int = Field(7, ge=1, le=30, description="Days until link expires (default 7)")


class MagicLinkResponse(BaseModel):
    """Single magic link result."""
    node_id: str
    token: str
    url: str
    expires_at: str


class MagicLinkBatchResponse(BaseModel):
    """Response containing one or more generated magic links."""
    links: List[MagicLinkResponse]


class MagicLinkValidation(BaseModel):
    """Result of validating a magic link token."""
    valid: bool
    node_id: Optional[str] = None
    node_name: Optional[str] = None
    organization_id: Optional[str] = None
    organization_name: Optional[str] = None
    partner_org_id: Optional[str] = None
    error: Optional[str] = None


# ---------------------------------------------------------------------------
# 2.7.1 — Supplier Chat & NLP Parsing
# ---------------------------------------------------------------------------

class SupplierChatMessage(BaseModel):
    """Incoming message from a supplier via the Magic Link chat interface."""
    message: str = Field(..., min_length=1, max_length=2000, description="Supplier's natural language message")


class ParsedNodeUpdate(BaseModel):
    """
    Output of the Pre-Database Local Parser.

    Translates a supplier's natural language message into strict schema updates.
    Example: "We are delayed by 2 days due to weather"
        → status=delayed, latency_hours=48, reason=weather, confidence=0.92
    """
    status: str = Field(
        "operational",
        description="Parsed status: operational, pending, delayed, offline",
    )
    latency_hours: Optional[float] = Field(
        None, description="Estimated delay in hours, if applicable"
    )
    reason: Optional[str] = Field(
        None, description="Brief reason for status change"
    )
    confidence: float = Field(
        0.0, ge=0.0, le=1.0, description="Parser confidence score"
    )


class HeartbeatPayload(BaseModel):
    """
    The single JSON payload committed to the database after parsing.

    Merges the raw chat message with the parsed schema update.
    """
    node_id: str
    organization_id: str
    raw_message: str
    parsed: ParsedNodeUpdate
    sender_type: str = Field("supplier", description="supplier or system")
    timestamp: Optional[str] = None


class ChatMessageResponse(BaseModel):
    """Response returned to the supplier after their message is processed."""
    status: str = Field("received", description="Message processing status")
    parsed: ParsedNodeUpdate
    confirmation: str = Field(..., description="Human-readable confirmation")
    message_id: str


# ---------------------------------------------------------------------------
# 2.7.1 — OEM Dispatch
# ---------------------------------------------------------------------------

class OemDispatchMessage(BaseModel):
    """OEM manager dispatches a message to supplier(s) via the canvas."""
    organization_id: str = Field(..., description="OEM organization ID")
    node_ids: List[str] = Field(..., min_length=1, description="Target node IDs")
    message: str = Field(..., min_length=1, max_length=2000, description="Message content")


class OemDispatchResponse(BaseModel):
    """Confirmation that the OEM message was dispatched."""
    dispatched_count: int
    message_ids: List[str]


# ---------------------------------------------------------------------------
# 2.7.2 — Chat History
# ---------------------------------------------------------------------------

class ChatHistoryEntry(BaseModel):
    """A single entry in the chat history for a node."""
    id: str
    sender_type: str  # 'oem', 'supplier', 'system', 'auto_ping'
    content: str
    parsed_data: Dict[str, Any] = Field(default_factory=dict)
    parse_confidence: float = 0.0
    created_at: str


class ChatHistoryResponse(BaseModel):
    """Full chat history for a node."""
    node_id: str
    messages: List[ChatHistoryEntry]
    total: int


# ---------------------------------------------------------------------------
# 2.7.3 — Dark Node Predictive Engine
# ---------------------------------------------------------------------------

class DarkNodeScore(BaseModel):
    """Confidence scoring output for a single node."""
    node_id: str
    node_name: str
    relational_impact: float = Field(0.0, ge=0.0, le=1.0)
    historical_reliability: float = Field(0.0, ge=0.0, le=1.0)
    macro_risk: float = Field(0.0, ge=0.0, le=1.0)
    silence_duration_hours: float = Field(0.0, ge=0.0)
    silence_score: float = Field(0.0, ge=0.0, le=1.0)
    composite_score: float = Field(0.0, ge=0.0, le=1.0)
    is_dark_node: bool = False
    last_heartbeat_at: Optional[str] = None


class DarkNodeListResponse(BaseModel):
    """List of dark nodes with their risk scores."""
    organization_id: str
    dark_nodes: List[DarkNodeScore]
    total_nodes: int
    dark_count: int
    scan_timestamp: str


class DarkNodePingResponse(BaseModel):
    """Response after pinging a dark node."""
    node_id: str
    ping_sent: bool
    message_id: Optional[str] = None
    error: Optional[str] = None
