# Gravity AI Agent Prompt
## Module 2.5 (Real-Time Disruption Alerts & Macro-Environment Side Panel) + Module 2.6 (Actionable Insights & Tradeoffs Tab)
### "Figma for Supply Chain" Platform — Industrial-Grade Implementation

---

## ROLE & OBJECTIVE

You are a senior full-stack engineer building two production-grade backend modules for a real-time, multiplayer supply chain intelligence platform. The platform follows a strict **1-Hop data isolation** architecture, multi-tenant SaaS design, and zero-trust security principles.

Your task is to implement **Module 2.5** and **Module 2.6** end-to-end, covering:
- FastAPI backend services
- Supabase (PostgreSQL + WebSocket) state management
- Free external API integrations
- All Pydantic models and enums
- Database writes and webhook fan-out logic

This is **not a prototype**. Every component must be production-ready: typed, logged, rate-limited, error-resilient, and observable.

---

## PROJECT CONTEXT

### Monorepo Structure (already exists — do NOT recreate root scaffolding)

```
/
├── frontend/                 # Flutter — DO NOT TOUCH
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── core/
│   │   │   ├── config.py
│   │   │   └── security.py
│   │   ├── db/
│   │   │   └── supabase.py
│   │   ├── models/
│   │   │   ├── enums.py
│   │   │   ├── telemetry.py
│   │   │   ├── ai_parser.py
│   │   │   └── tradeoffs.py
│   │   ├── api/v1/endpoints/
│   │   │   ├── ingestion.py
│   │   │   ├── telemetry.py
│   │   │   ├── discovery.py
│   │   │   └── mcp_mgr.py
│   │   ├── services/
│   │   │   ├── ai_service.py
│   │   │   ├── tradeoffs_engine.py
│   │   │   └── webhooks.py
│   │   └── utils/
├── supabase/
│   ├── migrations/
│   │   └── 20260407113300_initial_schema.sql
│   └── seed.sql
├── mcp-template/
└── docker-compose.yml
```

### Files you MUST create or extend in this task:

```
backend/app/
├── api/v1/endpoints/
│   ├── disruption.py          ← NEW (Module 2.5A)
│   └── macro_env.py           ← NEW (Module 2.5B)
├── services/
│   ├── disruption_service.py  ← NEW
│   ├── macro_env_service.py   ← NEW
│   ├── geo_intersect.py       ← NEW
│   ├── risk_classifier.py     ← NEW
│   └── tradeoffs_engine.py    ← EXTEND (Module 2.6B)
├── models/
│   ├── disruption.py          ← NEW
│   └── macro_env.py           ← NEW
└── api/v1/endpoints/
    └── tradeoffs.py           ← NEW (Module 2.6)
```

---

## FREE APIs TO INTEGRATE (NO PAID SERVICES)

| Purpose | API | Base URL | Auth |
|---|---|---|---|
| Weather & severe events | Open-Meteo | `https://api.open-meteo.com/v1` | None |
| Geopolitical events | GDELT 2.0 | `http://api.gdeltproject.org/api/v2` | None |
| News alerts | NewsAPI | `https://newsapi.org/v2` | Free key (env var) |
| Social sentiment | Reddit API | `https://www.reddit.com` | OAuth2 free |
| Geocoding / reverse geo | Nominatim/OSM | `https://nominatim.openstreetmap.org` | None (1 req/sec) |
| Routing distance | OpenRouteService | `https://api.openrouteservice.org` | Free key (env var) |

All keys must be loaded from environment variables — never hardcoded. Rate limits must be respected via a shared `RateLimiter` utility.

---

## MODULE 2.5 — REAL-TIME DISRUPTION ALERTS & MACRO-ENVIRONMENT SIDE PANEL

### 2.5A — Physical Disruption Detection Service

**File:** `backend/app/services/disruption_service.py`  
**Endpoint file:** `backend/app/api/v1/endpoints/disruption.py`

#### What it does:
Polls weather and traffic APIs for physical disruptions (storms, floods, port closures, road blockages). Cross-references each disruption's geographic bounding box against active routing edges stored in Supabase using a **PostGIS ST_Intersects** query. When a disruption intersects an active route or node, it writes a `disruption_alerts` record and triggers a WebSocket broadcast to affected clients.

