"""
Module 2.5B — Macro-Environment API Endpoints.

GET  /api/v1/macro-env/signals
POST /api/v1/macro-env/scan
"""

from __future__ import annotations

import logging
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.security import get_current_org_id
from app.db.supabase import get_supabase_client
from app.models.macro_env import MacroEnvSignalResponse, RiskClassification, RiskLevel
from app.services.macro_env_service import MacroEnvService
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/macro-env", tags=["macro-env"])

_service = MacroEnvService()


# ---------------------------------------------------------------------------
# GET /signals
# ---------------------------------------------------------------------------


@router.get(
    "/signals",
    response_model=List[MacroEnvSignalResponse],
    summary="Retrieve latest macro-environment risk signals for an organisation",
    status_code=status.HTTP_200_OK,
)
async def get_macro_signals(
    org_id: UUID = Query(..., description="Organisation UUID (must match JWT)"),
    country_code: Optional[str] = Query(None, description="ISO-2 country code filter"),
    current_org_id: UUID = Depends(get_current_org_id),
) -> List[MacroEnvSignalResponse]:
    """
    Returns stored macro-environment risk signals from macro_environment_signals table.
    Scoped to *org_id* nodes; optional country_code filter.
    """
    if org_id != current_org_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="org_id does not match authenticated organisation",
        )

    supabase = get_supabase_client()
    # macro_environment_signals has no org FK — filter by nodes that belong to org
    # to reconstruct which country_codes belong to this org
    nodes_resp = (
        supabase.table("supply_chain_nodes")
        .select("country_code")
        .eq("organization_id", str(org_id))
        .is_("deleted_at", "null")
        .execute()
    )
    org_country_codes = {
        row["country_code"] for row in (nodes_resp.data or []) if row.get("country_code")
    }

    if country_code:
        if country_code not in org_country_codes:
            return []
        org_country_codes = {country_code}

    if not org_country_codes:
        return []

    query = (
        supabase.table("macro_environment_signals")
        .select("*")
        .in_("country_code", list(org_country_codes))
        .order("created_at", desc=True)
        .limit(100)
    )
    result = query.execute()

    signals: List[MacroEnvSignalResponse] = []
    for row in result.data or []:
        payload = row.get("payload") or {}
        signals.append(
            MacroEnvSignalResponse(
                id=UUID(row["id"]) if row.get("id") else None,
                country_code=row["country_code"],
                risk_level=RiskLevel(row.get("risk_level", "low")),
                confidence=float(payload.get("confidence", 0.5)),
                primary_driver=payload.get("primary_driver", ""),
                affected_node_ids=[UUID(n) for n in payload.get("affected_node_ids", [])],
                signals_summary=payload.get("signals_summary", {}),
                classified_at=datetime.fromisoformat(row["created_at"]).replace(tzinfo=timezone.utc)
                if row.get("created_at")
                else datetime.now(timezone.utc),
            )
        )

    logger.info(
        "Returned macro signals",
        extra={
            "action": "GET /macro-env/signals",
            "org_id": str(org_id),
            "count": len(signals),
        },
    )
    return signals


# ---------------------------------------------------------------------------
# POST /scan
# ---------------------------------------------------------------------------


@router.post(
    "/scan",
    response_model=List[RiskClassification],
    summary="Trigger a full macro-environment risk scan for an organisation",
    status_code=status.HTTP_200_OK,
)
async def scan_macro_env(
    org_id: UUID = Query(..., description="Organisation UUID (must match JWT)"),
    current_org_id: UUID = Depends(get_current_org_id),
) -> List[RiskClassification]:
    """
    Runs MacroEnvService.run_macro_scan_for_org for the authenticated org:
    - Fetches GDELT, NewsAPI, and Reddit signals for each country with active nodes
    - Classifies risk level per country
    - Writes to macro_environment_signals
    - Broadcasts to org:{org_id}:macro-panel
    """
    if org_id != current_org_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="org_id does not match authenticated organisation",
        )

    logger.info(
        "Macro scan requested",
        extra={"action": "POST /macro-env/scan", "org_id": str(org_id)},
    )

    try:
        results = await _service.run_macro_scan_for_org(org_id)
    except Exception as exc:
        logger.error("Macro scan failed for org %s: %s", org_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Macro scan failed. See server logs.",
        ) from exc

    return results
