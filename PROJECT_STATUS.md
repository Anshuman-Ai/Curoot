# Curoot - Project Status & Architecture Guide

## Project Overview
Curoot is a high-end, intelligent supply chain platform featuring a dynamic, node-based multiplayer canvas. It leverages predictive AI, macro-environmental risk assessment, and Model Context Protocol (MCP) data sovereignty integrations to provide a premium enterprise solution.

## Technology Stack
- **Frontend Framework:** Flutter / Dart
- **State Management:** Riverpod 3.x (NotifierProvider architecture)
- **Backend API:** FastAPI (Python) — Uvicorn, APScheduler
- **AI Engine:** Google Gemini 1.5 Flash via `google-genai` SDK (Structured Outputs)
- **Database & Auth:** Supabase (PostgreSQL, Row Level Security, Realtime WebSockets)
- **Containerisation:** Docker / Docker Compose (MCP Zero-Trust adapters)
- **Design System:** Custom Dark-Mode tokens, Google Fonts (`Manrope`)

---

## 🟢 Completed Features

### 1. Interactive Multiplayer Canvas (`lib/ui/canvas/multiplayer_canvas.dart`)
- **Infinite 2D Workspace:** Engineered with an unbounded `InteractiveViewer` and intercepted `PointerScrollEvent` for smooth, bidirectional (X/Y) panning.
- **Node & Edge Rendering:** Custom painters render edges and positioned node widgets. 
- **Draggable Nodes:** Real-time state updates when dragging nodes.
- **Top Utility Bar:** Features buttons for "Search", "Recenter (crosshair)", and a premium "Community" marketplace button.
- **Background Aesthetics:** Infinite dot-grid background mapped directly to the matrix transformation for synchronized scaling.

### 2. Left Navigation Panel (`lib/ui/panels/left_panel.dart`)
- **Expandable Side-Rail:** Elegant expanding navigation (60px tray to 320px expanded panel) with animated width transitions.
- **Integrated Tabs:** Profile, Home, Omni-Ingestion (Upload), Add Node, Search, and Settings.
- **Routing:** Tapping the `Settings` icon seamlessly pushes the user out of the canvas overlay and into the dedicated settings route.

### 3. Right Context Panel (`lib/ui/panels/right_panel.dart`)
- **Node Details Dashboard:** Appears contextually when a canvas node is tapped.
- **Metrics Display:** Premium visualization of Carbon ESG (e.g., 84T CO₂), Reliability bars, and Macro Risks.
- **Disruption Alerts:** Dynamic warning alerts triggered by risk factors (e.g., Port Congestion).
- **Trade-Offs Engine:** Allows users to compare alternative supply chain nodes and dynamically pings the backend for comparative analysis (Cost Δ, Time Δ, Carbon Δ) with a switch/stay recommendation.

### 4. Comprehensive Settings Dashboard (`lib/ui/settings/settings_page.dart`)
- **High-End UI:** Full-screen desktop interface with a persistent left-rail navigator.
- **Organization & Team Management:** Features a multi-tenant workspace switcher relying on Supabase `organization_members`.
- **Network & RFP Preferences:** Interactive slider for default RFP reply timeframes and Admin Bot-abuse override toggles.
- **Data Sovereignty (MCP):** Features a critical "Master MCP Kill-Switch" to sever legacy ERP connections and a Pydantic "Universal Filter Rules" input to explicitly strip outgoing telemetry data payload keys.
- **Alerts & Predictive Engine Calibration:** Checkbox subscriptions for Macro-Environment risks (Geopolitical, Weather, Financial) and a "Dark Node Threshold" calibration slider.
- **Community & Templates:** Marketplace dashboard to manage, update, and unpublish active supply chain setups.

### 5. Supabase State Integrations (`lib/state/settings_provider.dart` & `canvas_provider.dart`)
- **Strict RLS Enforcement:** All critical providers automatically filter requests by `organization_id` based on the actively selected tenant in the workspace switcher.
- **Riverpod Upgrades:** Successfully migrated away from deprecated `StateProvider` and `activeColor` elements to support modern `NotifierProvider` logic and `activeThumbColor`.

