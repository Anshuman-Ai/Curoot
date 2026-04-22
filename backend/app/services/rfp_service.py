import asyncio
import logging
import datetime

logger = logging.getLogger(__name__)

# Basic in-memory rate limiting dict: { frozenset(org_id, node_id): list_of_timestamps }
_rfp_rate_limits = {}

async def process_template_rfps(org_id: str, nodes: list):
    """
    Simulates sending RFP requests sequentially for the auto-applied nodes.
    Applies the max 2 requests/day limit.
    """
    for node in nodes:
        node_id = node['original_id']
        key = frozenset({"org": org_id, "node": node_id}.items())
        
        now = datetime.datetime.now()
        
        if key not in _rfp_rate_limits:
            _rfp_rate_limits[key] = []
            
        # Clean up old timestamps (older than 24h)
        _rfp_rate_limits[key] = [t for t in _rfp_rate_limits[key] if (now - t).total_seconds() < 86400]
        
        if len(_rfp_rate_limits[key]) >= 2:
            logger.warning(f"RFP Cooldown enforced for Node {node['name']} ({node_id}). Limit of 2/day reached.")
            node['rfp_status'] = 'cooldown'
            # In a real app we might update the DB here.
            continue
            
        _rfp_rate_limits[key].append(now)
        
        # Simulate processing time (RFPs theoretically happen over days/weeks, here scaled to seconds for UI demo purposes)
        await asyncio.sleep(2)
        
        # Simulated instant success or failure hook instead of querying Supabase heavily
        if "fail" in node['name'].lower():
            logger.info(f"RFP simulated FAILURE & TIMEOUT for {node['name']}. Suggesting Tier 3 fallback.")
            node['rfp_status'] = 'failed'
        else:
            logger.info(f"RFP simulated SUCCESS/CONFIRMATION for {node['name']}.")
            node['rfp_status'] = 'success'
