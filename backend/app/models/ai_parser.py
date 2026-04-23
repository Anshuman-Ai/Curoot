from pydantic import BaseModel, Field
from typing import List, Optional

class Coordinate(BaseModel):
    lat: float = Field(..., description="Latitude coordinate")
    lng: float = Field(..., description="Longitude coordinate")

class SupplyChainNode(BaseModel):
    node_id: str = Field(..., description="Unique identifier for the supply chain node")
    name: str = Field(..., description="Name of the node or facility")
    type: str = Field(..., description="Type of node (e.g., supplier, warehouse, retail)")
    location: Coordinate = Field(..., description="Geographical location of the node")
    status: str = Field("operational", description="Current operational status")

class SupplyChainEdge(BaseModel):
    """Represents a directed relationship between two supply chain nodes."""
    source_node_id: str = Field(..., description="ID of the source node")
    target_node_id: str = Field(..., description="ID of the target node")
    relationship_type: str = Field(
        "supplies_to",
        description="Type of relationship (e.g., supplies_to, ships_via, stores_at)"
    )
    label: Optional[str] = Field(None, description="Human-readable label for the edge")

class AIExtractionResult(BaseModel):
    nodes: List[SupplyChainNode] = Field(..., description="Extracted supply chain nodes")
    edges: List[SupplyChainEdge] = Field(
        default_factory=list,
        description="Extracted relationships between supply chain nodes"
    )
    confidence: float = Field(..., description="Confidence score of the extraction")

class UniversalFilter(BaseModel):
    """
    Used for instantly stripping unauthorized keys (like pricing or PII) from incoming JSON payloads.
    Only allows specific fields meant for Omni-Format Ingestion.
    """
    node_id: str = Field(..., description="Node Identifier")
    status: str = Field(..., description="Operational status of the node")
    location: Optional[Coordinate] = Field(None, description="Location coordinates")
    timestamp: Optional[str] = Field(None, description="Timestamp of the update")
    crisis_message: Optional[str] = Field(None, description="Unstructured crisis or alert message, if any")

    class Config:
        extra = "ignore"  # Pydantic will securely strip out any additional incoming keys (Zero-Trust)

class MCPSpecRequest(BaseModel):
    db_type: str = Field(..., description="Type of legacy DB (e.g., sqlserver, postgres, oracle)")
    ip_address: str = Field(..., description="IP address or hostname of the legacy DB")
    table_name: str = Field(..., description="Name of the table to track")
    sync_frequency_seconds: int = Field(60, description="Sync frequency in seconds")
    credentials_ref: Optional[str] = Field(None, description="Reference to secret manager for credentials")
