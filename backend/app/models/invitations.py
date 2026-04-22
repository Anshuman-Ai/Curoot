from pydantic import BaseModel, EmailStr
from typing import Optional

class DirectInviteRequest(BaseModel):
    organization_id: str
    name: str
    email: EmailStr
    connection_type: str # 'supplier', 'factory'
    lat: Optional[float] = None
    lon: Optional[float] = None

class DirectInviteResponse(BaseModel):
    invite_id: str
    token: str
    node_id: str
    status: str
    message: str
