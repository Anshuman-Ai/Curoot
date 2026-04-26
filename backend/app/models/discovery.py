from pydantic import BaseModel
from typing import Optional, List

class DiscoverySearchRequest(BaseModel):
    query: str
    radius: Optional[float] = 50.0
    lat: Optional[float] = None
    lon: Optional[float] = None
    organization_id: str
    country: Optional[str] = None
    state: Optional[str] = None
    city: Optional[str] = None

class DiscoveryNode(BaseModel):
    id: str
    label: str
    tier: int # 1 = Active, 2 = Community, 3 = External (OSM)
    type: str # 'supplier', 'factory', 'oem', 'unverified'
    status: str # 'active', 'pending', 'delayed'
    lat: Optional[float] = None
    lon: Optional[float] = None
    distance: Optional[float] = None

class DiscoverySearchResponse(BaseModel):
    results: List[DiscoveryNode]
