"""
Module 2.7.1 — Supplier Chat Route (Token-Only Auth).

Serves the PWA chat interface and handles supplier messages.
No password, no app download — just a tokenized Magic Link.

Routes:
  GET  /supplier/chat               — Serve the PWA HTML page
  GET  /supplier/chat-data/{token}  — Validate + fetch history (PWA convenience)
  POST /supplier/chat/{token}       — Supplier submits a chat message
"""

from __future__ import annotations

import logging
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse

from app.models.heartbeat import ChatMessageResponse, SupplierChatMessage
from app.services.heartbeat_service import heartbeat_service

router = APIRouter(tags=["supplier"])
logger = logging.getLogger(__name__)

# Path to the static PWA file
_STATIC_DIR = Path(__file__).resolve().parents[4] / "static"
_CHAT_HTML = _STATIC_DIR / "supplier_chat.html"


@router.get("/supplier/chat", response_class=HTMLResponse)
async def serve_supplier_chat():
    """
    Serve the standalone Supplier Chat PWA.

    The token is passed as a query parameter (?token=xxx) and extracted
    by the frontend JavaScript — not validated here (validated on POST).
    """
    if not _CHAT_HTML.exists():
        raise HTTPException(
            status_code=404,
            detail="Supplier chat interface not found",
        )
    return HTMLResponse(content=_CHAT_HTML.read_text(encoding="utf-8"))


@router.get("/supplier/chat-data/{token}")
async def get_chat_data(token: str):
    """
    Convenience endpoint for the Magic Link PWA.

    Validates the token and returns the full chat context in a single call:
    - Token validity + node/org context
    - Chat history for the node

    This avoids the PWA needing two sequential requests on page load.
    """
    validation = await heartbeat_service.validate_magic_link(token)
    if not validation.valid:
        return {
            "valid": False,
            "error": validation.error or "Token invalid or expired",
        }

    history = await heartbeat_service.get_chat_history(
        node_id=validation.node_id, limit=100
    )

    return {
        "valid": True,
        "node_id": validation.node_id,
        "node_name": validation.node_name,
        "organization_name": validation.organization_name,
        "messages": [
            {
                "id": m.id,
                "sender_type": m.sender_type,
                "content": m.content,
                "parsed_data": m.parsed_data,
                "parse_confidence": m.parse_confidence,
                "created_at": m.created_at,
            }
            for m in history.messages
        ],
    }


@router.post("/supplier/chat/{token}", response_model=ChatMessageResponse)
async def handle_supplier_message(
    token: str,
    body: SupplierChatMessage,
):
    """
    Process a supplier's chat message.

    1. Validates the magic link token
    2. Parses the natural language message via NLP
    3. Commits structured update to the database
    4. Returns parsed confirmation to the supplier
    """
    result = await heartbeat_service.process_supplier_chat(
        token=token,
        message_text=body.message,
    )
    if result.status == "error":
        raise HTTPException(status_code=403, detail=result.confirmation)
    return result
