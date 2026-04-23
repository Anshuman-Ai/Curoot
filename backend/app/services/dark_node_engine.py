"""
Module 2.7.3 — Dark Node Predictive Engine.

Anticipates supplier silence and shifts into predictive modeling.
Calculates dynamic risk scores and auto-pings high-risk dark nodes
to create a self-healing network.

Confidence Score = 0.25×relational + 0.25×historical + 0.20×macro + 0.30×silence
"""

from __future__ import annotations

import logging
import time
import uuid
from datetime import datetime, timezone
from typing import List
from uuid import UUID

from app.db.supabase import get_supabase_client
from app.models.heartbeat import DarkNodePingResponse, DarkNodeScore

logger = logging.getLogger(__name__)

# Global threshold for V1 — designed for easy migration to org_preferences in V2
DARK_NODE_SILENCE_HOURS = 24          # hours without heartbeat → candidate
DARK_NODE_THRESHOLD = 0.70            # composite score to mark as dark
AUTO_PING_THRESHOLD = 0.80            # composite score to trigger auto-ping

# Scoring weights
W_RELATIONAL = 0.25
W_HISTORICAL = 0.25
W_MACRO = 0.20
W_SILENCE = 0.30


class DarkNodeEngine:
    """
    Predictive engine that scores silent nodes and auto-pings high-risk ones.

    Data flow:
        scan_for_dark_nodes (APScheduler every 20 min)
            → calculate_dark_node_score per node
            → mark dark nodes in DB
        auto_ping_dark_nodes (APScheduler every 60 min)
            → send targeted pings to critical dark nodes
    """

    # ------------------------------------------------------------------
    # 1. Calculate risk score for a single node
    # ------------------------------------------------------------------

    def calculate_dark_node_score(
        self,
        node: dict,
        macro_risk_map: dict[str, float],
        max_volume: float,
    ) -> DarkNodeScore:
        """
        Compute composite risk score for a potentially silent node.

        Args:
            node: Row from supply_chain_nodes with heartbeat fields.
            macro_risk_map: country_code → risk_score (0-1) from macro signals.
            max_volume: Maximum volume_weight across all org nodes (for normalisation).

        Returns:
            DarkNodeScore with component and composite scores.
        """
        node_id = str(node["id"])
        node_name = node.get("name", "Unknown")

        # --- Relational Impact (0-1): volume weight normalised ---
        volume = float(node.get("volume_weight") or 1.0)
        relational = min(volume / max(max_volume, 1.0), 1.0)

        # --- Historical Reliability (0-1): inverse of delay rate ---
        delay_rate = float(node.get("historical_delay_rate") or 0.0)
        historical = min(delay_rate, 1.0)  # higher delay_rate = higher risk

        # --- Macro-Environmental Fusion (0-1) ---
        # Cross-reference node location with macro signals
        location = node.get("location") or {}
        coords = location.get("coordinates", []) if isinstance(location, dict) else []
        macro = 0.0
        if len(coords) >= 2:
            # Look up country from metadata, fallback to 0
            country = (node.get("metadata") or {}).get("country_code", "")
            if country and country in macro_risk_map:
                macro = macro_risk_map[country]

        # --- Silence Duration (0-1) ---
        last_hb = node.get("last_heartbeat_at")
        silence_hours = 0.0
        if last_hb:
            try:
                last_hb_dt = datetime.fromisoformat(
                    str(last_hb).replace("Z", "+00:00")
                )
                silence_hours = (
                    datetime.now(timezone.utc) - last_hb_dt
                ).total_seconds() / 3600
            except (ValueError, TypeError):
                silence_hours = DARK_NODE_SILENCE_HOURS * 2  # assume very stale
        else:
            # Never had a heartbeat — treat as maximum silence
            silence_hours = DARK_NODE_SILENCE_HOURS * 3

        # Normalise silence: 0 at 0h, 1.0 at 2× threshold
        silence_score = min(silence_hours / (DARK_NODE_SILENCE_HOURS * 2), 1.0)

        # --- Composite ---
        composite = (
            W_RELATIONAL * relational
            + W_HISTORICAL * historical
            + W_MACRO * macro
            + W_SILENCE * silence_score
        )

        return DarkNodeScore(
            node_id=node_id,
            node_name=node_name,
            relational_impact=round(relational, 3),
            historical_reliability=round(historical, 3),
            macro_risk=round(macro, 3),
            silence_duration_hours=round(silence_hours, 1),
            silence_score=round(silence_score, 3),
            composite_score=round(composite, 3),
            is_dark_node=composite >= DARK_NODE_THRESHOLD,
            last_heartbeat_at=str(last_hb) if last_hb else None,
        )

    # ------------------------------------------------------------------
    # 2. Scan all nodes for dark node status (scheduled)
    # ------------------------------------------------------------------

    async def scan_for_dark_nodes(self, org_id: UUID) -> List[DarkNodeScore]:
        """
        Scheduled scan: evaluate every node in the org for dark node risk.

        1. Fetch all active nodes
        2. Fetch macro risk signals for cross-referencing
        3. Score each node
        4. Update is_dark_node + heartbeat_confidence in DB
        """
        t0 = time.monotonic()
        supabase = get_supabase_client()

        # Fetch all active nodes with heartbeat fields
        resp = (
            supabase.table("supply_chain_nodes")
            .select(
                "id, name, status, location, metadata, "
                "volume_weight, historical_delay_rate, "
                "last_heartbeat_at, is_dark_node, node_type"
            )
            .eq("organization_id", str(org_id))
            .is_("deleted_at", "null")
            .execute()
        )
        nodes = resp.data or []
        if not nodes:
            return []

        # Max volume for normalisation
        max_volume = max(float(n.get("volume_weight") or 1.0) for n in nodes)

        # Fetch macro risk signals (latest per country)
        macro_resp = (
            supabase.table("macro_environment_signals")
            .select("country_code, risk_level, confidence")
            .order("recorded_at", desc=True)
            .limit(100)
            .execute()
        )
        macro_risk_map: dict[str, float] = {}
        _risk_to_score = {"critical": 1.0, "high": 0.75, "medium": 0.5, "low": 0.1}
        for sig in macro_resp.data or []:
            cc = sig.get("country_code", "")
            if cc and cc not in macro_risk_map:
                level = sig.get("risk_level", "low")
                macro_risk_map[cc] = _risk_to_score.get(level, 0.1)

        # Score each node
        scores: List[DarkNodeScore] = []
        for node in nodes:
            score = self.calculate_dark_node_score(node, macro_risk_map, max_volume)
            scores.append(score)

            # Update DB if status changed
            current_dark = bool(node.get("is_dark_node"))
            if score.is_dark_node != current_dark or True:
                supabase.table("supply_chain_nodes").update({
                    "is_dark_node": score.is_dark_node,
                    "heartbeat_confidence": 1.0 - score.composite_score,
                }).eq("id", score.node_id).execute()

        duration_ms = int((time.monotonic() - t0) * 1000)
        dark_count = sum(1 for s in scores if s.is_dark_node)
        logger.info(
            "Dark node scan complete",
            extra={
                "action": "scan_for_dark_nodes",
                "org_id": str(org_id),
                "total_nodes": len(scores),
                "dark_count": dark_count,
                "duration_ms": duration_ms,
            },
        )
        return scores

    # ------------------------------------------------------------------
    # 3. Auto-ping critical dark nodes (scheduled)
    # ------------------------------------------------------------------

    async def auto_ping_dark_nodes(self, org_id: UUID) -> List[DarkNodePingResponse]:
        """
        For dark nodes with composite_score > AUTO_PING_THRESHOLD,
        automatically generate a targeted status request via the
        supplier's magic link interface.

        Creates a self-healing network that only spends compute
        and effort on high-risk zones.
        """
        t0 = time.monotonic()
        supabase = get_supabase_client()

        # Find dark nodes above auto-ping threshold
        resp = (
            supabase.table("supply_chain_nodes")
            .select("id, name, heartbeat_confidence, is_dark_node")
            .eq("organization_id", str(org_id))
            .eq("is_dark_node", True)
            .is_("deleted_at", "null")
            .execute()
        )
        dark_nodes = resp.data or []
        results: List[DarkNodePingResponse] = []

        for node in dark_nodes:
            node_id = str(node["id"])
            confidence = float(node.get("heartbeat_confidence") or 1.0)
            composite = 1.0 - confidence  # inverse

            if composite < AUTO_PING_THRESHOLD:
                continue

            # Check for existing active magic link
            link_resp = (
                supabase.table("magic_link_tokens")
                .select("token")
                .eq("node_id", node_id)
                .eq("is_revoked", False)
                .gt("expires_at", datetime.now(timezone.utc).isoformat())
                .limit(1)
                .execute()
            )

            if not link_resp.data:
                results.append(DarkNodePingResponse(
                    node_id=node_id,
                    ping_sent=False,
                    error="No active magic link — OEM must generate one first",
                ))
                continue

            # Insert auto-ping message
            msg_id = str(uuid.uuid4())
            now_iso = datetime.now(timezone.utc).isoformat()
            ping_text = (
                "🔔 Automated Status Check: Your supply chain partner has not "
                "received an update from your node recently. Please confirm your "
                "current operational status by replying to this message."
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
                "action": "auto_ping",
                "metadata": {
                    "composite_score": composite,
                    "threshold": AUTO_PING_THRESHOLD,
                },
            }).execute()

            results.append(DarkNodePingResponse(
                node_id=node_id,
                ping_sent=True,
                message_id=msg_id,
            ))

        # Broadcast ping events to OEM canvas
        if results:
            try:
                pinged_ids = [r.node_id for r in results if r.ping_sent]
                if pinged_ids:
                    supabase.channel(f"org:{org_id}:heartbeat").send(
                        type="broadcast",
                        event="auto_ping_sent",
                        payload={
                            "pinged_node_ids": pinged_ids,
                            "timestamp": datetime.now(timezone.utc).isoformat(),
                        },
                    )
            except Exception as exc:
                logger.warning("Auto-ping broadcast failed: %s", exc)

        duration_ms = int((time.monotonic() - t0) * 1000)
        logger.info(
            "Auto-ping complete",
            extra={
                "action": "auto_ping_dark_nodes",
                "org_id": str(org_id),
                "pinged": sum(1 for r in results if r.ping_sent),
                "skipped": sum(1 for r in results if not r.ping_sent),
                "duration_ms": duration_ms,
            },
        )
        return results


# Module-level singleton
dark_node_engine = DarkNodeEngine()
