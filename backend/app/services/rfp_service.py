"""
Database-backed RFP rate limiter.

Enforces SRS §2.2 anti-bot abuse requirement:
  - Max 2 RFP requests per org+node pair per 24h
  - 1-day cooldown after limit reached
  - Persists across server restarts via `rfp_requests` table
"""

import asyncio
import logging
import datetime
from uuid import UUID

from app.db.supabase import get_supabase_client

logger = logging.getLogger(__name__)


async def check_rfp_rate_limit(org_id: str, node_id: str) -> dict:
    """
    Check if an RFP can be sent for this org+node combination.
    
    Returns:
        dict with keys:
          - allowed: bool
          - remaining: int (requests left in window)
          - cooldown_until: str | None (ISO timestamp if in cooldown)
    """
    supabase = get_supabase_client()
    cutoff = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=24)).isoformat()
    
    # Count RFPs sent in last 24h for this org+node
    resp = (
        supabase.table("rfp_requests")
        .select("id, created_at")
        .eq("organization_id", org_id)
        .eq("target_node_id", node_id)
        .gte("created_at", cutoff)
        .execute()
    )
    
    recent_rfps = resp.data or []
    count = len(recent_rfps)
    
    if count >= 2:
        # Find the earliest RFP in the window to calculate cooldown end
        earliest = min(r["created_at"] for r in recent_rfps)
        try:
            earliest_dt = datetime.datetime.fromisoformat(earliest.replace("Z", "+00:00"))
            cooldown_end = earliest_dt + datetime.timedelta(hours=24)
        except (ValueError, TypeError):
            cooldown_end = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=24)
        
        return {
            "allowed": False,
            "remaining": 0,
            "cooldown_until": cooldown_end.isoformat(),
        }
    
    return {
        "allowed": True,
        "remaining": 2 - count,
        "cooldown_until": None,
    }


async def record_rfp_request(org_id: str, node_id: str, template_id: str = None) -> str:
    """
    Record an RFP request in the database for rate-limiting persistence.
    
    Returns the rfp_request ID.
    """
    supabase = get_supabase_client()
    import uuid
    rfp_id = str(uuid.uuid4())
    
    supabase.table("rfp_requests").insert({
        "id": rfp_id,
        "organization_id": org_id,
        "target_node_id": node_id,
        "template_id": template_id,
        "status": "pending",
        "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }).execute()
    
    return rfp_id


async def process_template_rfps(org_id: str, nodes: list):
    """
    Process RFP requests sequentially for auto-applied template nodes.
    Applies the max 2 requests/day limit using DB-backed persistence.
    """
    for node in nodes:
        node_id = node.get('original_id', node.get('id', ''))
        
        # Check rate limit from DB
        limit_check = await check_rfp_rate_limit(org_id, node_id)
        
        if not limit_check["allowed"]:
            logger.warning(
                "RFP Cooldown enforced for Node %s (%s). Limit of 2/day reached. "
                "Cooldown until: %s",
                node.get('name', 'Unknown'), node_id, limit_check["cooldown_until"]
            )
            node['rfp_status'] = 'cooldown'
            continue
        
        # Record the RFP in DB for persistence
        await record_rfp_request(org_id, node_id)
        
        # Simulate processing time
        await asyncio.sleep(2)
        
        # Simulated success/failure based on node name (demo purposes)
        if "fail" in node.get('name', '').lower():
            logger.info("RFP simulated FAILURE & TIMEOUT for %s. Suggesting Tier 3 fallback.", node['name'])
            node['rfp_status'] = 'failed'
        else:
            logger.info("RFP simulated SUCCESS/CONFIRMATION for %s.", node['name'])
            node['rfp_status'] = 'success'
