# Curoot - Project Status & Architecture Guide

## Project Overview
Curoot is a high-end, intelligent supply chain platform featuring a dynamic, node-based multiplayer canvas. It leverages predictive AI, macro-environmental risk assessment, and Model Context Protocol (MCP) data sovereignty integrations to provide a premium enterprise solution.

## Technology Stack
- **Frontend Framework:** Flutter / Dart
- **State Management:** Riverpod 3.x (NotifierProvider architecture)
- **Backend Service:** Supabase (PostgreSQL, Row Level Security, Auth)
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
- **Canvas Multiplayer Sockets:** Wire Supabase Realtime subscriptions to track mouse cursors and node dragging across multi-tenant teams.
- **Backend MCP Pipelines:** Build the Python backend endpoints for the MCP Kill-Switch API that terminates ERP pipelines.
- **Omni-Ingestion Panel Development:** Flesh out the file/data upload UI inside the Left Panel.
- **Add Node Flow:** Complete the interactive node creation menu inside the Left Panel.
- **Authentication Polishing:** Ensure the Supabase Session handoff efficiently routes unauthenticated users back to the Login Page.