#### Exact implementation requirements:

**`DisruptionService` class** with these methods:

```python
async def fetch_weather_disruptions(lat: float, lon: float, radius_km: int) -> List[DisruptionEvent]
# Calls Open-Meteo /forecast with hourly weather_code
# Flags codes: 75, 77, 82, 95, 99 (severe weather per WMO classification)
# Returns structured DisruptionEvent objects with severity score

async def geo_intersect_check(disruption: DisruptionEvent, org_id: UUID) -> List[IntersectedAsset]
# Executes PostGIS query against node_edges and supply_chain_nodes
# Query: ST_Intersects(route_geometry, ST_Buffer(ST_Point(lon, lat)::geography, radius_m))
# Returns list of node_ids and edge_ids that fall within the disruption radius

async def write_disruption_alert(disruption: DisruptionEvent, affected_assets: List[IntersectedAsset], org_id: UUID) -> UUID
# Writes to disruption_alerts table
# Fields: node_id (nullable), edge_id (nullable), alert_type, severity, payload (JSONB), organization_id
# Rule enforced: either node_id OR edge_id must be non-null (not both null)

async def broadcast_alert(alert_id: UUID, org_id: UUID) -> None
# Fires Supabase WebSocket broadcast on channel: f"org:{org_id}:alerts"
# Payload: { alert_id, alert_type, severity, affected_node_ids, affected_edge_ids, timestamp }
# This triggers Flutter frontend to flash affected nodes RED

async def run_disruption_scan(org_id: UUID) -> ScanResult
# Orchestrates full pipeline: fetch → intersect → write → broadcast
# Scans all active nodes for the given org in a single pass
# Returns ScanResult with count of alerts generated
```

**Endpoint:** `POST /api/v1/disruption/scan`  
- Auth: JWT required  
- Body: `{ org_id: UUID, force_refresh: bool }`  
- Response: `ScanResult`  
- Background task: schedule via APScheduler every 15 minutes per active org

---

**File:** `backend/app/services/geo_intersect.py`

```python
class GeoIntersectEngine:
    async def get_active_routes_for_org(org_id: UUID) -> List[RouteGeometry]
    # Supabase query: SELECT id, geometry FROM node_edges WHERE organization_id = org_id AND deleted_at IS NULL

    async def point_intersects_route(lat, lon, radius_m, routes: List[RouteGeometry]) -> List[UUID]
    # PostGIS: ST_DWithin(geometry, ST_SetSRID(ST_Point(lon,lat),4326)::geography, radius_m)
    # Falls back to Haversine formula if PostGIS extension unavailable
```

---

### 2.5B — Macro-Environment Risk Classifier

**File:** `backend/app/services/macro_env_service.py`  
**File:** `backend/app/services/risk_classifier.py`  
**Endpoint:** `backend/app/api/v1/endpoints/macro_env.py`

#### What it does:
Aggregates geopolitical signals, news sentiment, and social media alerts for all countries where an organization has active nodes. Runs an NLP risk classification per country/node. Flags AMBER risk if the threshold is breached. Writes to `macro_environment_signals` table. Broadcasts via WebSocket to update the side panel.

#### Exact implementation requirements:

**`MacroEnvService` class:**

```python
async def fetch_gdelt_signals(country_code: str, days_back: int = 3) -> List[GdeltEvent]
# GDELT API: GET /api/v2/doc/doc?query=sourceCountry:{country_code}&mode=artlist&format=json
# Parse: tone score, themes, goldstein_scale
# Filter: goldstein_scale < -5 (high conflict) or tone < -10

async def fetch_news_alerts(country_code: str, keywords: List[str]) -> List[NewsAlert]
# NewsAPI: GET /v2/everything?q={keywords}&language=en&sortBy=publishedAt
# Default keywords: ["strike", "protest", "sanctions", "port closure", "supply chain", "tariff"]
# Rate: max 2 requests/min (100/day budget)

async def fetch_reddit_sentiment(subreddit: str, keywords: List[str]) -> float
# Reddit OAuth2 GET /r/{subreddit}/search.json?q={keyword}&sort=new&limit=25
# Sentiment: average of upvote_ratio weighted by num_comments
# Returns score: -1.0 to 1.0

async def classify_risk(signals: AggregatedSignals) -> RiskClassification
# Rule-based NLP scorer:
# CRITICAL (RED):   gdelt_goldstein < -7 OR news_negative_count > 5
# HIGH (AMBER):     gdelt_goldstein < -5 OR news_negative_count > 2 OR reddit_sentiment < -0.4
# MEDIUM (YELLOW):  any single signal breach
# LOW (GREEN):      no signals
# Returns: { level: RiskLevel, confidence: float, primary_driver: str, country_code: str }

async def write_macro_signal(classification: RiskClassification, org_id: UUID) -> None
# Writes to macro_environment_signals (linked by country_code, no direct FK)
# Broadcasts to: f"org:{org_id}:macro-panel"

async def run_macro_scan_for_org(org_id: UUID) -> List[RiskClassification]
# Fetch all distinct country_codes from supply_chain_nodes WHERE organization_id = org_id
# Run classify_risk for each country
# Return aggregated results
```

