"""
AI Service — Gemini 1.5 Flash (Free Tier)

Handles:
  - Cold Start: Multimodal parsing of PDFs, CSVs, emails → entities + relationships
  - Smart Router: NLP crisis-message classification
  - Co-Pilot: Crisis advisory generation
  - MCP: Natural-language connector prompts
"""

import os
import email as email_lib
import logging
import mimetypes
from typing import Optional

from google import genai
from google.genai import types
from app.models.ai_parser import (
    AIExtractionResult,
    SupplyChainNode,
    SupplyChainEdge,
    Coordinate,
)
from app.core.config import settings

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Gemini client — Gemini 2.5 Flash
# ---------------------------------------------------------------------------
MODEL_NAME = "gemini-2.5-flash"

api_key = settings.GEMINI_API_KEY
client = genai.Client(api_key=api_key) if api_key else None


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _detect_mime(filename: str) -> str:
    """Return the MIME type for a filename, defaulting to octet-stream."""
    mime, _ = mimetypes.guess_type(filename)
    return mime or "application/octet-stream"


def _extract_text_from_eml(raw_bytes: bytes) -> str:
    """Parse .eml / .msg email files and return the plain-text body."""
    try:
        msg = email_lib.message_from_bytes(raw_bytes)
        parts: list[str] = []
        if msg.is_multipart():
            for part in msg.walk():
                ctype = part.get_content_type()
                if ctype == "text/plain":
                    payload = part.get_payload(decode=True)
                    if payload:
                        parts.append(payload.decode("utf-8", errors="replace"))
        else:
            payload = msg.get_payload(decode=True)
            if payload:
                parts.append(payload.decode("utf-8", errors="replace"))
        # Also grab subject + from as useful context
        subject = msg.get("Subject", "")
        sender = msg.get("From", "")
        header = f"From: {sender}\nSubject: {subject}\n\n"
        return header + "\n".join(parts)
    except Exception as exc:
        logger.warning("Email parsing fallback: %s", exc)
        return raw_bytes.decode("utf-8", errors="replace")


# ---------------------------------------------------------------------------
# 1. Cold Start — Unstructured File Parsing (entities + relationships)
# ---------------------------------------------------------------------------

_EXTRACTION_PROMPT = """You are a supply chain intelligence system. Analyze the following data and extract:

1. **Nodes**: Every supply chain entity (facilities, suppliers, warehouses, factories, ports, retailers).
   For each node provide: a unique node_id, name, type, geographic coordinates (lat/lng), and status.

2. **Edges**: Every relationship between nodes (e.g., "Supplier A supplies_to Warehouse B").
   For each edge provide: source_node_id, target_node_id, relationship_type, and a short label.

If coordinates are not explicitly stated, infer them from city/country names.
If status is unknown, default to "operational".

Data to analyze:
"""

_STUB_RESULT = AIExtractionResult(
    nodes=[
        SupplyChainNode(
            node_id="EXTRACTED-NODE-01",
            name="Global Distribution Center",
            type="warehouse",
            location=Coordinate(lat=34.0522, lng=-118.2437),
            status="operational",
        )
    ],
    edges=[],
    confidence=0.1,
)


async def process_unstructured_file(
    file_content: bytes, filename: str
) -> AIExtractionResult:
    """
    Cold Start Track — Multimodal AI parsing of PDFs, CSVs, emails.

    • Text files (CSV/TXT): decoded and sent as text prompt.
    • Binary files (PDF): sent as inline binary via Gemini multimodal.
    • Email files (.eml): parsed with Python email stdlib, then sent as text.
    """
    logger.info("Processing unstructured file: %s", filename)

    lower = filename.lower()
    mime = _detect_mime(filename)

    if not client:
        logger.warning("GEMINI_API_KEY not set. Returning stub data for Cold Start.")
        return _STUB_RESULT

    try:
        # ----- Route by file type -----
        if lower.endswith((".eml", ".msg")):
            # EMAIL: extract body and send as text
            text_content = _extract_text_from_eml(file_content)
            contents = [_EXTRACTION_PROMPT + text_content]

        elif lower.endswith(".pdf") or mime == "application/pdf":
            # PDF BINARY: send via Gemini multimodal inline_data
            contents = [
                _EXTRACTION_PROMPT,
                types.Part.from_bytes(data=file_content, mime_type="application/pdf"),
            ]

        else:
            # TEXT / CSV: decode and send as text prompt
            try:
                text_content = file_content.decode("utf-8")
            except UnicodeDecodeError:
                text_content = file_content.decode("latin-1", errors="replace")
            contents = [_EXTRACTION_PROMPT + text_content]

        # ----- Call Gemini 1.5 Flash -----
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=contents,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=AIExtractionResult,
                temperature=0.1,
            ),
        )

        if response.parsed:
            return response.parsed

        raise ValueError("AI did not return a valid schema.")

    except Exception as exc:
        logger.error("Error calling Gemini API for file parsing: %s", exc)
        return _STUB_RESULT


