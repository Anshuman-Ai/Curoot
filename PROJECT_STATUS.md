# Curoot - Project Status & Architecture Guide

## Project Overview
Curoot is a high-end, intelligent supply chain platform featuring a dynamic, node-based multiplayer canvas. It leverages predictive AI, macro-environmental risk assessment, and Model Context Protocol (MCP) data sovereignty integrations to provide a premium enterprise solution.

## Technology Stack
- **Frontend Framework:** Flutter / Dart
- **State Management:** Riverpod 3.x (NotifierProvider architecture)
- **Backend API:** FastAPI (Python) — Uvicorn, APScheduler
- **AI Engine:** Google Gemini 1.5 Flash via `google-genai` SDK (Structured Outputs)
- **Database & Auth:** Supabase (PostgreSQL, Row Level Security, Realtime WebSockets)
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

### 7. Omni Ingestion Backend (Cold Start & Continuous Sync)
- **Cold Start AI Parsing (`/api/v1/ingestion/unstructured`):** Accepts raw files (PDFs, CSVs) and routes them to Gemini 1.5 Flash for structured extraction using Pydantic `AIExtractionResult` schema with `response_schema` enforcement.
- **Modern Push Telemetry (`/api/v1/ingestion/telemetry`):** Accepts JSON heartbeats, strips unauthorized fields via `UniversalFilter`, and routes crisis messages to Gemini NLP for intelligent status classification (`operational`/`pending`/`delayed`/`offline`).
- **MCP Container Generator (`/api/v1/mcp_mgr/generate`):** Dynamically generates `docker-compose.yml` and `mcp_runner.py` Shock Absorber scripts for on-premise legacy DB sync using SQLite buffering.

### 8. AI Service Upgrade (`backend/app/services/ai_service.py`)
- **SDK Migration:** Replaced deprecated `google.generativeai` with the modern `google-genai` SDK (`google.genai.Client`).
- **Graceful Degradation:** If `GEMINI_API_KEY` is not set, the service safely returns stub data without crashing the server, enabling offline development.
- **Structured Outputs:** Uses Gemini's native Pydantic schema binding for type-safe AI responses.

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

## 📂 Project Structure
```text
Curoot
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/ (disruption_models.dart, tradeoff_models.dart, etc.)
│   │   ├── services/ (api_client.dart, supabase_service.dart, location_service.dart)
│   │   ├── state/ (canvas_provider.dart, settings_provider.dart)
│   │   └── ui/
│   │       ├── auth/ (login_page.dart, signup_page.dart)
│   │       ├── canvas/ (multiplayer_canvas.dart, node_widget.dart)
│   │       ├── community/ (community_screen.dart)
│   │       ├── modals/ (add_node_modal.dart)
│   │       ├── panels/ (left_panel.dart, right_panel.dart, omni_ingestion_panel.dart)
│   │       └── settings/ (settings_page.dart)
│   └── pubspec.yaml
├── mcp-template/
│   ├── src/ (erp_connector.py, main.py, sqlite_buffer.py, sync_worker.py)
│   └── Dockerfile
└── supabase/
    ├── migrations/
    ├── config.toml
    └── seed.sql
```

---

## 🟡 Pending / Future Work
- **Multiplayer Cursor Presence:** Track and render other team members' mouse cursors on the canvas in real-time via Supabase Presence channels.
- **MCP Kill-Switch API:** Build the backend endpoint that terminates active ERP sync containers on demand from the Settings dashboard.
- **Add Node Flow:** Complete the interactive node creation menu inside the Left Panel (Tri-Layer Discovery: Active → Community → Maps).
- **Authentication Polishing:** Ensure the Supabase Session handoff efficiently routes unauthenticated users back to the Login Page.
- **Supabase Migration Deployment:** Run `supabase db push` to apply the `ui_x`/`ui_y` migration to the production instance.
- **Gemini API Key Configuration:** Set `GEMINI_API_KEY` in the backend `.env` to activate live AI extraction (currently falling back to stubs).
