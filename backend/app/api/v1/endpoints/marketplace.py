from fastapi import APIRouter, BackgroundTasks
from app.models.marketplace import CommunityTemplateResponse, AutoApplyRequest, AutoApplyResponse
from app.services.rfp_service import process_template_rfps
import uuid

router = APIRouter(prefix="/marketplace", tags=["marketplace"])

MOCK_TEMPLATES = [
    {
        "id": "tpl_eth_asia",
        "name": "Ethical Sourcing Textiles - South Asia",
        "description": "A vetted multi-tier network of sustainable cotton suppliers and ethical manufacturers in South Asia.",
        "nodes": [
            {"id": "ct_1", "name": "Organic Cotton Farm", "type": "supplier"},
            {"id": "ct_2", "name": "FairTrade Dye Factory", "type": "factory"},
            {"id": "ct_3", "name": "FailSourcing - Unknown", "type": "supplier"} # purposeful failure trigger for demo
        ]
    },
    {
        "id": "tpl_semi_eu",
        "name": "Semiconductor Fab Network - EU",
        "description": "Pre-vetted European semiconductor fabrication channels with low disruption risk.",
        "nodes": [
            {"id": "se_1", "name": "Silica Mine Co.", "type": "supplier"},
            {"id": "se_2", "name": "EuroFab 3nm", "type": "factory"}
        ]
    }
]

@router.get("/templates", response_model=list[CommunityTemplateResponse])
async def get_community_templates():
    return MOCK_TEMPLATES

@router.post("/auto-apply", response_model=AutoApplyResponse)
async def auto_apply_template(request: AutoApplyRequest, background_tasks: BackgroundTasks):
    # Find template
    template = next((t for t in MOCK_TEMPLATES if t["id"] == request.template_id), None)
    if not template:
        return AutoApplyResponse(status="error", message="Template not found", nodes_imported=[])
        
    imported_nodes = []
    for tn in template["nodes"]:
        imported_nodes.append({
            "id": f"inst_{tn['id']}_{str(uuid.uuid4())[:6]}",
            "name": tn["name"],
            "type": tn["type"],
            "status": "pending", # Initial Yellow State
            "original_id": tn["id"]
        })
        
    # Queue background task to handle rate limiting and simulated supplier response
    background_tasks.add_task(process_template_rfps, request.organization_id, imported_nodes)
    
    return AutoApplyResponse(
        status="success", 
        message=f"Template '{template['name']}' mapped. Initiating RFP generation queue.",
        nodes_imported=imported_nodes
    )
