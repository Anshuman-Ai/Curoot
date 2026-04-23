"""
Omni Layer Integration Tests — SRS §2.1

Tests all three tracks:
  1. Cold Start (Unstructured AI Parsing)
  2. Continuous Sync (MCP Generation)
  3. Modern Push (Telemetry Smart Router)
"""

import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_ingest_unstructured():
    """
    Test the Cold Start Track: Unstructured AI Parsing.
    Simulates the Omni Ingestion file upload button.
    Verifies extraction returns nodes, edges, confidence, and persistence summary.
    """
    file_content = b"node_id,name,lat,lng,status\nNODE-01,Test Warehouse,34.05,-118.25,operational"
    files = {"file": ("test_supply_chain.csv", file_content, "text/csv")}

    response = client.post("/api/v1/ingestion/unstructured", files=files)

    assert response.status_code == 200
    data = response.json()
    assert "nodes" in data
    assert "edges" in data
    assert "confidence" in data
    assert "persisted" in data
    assert "ingestion_job_id" in data
    assert len(data["nodes"]) > 0
    assert data["nodes"][0]["node_id"] == "EXTRACTED-NODE-01"


def test_ingest_unstructured_pdf():
    """
    Test Cold Start with a PDF file (binary handling).
    The stub fallback should still return a valid extraction result.
    """
    # Minimal PDF-like binary content (won't parse as real PDF, but tests the routing)
    file_content = b"%PDF-1.4 fake content for testing"
    files = {"file": ("supply_chain_report.pdf", file_content, "application/pdf")}

    response = client.post("/api/v1/ingestion/unstructured", files=files)

    assert response.status_code == 200
    data = response.json()
    assert "nodes" in data
    assert "confidence" in data


def test_ingest_unstructured_email():
    """
    Test Cold Start with an .eml email file.
    """
    eml_content = (
        b"From: supplier@example.com\r\n"
        b"Subject: Shipment Update\r\n"
        b"Content-Type: text/plain\r\n\r\n"
        b"Warehouse WH-01 at lat 40.71, lng -74.00 is now operational."
    )
    files = {"file": ("shipment_update.eml", eml_content, "message/rfc822")}

    response = client.post("/api/v1/ingestion/unstructured", files=files)

    assert response.status_code == 200
    data = response.json()
    assert "nodes" in data


def test_ingest_telemetry_standard():
    """
    Test the Modern Push Track bypassing the AI parser.
    Simulates sending standard telemetry to the Omni Ingestion layer (Webhook action).
    """
    payload = {
        "node_id": "NODE-02",
        "status": "operational",
        "location": {"lat": 40.71, "lng": -74.00},
        "timestamp": "2026-04-18T10:00:00Z",
    }

    response = client.post("/api/v1/ingestion/telemetry", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["data"]["node_id"] == "NODE-02"
    # Standard route should NOT have advisory
    assert "advisory" not in data


def test_ingest_telemetry_crisis():
    """
    Test the Modern Push Track with a crisis message.
    Verifies AI status extraction AND Co-Pilot advisory generation.
    """
    payload = {
        "node_id": "NODE-03",
        "status": "operational",
        "crisis_message": "Critical failure, offline immediately",
    }

    response = client.post("/api/v1/ingestion/telemetry", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["data"]["status"] == "offline"
    # Crisis route SHOULD include an advisory from the Co-Pilot
    assert "advisory" in data
    assert len(data["advisory"]) > 0


def test_ingest_telemetry_strips_extra_keys():
    """
    Test that the UniversalFilter (Zero-Trust) strips unauthorized keys.
    """
    payload = {
        "node_id": "NODE-04",
        "status": "operational",
        "pricing": 9999.99,            # UNAUTHORIZED — should be stripped
        "internal_cost": 1234.56,      # UNAUTHORIZED — should be stripped
        "secret_notes": "confidential",  # UNAUTHORIZED — should be stripped
    }

    response = client.post("/api/v1/ingestion/telemetry", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert "pricing" not in data["data"]
    assert "internal_cost" not in data["data"]
    assert "secret_notes" not in data["data"]
    assert data["data"]["node_id"] == "NODE-04"


def test_generate_mcp_container():
    """
    Test the Continuous Sync / MCP Generator.
    Verifies dynamic generation per DB type, AI prompt, and full artefacts.
    """
    payload = {
        "db_type": "postgres",
        "ip_address": "192.168.1.100",
        "table_name": "inventory_sync",
        "sync_frequency_seconds": 30,
    }

    response = client.post("/api/v1/mcp_mgr/generate", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "configuration" in data
    assert "docker-compose.yml" in data["configuration"]
    assert "mcp_runner.py" in data["configuration"]
    assert "Dockerfile" in data["configuration"]
    assert "instructions" in data["configuration"]
    # Verify dynamic DB-specific content
    assert "TARGET_DB_IP=192.168.1.100" in data["configuration"]["docker-compose.yml"]
    assert "psycopg2" in data["configuration"]["mcp_runner.py"]
    # Verify AI prompt was generated
    assert len(data["message"]) > 20  # AI-generated or fallback prompt


def test_generate_mcp_container_oracle():
    """
    Test MCP generation for Oracle DB — should use cx_Oracle driver.
    """
    payload = {
        "db_type": "oracle",
        "ip_address": "10.0.0.50",
        "table_name": "erp_master",
        "sync_frequency_seconds": 120,
    }

    response = client.post("/api/v1/mcp_mgr/generate", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert "cx_Oracle" in data["configuration"]["mcp_runner.py"]
    assert "1521" in data["configuration"]["docker-compose.yml"]  # Oracle default port


def test_generate_mcp_container_sqlserver():
    """
    Test MCP generation for SQL Server — should use pyodbc driver.
    """
    payload = {
        "db_type": "sqlserver",
        "ip_address": "10.0.0.60",
        "table_name": "supply_orders",
        "sync_frequency_seconds": 90,
    }

    response = client.post("/api/v1/mcp_mgr/generate", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert "pyodbc" in data["configuration"]["mcp_runner.py"]
    assert "1433" in data["configuration"]["docker-compose.yml"]  # SQL Server default port