### 6. Canvas ↔ Supabase Realtime Data Pipeline
- **Database Migration:** Added `ui_x` and `ui_y` columns to `supply_chain_nodes` via `20260423012300_add_canvas_ui_coordinates.sql`, decoupling pixel canvas coordinates from geographic lat/lon.
- **Live Data Initialization:** `CanvasNotifier` fetches nodes and edges from Supabase on build, scoped by `organization_id` for 1-Hop isolation. Dummy hardcoded nodes (`supplier_taiwan`, `enterprise_a`, etc.) removed.
- **Realtime Subscriptions:** `SupabaseService.streamNodes()` subscribes to PostgreSQL Changes on `supply_chain_nodes`, syncing `INSERT`/`UPDATE`/`DELETE` events across multiplayer clients instantly.
- **Debounced Position Persistence:** Node drag events update local state at 60fps and persist coordinates to Supabase via a 500ms `Timer` debounce to prevent API rate-limit throttling.
- **Loading States:** Canvas UI displays a `CircularProgressIndicator` while the initial Supabase fetch completes.

### 7. Omni-Format AI Ingestion & Generation Layer (SRS §2.1) ✅ COMPLETE
All three tracks of the Omni Ingestion gateway are fully implemented and tested:

#### Track 1 — Cold Start (Unstructured AI Parsing)
- **Multimodal File Parsing (`/api/v1/ingestion/unstructured`):** Accepts PDFs (binary via Gemini multimodal `Part.from_bytes()`), CSVs, TXT files, and emails (`.eml` via Python `email` stdlib).
- **Entity + Relationship Extraction:** Gemini 1.5 Flash extracts `SupplyChainNode` entities AND `SupplyChainEdge` relationships with geographic coordinates.
- **Database Persistence:** Extracted nodes are upserted into `supply_chain_nodes`, edges into `node_edges`, with `ingestion_jobs` tracking each upload.
- **Frontend Integration:** Drag-and-drop zone, file picker, and AI extraction result dialog in `OmniIngestionPanel`.

#### Track 2 — Continuous Sync (Zero-Trust MCP Pull)
- **Dynamic MCP Script Generation (`/api/v1/mcp_mgr/generate`):** Generates fully working Python scripts customised per database type (PostgreSQL, MySQL, Oracle, SQL Server) with proper driver imports and connection strings.
- **SQLite Shock Absorber:** Generated containers buffer data locally in SQLite to prevent read-heavy polling from crashing legacy databases.
- **Append-Only HTTPS Push:** MCP containers push data outward via secure HTTPS to the platform's ingestion webhook.
- **AI Natural-Language Prompt:** Gemini 1.5 Flash generates contextual confirmation messages (e.g., "I have generated the secure MCP connector for your Oracle ERP…").
- **Reference Implementation (`mcp-template/`):** Full working container with `erp_connector.py` (factory-pattern multi-DB), `sqlite_buffer.py` (Shock Absorber), `sync_worker.py` (HTTPS push), `main.py` (poll loop), `Dockerfile`, and `requirements.txt`.
- **Frontend MCP Wizard:** 4-step wizard (Config → Generation → Verification → Download) with terminal animation and clipboard copy.
- **Supabase Tracking:** `ingestion_jobs` and `mcp_containers` records persisted on generation.

#### Track 3 — Modern Push (Webhooks + Smart Router)
- **Deterministic Universal Filter (`UniversalFilter`):** Pydantic model with `extra = "ignore"` strips unauthorized keys (pricing, PII) at the schema level — Zero-Trust enforcement.
- **Smart Routing:** Standard coordinate/status updates bypass the LLM entirely and update Supabase directly. Only crisis messages invoke AI compute.
- **AI Co-Pilot Advisory:** Crisis messages trigger `generate_crisis_advisory()` which produces actionable advisories for the operations team, persisted to `telemetry_events`.
- **Crisis NLP Classification:** `extract_status_from_crisis()` classifies operational status (`operational`/`pending`/`delayed`/`offline`) with keyword fallback.

#### Smart Router & LLM Quota Preservation
- Two distinct endpoints (`/unstructured` and `/telemetry`) with crisis-message branching.
- Advanced AI compute is only invoked for complex crisis resolution and initial entity mapping — standard logistics tracking bypasses the LLM entirely.

### 8. The "Heartbeat" Module & AI-Assisted Remote Control (SRS §2.7) ✅ COMPLETE
- **Conversational Magic Link (The "Remote Control"):** 
  - Tokenized Magic Link system allowing suppliers to report statuses via a frictionless Progressive Web App (PWA) chat interface (`supplier_chat.html`).
  - Pre-Database Local Parsing using Gemini 1.5 Flash to extract `status` (operational/pending/delayed/offline), `latency_hours`, and `reason` from natural language updates.
  - OEM dispatch functionality directly from the canvas to ping suppliers.
- **Database-Driven Orchestration:** 
  - Single JSON payload fan-out. A message writes to the `messages` table, updates `supply_chain_nodes` status/timestamps, and triggers a real-time webhook broadcast to update the canvas instantly without heavy polling.