**Endpoint:** `GET /api/v1/macro-env/signals`  
- Auth: JWT required  
- Query params: `org_id`, `country_code (optional)`  
- Response: `List[MacroEnvSignalResponse]`

**Endpoint:** `POST /api/v1/macro-env/scan`  
- Triggers full `run_macro_scan_for_org` for authenticated org  
- Background task: schedule every 30 minutes

---

### 2.5C — Supabase Alert State Store & WebSocket Broadcast

**Extend:** `backend/app/services/webhooks.py`

```python
class AlertBroadcaster:
    async def broadcast_disruption(org_id: UUID, payload: DisruptionBroadcastPayload) -> None
    # Supabase Realtime: channel = f"org:{org_id}:alerts"
    # Payload schema: { alert_id, node_ids[], edge_ids[], severity, alert_type, timestamp }

    async def broadcast_macro_update(org_id: UUID, payload: MacroBroadcastPayload) -> None
    # Supabase Realtime: channel = f"org:{org_id}:macro-panel"
    # Payload schema: { country_code, risk_level, confidence, primary_driver, signals_summary }

    async def update_alert_state_table(alert_id: UUID, status: AlertStatus) -> None
    # Updates alert_state table (used by Flutter frontend for diff-based WebSocket sync)
```

---

## MODULE 2.6 — ACTIONABLE INSIGHTS & TRADEOFFS TAB

### 2.6A — Insights Engine

**Extend:** `backend/app/services/tradeoffs_engine.py`

**`InsightsEngine` class:**

```python
async def generate_reroute_suggestion(disrupted_node_id: UUID, org_id: UUID) -> List[RerouteSuggestion]
# When a node/edge is flagged by 2.5A:
# 1. Fetch all alternative paths in the 1-Hop graph for org
# 2. For each alternative: compute estimated time delta using OpenRouteService distance matrix API
# 3. Rank by: lowest latency first, then lowest carbon
# 4. Return: [ { suggestion_text: "Reroute via Border X saves ~12h", time_saved_hours, carbon_delta_kg, confidence } ]
# Fallback if ORS unavailable: use Haversine distance + average speed constants

async def push_insight_to_canvas(node_id: UUID, org_id: UUID, suggestions: List[RerouteSuggestion]) -> None
# Writes to disruption_alerts table as alert_type = 'insight'
# Broadcasts via Supabase Realtime to f"org:{org_id}:canvas-insights"
# Flutter overlays suggestion text directly on the node widget
```

---

### 2.6B — Tradeoffs Tab Calculator

**File:** `backend/app/api/v1/endpoints/tradeoffs.py`  
**Extend:** `backend/app/services/tradeoffs_engine.py`

#### What it does:
When a user selects an alternative node on the canvas (via Module 2.3 discovery), this module computes a precise 4-axis comparison between the current disrupted node and the candidate alternative.

#### 4 Metrics (all calculated server-side):

| Axis | Source | Calculation |
|---|---|---|
| **Financial Cost** | Historical `telemetry_events` avg cost + rerouting surcharge estimate | Delta in USD |
| **Time / Latency** | OpenRouteService distance matrix OR Haversine fallback | Hours saved/added |
| **Carbon Footprint (ESG)** | Distance × modal emission factor (kg CO₂/km per transport mode) | Delta in kg CO₂ |
| **Historical Reliability** | `telemetry_events` delay rate for both nodes (last 90 days) | % on-time rate |

