"""
Unit tests for Module 2.5B — RiskClassifier.

Covers all 4 RiskLevel branches using deterministic signal inputs.
No external API calls — pure unit tests.
"""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.models.macro_env import AggregatedSignals, GdeltEvent, NewsAlert, RiskLevel
from app.services.risk_classifier import RiskClassifier


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _make_gdelt(goldstein: float, tone: float = 0.0) -> GdeltEvent:
    return GdeltEvent(
        url="https://example.com/article",
        title="Test GDELT Event",
        goldstein_scale=goldstein,
        tone=tone,
        country_code="US",
        event_date=datetime.now(timezone.utc),
    )


def _make_news(sentiment: float) -> NewsAlert:
    return NewsAlert(
        title="Test News Alert",
        description="Some supply chain disruption news.",
        published_at=datetime.now(timezone.utc),
        source_name="Reuters",
        url="https://reuters.com/test",
        sentiment_score=sentiment,
    )


def _make_signals(
    gdelt_events: list[GdeltEvent] | None = None,
    news_alerts: list[NewsAlert] | None = None,
    reddit_sentiment: float = 0.0,
    country_code: str = "US",
) -> AggregatedSignals:
    return AggregatedSignals(
        country_code=country_code,
        gdelt_events=gdelt_events or [],
        news_alerts=news_alerts or [],
        reddit_sentiment=reddit_sentiment,
        collected_at=datetime.now(timezone.utc),
    )


@pytest.fixture
def classifier() -> RiskClassifier:
    return RiskClassifier()


# ---------------------------------------------------------------------------
# Branch 1 — LOW risk
# ---------------------------------------------------------------------------


class TestLowRisk:
    def test_no_signals_returns_low(self, classifier: RiskClassifier) -> None:
        signals = _make_signals()
        result = classifier.classify(signals)
        assert result.risk_level == RiskLevel.LOW

    def test_positive_gdelt_returns_low(self, classifier: RiskClassifier) -> None:
        signals = _make_signals(gdelt_events=[_make_gdelt(goldstein=5.0)])
        result = classifier.classify(signals)
        assert result.risk_level == RiskLevel.LOW

    def test_positive_reddit_returns_low(self, classifier: RiskClassifier) -> None:
        signals = _make_signals(reddit_sentiment=0.8)
        result = classifier.classify(signals)
        assert result.risk_level == RiskLevel.LOW

    def test_confidence_high_for_low(self, classifier: RiskClassifier) -> None:
        signals = _make_signals()
        result = classifier.classify(signals)
        assert result.confidence >= 0.90

    def test_primary_driver_is_no_signals(self, classifier: RiskClassifier) -> None:
        signals = _make_signals()
        result = classifier.classify(signals)
        assert result.primary_driver == "no_signals"


# ---------------------------------------------------------------------------
# Branch 2 — MEDIUM risk
# ---------------------------------------------------------------------------


class TestMediumRisk:
    def test_mild_negative_gdelt_returns_medium(self, classifier: RiskClassifier) -> None:
        # goldstein < 0 but >= -5 → MEDIUM
        signals = _make_signals(gdelt_events=[_make_gdelt(goldstein=-2.0)])
        result = classifier.classify(signals)
        assert result.risk_level == RiskLevel.MEDIUM

    def test_single_negative_news_returns_medium(self, classifier: RiskClassifier) -> None:
        # 1 negative article, no GDELT, no reddit → MEDIUM
        signals = _make_signals(news_alerts=[_make_news(-0.2)])
        result = classifier.classify(signals)
        assert result.risk_level == RiskLevel.MEDIUM

    def test_slightly_negative_reddit_returns_medium(self, classifier: RiskClassifier) -> None:
        # reddit slightly negative but > -0.4 → MEDIUM
        signals = _make_signals(reddit_sentiment=-0.1)
        result = classifier.classify(signals)
        assert result.risk_level == RiskLevel.MEDIUM

    def test_gdelt_present_no_negative_score_returns_medium(
        self, classifier: RiskClassifier
    ) -> None:
        # goldstein exactly 0 — event present but not negative
        signals = _make_signals(gdelt_events=[_make_gdelt(goldstein=0.0)])
        result = classifier.classify(signals)
        assert result.risk_level == RiskLevel.MEDIUM

    def test_medium_signals_summary_populated(self, classifier: RiskClassifier) -> None:
        signals = _make_signals(news_alerts=[_make_news(-0.5)])
        result = classifier.classify(signals)
        assert "news_negative_count" in result.signals_summary
        assert result.signals_summary["news_negative_count"] >= 1


# ---------------------------------------------------------------------------
# Branch 3 — HIGH risk
# ---------------------------------------------------------------------------


