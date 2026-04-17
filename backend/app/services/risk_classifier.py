"""
Module 2.5B — Rule-Based Risk Classifier.

Accepts an AggregatedSignals object and returns a RiskClassification
using deterministic thresholds defined in the prompt specification.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import List
from uuid import UUID

from app.models.macro_env import AggregatedSignals, RiskClassification, RiskLevel

logger = logging.getLogger(__name__)

# Classification thresholds (from spec)
_CRITICAL_GOLDSTEIN = -7.0
_CRITICAL_NEWS_COUNT = 5
_HIGH_GOLDSTEIN = -5.0
_HIGH_NEWS_COUNT = 2
_HIGH_REDDIT_SENTIMENT = -0.4


class RiskClassifier:
    """
    4-level rule-based NLP risk classifier.

    Thresholds:
      CRITICAL (RED):   goldstein < -7  OR  news_negative_count > 5
      HIGH     (AMBER): goldstein < -5  OR  news_negative_count > 2  OR reddit_sentiment < -0.4
      MEDIUM   (YELLOW): any single signal breaches its lower bound
      LOW      (GREEN):  no breached signals
    """

    def classify(
        self,
        signals: AggregatedSignals,
        affected_node_ids: List[UUID] | None = None,
    ) -> RiskClassification:
        """
        Classify the risk level for a country from aggregated signals.

        Args:
            signals: All raw signals for a country.
            affected_node_ids: Node IDs in that country (for the response).

        Returns:
            RiskClassification with level, confidence, and primary driver.
        """
        # --- derived metrics ------------------------------------------------
        min_goldstein = self._min_goldstein(signals)
        news_negative_count = self._count_negative_news(signals)
        reddit_score = signals.reddit_sentiment
        gdelt_count = len(signals.gdelt_events)

        level, primary_driver, confidence = self._apply_rules(
            min_goldstein, news_negative_count, reddit_score, gdelt_count
        )

        classification = RiskClassification(
            country_code=signals.country_code,
            risk_level=level,
            confidence=confidence,
            primary_driver=primary_driver,
            affected_node_ids=affected_node_ids or [],
            signals_summary={
                "min_goldstein_scale": min_goldstein,
                "news_negative_count": news_negative_count,
                "reddit_sentiment": reddit_score,
                "gdelt_event_count": gdelt_count,
                "news_alert_count": len(signals.news_alerts),
            },
            classified_at=datetime.now(timezone.utc),
        )

        logger.info(
            "Risk classified",
            extra={
                "action": "classify_risk",
                "country_code": signals.country_code,
                "risk_level": level.value,
                "confidence": confidence,
                "primary_driver": primary_driver,
            },
        )
        return classification

    # ------------------------------------------------------------------
    # Rule engine
    # ------------------------------------------------------------------

    def _apply_rules(
        self,
        min_goldstein: float,
        news_negative_count: int,
        reddit_score: float,
        gdelt_count: int,
    ) -> tuple[RiskLevel, str, float]:
        """Apply threshold rules and return (level, primary_driver, confidence)."""

        # CRITICAL
        if min_goldstein < _CRITICAL_GOLDSTEIN:
            return RiskLevel.CRITICAL, "gdelt_goldstein_extreme", 0.95
        if news_negative_count > _CRITICAL_NEWS_COUNT:
            return RiskLevel.CRITICAL, "high_volume_negative_news", 0.90

        # HIGH
        if min_goldstein < _HIGH_GOLDSTEIN:
            return RiskLevel.HIGH, "gdelt_goldstein_high", 0.80
        if news_negative_count > _HIGH_NEWS_COUNT:
            return RiskLevel.HIGH, "elevated_negative_news", 0.75
        if reddit_score < _HIGH_REDDIT_SENTIMENT:
            return RiskLevel.HIGH, "negative_social_sentiment", 0.70

        # MEDIUM — any single weaker signal
        if min_goldstein < 0:
            return RiskLevel.MEDIUM, "mild_gdelt_signals", 0.55
        if news_negative_count > 0:
            return RiskLevel.MEDIUM, "some_negative_news", 0.50
        if reddit_score < 0:
            return RiskLevel.MEDIUM, "slightly_negative_sentiment", 0.45
        if gdelt_count > 0 and min_goldstein <= 0.0:
            return RiskLevel.MEDIUM, "gdelt_activity_present", 0.40

        # LOW
        return RiskLevel.LOW, "no_signals", 0.95

    # ------------------------------------------------------------------
    # Metric extractors
    # ------------------------------------------------------------------

    def _min_goldstein(self, signals: AggregatedSignals) -> float:
        """Return the minimum (most negative) Goldstein scale across GDELT events."""
        if not signals.gdelt_events:
            return 0.0
        return min(e.goldstein_scale for e in signals.gdelt_events)

    def _count_negative_news(self, signals: AggregatedSignals) -> int:
        """Count NewsAlert objects with a negative sentiment score."""
        return sum(1 for n in signals.news_alerts if n.sentiment_score < 0)


# Module-level singleton
risk_classifier = RiskClassifier()
