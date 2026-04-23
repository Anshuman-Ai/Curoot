# Project Structure: Figma for Supply Chain

This document defines the monorepo file architecture for the platform. The system is divided into four main directories: `frontend` (Flutter), `backend` (FastAPI), `supabase` (DB/Auth/Realtime), and `mcp-template` (Localized Zero-Trust Edge Agent).

## Repository Root
```text
/
├── .env                          # Environment variables (Supabase, Gemini, API keys)
├── .gitignore
├── DB_Relation.md                # Database relationship documentation
├── docker-compose.yml            # Full-stack local dev (FastAPI + optional MCP connector)
├── module_2_5and2_6.md           # SRS modules 2.5 & 2.6 specification
├── MVP & SRS.md                  # Master SRS document
├── PROJECT_STATUS.md             # Current implementation status & architecture guide
├── Project_Structure.md          # This file
├── README.md
│
├── backend/                      # Layer 2 & 4: Python/FastAPI API & AI/Routing Engine
│   ├── app/
│   │   ├── main.py                       # FastAPI entry point, router registration, APScheduler
│   │   ├── api/
│   │   │   └── v1/
│   │   │       └── endpoints/
│   │   │           ├── __init__.py
│   │   │           ├── discovery.py      # Tri-Layer pull (Active → Community → Maps)
│   │   │           ├── disruption.py     # Module 2.5A — Disruption alert endpoints
│   │   │           ├── ingestion.py      # SRS §2.1 — Cold Start AI parsing + Smart Router telemetry
│   │   │           │                     #   POST /unstructured — PDF/CSV/email → Gemini → Supabase
│   │   │           │                     #   POST /telemetry — UniversalFilter → DB or AI Co-Pilot
│   │   │           ├── invitations.py    # Direct invite endpoint
│   │   │           ├── macro_env.py      # Module 2.5B — Macro-environment signals
│   │   │           ├── marketplace.py    # Community marketplace CRUD
│   │   │           ├── mcp_mgr.py        # SRS §2.1 — MCP container generator
│   │   │           │                     #   POST /generate — Dynamic per DB type (Postgres/MySQL/Oracle/SQL Server)
│   │   │           │                     #   Generates docker-compose.yml, Dockerfile, mcp_runner.py
│   │   │           │                     #   AI natural-language prompt via Gemini
│   │   │           ├── telemetry.py      # Telemetry events — POST/GET /telemetry/events
│   │   │           └── tradeoffs.py      # Module 2.6 — Actionable tradeoff analysis
│   │   ├── core/
│   │   │   ├── config.py                 # Environment variables (Supabase, NewsAPI, Reddit, etc.)
│   │   │   └── security.py              # Org ID header extraction (JWT in production)
│   │   ├── db/
│   │   │   └── supabase.py              # Supabase service-role client factory
│   │   ├── models/                       # Pydantic schemas validating API payloads
│   │   │   ├── ai_parser.py             # AIExtractionResult, SupplyChainNode, SupplyChainEdge,
│   │   │   │                            # UniversalFilter (Zero-Trust), MCPSpecRequest
│   │   │   ├── discovery.py             # Discovery search request/response schemas
│   │   │   ├── disruption.py            # Disruption alert models & broadcast payloads
│   │   │   ├── enums.py                 # SQL enum mirrors (node_status_enum, etc.)
│   │   │   ├── invitations.py           # DirectInviteRequest/Response
│   │   │   ├── macro_env.py             # Macro-environment signal models
│   │   │   ├── marketplace.py           # Community marketplace schemas
│   │   │   ├── telemetry.py             # TelemetryEvent, TelemetryEventResponse
│   │   │   └── tradeoffs.py             # Tradeoff request/response models
│   │   ├── services/
│   │   │   ├── ai_service.py            # Gemini 1.5 Flash (free tier) — 4 capabilities:
│   │   │   │                            #   1. process_unstructured_file() — multimodal PDF/CSV/email parsing
│   │   │   │                            #   2. extract_status_from_crisis() — NLP crisis classification
│   │   │   │                            #   3. generate_crisis_advisory() — Co-Pilot advisory text
│   │   │   │                            #   4. generate_mcp_prompt() — MCP natural-language prompt
│   │   │   ├── disruption_service.py    # Disruption scan orchestration
│   │   │   ├── geo_intersect.py         # Geospatial intersection logic
│   │   │   ├── macro_env_service.py     # Macro-environment signal aggregation
│   │   │   ├── rfp_service.py           # RFP request handling
│   │   │   ├── risk_classifier.py       # Risk level classification
│   │   │   ├── tradeoffs_engine.py      # Financial/Time/Carbon/Reliability math engine
│   │   │   └── webhooks.py              # Supabase Realtime alert broadcasting
│   │   └── utils/
│   │       └── rate_limiter.py          # Token-bucket rate limiter for external APIs
│   ├── tests/
│   │   ├── test_disruption.py
│   │   ├── test_tradeoffs.py
│   │   └── __init__.py
│   ├── Dockerfile                        # Backend container image
│   ├── requirements.txt
│   ├── simulate_erp_mcp.py              # MCP Shock Absorber E2E integration test
│   ├── test_omni_layer.py               # 9 integration tests for SRS §2.1 (all 3 tracks)
│   └── validate_mcp_environment.py      # MCP environment validation script
│
├── frontend/                     # Layer 1: Flutter Web/Desktop Application
│   ├── analysis_options.yaml
│   ├── devtools_options.yaml
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/                       # Dart data classes mirroring Supabase tables
│   │   │   ├── disruption_models.dart
│   │   │   ├── node_edge.dart
│   │   │   ├── organization.dart
│   │   │   ├── supply_chain_node.dart
│   │   │   ├── telemetry_event.dart
│   │   │   └── tradeoff_models.dart
│   │   ├── services/
│   │   │   ├── api_client.dart           # FastAPI client — ingestion, MCP, tradeoffs, discovery, etc.
│   │   │   ├── location_service.dart     # Priority 3 Google Maps fallback handler
│   │   │   └── supabase_service.dart     # WebSockets for real-time edge/node updates
│   │   ├── state/
│   │   │   ├── canvas_provider.dart      # Manages the local 1-Hop Ego-centric view
│   │   │   ├── disruption_provider.dart
│   │   │   ├── settings_provider.dart    # Manages Org config, tenant state, UI settings
│   │   │   └── tradeoffs_provider.dart
│   │   └── ui/
│   │       ├── auth/
│   │       │   ├── login_page.dart
│   │       │   └── signup_page.dart
│   │       ├── canvas/
│   │       │   ├── add_node_panel.dart
│   │       │   ├── edge_painter.dart     # Draws routes between 1-Hop connections
│   │       │   ├── multiplayer_canvas.dart # The core visual node workspace
│   │       │   └── node_widget.dart      # Individual node rendering (Flash red logic)
│   │       ├── community/
│   │       │   └── community_screen.dart # Marketplace for quick setups
│   │       ├── modals/
│   │       │   └── add_node_modal.dart   # The [+] unified search/invite modal
│   │       ├── panels/
│   │       │   ├── left_panel.dart       # Side bar icon tray and left panel sidebar
│   │       │   ├── mcp_generation_wizard.dart  # 4-step MCP Docker container wizard
│   │       │   ├── omni_ingestion_panel.dart   # File upload + webhook config + pipeline status
│   │       │   └── right_panel.dart      # Realtime AI Tradeoffs and Risk comparison UI
│   │       └── settings/
│   │           └── settings_page.dart    # Comprehensive dashboard UI
│   └── web/
│       ├── index.html
│       └── manifest.json
│
├── mcp-template/                 # Zero-Trust Data Connector (Localized Docker Adapter)
│   ├── src/
│   │   ├── main.py                       # Entry point — init → poll loop (pull → flush → sleep)
│   │   ├── erp_connector.py             # Factory-pattern DB connector (Postgres/MySQL/Oracle/SQL Server)
│   │   │                                #   Watermark-based incremental reads
│   │   │                                #   Outputs UniversalFilter-compatible payloads
│   │   ├── sqlite_buffer.py             # SQLite Shock Absorber — enqueue, batch, dequeue, mark synced/failed
│   │   └── sync_worker.py               # Append-only HTTPS push to Curoot cloud with per-payload ACK
│   ├── buffer.db                         # Local SQLite file (generated at runtime)
│   ├── Dockerfile                        # Python 3.11-slim with DB driver system deps
│   └── requirements.txt                  # requests, psycopg2-binary, pymysql, pyodbc
│
└── supabase/                     # Layer 3: DB Schema, Migrations, and RLS
    ├── config.toml                       # Local Supabase configuration
    ├── seed.sql                          # Mock data for organizations, active/faded nodes
    └── migrations/
        ├── 20260407113300_initial_schema.sql       # Full schema — 19 tables, indexes, RLS, audit
        └── 20260423012300_add_canvas_ui_coordinates.sql  # Adds ui_x/ui_y for canvas positions
```