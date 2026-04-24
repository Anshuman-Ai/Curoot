"""
Module 2.4 — Zero-Knowledge Abstraction Engine.

Strips Tier-2+ identity from disruption events and generates sanitized payloads.
Propagates these delays to downstream partners.
"""

from __future__ import annotations

import logging
import time
from uuid import UUID
from typing import Any, Dict, List

from app.db.supabase import get_supabase_client
from app.models.abstraction import AbstractedPayload, CascadeResult
from app.services.webhooks import alert_broadcaster

logger = logging.getLogger(__name__)


class AbstractionEngine:
    """
    Handles zero-knowledge abstraction of upstream disruptions.
    """

    async def abstract_disruption(
        self,
        node: Dict[str, Any],
        disruption_event: Dict[str, Any],
        delay_hours: float
    ) -> AbstractedPayload:
        """
        Takes a raw disruption alert + affected node, strips identity/location,
        and produces an AbstractedPayload.
        """
        # Hardcode reason to 'Upstream Exception' to protect NDA boundaries
        return AbstractedPayload(
            status=f"Delayed ~{int(delay_hours)}h",
            reason="Upstream Exception",
            delay_hours=delay_hours,
            severity=disruption_event.get("severity", "medium")
        )

    async def calculate_cascade_delay(self, original_delay_hours: float) -> float:
        """
        Models how delay propagates: original_delay * dampening_factor + transit_buffer.
        """
        dampening_factor = 0.85
        edge_transit_buffer = 12.0
        return (original_delay_hours * dampening_factor) + edge_transit_buffer

    async def propagate_to_downstream(
        self,
        disrupted_node_id: UUID,
        org_id: UUID,
        disruption_event: Dict[str, Any]
    ) -> CascadeResult:
        """
        Finds all immediate downstream partner orgs, writes abstracted_payload
        to their node copy, and broadcasts via a new Realtime channel.
        """
        supabase = get_supabase_client()
        
        # 1. Fetch the disrupted node to get its details
        node_resp = (
            supabase.table("supply_chain_nodes")
            .select("*")
            .eq("id", str(disrupted_node_id))
            .eq("organization_id", str(org_id))
            .maybe_single()
            .execute()
        )
        node = node_resp.data
        if not node:
            logger.warning("Could not find disrupted node %s for abstraction", disrupted_node_id)
            return CascadeResult(source_node_id=disrupted_node_id, partners_notified=0, delay_propagated_hours=0)

        # 2. Estimate initial delay based on severity
        severity_delays = {"low": 12.0, "medium": 48.0, "high": 96.0, "critical": 168.0}
        initial_delay = severity_delays.get(disruption_event.get("severity", "medium"), 48.0)
        
        cascaded_delay = await self.calculate_cascade_delay(initial_delay)
        
        # 3. Create abstracted payload
        payload = await self.abstract_disruption(node, disruption_event, cascaded_delay)
        payload_dict = payload.model_dump()
        payload_dict["abstracted_at"] = payload.abstracted_at.isoformat()

        # 4. Find downstream partners
        # In this data model, a downstream partner is another org that has a supply_chain_nodes
        # record representing THIS org's node. That means we look for supply_chain_nodes where
        # partner_org_id = org_id.
        partners_resp = (
            supabase.table("supply_chain_nodes")
            .select("id, organization_id")
            .eq("partner_org_id", str(org_id))
            .is_("deleted_at", "null")
            .execute()
        )
        partners = partners_resp.data or []
        
        notified = 0
        for partner_node in partners:
            target_org_id = partner_node["organization_id"]
            target_node_id = partner_node["id"]
            
            # Skip self-references if any
            if target_org_id == str(org_id):
                continue
                
            try:
                t0 = time.monotonic()
                # Update the partner's node copy with the abstracted payload
                supabase.table("supply_chain_nodes").update({
                    "abstracted_payload": payload_dict,
                    "cascade_delay_hours": cascaded_delay,
                    "status": "delayed"
                }).eq("id", target_node_id).execute()
                
                # Write to downstream_alerts
                supabase.table("downstream_alerts").insert({
                    "source_org_id": str(org_id),
                    "target_org_id": target_org_id,
                    "target_node_id": target_node_id,
                    "abstracted_payload": payload_dict
                }).execute()
                
                duration_ms = int((time.monotonic() - t0) * 1000)
                logger.info(
                    "Propagated abstracted alert to downstream partner",
                    extra={
                        "source_org_id": str(org_id),
                        "target_org_id": target_org_id,
                        "duration_ms": duration_ms
                    }
                )
                
                # Broadcast
                await alert_broadcaster.broadcast_upstream_alert(
                    UUID(target_org_id),
                    UUID(target_node_id),
                    payload_dict
                )
                
                notified += 1
            except Exception as exc:
                logger.error("Failed to propagate abstracted alert to %s: %s", target_org_id, exc)

        return CascadeResult(
            source_node_id=disrupted_node_id,
            partners_notified=notified,
            delay_propagated_hours=cascaded_delay
        )

# Singleton
abstraction_engine = AbstractionEngine()
