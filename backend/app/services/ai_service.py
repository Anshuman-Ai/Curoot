import os
import logging
from typing import Dict, Any

from google import genai
from google.genai import types
from app.models.ai_parser import AIExtractionResult, SupplyChainNode, Coordinate

logger = logging.getLogger(__name__)

# Initialize Gemini API client safely
api_key = os.getenv("GEMINI_API_KEY")
client = genai.Client(api_key=api_key) if api_key else None

async def process_unstructured_file(file_content: bytes, filename: str) -> AIExtractionResult:
    """
    Calls Gemini 1.5 Flash to parse unstructured text (PDF/CSV) and extract supply chain nodes.
    """
    logger.info(f"Processing unstructured file: {filename}")
    
    # Try to decode content. If it's binary like PDF, we might need to handle it via File API,
    # but for this MVP we assume text/csv/email dumps that can be decoded.
    try:
        text_content = file_content.decode('utf-8')
    except UnicodeDecodeError:
        text_content = str(file_content)

    prompt = f"Analyze the following supply chain data file named '{filename}'. Extract all the supply chain nodes (facilities, suppliers, warehouses) mentioned, their coordinates (if inferable), and their operational status. File content:\\n\\n{text_content}"
    
    if not client:
        logger.warning("GEMINI_API_KEY not set. Returning stub data for Cold Start.")
        return AIExtractionResult(
            nodes=[
                SupplyChainNode(
                    node_id="EXTRACTED-NODE-01",
                    name="Global Distribution Center",
                    type="warehouse",
                    location=Coordinate(lat=34.0522, lng=-118.2437),
                    status="operational"
                )
            ],
            confidence=0.1
        )

    try:
        # Use Structured Outputs with Pydantic
        response = client.models.generate_content(
            model='gemini-1.5-flash',
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=AIExtractionResult,
                temperature=0.1
            ),
        )
        # response.parsed is the validated Pydantic model returned by the SDK
        if response.parsed:
            return response.parsed
            
        raise ValueError("AI did not return a valid schema.")
    except Exception as e:
        logger.error(f"Error calling Gemini API for file parsing: {e}")
        # Fallback to stub if it fails, ensuring the system doesn't crash during demo
        return AIExtractionResult(
            nodes=[
                SupplyChainNode(
                    node_id="EXTRACTED-NODE-01",
                    name="Global Distribution Center",
                    type="warehouse",
                    location=Coordinate(lat=34.0522, lng=-118.2437),
                    status="operational"
                )
            ],
            confidence=0.1
        )

async def extract_status_from_crisis(crisis_message: str) -> str:
    """
    NLP status extraction from a crisis message using Gemini.
    """
    logger.info(f"Extracting context from crisis message: {crisis_message}")
    
    prompt = f"You are a supply chain assistant. Classify the operational status based on this crisis message. Respond with ONLY one word from this list: [operational, pending, delayed, offline]. Crisis message: '{crisis_message}'"
    
    if client:
        try:
            response = client.models.generate_content(
                model='gemini-1.5-flash',
                contents=prompt,
                config=types.GenerateContentConfig(
                    temperature=0.0
                )
            )
            status = response.text.strip().lower()
            if status in ["operational", "pending", "delayed", "offline"]:
                return status
        except Exception as e:
            logger.error(f"Error calling Gemini API for crisis parsing: {e}")
        
    # Fallback if no client or API error
    msg = crisis_message.lower()
    if "shut" in msg or "offline" in msg or "critical" in msg:
        return "offline"
    elif "delay" in msg or "slow" in msg or "congested" in msg:
        return "delayed"
        
    return "operational"
