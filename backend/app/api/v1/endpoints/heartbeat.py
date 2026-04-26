"""
Module 2.7 — Heartbeat API Endpoints (OEM-authenticated).

Routes:
  POST /heartbeat/magic-link       — Generate magic link for node(s)
  GET  /heartbeat/validate/{token} — Validate a magic link token
  POST /heartbeat/dispatch         — OEM dispatches message to supplier(s)
  GET  /heartbeat/chat-history/{node_id} — Fetch chat log for a node
  GET  /heartbeat/dark-nodes       — List dark nodes with risk scores
  POST /heartbeat/ping/{node_id}   — Manual ping to a dark node
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, Query, Request

from app.core.security import get_current_org_id
from app.models.heartbeat import (
    ChatHistoryResponse,
    DarkNodeListResponse,
    DarkNodePingResponse,
    MagicLinkBatchResponse,
    MagicLinkCreate,
    MagicLinkValidation,
    OemDispatchMessage,
    OemDispatchResponse,
)
from app.services.dark_node_engine import dark_node_engine
from app.services.heartbeat_service import heartbeat_service

router = APIRouter(prefix="/heartbeat", tags=["heartbeat"])
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Magic Link
# ---------------------------------------------------------------------------

@router.post("/magic-link", response_model=MagicLinkBatchResponse)
async def generate_magic_links(
    body: MagicLinkCreate,
    request: Request,
):
    """Generate tokenized magic links for one or more nodes."""
    base_url = str(request.base_url).rstrip("/")
    links = []
    for node_id in body.node_ids:
        try:
            link = await heartbeat_service.generate_magic_link(
                node_id=node_id,
                org_id=body.organization_id,
                expiry_days=body.expiry_days,
                base_url=base_url,
            )
            links.append(link)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc))
    return MagicLinkBatchResponse(links=links)


@router.get("/validate/{token}", response_model=MagicLinkValidation)
async def validate_magic_link(token: str):
    """Validate a magic link token and return node context."""
    return await heartbeat_service.validate_magic_link(token)


# ---------------------------------------------------------------------------
# OEM Dispatch
# ---------------------------------------------------------------------------

@router.post("/dispatch", response_model=OemDispatchResponse)
async def dispatch_oem_message(body: OemDispatchMessage):
    """OEM manager dispatches a message to selected supplier node(s)."""
    return await heartbeat_service.dispatch_oem_message(
        org_id=body.organization_id,
        node_ids=body.node_ids,
        message_text=body.message,
    )


# ---------------------------------------------------------------------------
# Chat History
# ---------------------------------------------------------------------------

@router.get("/chat-history/{node_id}", response_model=ChatHistoryResponse)
async def get_chat_history(
    node_id: str,
    limit: int = Query(50, ge=1, le=200),
):
    """Fetch the full chat log for a specific node."""
    return await heartbeat_service.get_chat_history(node_id=node_id, limit=limit)


# ---------------------------------------------------------------------------
# Dark Nodes
# ---------------------------------------------------------------------------

@router.get("/dark-nodes", response_model=DarkNodeListResponse)
async def list_dark_nodes(
    org_id: UUID = Query(..., description="Organization ID"),
):
    """
    List all dark nodes with their risk scores for an organisation.
    Triggers a fresh scan before returning results.
    """
    scores = await dark_node_engine.scan_for_dark_nodes(org_id)
    dark_only = [s for s in scores if s.is_dark_node]
    return DarkNodeListResponse(
        organization_id=str(org_id),
        dark_nodes=dark_only,
        total_nodes=len(scores),
        dark_count=len(dark_only),
        scan_timestamp=datetime.now(timezone.utc).isoformat(),
    )


@router.post("/ping/{node_id}", response_model=DarkNodePingResponse)
async def ping_dark_node(
    node_id: str,
    org_id: UUID = Query(..., description="Organization ID"),
):
    """
    Manually ping a specific dark node to request a status update.
    Inserts an auto_ping message for the supplier.
    """
    from app.db.supabase import get_supabase_client
    import uuid as _uuid

    supabase = get_supabase_client()
    now_iso = datetime.now(timezone.utc).isoformat()

    # Check for active magic link
    link_resp = (
        supabase.table("magic_link_tokens")
        .select("token")
        .eq("node_id", node_id)
        .eq("is_revoked", False)
        .gt("expires_at", now_iso)
        .limit(1)
        .execute()
    )
    if not link_resp.data:
        return DarkNodePingResponse(
            node_id=node_id,
            ping_sent=False,
            error="No active magic link for this node. Generate one first.",
        )

    msg_id = str(_uuid.uuid4())
    ping_text = (
        "🔔 Status Check Requested: Your supply chain partner is requesting "
        "a status update for this node. Please reply with your current "
        "operational status."
    )

    supabase.table("messages").insert({
        "id": msg_id,
        "sender_org_id": str(org_id),
        "recipient_org_id": str(org_id),
        "node_id": node_id,
        "content": ping_text,
        "message_type": "auto_ping",
        "created_at": now_iso,
    }).execute()

    supabase.table("communication_logs").insert({
        "organization_id": str(org_id),
        "target_node_id": node_id,
        "message_id": msg_id,
        "action": "manual_ping",
        "metadata": {"triggered_by": "oem_dashboard"},
    }).execute()

    return DarkNodePingResponse(
        node_id=node_id,
        ping_sent=True,
        message_id=msg_id,
    )
