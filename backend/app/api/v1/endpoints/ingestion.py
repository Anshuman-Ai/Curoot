from fastapi import APIRouter, File, UploadFile, HTTPException
import logging
from typing import Dict, Any

from app.models.ai_parser import AIExtractionResult, UniversalFilter
from app.services import ai_service
from app.db.supabase import get_supabase_client

router = APIRouter()
logger = logging.getLogger(__name__)

@router.post("/unstructured", response_model=AIExtractionResult)
async def ingest_unstructured(file: UploadFile = File(...)):
    """
    Cold Start Track: Unstructured AI Parsing
    
    Accepts raw files (PDFs, CSVs) from legacy supply chain integrations.
    Files are passed to the AI service (Gemini 2.5) to securely extract network
    topologies and map them to standard Pydantic schemas. 
    Maintains Zero-Trust by isolating the ingestion environment and strictly typing the output.
    """
    try:
        content = await file.read()
        if not content:
            raise HTTPException(status_code=400, detail="Empty file uploaded.")
            
        # Pass to the secure AI extraction service
        extraction_result = await ai_service.process_unstructured_file(content, file.filename)
        return extraction_result
        
    except Exception as e:
        logger.error(f"Error processing file {file.filename}: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error during ingestion.")


@router.post("/telemetry", response_model=Dict[str, Any])
async def ingest_telemetry(payload: UniversalFilter):
    """
    Modern Push Track / Smart Router
    
    Accepts JSON payloads representing node status or location updates.
    The UniversalFilter Pydantic schema strictly enforces authorized keys, instantly dropping
    unauthorized properties (e.g., PII, internal financials) to adhere to Zero-Trust architecture.
    
    If the payload contains unstructured 'crisis_message', the message is routed
    into the AI parser for NLP status extraction. Otherwise, standard payloads bypass the LLM.
    """
    # The payload is already stripped of extra fields by UniversalFilter
    # using model_dump to convert into dict (pydantic v2 support) or dict() for v1
    safe_data = payload.dict(exclude_none=True) if hasattr(payload, 'dict') else payload.model_dump(exclude_none=True)
    
    # Helper to update Supabase
    def _update_node_db(data: Dict[str, Any]):
        try:
            supabase = get_supabase_client()
            update_doc = {}
            if "status" in data:
                update_doc["status"] = data["status"]
            if "location" in data and isinstance(data["location"], dict):
                # Format to PostGIS GeoJSON Point geometry
                update_doc["location"] = {
                    "type": "Point",
                    "coordinates": [data["location"].get("lng"), data["location"].get("lat")]
                }
            if update_doc:
                supabase.table("supply_chain_nodes").update(update_doc).eq("id", data["node_id"]).execute()
        except Exception as e:
            logger.error(f"Error updating Supabase supply_chain_nodes for {data.get('node_id')}: {str(e)}")

    # Standard routing: bypass LLM if no crisis message
    if not payload.crisis_message:
        _update_node_db(safe_data)
        return {
            "status": "success",
            "message": "Telemetry securely routed to database.",
            "data": safe_data
        }
        
    # Exceptional routing: Crisis detected -> extract using AI
    logger.info("Crisis message detected in telemetry. Routing to AI service.")
    extracted_status = await ai_service.extract_status_from_crisis(payload.crisis_message)
    
    # Augment safe payload with AI-determined context
    safe_data["status"] = extracted_status
    
    _update_node_db(safe_data)
    
    return {
        "status": "success",
        "message": "Crisis message analyzed and telemetry routed.",
        "data": safe_data
    }
