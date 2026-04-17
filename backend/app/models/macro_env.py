"""
Pydantic models for Module 2.5B — Macro-Environment Risk Classifier.
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class RiskLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class GdeltEvent(BaseModel):
    """A single GDELT 2.0 article/event record."""

    url: str
    title: str
    goldstein_scale: float
    tone: float
    country_code: str
    event_date: datetime


class NewsAlert(BaseModel):
    """A single NewsAPI article with a computed sentiment score."""

    title: str
    description: str
    published_at: datetime
    source_name: str
    url: str
    sentiment_score: float  # computed via keyword-based tone analysis


class AggregatedSignals(BaseModel):
    """All raw signals collected for a country before classification."""

    country_code: str
    gdelt_events: List[GdeltEvent] = Field(default_factory=list)
    news_alerts: List[NewsAlert] = Field(default_factory=list)
    reddit_sentiment: float = 0.0  # -1.0 → 1.0
    collected_at: datetime


class RiskClassification(BaseModel):
    """Output of the risk classifier for a single country."""

    country_code: str
    risk_level: RiskLevel
    confidence: float  # 0.0 – 1.0
    primary_driver: str
    affected_node_ids: List[UUID] = Field(default_factory=list)
    signals_summary: Dict[str, Any] = Field(default_factory=dict)
    classified_at: datetime


class MacroBroadcastPayload(BaseModel):
    """Payload pushed to org:{org_id}:macro-panel Realtime channel."""

    country_code: str
    risk_level: RiskLevel
    confidence: float
    primary_driver: str
    signals_summary: Dict[str, Any] = Field(default_factory=dict)


class MacroEnvSignalResponse(BaseModel):
    """API response model for GET /api/v1/macro-env/signals."""

    id: Optional[UUID] = None
    country_code: str
    risk_level: RiskLevel
    confidence: float
    primary_driver: str
    affected_node_ids: List[UUID] = Field(default_factory=list)
    signals_summary: Dict[str, Any] = Field(default_factory=dict)
    classified_at: datetime
