"""
Omni-Format Ingestion Endpoints — SRS §2.1

Tracks:
  POST /unstructured   — Cold Start: AI parsing of PDFs, CSVs, emails → persist to DB
  POST /telemetry      — Modern Push: Smart Router with Universal Filter + crisis Co-Pilot
"""

from __future__ import annotations

import logging
import uuid
from typing import Any, Dict

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.db.supabase import get_supabase_client
from app.models.ai_parser import AIExtractionResult, UniversalFilter
from app.services import ai_service

router = APIRouter()
logger = logging.getLogger(__name__)


def _guess_country(lat: float, lng: float) -> str:
    """Best-effort country code from lat/lng for common supply chain regions."""
    # Major supply chain hubs — rough bounding boxes
    _regions = [
        ("CN", 18, 54, 73, 135),     # China
        ("IN", 6, 36, 68, 98),       # India
        ("DE", 47, 55, 6, 15),       # Germany
        ("US", 24, 50, -125, -66),   # United States
        ("JP", 30, 46, 128, 146),    # Japan
        ("KR", 33, 39, 124, 132),    # South Korea
        ("TW", 21, 26, 119, 123),    # Taiwan
        ("VN", 8, 24, 102, 110),     # Vietnam
        ("TH", 5, 21, 97, 106),      # Thailand
        ("MY", 0, 8, 99, 120),       # Malaysia
        ("ID", -11, 6, 95, 141),     # Indonesia
        ("BR", -34, 6, -74, -34),    # Brazil
        ("MX", 14, 33, -118, -86),   # Mexico
        ("GB", 49, 61, -9, 2),       # United Kingdom
        ("FR", 41, 52, -5, 10),      # France
        ("IT", 36, 47, 6, 19),       # Italy
        ("TR", 35, 42, 25, 45),      # Turkey
        ("AE", 22, 27, 51, 56),      # UAE
        ("SA", 16, 33, 34, 56),      # Saudi Arabia
        ("AU", -44, -10, 112, 154),  # Australia
    ]
    for code, lat_min, lat_max, lng_min, lng_max in _regions:
        if lat_min <= lat <= lat_max and lng_min <= lng <= lng_max:
            return code
    return "XX"  # Unknown


# ---------------------------------------------------------------------------
# Helper — persist AI extraction to Supabase
# ---------------------------------------------------------------------------

def _persist_extraction(
    extraction: AIExtractionResult, org_id: str, job_id: str
) -> dict:
    """
    Write extracted nodes to `supply_chain_nodes` and edges to `node_edges`.
    Returns a summary dict with counts.
    """
    supabase = get_supabase_client()

    node_id_map: Dict[str, str] = {}   # ai_node_id → supabase uuid
    nodes_created = 0
    edges_created = 0

    # ---- Upsert Nodes ----
    for node in extraction.nodes:
        db_id = str(uuid.uuid4())
        node_id_map[node.node_id] = db_id

        row = {
            "id": db_id,
            "organization_id": org_id,
            "name": node.name,
            "node_type": node.type,
            "status": node.status,
            "location": f"POINT({node.location.lng} {node.location.lat})",
            "country_code": node.country_code or _guess_country(node.location.lat, node.location.lng),
            "metadata": {"source": "cold_start", "ingestion_job_id": job_id},
        }
        try:
            supabase.table("supply_chain_nodes").insert(row).execute()
            nodes_created += 1
        except Exception as exc:
            logger.error("Failed to insert node %s: %s", node.node_id, exc)

    # ---- Upsert Edges ----
    for edge in extraction.edges:
        source_uuid = node_id_map.get(edge.source_node_id)
        target_uuid = node_id_map.get(edge.target_node_id)
        if not source_uuid or not target_uuid:
            logger.warning(
                "Skipping edge %s→%s: node ID not found in extraction",
                edge.source_node_id,
                edge.target_node_id,
            )
            continue

        edge_row = {
            "id": str(uuid.uuid4()),
            "organization_id": org_id,
            "source_node_id": source_uuid,
            "target_node_id": target_uuid,
            "edge_type": edge.relationship_type,
            "metadata": {"label": edge.label or ""},
        }
        try:
            supabase.table("node_edges").insert(edge_row).execute()
            edges_created += 1
        except Exception as exc:
            logger.error("Failed to insert edge: %s", exc)

    return {"nodes_created": nodes_created, "edges_created": edges_created}


def _create_ingestion_job(org_id: str, filename: str, track: str) -> str:
    """Create an ingestion_jobs record and return its ID."""
    job_id = str(uuid.uuid4())
    try:
        supabase = get_supabase_client()
        supabase.table("ingestion_jobs").insert(
            {
                "id": job_id,
                "organization_id": org_id,
                "source_type": track,
                "source_ref": filename,
                "status": "processing",
            }
        ).execute()
    except Exception as exc:
        logger.error("Failed to create ingestion_job: %s", exc)
    return job_id


