"""
Module 2.7 — Heartbeat Service.

Implements:
  §2.7.1 — Magic Link generation / validation
  §2.7.1 — Pre-Database Local NLP Parser (Gemini 1.5 Flash)
  §2.7.2 — Database-Driven Orchestration (single JSON payload fan-out)
  §2.7.1 — OEM dispatch to supplier(s)
"""

from __future__ import annotations

import logging
import os
import secrets
import time
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional
from uuid import UUID

from app.db.supabase import get_supabase_client
from app.models.heartbeat import (
    ChatHistoryEntry,
    ChatHistoryResponse,
    ChatMessageResponse,
    MagicLinkResponse,
    MagicLinkValidation,
    OemDispatchResponse,
    ParsedNodeUpdate,
)

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Gemini client (reuses same setup as ai_service.py)
# ---------------------------------------------------------------------------
_MODEL_NAME = "gemini-1.5-flash"

try:
    from google import genai
    from google.genai import types as genai_types

    _api_key = os.getenv("GEMINI_API_KEY")
    _gemini_client = genai.Client(api_key=_api_key) if _api_key else None
except ImportError:
    _gemini_client = None
    genai_types = None  # type: ignore[assignment]

# ---------------------------------------------------------------------------
# NLP Parsing prompt
# ---------------------------------------------------------------------------
_PARSE_PROMPT = """You are a supply chain status parser. Given a supplier's natural language message, extract:

1. **status**: One of: operational, pending, delayed, offline
2. **latency_hours**: Estimated delay in hours (null if not applicable)
3. **reason**: Brief reason for the status (null if not mentioned)
4. **confidence**: Your confidence in the extraction (0.0 to 1.0)

Rules:
- "delayed by 2 days" → latency_hours: 48
- "everything is on track" → status: operational, latency_hours: null
- "factory shut down" → status: offline
- "waiting for materials" → status: pending
- If unsure, set confidence lower and default status to operational.

Respond ONLY with valid JSON matching this exact schema:
{"status": "...", "latency_hours": ..., "reason": "...", "confidence": ...}

Supplier message: """


