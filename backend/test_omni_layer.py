import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_ingest_unstructured():
    """
    Test the Cold Start Track: Unstructured AI Parsing.
    Simulates the Omni Ingestion file upload button.
    """
    file_content = b"node_id,name,lat,lng,status\nNODE-01,Test Warehouse,34.05,-118.25,operational"
    files = {"file": ("test_supply_chain.csv", file_content, "text/csv")}
    
    response = client.post("/api/v1/unstructured", files=files)
    
    assert response.status_code == 200
    data = response.json()
    assert "nodes" in data
    assert "confidence" in data
    assert data["confidence"] == 0.92
    assert len(data["nodes"]) > 0
    assert data["nodes"][0]["node_id"] == "EXTRACTED-NODE-01"

def test_ingest_telemetry_standard():
    """
    Test the Modern Push Track bypassing the AI parser.
    Simulates sending standard telemetry to the Omni Ingestion layer (Webhook action).
    """
    payload = {
        "node_id": "NODE-02",
        "status": "operational",
        "location": {"lat": 40.71, "lng": -74.00},
        "timestamp": "2026-04-18T10:00:00Z"
    }
    
    response = client.post("/api/v1/telemetry", json=payload)
    
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["data"]["node_id"] == "NODE-02"

def test_ingest_telemetry_crisis():
    """
    Test the Modern Push Track with a crisis message.
    Simulates unstructured status update routing through the AI parser NLP logic.
    """
    payload = {
        "node_id": "NODE-03",
        "status": "operational",
        "crisis_message": "Critical failure, offline immediately"
    }
    
    response = client.post("/api/v1/telemetry", json=payload)
    
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["data"]["status"] == "offline"

def test_generate_mcp_container():
    """
    Test the Continuous Sync / MCP Generator.
    Simulates the Enterprise MCP Generator button / generation wizard form submit.
    """
    payload = {
        "db_type": "postgres",
        "ip_address": "192.168.1.100",
        "table_name": "inventory_sync",
        "sync_frequency_seconds": 30
    }
    
    response = client.post("/api/v1/generate", json=payload)
    
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "configuration" in data
    assert "docker-compose.yml" in data["configuration"]
    assert "mcp_runner.py" in data["configuration"]
    assert "TARGET_DB_IP=192.168.1.100" in data["configuration"]["docker-compose.yml"]
