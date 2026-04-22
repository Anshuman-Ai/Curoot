from fastapi import APIRouter, Depends, HTTPException
from app.models.discovery import DiscoverySearchRequest, DiscoverySearchResponse, DiscoveryNode
from app.db.supabase import get_supabase_client
import httpx

router = APIRouter(prefix="/discovery", tags=["discovery"])

@router.post("/search", response_model=DiscoverySearchResponse)
async def search_nodes(request: DiscoverySearchRequest):
    supabase = get_supabase_client()
    results = []

    # Tier 1: Active Nodes (Query supply_chain_nodes for this org)
    try:
        t1_resp = supabase.table("supply_chain_nodes") \
            .select("id, name, type, status") \
            .eq("organization_id", request.organization_id) \
            .ilike("name", f"%{request.query}%") \
            .execute()
        
        for row in t1_resp.data or []:
            results.append(DiscoveryNode(
                id=str(row.get("id")),
                label=row.get("name") or "Unknown",
                tier=1,
                type=row.get("type", "supplier"),
                status=row.get("status", "active")
            ))
    except Exception as e:
        print(f"Tier 1 error: {e}")

    # Tier 2: Community Nodes (Query template_nodes)
    try:
        t2_resp = supabase.table("template_nodes") \
            .select("id, name, type") \
            .ilike("name", f"%{request.query}%") \
            .execute()
            
        for row in t2_resp.data or []:
            results.append(DiscoveryNode(
                id=f"tpl_{row.get('id')}",
                label=row.get("name") or "Community Node",
                tier=2,
                type=row.get("type", "supplier"),
                status="pending"
            ))
    except Exception as e:
        print(f"Tier 2 error: {e}")

    # Tier 3: External (OpenStreetMap)
    try:
        async with httpx.AsyncClient() as client:
            osm_url = f"https://nominatim.openstreetmap.org/search?q={request.query}&format=json&limit=2"
            osm_resp = await client.get(osm_url, headers={"User-Agent": "Curoot-App/1.0"})
            if osm_resp.status_code == 200:
                osm_data = osm_resp.json()
                for i, item in enumerate(osm_data):
                    results.append(DiscoveryNode(
                        id=f"osm_{item.get('osm_id', i)}",
                        label=item.get("display_name", "OSM Node").split(',')[0],
                        tier=3,
                        type="unverified",
                        status="pending",
                        lat=float(item.get("lat") or 0.0),
                        lon=float(item.get("lon") or 0.0)
                    ))
    except Exception as e:
        print(f"Tier 3 error: {e}")

    return DiscoverySearchResponse(results=results)
