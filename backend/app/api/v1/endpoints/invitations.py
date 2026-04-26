"""
Node Invitations API — Module 2.3 (Node Discovery & Onboarding).

POST /api/v1/invitations/create   — Create invitation + pending node
GET  /api/v1/invitations/validate — Validate an invitation token (supplier-facing)
POST /api/v1/invitations/accept   — Supplier accepts invitation (onboarding)

Enforces:
  - 7-day token expiry (SRS §2.3 Phase 3)
  - Pending node creation on canvas
  - country_code metadata population (M6 fix)
"""

from fastapi import APIRouter, HTTPException, Query
from app.models.invitations import DirectInviteRequest, DirectInviteResponse
from app.db.supabase import get_supabase_client
import uuid
import datetime

router = APIRouter(prefix="/invitations", tags=["invitations"])

# Invitation token expiry in days
INVITATION_EXPIRY_DAYS = 7


@router.post("/create", response_model=DirectInviteResponse)
async def create_invitation(request: DirectInviteRequest):
    supabase = get_supabase_client()
    
    token = str(uuid.uuid4().hex)
    new_node_id = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc)
    expires_at = now + datetime.timedelta(days=INVITATION_EXPIRY_DAYS)
    
    # Resolve country_code from coordinates if available (M6 fix)
    country_code = None
    if request.lat is not None and request.lon is not None:
        country_code = _estimate_country_code(request.lat, request.lon)
    if country_code is None:
        country_code = "US"  # Fallback to satisfy NOT NULL constraint
    
    try:
        # Create unverified node on the canvas
        node_lat = request.lat if request.lat is not None else 0.0
        node_lon = request.lon if request.lon is not None else 0.0
        node_payload = {
            "id": new_node_id,
            "organization_id": request.organization_id,
            "name": request.name,
            "display_name": request.name,
            "node_type": request.connection_type,
            "status": "pending",
            "location": f"POINT({node_lon} {node_lat})",
            "country_code": country_code,
            "metadata": {
                "email": request.email,
                "lat": request.lat,
                "lon": request.lon,
                "country_code": country_code,
                "invitation_token": token,
            }
        }
        supabase.table("supply_chain_nodes").insert(node_payload).execute()
        
        # Resolve a valid user for invited_by_user (MVP fallback)
        users_res = supabase.auth.admin.list_users()
        if isinstance(users_res, list):
            users_list = users_res
        else:
            users_list = getattr(users_res, 'users', getattr(users_res, 'data', []))
        valid_user_id = users_list[0].id if users_list else request.organization_id
        
        # Create invitation record with expiry (C3 fix)
        invite_id = str(uuid.uuid4())
        invite_payload = {
            "id": invite_id,
            "organization_id": request.organization_id,
            "invited_by_user": valid_user_id,
            "target_node_id": new_node_id,
            "target_org_name": request.name,
            "target_email": request.email,
            "connection_type": "upstream", # Enum requires upstream/downstream
            "status": "pending",
            "invite_token": token,
            "expires_at": expires_at.isoformat(),
            "created_at": now.isoformat(),
        }
        supabase.table("node_invitations").insert(invite_payload).execute()
        
        invite_link = f"https://app.curoot.com/onboard?token={token}"
        whatsapp_link = None
        if request.channel == "whatsapp" and request.phone:
            import urllib.parse
            phone_clean = "".join(filter(str.isdigit, request.phone))
            msg = urllib.parse.quote(f"You have been invited to Curoot Supply Chain. Click here to join: {invite_link}")
            whatsapp_link = f"https://wa.me/{phone_clean}?text={msg}"
            
        return DirectInviteResponse(
            invite_id=invite_id,
            token=token,
            node_id=new_node_id,
            status="pending",
            message=f"Invitation created. Token expires at {expires_at.strftime('%Y-%m-%d %H:%M UTC')} ({INVITATION_EXPIRY_DAYS} days).",
            expires_at=expires_at.isoformat(),
            email=request.email,
            invite_link=invite_link,
            whatsapp_link=whatsapp_link
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/validate")
async def validate_invitation(token: str = Query(..., description="Invitation token to validate")):
    """
    Validate an invitation token. Used by the supplier onboarding page.
    Checks that the token exists, is pending, and has not expired.
    """
    supabase = get_supabase_client()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    
    resp = (
        supabase.table("node_invitations")
        .select("id, organization_id, target_node_id, target_org_name, target_email, status, expires_at")
        .eq("invite_token", token)
        .maybe_single()
        .execute()
    )
    
    invitation = resp.data
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found or invalid token")
    
    # Check status
    if invitation["status"] != "pending":
        raise HTTPException(
            status_code=410,
            detail=f"Invitation has already been {invitation['status']}"
        )
    
    # Check expiry (C3 enforcement)
    expires_at = invitation.get("expires_at")
    if expires_at:
        try:
            exp_dt = datetime.datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
            if datetime.datetime.now(datetime.timezone.utc) > exp_dt:
                # Mark as expired in DB
                supabase.table("node_invitations").update({
                    "status": "expired"
                }).eq("id", invitation["id"]).execute()
                
                raise HTTPException(
                    status_code=410,
                    detail="Invitation has expired. Please request a new invitation."
                )
        except ValueError:
            pass
    
    return {
        "valid": True,
        "invitation_id": invitation["id"],
        "organization_id": invitation["organization_id"],
        "node_id": invitation["target_node_id"],
        "name": invitation["target_org_name"],
        "email": invitation["target_email"],
    }


@router.post("/accept")
async def accept_invitation(token: str, supplier_name: str = None, supplier_status: str = "operational"):
    """
    Supplier accepts an invitation (onboarding endpoint — M4 fix).
    
    - Validates the token
    - Updates invitation status to 'accepted'
    - Updates the supply_chain_node from 'pending' to 'operational'
    - Records accepted_at timestamp
    """
    supabase = get_supabase_client()
    now = datetime.datetime.now(datetime.timezone.utc)
    
    # Validate token first
    resp = (
        supabase.table("node_invitations")
        .select("id, target_node_id, status, expires_at")
        .eq("invite_token", token)
        .maybe_single()
        .execute()
    )
    
    invitation = resp.data
    if not invitation:
        raise HTTPException(status_code=404, detail="Invalid invitation token")
    
    if invitation["status"] != "pending":
        raise HTTPException(status_code=410, detail=f"Invitation already {invitation['status']}")
    
    # Check expiry
    expires_at = invitation.get("expires_at")
    if expires_at:
        try:
            exp_dt = datetime.datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
            if now > exp_dt:
                supabase.table("node_invitations").update({
                    "status": "expired"
                }).eq("id", invitation["id"]).execute()
                raise HTTPException(status_code=410, detail="Invitation has expired")
        except ValueError:
            pass
    
    node_id = invitation["target_node_id"]
    
    # Update invitation
    supabase.table("node_invitations").update({
        "status": "accepted",
        "accepted_at": now.isoformat(),
    }).eq("id", invitation["id"]).execute()
    
    # Activate the node on the canvas
    update_data = {"status": supplier_status}
    if supplier_name:
        update_data["name"] = supplier_name
    
    supabase.table("supply_chain_nodes").update(update_data).eq("id", node_id).execute()
    
    return {
        "status": "accepted",
        "node_id": node_id,
        "message": "Invitation accepted. Your node is now live on the supply chain canvas."
    }


def _estimate_country_code(lat: float, lon: float) -> str | None:
    """
    Rough country estimation from coordinates for metadata population.
    Uses broad geographic bounding boxes for common supply chain regions.
    """
    regions = [
        ((6.0, 35.0, 68.0, 97.0), "IN"),    # India
        ((18.0, 54.0, 73.0, 135.0), "CN"),   # China
        ((24.0, 46.0, 124.0, 146.0), "JP"),  # Japan
        ((33.0, 37.0, 125.0, 130.0), "KR"),  # South Korea
        ((35.0, 71.0, -10.0, 40.0), "EU"),   # Europe (broad)
        ((25.0, 50.0, -125.0, -65.0), "US"), # USA
        ((-10.0, 6.0, 95.0, 141.0), "ID"),   # Indonesia
        ((1.0, 8.0, 100.0, 120.0), "MY"),    # Malaysia
        ((-35.0, -22.0, 16.0, 33.0), "ZA"),  # South Africa
        ((-34.0, 5.0, -73.0, -35.0), "BR"),  # Brazil
    ]
    
    for (lat_min, lat_max, lon_min, lon_max), code in regions:
        if lat_min <= lat <= lat_max and lon_min <= lon <= lon_max:
            return code
    
    return None