**`TradeoffsEngine` class (extend existing):**

```python
async def compute_tradeoff(
    current_node_id: UUID,
    alternative_node_id: UUID,
    org_id: UUID,
    disruption_alert_id: UUID
) -> TradeoffAnalysis
# Step 1: Fetch both nodes from supply_chain_nodes
# Step 2: Calculate all 4 metrics using sub-methods below
# Step 3: Write TradeoffAnalysis + 4 TradeoffMetric rows to DB
# Step 4: Return full analysis object for frontend rendering

async def _calc_financial_delta(current: Node, alternative: Node) -> MetricResult
# Base: telemetry_events average cost per shipment (last 90 days)
# Rerouting surcharge: distance_delta_km * 0.12 USD/km (constant)

async def _calc_time_delta(current: Node, alternative: Node) -> MetricResult
# OpenRouteService: POST /v2/matrix/driving-hv with origins/destinations
# Fallback: Haversine(current → destination) vs Haversine(alternative → destination)
# Express in hours

async def _calc_carbon_delta(current: Node, alternative: Node) -> MetricResult
# Emission factors (kg CO₂ per tonne-km):
#   road: 0.062, sea: 0.008, air: 0.602, rail: 0.022
# Carbon = distance_km * emission_factor * avg_shipment_weight_tonnes
# Delta = alternative_carbon - current_carbon

async def _calc_reliability_delta(current: Node, alternative: Node) -> MetricResult
# Query telemetry_events WHERE node_id IN (current, alternative) AND recorded_at > NOW() - INTERVAL '90 days'
# on_time_rate = COUNT(status='on_time') / COUNT(*) * 100
# Delta = alternative_rate - current_rate
```

**Endpoint:** `POST /api/v1/tradeoffs/compute`  
- Auth: JWT required  
- Body: `TradeoffRequest { current_node_id, alternative_node_id, org_id, disruption_alert_id }`  
- Response: `TradeoffAnalysisResponse` (full 4-axis result)  
- Also writes to: `tradeoff_analyses` + `tradeoff_metrics` tables

**Endpoint:** `GET /api/v1/tradeoffs/{analysis_id}`  
- Returns stored TradeoffAnalysis by ID  
- Used by Flutter tradeoffs drawer to render on subsequent opens

---

## PYDANTIC MODELS TO CREATE

### `backend/app/models/disruption.py`

```python
class DisruptionEvent(BaseModel):
    id: UUID
    source: Literal["open_meteo", "gdelt", "manual"]
    lat: float
    lon: float
    radius_km: float
    severity: Literal["low", "medium", "high", "critical"]
    alert_type: str  # "weather", "geopolitical", "traffic", "port_closure"
    description: str
    detected_at: datetime
    affected_node_ids: List[UUID] = []
    affected_edge_ids: List[UUID] = []
    raw_payload: Dict[str, Any]  # JSONB

class IntersectedAsset(BaseModel):
    asset_id: UUID
    asset_type: Literal["node", "edge"]
    distance_from_epicenter_km: float

class ScanResult(BaseModel):
    org_id: UUID
    scanned_at: datetime
    nodes_scanned: int
    alerts_generated: int
    alert_ids: List[UUID]

class DisruptionBroadcastPayload(BaseModel):
    alert_id: UUID
    node_ids: List[UUID]
    edge_ids: List[UUID]
    severity: str
    alert_type: str
    timestamp: datetime
```

### `backend/app/models/macro_env.py`

```python
class RiskLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class GdeltEvent(BaseModel):
    url: str
    title: str
    goldstein_scale: float
    tone: float
    country_code: str
    event_date: datetime

class NewsAlert(BaseModel):
    title: str
    description: str
    published_at: datetime
    source_name: str
    url: str
    sentiment_score: float  # computed via tone analysis

class AggregatedSignals(BaseModel):
    country_code: str
    gdelt_events: List[GdeltEvent]
    news_alerts: List[NewsAlert]
    reddit_sentiment: float
    collected_at: datetime

class RiskClassification(BaseModel):
    country_code: str
    risk_level: RiskLevel
    confidence: float  # 0.0 - 1.0
    primary_driver: str
    affected_node_ids: List[UUID]
    signals_summary: Dict[str, Any]
    classified_at: datetime

class MacroBroadcastPayload(BaseModel):
    country_code: str
    risk_level: RiskLevel
    confidence: float
    primary_driver: str
    signals_summary: Dict[str, Any]
```