# ---------------------------------------------------------------------------
# 2. Smart Router — Crisis NLP Classification
# ---------------------------------------------------------------------------

async def extract_status_from_crisis(crisis_message: str) -> str:
    """
    Classify operational status from a crisis message using Gemini 1.5 Flash.
    Returns one of: operational, pending, delayed, offline.
    """
    logger.info("Extracting context from crisis message: %s", crisis_message)

    prompt = (
        "You are a supply chain assistant. Classify the operational status based on "
        "this crisis message. Respond with ONLY one word from this list: "
        "[operational, pending, delayed, offline]. "
        f"Crisis message: '{crisis_message}'"
    )

    if client:
        try:
            response = client.models.generate_content(
                model=MODEL_NAME,
                contents=prompt,
                config=types.GenerateContentConfig(temperature=0.0),
            )
            status = response.text.strip().lower()
            if status in ("operational", "pending", "delayed", "offline"):
                return status
        except Exception as exc:
            logger.error("Error calling Gemini API for crisis parsing: %s", exc)

    # Fallback keyword heuristic
    msg = crisis_message.lower()
    if any(kw in msg for kw in ("shut", "offline", "critical", "closed")):
        return "offline"
    if any(kw in msg for kw in ("delay", "slow", "congested", "strike")):
        return "delayed"
    return "operational"


# ---------------------------------------------------------------------------
# 3. Co-Pilot — Crisis Advisory Generation
# ---------------------------------------------------------------------------

async def generate_crisis_advisory(
    crisis_message: str, node_id: str, status: str
) -> str:
    """
    Generate a short, actionable advisory for the AI Co-Pilot panel
    when a crisis message is detected.
    """
    prompt = (
        "You are an AI supply chain co-pilot. A crisis has been detected:\n"
        f"Node: {node_id}\n"
        f"Status: {status}\n"
        f"Crisis Report: {crisis_message}\n\n"
        "Provide a brief (2-3 sentence) actionable advisory for the operations team. "
        "Include recommended immediate actions and potential downstream impacts."
    )

    if client:
        try:
            response = client.models.generate_content(
                model=MODEL_NAME,
                contents=prompt,
                config=types.GenerateContentConfig(temperature=0.3),
            )
            return response.text.strip()
        except Exception as exc:
            logger.error("Error generating crisis advisory: %s", exc)

    return (
        f"⚠️ ALERT: Node {node_id} status changed to {status}. "
        f"Crisis: {crisis_message}. "
        "Recommend activating contingency routes and notifying downstream partners."
    )


# ---------------------------------------------------------------------------
# 4. MCP — Natural-Language Connector Prompt
# ---------------------------------------------------------------------------

async def generate_mcp_prompt(db_type: str, ip_address: str, table_name: str) -> str:
    """
    Generate an AI-authored natural-language prompt describing the MCP connector
    that was just created, matching the SRS requirement:
    "I have generated the secure MCP connector for your Oracle ERP..."
    """
    prompt = (
        "You are an AI assistant for a supply chain platform. "
        f"A secure MCP (Model Context Protocol) Docker container has just been generated "
        f"to connect to a {db_type} database at {ip_address}, tracking the '{table_name}' table.\n\n"
        "Write a single professional confirmation message (2-3 sentences) addressed to the user, "
        "explaining what was generated, that it uses a Zero-Trust architecture with a local SQLite "
        "shock absorber, and asking if they'd like to begin mapping live telemetry to the Main Canvas."
    )

    if client:
        try:
            response = client.models.generate_content(
                model=MODEL_NAME,
                contents=prompt,
                config=types.GenerateContentConfig(temperature=0.5),
            )
            return response.text.strip()
        except Exception as exc:
            logger.error("Error generating MCP prompt: %s", exc)

    return (
        f"I have generated the secure MCP connector for your {db_type} ERP at {ip_address}. "
        f"The container uses a Zero-Trust architecture with a local SQLite shock absorber to safely "
        f"sync the '{table_name}' table without exposing your database. "
        "Should I begin mapping live telemetry to the Main Canvas?"
    )
