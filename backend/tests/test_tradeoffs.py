"""
Integration tests for Module 2.6B — TradeoffsEngine.compute_tradeoff.

All Supabase DB calls and external HTTP calls are mocked so the tests
are hermetic and run without any live infrastructure.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, Optional
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import UUID, uuid4

import pytest

from app.models.tradeoffs import MetricResult, TradeoffAnalysisResponse
from app.services.tradeoffs_engine import TradeoffsEngine

# ---------------------------------------------------------------------------
# Shared test data
# ---------------------------------------------------------------------------

ORG_ID = uuid4()
CURRENT_NODE_ID = uuid4()
ALT_NODE_ID = uuid4()
ALERT_ID = uuid4()
ANALYSIS_ID = uuid4()


def _make_node(
    node_id: UUID,
    lat: float = 48.8566,
    lon: float = 2.3522,
    transport_mode: str = "road",
    name: str = "Test Node",
) -> Dict[str, Any]:
    """Build a minimal supply_chain_node dict that matches what Supabase returns."""
    return {
        "id": str(node_id),
        "organization_id": str(ORG_ID),
        "name": name,
        "node_type": "warehouse",
        "transport_mode": transport_mode,
        "status": "active",
        "deleted_at": None,
        "location": {
            "type": "Point",
            "coordinates": [lon, lat],  # GeoJSON: [lon, lat]
        },
    }


def _supabase_single(data: Dict[str, Any]) -> MagicMock:
    """Return a mock that mimics supabase.table(...).select(...).eq(...).single().execute()."""
    mock = MagicMock()
    mock.data = data
    return mock


def _supabase_list(data: list) -> MagicMock:
    mock = MagicMock()
    mock.data = data
    mock.count = len(data)
    return mock


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def engine() -> TradeoffsEngine:
    return TradeoffsEngine()


@pytest.fixture
def current_node() -> Dict[str, Any]:
    return _make_node(CURRENT_NODE_ID, lat=48.8566, lon=2.3522, name="Paris Warehouse")


@pytest.fixture
def alternative_node() -> Dict[str, Any]:
    return _make_node(ALT_NODE_ID, lat=51.5074, lon=-0.1278, name="London Warehouse", transport_mode="rail")


# ---------------------------------------------------------------------------
# Helper: mock Supabase and ORS
# ---------------------------------------------------------------------------


def _build_supabase_mock(
    current: Dict[str, Any],
    alternative: Dict[str, Any],
    telemetry_data: Optional[list] = None,
    on_time_total: int = 10,
    on_time_count: int = 8,
) -> MagicMock:
    """
    Builds a comprehensive mock of the Supabase client covering:
    - supply_chain_nodes.single() for current and alternative
    - tradeoff_analyses.insert()
    - tradeoff_metrics.insert()
    - telemetry_events queries for cost, reliability
    """
    supabase = MagicMock()

    # Node fetches
    node_results = {
        str(current["id"]): current,
        str(alternative["id"]): alternative,
    }

    def _table_mock(table_name: str) -> MagicMock:
        t = MagicMock()

        if table_name == "supply_chain_nodes":
            def _select(*a, **kw):
                s = MagicMock()
                def _eq(col, val):
                    eq = MagicMock()
                    def _eq2(col2, val2):
                        eq2 = MagicMock()
                        def _single():
                            single = MagicMock()
                            single.execute = MagicMock(
                                return_value=_supabase_single(node_results.get(str(val), current))
                            )
                            return single
                        eq2.single = _single
                        eq2.maybe_single = _single
                        return eq2
                    eq.eq = _eq2
                    return eq
                s.eq = _eq
                return s
            t.select = _select

        elif table_name == "telemetry_events":
            # Always return some cost/reliability data
            exec_result_cost = _supabase_list(telemetry_data or [{"cost_usd": 1200.0}])
            exec_result_total = _supabase_list([{}] * on_time_total)
            exec_result_total.count = on_time_total
            exec_result_ontime = _supabase_list([{}] * on_time_count)
            exec_result_ontime.count = on_time_count

            call_count = {"n": 0}

            def _select_telem(*a, **kw):
                s = MagicMock()
                s.eq = MagicMock(return_value=s)
                s.gte = MagicMock(return_value=s)

                def _execute():
                    call_count["n"] += 1
                    # Alternate between cost, total, on_time per pair of nodes
                    n = call_count["n"]
                    if n % 3 == 1:
                        return exec_result_cost
                    elif n % 3 == 2:
                        return exec_result_total
                    return exec_result_ontime

                s.execute = _execute
                return s

            t.select = _select_telem

        elif table_name in ("tradeoff_analyses", "tradeoff_metrics"):
            insert_mock = MagicMock()
            insert_mock.execute = MagicMock(return_value=MagicMock(data=[{"id": str(ANALYSIS_ID)}]))
            t.insert = MagicMock(return_value=insert_mock)

        return t

    supabase.table = _table_mock
    return supabase


# ---------------------------------------------------------------------------
# Core compute_tradeoff tests
# ---------------------------------------------------------------------------


class TestComputeTradeoff:
    @pytest.mark.asyncio
    async def test_returns_tradeoff_analysis_response(
        self,
        engine: TradeoffsEngine,
        current_node: Dict[str, Any],
        alternative_node: Dict[str, Any],
    ) -> None:
        """compute_tradeoff should always return a TradeoffAnalysisResponse."""
        supabase_mock = _build_supabase_mock(current_node, alternative_node)

        with (
            patch("app.services.tradeoffs_engine.get_supabase_client", return_value=supabase_mock),
            patch("app.services.tradeoffs_engine._ors_travel_time_hours", new=AsyncMock(return_value=(5.0, 3.5))),
            patch("app.services.tradeoffs_engine._avg_telemetry_cost", new=AsyncMock(side_effect=[1200.0, 900.0])),
            patch("app.services.tradeoffs_engine._on_time_rate", new=AsyncMock(side_effect=[78.0, 92.0])),
        ):
            result = await engine.compute_tradeoff(
                current_node_id=CURRENT_NODE_ID,
                alternative_node_id=ALT_NODE_ID,
                org_id=ORG_ID,
                disruption_alert_id=ALERT_ID,
            )

        assert isinstance(result, TradeoffAnalysisResponse)

    @pytest.mark.asyncio
    async def test_exactly_four_metrics_returned(
        self,
        engine: TradeoffsEngine,
        current_node: Dict[str, Any],
        alternative_node: Dict[str, Any],
    ) -> None:
        """Response must contain exactly 4 MetricResult items."""
        supabase_mock = _build_supabase_mock(current_node, alternative_node)

        with (
            patch("app.services.tradeoffs_engine.get_supabase_client", return_value=supabase_mock),
            patch("app.services.tradeoffs_engine._ors_travel_time_hours", new=AsyncMock(return_value=(5.0, 3.5))),
            patch("app.services.tradeoffs_engine._avg_telemetry_cost", new=AsyncMock(side_effect=[1200.0, 900.0])),
            patch("app.services.tradeoffs_engine._on_time_rate", new=AsyncMock(side_effect=[78.0, 92.0])),
        ):
            result = await engine.compute_tradeoff(
                current_node_id=CURRENT_NODE_ID,
                alternative_node_id=ALT_NODE_ID,
                org_id=ORG_ID,
                disruption_alert_id=ALERT_ID,
            )

        assert len(result.metrics) == 4
        metric_types = {m.metric_type for m in result.metrics}
        assert metric_types == {"financial", "time", "carbon", "reliability"}

    @pytest.mark.asyncio
    async def test_recommendation_switch_when_3_or_more_improvements(
        self,
        engine: TradeoffsEngine,
        current_node: Dict[str, Any],
        alternative_node: Dict[str, Any],
    ) -> None:
        """3+ improvements → recommendation='switch'."""
        supabase_mock = _build_supabase_mock(current_node, alternative_node)

        with (
            patch("app.services.tradeoffs_engine.get_supabase_client", return_value=supabase_mock),
            # Time: alternative saves 1.5h (improvement)
            patch("app.services.tradeoffs_engine._ors_travel_time_hours", new=AsyncMock(return_value=(5.0, 3.5))),
            # Financial: alternative cheaper by $300 (improvement)
            patch("app.services.tradeoffs_engine._avg_telemetry_cost", new=AsyncMock(side_effect=[1200.0, 900.0])),
            # Reliability: alternative 14% better (improvement)
            patch("app.services.tradeoffs_engine._on_time_rate", new=AsyncMock(side_effect=[78.0, 92.0])),
        ):
            result = await engine.compute_tradeoff(
                current_node_id=CURRENT_NODE_ID,
                alternative_node_id=ALT_NODE_ID,
                org_id=ORG_ID,
                disruption_alert_id=ALERT_ID,
            )

        # 3 improvements (financial, time, reliability) → switch
        assert result.overall_recommendation == "switch"

    @pytest.mark.asyncio
    async def test_recommendation_stay_when_fewer_than_2_improvements(
        self,
        engine: TradeoffsEngine,
        current_node: Dict[str, Any],
        alternative_node: Dict[str, Any],
    ) -> None:
        """0-1 improvements → recommendation='stay'."""
        supabase_mock = _build_supabase_mock(current_node, alternative_node)

        with (
            patch("app.services.tradeoffs_engine.get_supabase_client", return_value=supabase_mock),
            # Time: alternative slower by 2h (NOT improvement)
            patch("app.services.tradeoffs_engine._ors_travel_time_hours", new=AsyncMock(return_value=(3.0, 5.0))),
            # Financial: alternative more expensive (NOT improvement)
            patch("app.services.tradeoffs_engine._avg_telemetry_cost", new=AsyncMock(side_effect=[900.0, 1400.0])),
            # Reliability: alternative worse (NOT improvement)
            patch("app.services.tradeoffs_engine._on_time_rate", new=AsyncMock(side_effect=[92.0, 75.0])),
        ):
            result = await engine.compute_tradeoff(
                current_node_id=CURRENT_NODE_ID,
                alternative_node_id=ALT_NODE_ID,
                org_id=ORG_ID,
                disruption_alert_id=ALERT_ID,
            )

        assert result.overall_recommendation == "stay"

    @pytest.mark.asyncio
    async def test_recommendation_investigate_on_2_improvements(
        self,
        engine: TradeoffsEngine,
        current_node: Dict[str, Any],
        alternative_node: Dict[str, Any],
    ) -> None:
        """Exactly 2 improvements → recommendation='investigate'."""
        alt_node = alternative_node.copy()
        alt_node["transport_mode"] = "road"
        supabase_mock = _build_supabase_mock(current_node, alt_node)

        with (
            patch("app.services.tradeoffs_engine.get_supabase_client", return_value=supabase_mock),
            # Time: improvement
            patch("app.services.tradeoffs_engine._ors_travel_time_hours", new=AsyncMock(return_value=(5.0, 3.0))),
            # Financial: improvement
            patch("app.services.tradeoffs_engine._avg_telemetry_cost", new=AsyncMock(side_effect=[1200.0, 900.0])),
            # Reliability: worse (NOT improvement)
            patch("app.services.tradeoffs_engine._on_time_rate", new=AsyncMock(side_effect=[92.0, 80.0])),
        ):
            result = await engine.compute_tradeoff(
                current_node_id=CURRENT_NODE_ID,
                alternative_node_id=ALT_NODE_ID,
                org_id=ORG_ID,
                disruption_alert_id=ALERT_ID,
            )

        assert result.overall_recommendation == "investigate"

    @pytest.mark.asyncio
    async def test_org_ids_in_response_match_input(
        self,
        engine: TradeoffsEngine,
        current_node: Dict[str, Any],
        alternative_node: Dict[str, Any],
    ) -> None:
        """Returned org/node IDs must echo the request."""
        supabase_mock = _build_supabase_mock(current_node, alternative_node)

        with (
            patch("app.services.tradeoffs_engine.get_supabase_client", return_value=supabase_mock),
            patch("app.services.tradeoffs_engine._ors_travel_time_hours", new=AsyncMock(return_value=(5.0, 3.5))),
            patch("app.services.tradeoffs_engine._avg_telemetry_cost", new=AsyncMock(side_effect=[1200.0, 900.0])),
            patch("app.services.tradeoffs_engine._on_time_rate", new=AsyncMock(side_effect=[78.0, 92.0])),
        ):
            result = await engine.compute_tradeoff(
                current_node_id=CURRENT_NODE_ID,
                alternative_node_id=ALT_NODE_ID,
                org_id=ORG_ID,
                disruption_alert_id=ALERT_ID,
            )

        assert result.org_id == ORG_ID
        assert result.current_node_id == CURRENT_NODE_ID
        assert result.alternative_node_id == ALT_NODE_ID
        assert result.disruption_alert_id == ALERT_ID

    @pytest.mark.asyncio
    async def test_confidence_bounded_0_to_1(
        self,
        engine: TradeoffsEngine,
        current_node: Dict[str, Any],
        alternative_node: Dict[str, Any],
    ) -> None:
        supabase_mock = _build_supabase_mock(current_node, alternative_node)

        with (
            patch("app.services.tradeoffs_engine.get_supabase_client", return_value=supabase_mock),
            patch("app.services.tradeoffs_engine._ors_travel_time_hours", new=AsyncMock(return_value=(5.0, 3.5))),
            patch("app.services.tradeoffs_engine._avg_telemetry_cost", new=AsyncMock(side_effect=[1200.0, 900.0])),
            patch("app.services.tradeoffs_engine._on_time_rate", new=AsyncMock(side_effect=[78.0, 92.0])),
        ):
            result = await engine.compute_tradeoff(
                current_node_id=CURRENT_NODE_ID,
                alternative_node_id=ALT_NODE_ID,
                org_id=ORG_ID,
                disruption_alert_id=ALERT_ID,
            )

        assert 0.0 <= result.recommendation_confidence <= 1.0


# ---------------------------------------------------------------------------
# Individual axis tests
# ---------------------------------------------------------------------------


class TestFinancialAxis:
    @pytest.mark.asyncio
    async def test_financial_is_improvement_when_alternative_cheaper(
        self, engine: TradeoffsEngine, current_node: Dict[str, Any], alternative_node: Dict[str, Any]
    ) -> None:
        supabase_mock = _build_supabase_mock(current_node, alternative_node)

        with (
            patch("app.services.tradeoffs_engine.get_supabase_client", return_value=supabase_mock),
            patch("app.services.tradeoffs_engine._ors_travel_time_hours", new=AsyncMock(return_value=(5.0, 5.0))),
            patch("app.services.tradeoffs_engine._avg_telemetry_cost", new=AsyncMock(side_effect=[1200.0, 800.0])),
            patch("app.services.tradeoffs_engine._on_time_rate", new=AsyncMock(side_effect=[80.0, 80.0])),
        ):
            result = await engine.compute_tradeoff(
                current_node_id=CURRENT_NODE_ID,
                alternative_node_id=ALT_NODE_ID,
                org_id=ORG_ID,
                disruption_alert_id=ALERT_ID,
            )

        financial = next(m for m in result.metrics if m.metric_type == "financial")
        assert financial.is_improvement is True
        assert financial.delta < 0

    @pytest.mark.asyncio
    async def test_financial_unit_is_usd(
        self, engine: TradeoffsEngine, current_node: Dict[str, Any], alternative_node: Dict[str, Any]
    ) -> None:
        supabase_mock = _build_supabase_mock(current_node, alternative_node)

        with (
            patch("app.services.tradeoffs_engine.get_supabase_client", return_value=supabase_mock),
            patch("app.services.tradeoffs_engine._ors_travel_time_hours", new=AsyncMock(return_value=(5.0, 5.0))),
            patch("app.services.tradeoffs_engine._avg_telemetry_cost", new=AsyncMock(side_effect=[1200.0, 900.0])),
            patch("app.services.tradeoffs_engine._on_time_rate", new=AsyncMock(side_effect=[80.0, 80.0])),
        ):
            result = await engine.compute_tradeoff(
                current_node_id=CURRENT_NODE_ID,
                alternative_node_id=ALT_NODE_ID,
                org_id=ORG_ID,
                disruption_alert_id=ALERT_ID,
            )

        financial = next(m for m in result.metrics if m.metric_type == "financial")
        assert financial.unit == "USD"


class TestTimeAxis:
    @pytest.mark.asyncio
    async def test_time_is_improvement_when_alternative_faster(
        self, engine: TradeoffsEngine, current_node: Dict[str, Any], alternative_node: Dict[str, Any]
    ) -> None:
        supabase_mock = _build_supabase_mock(current_node, alternative_node)

        with (
            patch("app.services.tradeoffs_engine.get_supabase_client", return_value=supabase_mock),
            patch("app.services.tradeoffs_engine._ors_travel_time_hours", new=AsyncMock(return_value=(8.0, 5.0))),
            patch("app.services.tradeoffs_engine._avg_telemetry_cost", new=AsyncMock(side_effect=[1200.0, 1200.0])),
            patch("app.services.tradeoffs_engine._on_time_rate", new=AsyncMock(side_effect=[80.0, 80.0])),
        ):
            result = await engine.compute_tradeoff(
                current_node_id=CURRENT_NODE_ID,
                alternative_node_id=ALT_NODE_ID,
                org_id=ORG_ID,
                disruption_alert_id=ALERT_ID,
            )

        time_m = next(m for m in result.metrics if m.metric_type == "time")
        assert time_m.is_improvement is True
        assert time_m.delta < 0
        assert time_m.unit == "hours"


class TestReliabilityAxis:
    @pytest.mark.asyncio
    async def test_reliability_is_improvement_when_higher_on_time_rate(
        self, engine: TradeoffsEngine, current_node: Dict[str, Any], alternative_node: Dict[str, Any]
    ) -> None:
        supabase_mock = _build_supabase_mock(current_node, alternative_node)

        with (
            patch("app.services.tradeoffs_engine.get_supabase_client", return_value=supabase_mock),
            patch("app.services.tradeoffs_engine._ors_travel_time_hours", new=AsyncMock(return_value=(5.0, 5.0))),
            patch("app.services.tradeoffs_engine._avg_telemetry_cost", new=AsyncMock(side_effect=[1200.0, 1200.0])),
            patch("app.services.tradeoffs_engine._on_time_rate", new=AsyncMock(side_effect=[70.0, 90.0])),
        ):
            result = await engine.compute_tradeoff(
                current_node_id=CURRENT_NODE_ID,
                alternative_node_id=ALT_NODE_ID,
                org_id=ORG_ID,
                disruption_alert_id=ALERT_ID,
            )

        rel = next(m for m in result.metrics if m.metric_type == "reliability")
        assert rel.is_improvement is True
        assert rel.delta > 0
        assert rel.unit == "%"


class TestCarbonAxis:
    @pytest.mark.asyncio
    async def test_carbon_unit_is_kg_co2(
        self, engine: TradeoffsEngine, current_node: Dict[str, Any], alternative_node: Dict[str, Any]
    ) -> None:
        supabase_mock = _build_supabase_mock(current_node, alternative_node)

        with (
            patch("app.services.tradeoffs_engine.get_supabase_client", return_value=supabase_mock),
            patch("app.services.tradeoffs_engine._ors_travel_time_hours", new=AsyncMock(return_value=(5.0, 5.0))),
            patch("app.services.tradeoffs_engine._avg_telemetry_cost", new=AsyncMock(side_effect=[1200.0, 1200.0])),
            patch("app.services.tradeoffs_engine._on_time_rate", new=AsyncMock(side_effect=[80.0, 80.0])),
        ):
            result = await engine.compute_tradeoff(
                current_node_id=CURRENT_NODE_ID,
                alternative_node_id=ALT_NODE_ID,
                org_id=ORG_ID,
                disruption_alert_id=ALERT_ID,
            )

        carbon = next(m for m in result.metrics if m.metric_type == "carbon")
        assert carbon.unit == "kg CO2"

    @pytest.mark.asyncio
    async def test_rail_mode_lower_carbon_than_road(
        self, engine: TradeoffsEngine
    ) -> None:
        """Rail emission factor (0.022) < road (0.062) → carbon improvement."""
        road_node = _make_node(CURRENT_NODE_ID, lat=48.8566, lon=2.3522, transport_mode="road")
        rail_node = _make_node(ALT_NODE_ID, lat=51.5074, lon=-0.1278, transport_mode="rail")
        supabase_mock = _build_supabase_mock(road_node, rail_node)

        with (
            patch("app.services.tradeoffs_engine.get_supabase_client", return_value=supabase_mock),
            patch("app.services.tradeoffs_engine._ors_travel_time_hours", new=AsyncMock(return_value=(5.0, 5.0))),
            patch("app.services.tradeoffs_engine._avg_telemetry_cost", new=AsyncMock(side_effect=[1200.0, 1200.0])),
            patch("app.services.tradeoffs_engine._on_time_rate", new=AsyncMock(side_effect=[80.0, 80.0])),
        ):
            result = await engine.compute_tradeoff(
                current_node_id=CURRENT_NODE_ID,
                alternative_node_id=ALT_NODE_ID,
                org_id=ORG_ID,
                disruption_alert_id=ALERT_ID,
            )

        carbon = next(m for m in result.metrics if m.metric_type == "carbon")
        # Rail has lower emission factor, so carbon delta should be negative (improvement)
        assert carbon.is_improvement is True
