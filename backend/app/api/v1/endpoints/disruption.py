"""
Module 2.5A — Disruption API Endpoint.

POST /api/v1/disruption/scan
"""

from __future__ import annotations

import logging
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from pydantic import BaseModel

from app.core.security import get_current_org_id
from app.models.disruption import ScanResult
from app.services.disruption_service import DisruptionService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/disruption", tags=["disruption"])

_service = DisruptionService()


class ScanRequest(BaseModel):
    org_id: UUID
    force_refresh: bool = False


@router.post(
    "/scan",
    response_model=ScanResult,
    summary="Trigger a real-time disruption scan for an organisation",
    status_code=status.HTTP_200_OK,
)
async def scan_disruptions(
    body: ScanRequest,
    background_tasks: BackgroundTasks,
    current_org_id: UUID = Depends(get_current_org_id),
) -> ScanResult:
    """
    Triggers a full disruption scan for *org_id*:
    - Fetches severe weather data from Open-Meteo for every active node
    - Geo-intersects disruptions against active routes (PostGIS / Haversine)
    - Writes disruption_alerts rows
    - Broadcasts to org:{org_id}:alerts via Supabase Realtime

    The JWT-extracted org must match the requested org_id (tenant isolation).
    If `force_refresh=false` the scan still runs; the flag is reserved for
    future cache-bypass semantics.
    """
    if body.org_id != current_org_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="org_id does not match authenticated organisation",
        )

    logger.info(
        "Disruption scan requested",
        extra={"action": "POST /disruption/scan", "org_id": str(body.org_id)},
    )

    try:
        result = await _service.run_disruption_scan(body.org_id)
    except Exception as exc:
        logger.error("Disruption scan failed for org %s: %s", body.org_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Disruption scan failed. See server logs.",
        ) from exc

    return result
