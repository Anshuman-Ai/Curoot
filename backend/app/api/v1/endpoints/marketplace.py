"""
Module 2.2 — Community-Driven Quick Setup & Auto-Apply.

GET  /api/v1/marketplace/templates  — List community templates (from DB)
POST /api/v1/marketplace/auto-apply — Auto-apply a template to org canvas

Templates are fetched from the `community_templates` + `template_nodes` DB tables.
Falls back to hardcoded templates only if DB is empty (first-run scenario).
"""

from __future__ import annotations

import logging
import uuid

from fastapi import APIRouter, BackgroundTasks
from app.models.marketplace import CommunityTemplateResponse, AutoApplyRequest, AutoApplyResponse
from app.services.rfp_service import process_template_rfps
from app.db.supabase import get_supabase_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/marketplace", tags=["marketplace"])

# Fallback templates used ONLY if community_templates DB table is empty
_FALLBACK_TEMPLATES = [
    {
        "id": "tpl_eth_asia",
        "name": "Ethical Sourcing Textiles - South Asia",
        "description": "A vetted multi-tier network of sustainable cotton suppliers and ethical manufacturers in South Asia.",
        "nodes": [
            {"id": "ct_1", "name": "Organic Cotton Farm", "type": "supplier"},
            {"id": "ct_2", "name": "FairTrade Dye Factory", "type": "factory"},
            {"id": "ct_3", "name": "Certified Textile Mill", "type": "factory"},
        ]
    },
    {
        "id": "tpl_semi_eu",
        "name": "Semiconductor Fab Network - EU",
        "description": "Pre-vetted European semiconductor fabrication channels with low disruption risk.",
        "nodes": [
            {"id": "se_1", "name": "Silica Mine Co.", "type": "supplier"},
            {"id": "se_2", "name": "EuroFab 3nm", "type": "factory"},
        ]
    }
]


@router.get("/templates", response_model=list[CommunityTemplateResponse])
async def get_community_templates():
    """
    Fetch community templates from the database.
    Falls back to hardcoded templates only if DB table is empty.
    """
    supabase = get_supabase_client()
    
    try:
        # Fetch templates from DB (M3 fix)
        tpl_resp = (
            supabase.table("community_templates")
            .select("id, name, description, industry, node_count, metadata")
            .is_("deleted_at", "null")
            .execute()
        )
        
        db_templates = tpl_resp.data or []
        
        if db_templates:
            # For each template, fetch its nodes
            result = []
            for tpl in db_templates:
                tpl_id = str(tpl["id"])
                nodes_resp = (
                    supabase.table("template_nodes")
                    .select("id, name, node_type")
                    .eq("template_id", tpl_id)
                    .execute()
                )
                
                nodes = [
                    {"id": str(n["id"]), "name": n["name"], "type": n.get("node_type", "supplier")}
                    for n in (nodes_resp.data or [])
                ]
                
                result.append({
                    "id": tpl_id,
                    "name": tpl["name"],
                    "description": tpl.get("description", ""),
                    "nodes": nodes,
                })
            
            logger.info("Loaded %d community templates from database", len(result))
            return result
    except Exception as e:
        logger.warning("Failed to load templates from DB, using fallback: %s", e)
    
    # Fallback to hardcoded templates
    logger.info("Using fallback templates (DB empty or unavailable)")
    return _FALLBACK_TEMPLATES


@router.post("/auto-apply", response_model=AutoApplyResponse)
async def auto_apply_template(request: AutoApplyRequest, background_tasks: BackgroundTasks):
    """
    Auto-apply a community template to the org's canvas.
    
    1. Looks up template from DB first, then fallback
    2. Creates pending nodes on the canvas
    3. Queues background RFP processing with DB-backed rate limiting
    """
    supabase = get_supabase_client()
    template = None
    
    # Try DB first
    try:
        tpl_resp = (
            supabase.table("community_templates")
            .select("id, name")
            .eq("id", request.template_id)
            .maybe_single()
            .execute()
        )
        
        if tpl_resp.data:
            nodes_resp = (
                supabase.table("template_nodes")
                .select("id, name, node_type")
                .eq("template_id", request.template_id)
                .execute()
            )
            
            template = {
                "id": str(tpl_resp.data["id"]),
                "name": tpl_resp.data["name"],
                "nodes": [
                    {"id": str(n["id"]), "name": n["name"], "type": n.get("node_type", "supplier")}
                    for n in (nodes_resp.data or [])
                ]
            }
    except Exception as e:
        logger.warning("DB template lookup failed: %s", e)
    
    # Fallback to hardcoded
    if not template:
        template = next((t for t in _FALLBACK_TEMPLATES if t["id"] == request.template_id), None)
    
    if not template:
        return AutoApplyResponse(status="error", message="Template not found", nodes_imported=[])
        
    imported_nodes = []
    for tn in template["nodes"]:
        imported_nodes.append({
            "id": f"inst_{tn['id']}_{str(uuid.uuid4())[:6]}",
            "name": tn["name"],
            "type": tn["type"],
            "status": "pending",  # Initial Yellow State
            "original_id": tn["id"]
        })
        
    # Queue background task with DB-backed rate limiting (C2 fix integration)
    background_tasks.add_task(process_template_rfps, request.organization_id, imported_nodes)
    
    return AutoApplyResponse(
        status="success", 
        message=f"Template '{template['name']}' mapped. Initiating RFP generation queue.",
        nodes_imported=imported_nodes
    )