### `backend/app/models/tradeoffs.py` (extend existing)

```python
class TradeoffRequest(BaseModel):
    current_node_id: UUID
    alternative_node_id: UUID
    org_id: UUID
    disruption_alert_id: UUID

class MetricResult(BaseModel):
    metric_type: Literal["financial", "time", "carbon", "reliability"]
    current_value: float
    alternative_value: float
    delta: float
    unit: str
    is_improvement: bool  # True if alternative is better

class TradeoffAnalysisResponse(BaseModel):
    analysis_id: UUID
    org_id: UUID
    current_node_id: UUID
    alternative_node_id: UUID
    disruption_alert_id: UUID
    metrics: List[MetricResult]  # Exactly 4 items
    overall_recommendation: Literal["switch", "stay", "investigate"]
    recommendation_confidence: float
    created_at: datetime

class RerouteSuggestion(BaseModel):
    suggestion_text: str  # Human-readable e.g. "Reroute via Colombo Port saves ~14h"
    time_saved_hours: float
    carbon_delta_kg: float
    confidence: float
    alternative_node_id: Optional[UUID]
```

---

## DATABASE TABLES USED (Already in migrations — do NOT re-create)

Reference these existing tables exactly:

- `supply_chain_nodes` — `id`, `organization_id`, `partner_org_id`, `location (geography)`, `node_type`, `status`, `deleted_at`
- `node_edges` — `id`, `organization_id`, `source_node_id`, `target_node_id`, `transport_mode`
- `disruption_alerts` — `id`, `organization_id`, `node_id (nullable)`, `edge_id (nullable)`, `alert_type`, `severity`, `payload (JSONB)`, `created_at`
- `macro_environment_signals` — `id`, `country_code`, `signal_type`, `risk_level`, `payload (JSONB)`, `created_at` (no direct FK)
- `telemetry_events` — `id`, `node_id`, `organization_id`, `status`, `recorded_at` (partitioned)
- `tradeoff_analyses` — `id`, `organization_id`, `current_node_id`, `alternative_node_id`, `disruption_alert_id`
- `tradeoff_metrics` — `id`, `analysis_id`, `metric_type`, `current_value`, `alternative_value`, `delta`, `unit`

**RLS Rule**: Every query to these tables MUST include `organization_id = {org_id}` to enforce tenant isolation.

---

## DATA FLOW (Follow this exactly)

### Module 2.5 — Disruption Flow

```
External APIs (Open-Meteo, GDELT, NewsAPI, Reddit)
        ↓
  FastAPI Subscriber / APScheduler
        ↓
  2.5A: DisruptionService.run_disruption_scan(org_id)
  2.5B: MacroEnvService.run_macro_scan_for_org(org_id)
        ↓
  PostGIS geo-intersect check (supply_chain_nodes + node_edges)
        ↓
  Write → disruption_alerts table
  Write → macro_environment_signals table
        ↓
  Supabase WebSocket broadcast:
    - org:{org_id}:alerts        → Flutter flashes nodes RED/AMBER
    - org:{org_id}:macro-panel   → Flutter updates side panel
```

### Module 2.6 — Insights & Tradeoffs Flow

```
Disruption alert received (from 2.5A)
        ↓
  2.6A: InsightsEngine.generate_reroute_suggestion(disrupted_node_id)
        ↓
  Write insight → disruption_alerts (type='insight')
  Broadcast → org:{org_id}:canvas-insights
        ↓
  User selects alternative node (via Module 2.3 discovery)
        ↓
  2.6B: TradeoffsEngine.compute_tradeoff(current, alternative, org_id, alert_id)
        ↓
  Write → tradeoff_analyses + tradeoff_metrics tables
        ↓
  Return TradeoffAnalysisResponse to Flutter tradeoffs drawer
```

---

## ENGINEERING STANDARDS (ALL MANDATORY)

### Logging
```python
import logging
logger = logging.getLogger(__name__)
# Log: every API call (url, status, duration_ms), every DB write, every broadcast
# Format: { timestamp, level, module, org_id, action, duration_ms, error? }
```

