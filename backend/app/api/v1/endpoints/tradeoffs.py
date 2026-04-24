"""
Module 2.6B — Tradeoffs API Endpoints.

POST /api/v1/tradeoffs/compute
GET  /api/v1/tradeoffs/{analysis_id}
"""

from __future__ import annotations

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.security import get_current_org_id
from app.db.supabase import get_supabase_client
from app.models.tradeoffs import (
    MetricResult,
    TradeoffAnalysisResponse,
    TradeoffRequest,
)
from app.services.tradeoffs_engine import tradeoffs_engine
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/tradeoffs", tags=["tradeoffs"])


# ---------------------------------------------------------------------------
# POST /compute
# ---------------------------------------------------------------------------


@router.post(
    "/compute",
    response_model=TradeoffAnalysisResponse,
    summary="Compute 4-axis tradeoff between two supply-chain nodes",
    status_code=status.HTTP_200_OK,
)
async def compute_tradeoff(
    body: TradeoffRequest,
    current_org_id: UUID = Depends(get_current_org_id),
) -> TradeoffAnalysisResponse:
    """
    Computes and persists a 4-axis tradeoff analysis:
      - Financial cost delta (USD)
      - Time / latency delta (hours)
      - Carbon footprint delta (kg CO₂)
      - Historical reliability delta (% on-time)

    Writes to `tradeoff_analyses` and `tradeoff_metrics` tables.
    Returns the full TradeoffAnalysisResponse for the Flutter tradeoffs drawer.
    """
    if body.org_id != current_org_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="org_id does not match authenticated organisation",
        )

    logger.info(
        "Tradeoff compute requested",
        extra={
            "action": "POST /tradeoffs/compute",
            "org_id": str(body.org_id),
            "current_node_id": str(body.current_node_id),
            "alternative_node_id": str(body.alternative_node_id),
        },
    )

    try:
        result = await tradeoffs_engine.compute_tradeoff(
            current_node_id=body.current_node_id,
            alternative_node_id=body.alternative_node_id,
            org_id=body.org_id,
            disruption_alert_id=body.disruption_alert_id,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        logger.error("Tradeoff compute failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Tradeoff computation failed. See server logs.",
        ) from exc

    return result


# ---------------------------------------------------------------------------
# GET /{analysis_id}
# ---------------------------------------------------------------------------


@router.get(
    "/{analysis_id}",
    response_model=TradeoffAnalysisResponse,
    summary="Retrieve a stored tradeoff analysis by ID",
    status_code=status.HTTP_200_OK,
)
async def get_tradeoff(
    analysis_id: UUID,
    current_org_id: UUID = Depends(get_current_org_id),
) -> TradeoffAnalysisResponse:
    """
    Returns a previously computed TradeoffAnalysis by ID.
    Used by the Flutter tradeoffs drawer on subsequent opens.
    """
    supabase = get_supabase_client()

    # RLS: always include organization_id
    analysis_resp = (
        supabase.table("tradeoff_analyses")
        .select("*")
        .eq("id", str(analysis_id))
        .eq("organization_id", str(current_org_id))
        .maybe_single()
        .execute()
    )

    if getattr(analysis_resp, "data", None) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"TradeoffAnalysis {analysis_id} not found",
        )

    row = analysis_resp.data

    metrics_resp = (
        supabase.table("tradeoff_metrics")
        .select("*")
        .eq("analysis_id", str(analysis_id))
        .execute()
    )

    metrics = [
        MetricResult(
            metric_type=m["metric_type"],
            current_value=float(m["current_value"]),
            alternative_value=float(m["alternative_value"]),
            delta=float(m["delta"]),
            unit=m["unit"],
            is_improvement=_is_improvement(m["metric_type"], float(m["delta"])),
        )
        for m in (metrics_resp.data or [])
    ]

    logger.info(
        "Returned tradeoff analysis",
        extra={
            "action": "GET /tradeoffs/{analysis_id}",
            "analysis_id": str(analysis_id),
            "org_id": str(current_org_id),
        },
    )

    return TradeoffAnalysisResponse(
        analysis_id=UUID(row["id"]),
        org_id=UUID(row["organization_id"]),
        current_node_id=UUID(row["current_node_id"]),
        alternative_node_id=UUID(row["alternative_node_id"]),
        disruption_alert_id=UUID(row["disruption_alert_id"]),
        metrics=metrics,
        overall_recommendation=row.get("overall_recommendation", "investigate"),
        recommendation_confidence=float(row.get("recommendation_confidence", 0.5)),
        created_at=datetime.fromisoformat(row["created_at"]).replace(tzinfo=timezone.utc)
        if row.get("created_at")
        else datetime.now(timezone.utc),
    )


def _is_improvement(metric_type: str, delta: float) -> bool:
    """
    Convention:
      financial, time, carbon → lower is better (delta < 0 is improvement)
      reliability              → higher is better (delta > 0 is improvement)
    """
    if metric_type == "reliability":
        return delta > 0
    return delta < 0