class TestHighRisk:
    def test_goldstein_below_minus5_returns_high(self, classifier: RiskClassifier) -> None:
        signals = _make_signals(gdelt_events=[_make_gdelt(goldstein=-6.0)])
        result = classifier.classify(signals)
        assert result.risk_level == RiskLevel.HIGH

    def test_three_negative_news_returns_high(self, classifier: RiskClassifier) -> None:
        # news_negative_count > 2 → HIGH
        signals = _make_signals(
            news_alerts=[_make_news(-0.3), _make_news(-0.5), _make_news(-0.1)]
        )
        result = classifier.classify(signals)
        assert result.risk_level == RiskLevel.HIGH

    def test_reddit_sentiment_below_minus04_returns_high(
        self, classifier: RiskClassifier
    ) -> None:
        signals = _make_signals(reddit_sentiment=-0.5)
        result = classifier.classify(signals)
        assert result.risk_level == RiskLevel.HIGH

    def test_high_risk_confidence_above_065(self, classifier: RiskClassifier) -> None:
        signals = _make_signals(gdelt_events=[_make_gdelt(goldstein=-6.0)])
        result = classifier.classify(signals)
        assert result.confidence >= 0.65

    def test_primary_driver_identifies_gdelt(self, classifier: RiskClassifier) -> None:
        signals = _make_signals(gdelt_events=[_make_gdelt(goldstein=-6.0)])
        result = classifier.classify(signals)
        assert "gdelt" in result.primary_driver


# ---------------------------------------------------------------------------
# Branch 4 — CRITICAL risk
# ---------------------------------------------------------------------------


class TestCriticalRisk:
    def test_goldstein_below_minus7_returns_critical(self, classifier: RiskClassifier) -> None:
        signals = _make_signals(gdelt_events=[_make_gdelt(goldstein=-8.0)])
        result = classifier.classify(signals)
        assert result.risk_level == RiskLevel.CRITICAL

    def test_six_negative_news_returns_critical(self, classifier: RiskClassifier) -> None:
        # news_negative_count > 5 → CRITICAL
        news = [_make_news(-0.4) for _ in range(6)]
        signals = _make_signals(news_alerts=news)
        result = classifier.classify(signals)
        assert result.risk_level == RiskLevel.CRITICAL

    def test_goldstein_exactly_minus7_is_not_critical(
        self, classifier: RiskClassifier
    ) -> None:
        # boundary: -7 is NOT < -7, so should be HIGH not CRITICAL
        signals = _make_signals(gdelt_events=[_make_gdelt(goldstein=-7.0)])
        result = classifier.classify(signals)
        assert result.risk_level == RiskLevel.HIGH

    def test_critical_confidence_very_high(self, classifier: RiskClassifier) -> None:
        signals = _make_signals(gdelt_events=[_make_gdelt(goldstein=-9.0)])
        result = classifier.classify(signals)
        assert result.confidence >= 0.85

    def test_primary_driver_is_gdelt_extreme(self, classifier: RiskClassifier) -> None:
        signals = _make_signals(gdelt_events=[_make_gdelt(goldstein=-9.0)])
        result = classifier.classify(signals)
        assert result.primary_driver == "gdelt_goldstein_extreme"

    def test_primary_driver_is_high_volume_news(self, classifier: RiskClassifier) -> None:
        news = [_make_news(-0.6) for _ in range(6)]
        signals = _make_signals(news_alerts=news)
        result = classifier.classify(signals)
        assert result.primary_driver == "high_volume_negative_news"


# ---------------------------------------------------------------------------
# Cross-cutting — affected_node_ids propagation
# ---------------------------------------------------------------------------


class TestAffectedNodeIds:
    def test_node_ids_propagated_to_result(self, classifier: RiskClassifier) -> None:
        node_ids = [uuid4(), uuid4()]
        signals = _make_signals()
        result = classifier.classify(signals, affected_node_ids=node_ids)
        assert result.affected_node_ids == node_ids

    def test_empty_node_ids_by_default(self, classifier: RiskClassifier) -> None:
        signals = _make_signals()
        result = classifier.classify(signals)
        assert result.affected_node_ids == []


# ---------------------------------------------------------------------------
# Signals summary structure
# ---------------------------------------------------------------------------


class TestSignalsSummary:
    def test_summary_contains_all_keys(self, classifier: RiskClassifier) -> None:
        signals = _make_signals(
            gdelt_events=[_make_gdelt(-3.0)],
            news_alerts=[_make_news(-0.2)],
            reddit_sentiment=-0.1,
        )
        result = classifier.classify(signals)
        expected_keys = {
            "min_goldstein_scale",
            "news_negative_count",
            "reddit_sentiment",
            "gdelt_event_count",
            "news_alert_count",
        }
        assert expected_keys == set(result.signals_summary.keys())

    def test_gdelt_count_matches_input(self, classifier: RiskClassifier) -> None:
        gdelt = [_make_gdelt(-1.0), _make_gdelt(-2.0), _make_gdelt(-3.0)]
        signals = _make_signals(gdelt_events=gdelt)
        result = classifier.classify(signals)
        assert result.signals_summary["gdelt_event_count"] == 3