- **The "Dark Node" Predictive Engine:** 
  - An APScheduler-driven risk engine (`dark_node_engine.py`) that calculates a composite score based on: Relational Impact, Historical Reliability, Macro-Environmental Fusion, and Silence Duration.
  - Automated Ping: If a node crosses the 80% risk threshold, it automatically triggers a targeted status request directly to the supplier's Magic Link.

### 9. AI Service (`backend/app/services/ai_service.py`)
- **Model:** Gemini 1.5 Flash (free tier) — one-line swap to upgrade to 2.5 Pro later.
- **SDK:** Modern `google-genai` SDK (`google.genai.Client`) with Structured Outputs.
- **Graceful Degradation:** Returns stub data when `GEMINI_API_KEY` is not set.
- **Capabilities:** File parsing (multimodal), crisis NLP classification, Co-Pilot advisory generation, MCP natural-language prompts.

### 10. Supabase Schema (`supabase/migrations/`)
- **20 Tables:** organizations, organization_members, supply_chain_nodes, node_edges, ingestion_jobs, mcp_containers, telemetry_events, disruption_alerts, alert_state, macro_environment_signals, community_templates, template_nodes, node_invitations, rfp_requests, tradeoff_analyses, tradeoff_metrics, messages, communication_logs, magic_link_tokens, audit.audit_log.
- **Indexes:** GiST (geospatial), BRIN (time-series), GIN (JSONB), partial indexes for active records.
- **RLS Policies:** Organization-scoped isolation on all tenant tables.
- **Audit Schema:** Append-only regulatory logging with 7-year retention.

### 11. Telemetry Events System
- **Model (`backend/app/models/telemetry.py`):** `TelemetryEvent` and `TelemetryEventResponse` Pydantic schemas.
- **Endpoints (`/api/v1/telemetry/events`):** POST to record events, GET to query by node_id with ordering and pagination.

### 12. Docker Compose (`docker-compose.yml`)
- **Full-stack local dev:** FastAPI backend service + optional MCP connector (activated via `--profile mcp`).
- **Environment-driven:** All configuration via `.env` file.

### 13. Test Suite (`backend/test_omni_layer.py`)
- **9 integration tests** covering all three tracks:
  - Cold Start: CSV, PDF binary, email `.eml` file uploads
  - Modern Push: standard telemetry, crisis NLP, zero-trust key stripping
  - Continuous Sync: MCP generation for PostgreSQL, Oracle, SQL Server
- **All 9 tests passing** ✅

### 14. Community Quick Setup & Auto-Apply (SRS §2.2) ✅ COMPLETE
- **Community Screen:** Built a dedicated `CommunityScreen` UI separating marketplace templates from the main canvas.
- **Backend Refactoring:** Updated RFP services and templates to support PII-sanitized public publishing.

### 15. Node Discovery & Onboarding (SRS §2.3) ✅ COMPLETE
- **Add Node Flow:** Integrated the interactive "Add Node" discovery menu in the Left Panel and via a floating action button (`_AddNodeFab`).
- **Hierarchical Discovery (Tier 1-3):** Implemented radius-aware search for Active, Community, and OSM cached nodes.
- **Multi-Channel Dispatch:** Created invite workflows natively supporting Email and WhatsApp routing, generating tracking links directly on the canvas.

---

## 🎨 Design System Tokens
Curoot enforces a highly customized, premium "dark mode" industrial aesthetic:
- **Primary Backgrounds:** Pure black (`#000000`) or deep space grey (`#0F1115`).
- **Surface / Panels:** `#121212` / `#16181D`
- **Tile Elements:** `#1E2128` / `#313533`
- **Primary Highlight:** Elegant Teal `Color(0xFF2DD4BF)` - Used for active tabs, positive metrics, and active checkboxes.
- **Accent Highlight:** Indigo / Purple `Color(0xFF8083FF)`
- **Typography:** `GoogleFonts.manrope()` across all headers, metrics, and body text to enforce a sharp, tech-forward look.

---

## 🟡 Pending / Future Work
- **Multiplayer Cursor Presence:** Track and render other team members' mouse cursors on the canvas in real-time via Supabase Presence channels.
- **MCP Kill-Switch API:** Build the backend endpoint that terminates active ERP sync containers on demand from the Settings dashboard.
- **Authentication Polishing:** Ensure the Supabase Session handoff efficiently routes unauthenticated users back to the Login Page.
- **Supabase Migration Deployment:** Run `supabase db push` to apply the initial schema and `ui_x`/`ui_y` migration to the production instance.
- **AI Model Upgrade Path:** Upgrade from Gemini 1.5 Flash (free tier) to Gemini 2.5 Pro by changing `MODEL_NAME` in `ai_service.py` when ready.
