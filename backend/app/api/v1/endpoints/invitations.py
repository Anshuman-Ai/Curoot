from fastapi import APIRouter, HTTPException
from app.models.invitations import DirectInviteRequest, DirectInviteResponse
from app.db.supabase import get_supabase_client
import uuid
import datetime

router = APIRouter(prefix="/invitations", tags=["invitations"])

@router.post("/create", response_model=DirectInviteResponse)
async def create_invitation(request: DirectInviteRequest):
    supabase = get_supabase_client()
    
    # Simulate generating a 7-day token
    token = str(uuid.uuid4().hex)
    new_node_id = str(uuid.uuid4())
    
    try:
        # Create unverified node on the canvas
        node_payload = {
            "id": new_node_id,
            "organization_id": request.organization_id,
            "name": request.name,
            "type": request.connection_type,
            "status": "pending",
            # Assuming metadata handles dynamic unstructured fields
            "metadata": {"email": request.email, "lat": request.lat, "lon": request.lon}
        }
        supabase.table("supply_chain_nodes").insert(node_payload).execute()
        
        # Create invitation record
        invite_id = str(uuid.uuid4())
        invite_payload = {
            "id": invite_id,
            "organization_id": request.organization_id,
            "target_node_id": new_node_id,
            # accepted_org_id is null initially
        }
        supabase.table("node_invitations").insert(invite_payload).execute()
        
        return DirectInviteResponse(
            invite_id=invite_id,
            token=token,
            node_id=new_node_id,
            status="pending",
            message="Invitation simulation created successfully. Link expires in 7 days."
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
