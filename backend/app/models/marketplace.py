from pydantic import BaseModel
from typing import List, Optional

class TemplateNode(BaseModel):
    id: str
    name: str
    type: str

class CommunityTemplateResponse(BaseModel):
    id: str
    name: str
    description: str
    nodes: List[TemplateNode]

class AutoApplyRequest(BaseModel):
    template_id: str
    organization_id: str

class AutoApplyResponse(BaseModel):
    status: str
    message: str
    nodes_imported: List[dict]