def _complete_ingestion_job(job_id: str, status: str = "completed") -> None:
    """Mark an ingestion job as completed or failed."""
    try:
        supabase = get_supabase_client()
        supabase.table("ingestion_jobs").update({"status": status}).eq(
            "id", job_id
        ).execute()
    except Exception as exc:
        logger.error("Failed to update ingestion_job %s: %s", job_id, exc)


# ---------------------------------------------------------------------------
# Cold Start Track: Unstructured AI Parsing
# ---------------------------------------------------------------------------

@router.post("/unstructured", response_model=Dict[str, Any])
async def ingest_unstructured(file: UploadFile = File(...)):
    """
    Cold Start Track — Unstructured AI Parsing.

    Accepts raw files (PDFs, CSVs, emails) from legacy supply chain integrations.
    Files are passed to the AI service (Gemini 1.5 Flash) to extract entities,
    relationships, and geographic coordinates. Results are persisted to Supabase.
    """
    try:
        content = await file.read()
        if not content:
            raise HTTPException(status_code=400, detail="Empty file uploaded.")

        # Default org for demo — in production, extract from JWT
        org_id = "00000000-0000-0000-0000-000000000000"

        # Create tracking job
        job_id = _create_ingestion_job(org_id, file.filename or "unknown", "cold_start")

        # AI extraction
        extraction_result = await ai_service.process_unstructured_file(
            content, file.filename or "unknown"
        )

        # Persist to Supabase
        persist_summary = _persist_extraction(extraction_result, org_id, job_id)
        _complete_ingestion_job(job_id, "completed")

        return {
            "nodes": [n.model_dump() for n in extraction_result.nodes],
            "edges": [e.model_dump() for e in extraction_result.edges],
            "confidence": extraction_result.confidence,
            "persisted": persist_summary,
            "ingestion_job_id": job_id,
        }

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Error processing file %s: %s", file.filename, exc)
        raise HTTPException(
            status_code=500, detail="Internal server error during ingestion."
        )


# ---------------------------------------------------------------------------
# Modern Push Track / Smart Router
# ---------------------------------------------------------------------------

@router.post("/telemetry", response_model=Dict[str, Any])
async def ingest_telemetry(payload: UniversalFilter):
    """
    Modern Push Track — Smart Router.

    The UniversalFilter Pydantic schema enforces authorized keys, dropping
    unauthorized properties (Zero-Trust).

    Routing logic:
      • Standard coord/status → bypass LLM → update Supabase directly.
      • Crisis message detected → NLP status extraction → Co-Pilot advisory broadcast.
    """
    safe_data = payload.model_dump(exclude_none=True)

    def _update_node_db(data: Dict[str, Any]) -> None:
        try:
            supabase = get_supabase_client()
            update_doc: Dict[str, Any] = {}
            if "status" in data:
                update_doc["status"] = data["status"]
            if "location" in data and isinstance(data["location"], dict):
                update_doc["location"] = (
                    f"POINT({data['location'].get('lng')} {data['location'].get('lat')})"
                )
            if update_doc:
                supabase.table("supply_chain_nodes").update(update_doc).eq(
                    "id", data["node_id"]
                ).execute()
        except Exception as exc:
            logger.error(
                "Error updating supply_chain_nodes for %s: %s",
                data.get("node_id"),
                exc,
            )

    # ---- Standard routing: bypass LLM ----
    if not payload.crisis_message:
        _update_node_db(safe_data)
        return {
            "status": "success",
            "message": "Telemetry securely routed to database.",
            "data": safe_data,
        }

    # ---- Crisis routing: AI classification + Co-Pilot advisory ----
    logger.info("Crisis message detected in telemetry. Routing to AI service.")

    extracted_status = await ai_service.extract_status_from_crisis(
        payload.crisis_message
    )
    safe_data["status"] = extracted_status
    _update_node_db(safe_data)

    # Generate Co-Pilot advisory
    advisory = await ai_service.generate_crisis_advisory(
        payload.crisis_message, payload.node_id, extracted_status
    )

    # Broadcast to Co-Pilot channel via Supabase Realtime
    try:
        supabase = get_supabase_client()
        # Use a default org for demo; in production, resolve from node_id
        channel_name = "org:copilot:alerts"
        copilot_payload = {
            "node_id": payload.node_id,
            "status": extracted_status,
            "crisis_message": payload.crisis_message,
            "advisory": advisory,
        }
        supabase.table("telemetry_events").insert(
            {
                "id": str(uuid.uuid4()),
                "node_id": payload.node_id,
                "organization_id": "00000000-0000-0000-0000-000000000000",
                "event_type": "crisis",
                "payload": copilot_payload,
            }
        ).execute()
        logger.info("Crisis advisory persisted and broadcast for node %s", payload.node_id)
    except Exception as exc:
        logger.error("Failed to persist/broadcast crisis advisory: %s", exc)

    return {
        "status": "success",
        "message": "Crisis message analyzed and telemetry routed.",
        "data": safe_data,
        "advisory": advisory,
    }