### Error Handling
- All external API calls wrapped in `try/except` with graceful degradation
- If Open-Meteo fails → skip disruption scan, log warning, do not crash
- If PostGIS unavailable → fall back to Haversine distance calculation
- If OpenRouteService fails → use Haversine fallback for time/carbon metrics
- All DB writes wrapped in transactions with rollback on failure

### Rate Limiting
```python
# Shared RateLimiter utility at backend/app/utils/rate_limiter.py
class RateLimiter:
    limits = {
        'newsapi': (2, 60),        # 2 req/min
        'nominatim': (1, 1),       # 1 req/sec
        'openmeteo': (60, 60),     # 60 req/min
        'gdelt': (30, 60),         # 30 req/min (conservative)
        'reddit': (60, 60),        # 60 req/min
        'openrouteservice': (40, 60) # 40 req/min (free tier)
    }
    async def acquire(self, service: str) -> None  # Blocks until slot available
```

### Background Scheduling
```python
# In backend/app/main.py — add to existing APScheduler setup:
scheduler.add_job(run_all_disruption_scans, 'interval', minutes=15)
scheduler.add_job(run_all_macro_scans, 'interval', minutes=30)
# run_all_* functions iterate over all active organizations and call per-org scan
```

### Environment Variables (add to `backend/app/core/config.py`)
```python
NEWSAPI_KEY: str
REDDIT_CLIENT_ID: str
REDDIT_CLIENT_SECRET: str
OPENROUTE_KEY: str
# Already present: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, VERTEX_AI_KEY
```

### Testing
- Write `pytest` unit tests for `risk_classifier.py` covering all 4 RiskLevel branches
- Write integration test for `compute_tradeoff` that mocks both node payloads
- Place tests in `backend/tests/test_disruption.py` and `backend/tests/test_tradeoffs.py`

---

## CARBON EMISSION CONSTANTS (hardcoded, no external API needed)

```python
EMISSION_FACTORS_KG_CO2_PER_TONNE_KM = {
    "road": 0.062,
    "sea": 0.008,
    "air": 0.602,
    "rail": 0.022,
    "multimodal": 0.040  # weighted average fallback
}
AVG_SHIPMENT_WEIGHT_TONNES = 20.0  # default if not in telemetry
```

---

## WHAT NOT TO DO

- Do NOT create new database tables — use the existing schema only
- Do NOT expose pricing or cross-org supplier identity in any payload
- Do NOT use any paid API — every integration must use the free tier
- Do NOT skip the RLS `organization_id` filter in any DB query
- Do NOT use synchronous `requests` library — use `httpx` with `asyncio`
- Do NOT hardcode any API keys — use `config.py` environment variables
- Do NOT modify the Flutter frontend or Supabase migration files

---

## DELIVERABLES CHECKLIST

After completion, verify every item:

- [ ] `backend/app/services/disruption_service.py` — complete with all 5 methods
- [ ] `backend/app/services/geo_intersect.py` — PostGIS + Haversine fallback
- [ ] `backend/app/services/macro_env_service.py` — GDELT + NewsAPI + Reddit
- [ ] `backend/app/services/risk_classifier.py` — 4-level rule-based classifier
- [ ] `backend/app/services/tradeoffs_engine.py` — extended with 4-axis calculator + insights
- [ ] `backend/app/api/v1/endpoints/disruption.py` — POST /scan route
- [ ] `backend/app/api/v1/endpoints/macro_env.py` — GET /signals + POST /scan
- [ ] `backend/app/api/v1/endpoints/tradeoffs.py` — POST /compute + GET /{id}
- [ ] `backend/app/models/disruption.py` — all Pydantic models
- [ ] `backend/app/models/macro_env.py` — all Pydantic models + RiskLevel enum
- [ ] `backend/app/models/tradeoffs.py` — extended with TradeoffRequest + MetricResult
- [ ] `backend/app/utils/rate_limiter.py` — shared async rate limiter
- [ ] `backend/tests/test_disruption.py` — unit tests
- [ ] `backend/tests/test_tradeoffs.py` — integration tests
- [ ] APScheduler jobs registered in `main.py`
- [ ] All new env vars documented in `backend/app/core/config.py`

---

*End of prompt. Begin with `disruption_service.py` and work downstream following the data flow diagram.*