class HeartbeatService:
    """
    Orchestrates the Heartbeat Module's core operations.

    Data flow:
        generate_magic_link → supplier opens PWA → sends chat message
        → parse_supplier_message (NLP) → process_supplier_chat (DB fan-out)
        → Supabase Realtime broadcast → OEM canvas updates
    """

    # ------------------------------------------------------------------
    # 1. Magic Link Generation
    # ------------------------------------------------------------------

    async def generate_magic_link(
        self,
        node_id: str,
        org_id: str,
        expiry_days: int = 7,
        base_url: str = "",
    ) -> MagicLinkResponse:
        """
        Generate a cryptographically secure magic link token for a node.

        Token is stored in magic_link_tokens with a 7-day default expiry.
        Returns a URL like: {base_url}/supplier/chat?token=xxx
        """
        token = secrets.token_urlsafe(48)
        expires_at = datetime.now(timezone.utc) + timedelta(days=expiry_days)

        t0 = time.monotonic()
        supabase = get_supabase_client()

        # Revoke any existing active tokens for this node
        supabase.table("magic_link_tokens").update(
            {"is_revoked": True}
        ).eq("node_id", node_id).eq("is_revoked", False).execute()

        # Insert new token
        row = {
            "token": token,
            "node_id": node_id,
            "organization_id": org_id,
            "expires_at": expires_at.isoformat(),
            "is_revoked": False,
        }
        supabase.table("magic_link_tokens").insert(row).execute()

        duration_ms = int((time.monotonic() - t0) * 1000)
        logger.info(
            "Magic link generated",
            extra={
                "action": "generate_magic_link",
                "node_id": node_id,
                "org_id": org_id,
                "duration_ms": duration_ms,
            },
        )

        if not base_url:
            base_url = "http://localhost:8000"

        url = f"{base_url}/supplier/chat?token={token}"
        return MagicLinkResponse(
            node_id=node_id,
            token=token,
            url=url,
            expires_at=expires_at.isoformat(),
        )

    # ------------------------------------------------------------------
    # 2. Magic Link Validation
    # ------------------------------------------------------------------

    async def validate_magic_link(self, token: str) -> MagicLinkValidation:
        """
        Validate a magic link token.

        Checks: exists, not revoked, not expired.
        Returns node context if valid.
        """
        supabase = get_supabase_client()
        try:
            resp = (
                supabase.table("magic_link_tokens")
                .select("*, supply_chain_nodes(id, name, organization_id, organizations(name))")
                .eq("token", token)
                .eq("is_revoked", False)
                .single()
                .execute()
            )
        except Exception:
            return MagicLinkValidation(valid=False, error="Token not found")

        row = resp.data
        if not row:
            return MagicLinkValidation(valid=False, error="Token not found")

        # Check expiry
        expires_at = datetime.fromisoformat(row["expires_at"].replace("Z", "+00:00"))
        if datetime.now(timezone.utc) > expires_at:
            return MagicLinkValidation(valid=False, error="Token expired")

        node = row.get("supply_chain_nodes", {})
        org = node.get("organizations", {}) if node else {}

        return MagicLinkValidation(
            valid=True,
            node_id=str(node.get("id", "")),
            node_name=node.get("name", "Unknown Node"),
            organization_id=str(node.get("organization_id", "")),
            organization_name=org.get("name", "Unknown Org"),
        )

    # ------------------------------------------------------------------
    # 3. Pre-Database Local NLP Parser
    # ------------------------------------------------------------------

    async def parse_supplier_message(self, raw_text: str) -> ParsedNodeUpdate:
        """
        Parse a supplier's natural language message into structured schema updates.

        Uses Gemini 1.5 Flash with a strict JSON prompt.
        Falls back to keyword heuristic if Gemini is unavailable.

        Example:
            "We are delayed by 2 days due to weather"
            → ParsedNodeUpdate(status="delayed", latency_hours=48,
                               reason="weather", confidence=0.92)
        """
        t0 = time.monotonic()

        if _gemini_client and genai_types:
            try:
                response = _gemini_client.models.generate_content(
                    model=_MODEL_NAME,
                    contents=_PARSE_PROMPT + raw_text,
                    config=genai_types.GenerateContentConfig(
                        response_mime_type="application/json",
                        response_schema=ParsedNodeUpdate,
                        temperature=0.0,
                    ),
                )
                if response.parsed:
                    duration_ms = int((time.monotonic() - t0) * 1000)
                    logger.info(
                        "NLP parse complete (Gemini)",
                        extra={
                            "action": "parse_supplier_message",
                            "status": response.parsed.status,
                            "confidence": response.parsed.confidence,
                            "duration_ms": duration_ms,
                        },
                    )
                    return response.parsed
            except Exception as exc:
                logger.warning("Gemini parse failed, using fallback: %s", exc)

        # Fallback: keyword heuristic
        return self._keyword_parse(raw_text)

    def _keyword_parse(self, text: str) -> ParsedNodeUpdate:
        """Deterministic keyword-based fallback parser."""
        msg = text.lower()

        # Offline indicators
        if any(kw in msg for kw in ("shut down", "offline", "closed", "halted", "stopped")):
            return ParsedNodeUpdate(status="offline", reason="facility closure indicated", confidence=0.60)

        # Delay indicators
        if any(kw in msg for kw in ("delay", "late", "behind", "slow", "congested", "strike")):
            hours = self._extract_hours(msg)
            reason = self._extract_reason(msg)
            return ParsedNodeUpdate(
                status="delayed",
                latency_hours=hours,
                reason=reason or "delay indicated",
                confidence=0.55,
            )

        # Pending indicators
        if any(kw in msg for kw in ("waiting", "pending", "hold", "not ready", "preparing")):
            return ParsedNodeUpdate(status="pending", reason="awaiting action", confidence=0.50)

        # Default: operational
        if any(kw in msg for kw in ("on track", "good", "fine", "ready", "shipped", "completed", "done")):
            return ParsedNodeUpdate(status="operational", reason="positive confirmation", confidence=0.65)

        return ParsedNodeUpdate(status="operational", reason="no clear signal", confidence=0.30)

    def _extract_hours(self, text: str) -> Optional[float]:
        """Extract delay duration in hours from text."""
        import re

        # "2 days" → 48
        match = re.search(r"(\d+)\s*day", text)
        if match:
            return float(match.group(1)) * 24

        # "48 hours" → 48
        match = re.search(r"(\d+)\s*hour", text)
        if match:
            return float(match.group(1))

        # "1 week" → 168
        match = re.search(r"(\d+)\s*week", text)
        if match:
            return float(match.group(1)) * 168

        return None

    def _extract_reason(self, text: str) -> Optional[str]:
        """Extract a brief reason from the message."""
        reasons = {
            "weather": "weather conditions",
            "rain": "weather conditions",
            "storm": "severe weather",
            "flood": "flooding",
            "strike": "labor strike",
            "customs": "customs delay",
            "port": "port congestion",
            "material": "material shortage",
            "shortage": "supply shortage",
            "power": "power outage",
            "machine": "equipment failure",
            "transport": "transportation issue",
            "shipping": "shipping delay",
        }
        msg = text.lower()
        for keyword, reason in reasons.items():
            if keyword in msg:
                return reason
        return None

    # ------------------------------------------------------------------
    # 4. Database-Driven Orchestration (§2.7.2)
    # ------------------------------------------------------------------

    async def process_supplier_chat(
        self, token: str, message_text: str
    ) -> ChatMessageResponse:
        """
        Full pipeline when a supplier sends a chat message:

        1. Validate magic link token
        2. Parse message with NLP
        3. Fire single JSON payload:
           - INSERT messages (with parsed_data)
           - UPDATE supply_chain_nodes (status, last_heartbeat_at, is_dark_node=false)
           - INSERT telemetry_events (heartbeat event)
           - INSERT communication_logs (immutable audit)
        4. Broadcast via Supabase Realtime
        5. Return confirmation to supplier
        """
        # Step 1: Validate
        validation = await self.validate_magic_link(token)
        if not validation.valid:
            return ChatMessageResponse(
                status="error",
                parsed=ParsedNodeUpdate(confidence=0.0),
                confirmation=f"Link error: {validation.error}",
                message_id="",
            )

        node_id = validation.node_id
        org_id = validation.organization_id
        t0 = time.monotonic()

        # Step 2: NLP Parse
        parsed = await self.parse_supplier_message(message_text)

        # Step 3: Single JSON payload — multiple DB writes
        supabase = get_supabase_client()
        now_iso = datetime.now(timezone.utc).isoformat()
        msg_id = str(uuid.uuid4())

        # 3a. INSERT message with parsed data
        supabase.table("messages").insert({
            "id": msg_id,
            "sender_org_id": org_id,
            "recipient_org_id": org_id,
            "node_id": node_id,
            "content": message_text,
            "message_type": "supplier_chat",
            "parsed_data": {
                "status": parsed.status,
                "latency_hours": parsed.latency_hours,
                "reason": parsed.reason,
            },
            "parse_confidence": parsed.confidence,
            "created_at": now_iso,
        }).execute()

        # 3b. UPDATE supply_chain_nodes
        node_update: Dict[str, Any] = {
            "status": parsed.status,
            "last_heartbeat_at": now_iso,
            "is_dark_node": False,
            "updated_at": now_iso,
        }
        if parsed.confidence >= 0.5:
            node_update["status"] = parsed.status
        supabase.table("supply_chain_nodes").update(
            node_update
        ).eq("id", node_id).execute()

        # 3c. INSERT telemetry_events
        supabase.table("telemetry_events").insert({
            "id": str(uuid.uuid4()),
            "node_id": node_id,
            "organization_id": org_id,
            "event_type": "heartbeat",
            "payload": {
                "source": "supplier_chat",
                "status": parsed.status,
                "latency_hours": parsed.latency_hours,
                "reason": parsed.reason,
                "confidence": parsed.confidence,
                "raw_message": message_text[:200],
            },
        }).execute()

        # 3d. INSERT communication_logs
        supabase.table("communication_logs").insert({
            "organization_id": org_id,
            "target_node_id": node_id,
            "message_id": msg_id,
            "action": "supplier_heartbeat",
            "metadata": {
                "parsed_status": parsed.status,
                "confidence": parsed.confidence,
            },
        }).execute()

        # Step 4: Broadcast (existing Realtime infrastructure handles node
        # updates automatically via the supply_chain_nodes subscription;
        # we also broadcast to a dedicated heartbeat channel for the chat)
        try:
            channel_name = f"org:{org_id}:heartbeat"
            supabase.channel(channel_name).send(
                type="broadcast",
                event="heartbeat_update",
                payload={
                    "node_id": node_id,
                    "status": parsed.status,
                    "message_id": msg_id,
                    "confidence": parsed.confidence,
                    "timestamp": now_iso,
                },
            )
        except Exception as exc:
            logger.warning("Heartbeat broadcast failed: %s", exc)

        duration_ms = int((time.monotonic() - t0) * 1000)
        logger.info(
            "Supplier chat processed",
            extra={
                "action": "process_supplier_chat",
                "node_id": node_id,
                "parsed_status": parsed.status,
                "confidence": parsed.confidence,
                "duration_ms": duration_ms,
            },
        )

        # Step 5: Build confirmation
        confirmation = self._build_confirmation(parsed)
        return ChatMessageResponse(
            status="received",
            parsed=parsed,
            confirmation=confirmation,
            message_id=msg_id,
        )

    def _build_confirmation(self, parsed: ParsedNodeUpdate) -> str:
        """Build a human-readable confirmation for the supplier."""
        parts = [f"✓ Status updated: {parsed.status.upper()}"]
        if parsed.latency_hours:
            parts.append(f"ETA delay: +{parsed.latency_hours:.0f}h")
        if parsed.reason:
            parts.append(f"Reason: {parsed.reason}")
        parts.append(f"Confidence: {parsed.confidence:.0%}")
        return " | ".join(parts)

    # ------------------------------------------------------------------
    # 5. OEM Dispatch (§2.7.1)
    # ------------------------------------------------------------------

    async def dispatch_oem_message(
        self, org_id: str, node_ids: List[str], message_text: str
    ) -> OemDispatchResponse:
        """
        OEM manager dispatches a message to one or more supplier nodes.

        Inserts into messages table, logs to communication_logs,
        and broadcasts to each node's heartbeat channel.
        """
        supabase = get_supabase_client()
        message_ids: List[str] = []
        now_iso = datetime.now(timezone.utc).isoformat()

        for node_id in node_ids:
            msg_id = str(uuid.uuid4())

            # Insert message
            supabase.table("messages").insert({
                "id": msg_id,
                "sender_org_id": org_id,
                "recipient_org_id": org_id,
                "node_id": node_id,
                "content": message_text,
                "message_type": "oem_dispatch",
                "created_at": now_iso,
            }).execute()

            # Log
            supabase.table("communication_logs").insert({
                "organization_id": org_id,
                "target_node_id": node_id,
                "message_id": msg_id,
                "action": "oem_dispatch",
                "metadata": {"message_preview": message_text[:100]},
            }).execute()

            message_ids.append(msg_id)

        # Broadcast to heartbeat channel
        try:
            channel_name = f"org:{org_id}:heartbeat"
            supabase.channel(channel_name).send(
                type="broadcast",
                event="oem_dispatch",
                payload={
                    "node_ids": node_ids,
                    "message_preview": message_text[:100],
                    "timestamp": now_iso,
                },
            )
        except Exception as exc:
            logger.warning("OEM dispatch broadcast failed: %s", exc)

        logger.info(
            "OEM message dispatched",
            extra={
                "action": "dispatch_oem_message",
                "org_id": org_id,
                "node_count": len(node_ids),
            },
        )

        return OemDispatchResponse(
            dispatched_count=len(message_ids),
            message_ids=message_ids,
        )

    # ------------------------------------------------------------------
    # 6. Chat History (§2.7.2)
    # ------------------------------------------------------------------

    async def get_chat_history(
        self, node_id: str, limit: int = 50
    ) -> ChatHistoryResponse:
        """Fetch the chat log for a specific node, ordered by most recent."""
        supabase = get_supabase_client()
        resp = (
            supabase.table("messages")
            .select("id, content, message_type, parsed_data, parse_confidence, created_at")
            .eq("node_id", node_id)
            .order("created_at", desc=False)
            .limit(limit)
            .execute()
        )

        entries = []
        for row in resp.data or []:
            msg_type = row.get("message_type", "text")
            sender_map = {
                "supplier_chat": "supplier",
                "oem_dispatch": "oem",
                "auto_ping": "system",
            }
            entries.append(ChatHistoryEntry(
                id=row["id"],
                sender_type=sender_map.get(msg_type, "system"),
                content=row.get("content", ""),
                parsed_data=row.get("parsed_data") or {},
                parse_confidence=row.get("parse_confidence") or 0.0,
                created_at=row.get("created_at", ""),
            ))

        return ChatHistoryResponse(
            node_id=node_id,
            messages=entries,
            total=len(entries),
        )


# Module-level singleton
heartbeat_service = HeartbeatService()
