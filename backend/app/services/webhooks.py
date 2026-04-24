"""
Module 2.5C — Alert Broadcaster & Alert State Manager.

Wraps Supabase Realtime broadcasts for disruption alerts,
macro-environment signals, and alert state updates.
"""

from __future__ import annotations

import logging
import time
from uuid import UUID

from app.db.supabase import get_supabase_client
from app.models.disruption import DisruptionBroadcastPayload
from app.models.macro_env import MacroBroadcastPayload

logger = logging.getLogger(__name__)


class AlertBroadcaster:
    """
    Fires Supabase Realtime broadcasts to per-org channels.

    Channels:
      org:{org_id}:alerts        — Flutter flashes nodes RED/AMBER
      org:{org_id}:macro-panel   — Flutter updates side panel
      org:{org_id}:canvas-insights — Flutter overlays suggestions on nodes
    """

    async def broadcast_disruption(
        self, org_id: UUID, payload: DisruptionBroadcastPayload
    ) -> None:
        """
        Broadcast to org:{org_id}:alerts.

        Payload schema:
          { alert_id, node_ids[], edge_ids[], severity, alert_type, timestamp }
        """
        channel_name = f"org:{org_id}:alerts"
        broadcast_payload = {
            "alert_id": str(payload.alert_id),
            "node_ids": [str(n) for n in payload.node_ids],
            "edge_ids": [str(e) for e in payload.edge_ids],
            "severity": payload.severity,
            "alert_type": payload.alert_type,
            "timestamp": payload.timestamp.isoformat(),
        }

        t0 = time.monotonic()
        try:
            supabase = get_supabase_client()
            supabase.channel(channel_name).send(
                type="broadcast",
                event="disruption_alert",
                payload=broadcast_payload,
            )
            duration_ms = int((time.monotonic() - t0) * 1000)
            logger.info(
                "Broadcast disruption alert",
                extra={
                    "action": "broadcast_disruption",
                    "channel": channel_name,
                    "alert_id": str(payload.alert_id),
                    "org_id": str(org_id),
                    "duration_ms": duration_ms,
                },
            )
        except Exception as exc:  # noqa: BLE001
            logger.error(
                "Failed to broadcast disruption to %s: %s", channel_name, exc,
                extra={"action": "broadcast_disruption", "org_id": str(org_id)},
            )

    async def broadcast_macro_update(
        self, org_id: UUID, payload: MacroBroadcastPayload
    ) -> None:
        """
        Broadcast to org:{org_id}:macro-panel.

        Payload schema:
          { country_code, risk_level, confidence, primary_driver, signals_summary }
        """
        channel_name = f"org:{org_id}:macro-panel"
        broadcast_payload = {
            "country_code": payload.country_code,
            "risk_level": payload.risk_level.value,
            "confidence": payload.confidence,
            "primary_driver": payload.primary_driver,
            "signals_summary": payload.signals_summary,
        }

        t0 = time.monotonic()
        try:
            supabase = get_supabase_client()
            supabase.channel(channel_name).send(
                type="broadcast",
                event="macro_update",
                payload=broadcast_payload,
            )
            duration_ms = int((time.monotonic() - t0) * 1000)
            logger.info(
                "Broadcast macro update",
                extra={
                    "action": "broadcast_macro_update",
                    "channel": channel_name,
                    "country_code": payload.country_code,
                    "risk_level": payload.risk_level.value,
                    "org_id": str(org_id),
                    "duration_ms": duration_ms,
                },
            )
        except Exception as exc:  # noqa: BLE001
            logger.error(
                "Failed to broadcast macro update to %s: %s", channel_name, exc,
                extra={"action": "broadcast_macro_update", "org_id": str(org_id)},
            )

    async def broadcast_upstream_alert(
        self, org_id: UUID, target_node_id: UUID, abstracted_payload: dict
    ) -> None:
        """
        Broadcast to org:{org_id}:upstream-alerts.

        Payload schema:
          { target_node_id, abstracted_payload }
        """
        channel_name = f"org:{org_id}:upstream-alerts"
        broadcast_payload = {
            "target_node_id": str(target_node_id),
            "abstracted_payload": abstracted_payload,
        }

        t0 = time.monotonic()
        try:
            supabase = get_supabase_client()
            supabase.channel(channel_name).send(
                type="broadcast",
                event="upstream_alert",
                payload=broadcast_payload,
            )
            duration_ms = int((time.monotonic() - t0) * 1000)
            logger.info(
                "Broadcast upstream alert",
                extra={
                    "action": "broadcast_upstream_alert",
                    "channel": channel_name,
                    "target_node_id": str(target_node_id),
                    "org_id": str(org_id),
                    "duration_ms": duration_ms,
                },
            )
        except Exception as exc:  # noqa: BLE001
            logger.error(
                "Failed to broadcast upstream alert to %s: %s", channel_name, exc,
                extra={"action": "broadcast_upstream_alert", "org_id": str(org_id)},
            )

    async def update_alert_state_table(
        self, alert_id: UUID, status: str
    ) -> None:
        """
        Updates alert_state table used by Flutter frontend for
        diff-based WebSocket sync.

        Valid status values: 'active', 'acknowledged', 'resolved'
        """
        t0 = time.monotonic()
        try:
            supabase = get_supabase_client()
            supabase.table("alert_state").upsert(
                {
                    "alert_id": str(alert_id),
                    "status": status,
                    "updated_at": "now()",
                },
                on_conflict="alert_id",
            ).execute()
            duration_ms = int((time.monotonic() - t0) * 1000)
            logger.info(
                "Updated alert state",
                extra={
                    "action": "update_alert_state_table",
                    "alert_id": str(alert_id),
                    "status": status,
                    "duration_ms": duration_ms,
                },
            )
        except Exception as exc:  # noqa: BLE001
            logger.error(
                "Failed to update alert state for %s: %s", alert_id, exc,
                extra={"action": "update_alert_state_table", "alert_id": str(alert_id)},
            )

alert_broadcaster = AlertBroadcaster()

