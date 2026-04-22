# Project Structure: Figma for Supply Chain

This document defines the monorepo file architecture for the platform. The system is divided into four main directories: `frontend` (Flutter), `backend` (FastAPI), `supabase` (DB/Auth/Realtime), and `mcp-template` (Localized Zero-Trust Edge Agent).

## Repository Root
```text
/
├── .env
├── .gitignore
├── DB_Relation.md
├── docker-compose.yml        # For local dev (orchestrates FastAPI & Frontend)
├── module_2_5and2_6.md
├── MVP & SRS.md
├── Project_Structure.md
├── README.md
├── backend/                  # Layer 2 & 4: Python/FastAPI API & AI/Routing Engine
│   ├── app/
│   │   ├── main.py                   # FastAPI application entry point
│   │   ├── api/                      # Routing logic
│   │   │   └── v1/
│   │   │       └── endpoints/
│   │   │           ├── __init__.py
│   │   │           ├── discovery.py      # Tri-Layer pull (Active -> Community -> Maps)
│   │   │           ├── disruption.py
│   │   │           ├── ingestion.py      # Cold Start AI + Smart Router telemetry -> Gemini
│   │   │           ├── invitations.py    # Direct invite endpoint
│   │   │           ├── macro_env.py
│   │   │           ├── marketplace.py    # Community marketplace CRUD
│   │   │           ├── mcp_mgr.py        # Generates docker-compose + Shock Absorber scripts
│   │   │           ├── telemetry.py      # Smart Router -> Direct to Supabase DB
│   │   │           └── tradeoffs.py
│   │   ├── core/
│   │   │   ├── config.py             # Environment variables (Supabase URL/Keys, Vertex AI)
│   │   │   └── security.py           # JWT validation, Universal Filter initialization
│   │   ├── db/
│   │   │   └── supabase.py           # Supabase service-role client (for backend bypasses)
│   │   ├── models/                   # Pydantic schemas validating API payloads
│   │   │   ├── ai_parser.py          # Multimodal ingestion schemas (AIExtractionResult, UniversalFilter)
│   │   │   ├── discovery.py          # Discovery search request/response schemas
│   │   │   ├── disruption.py
│   │   │   ├── enums.py              # Mirrors SQL enums (node_status_enum, etc.)
│   │   │   ├── invitations.py        # DirectInviteRequest/Response with EmailStr
│   │   │   ├── macro_env.py
│   │   │   ├── marketplace.py        # Community marketplace schemas
│   │   │   ├── telemetry.py          # Strict telemetry ingestion payloads
│   │   │   └── tradeoffs.py
│   │   ├── services/
│   │   │   ├── ai_service.py         # Google Gemini 1.5 Flash via google-genai SDK (Structured Outputs)
│   │   │   ├── disruption_service.py
│   │   │   ├── geo_intersect.py
│   │   │   ├── macro_env_service.py
│   │   │   ├── risk_classifier.py
│   │   │   ├── tradeoffs_engine.py   # Calculates Financial/Time/Carbon/Reliability math
│   │   │   └── webhooks.py           # Pydantic universal filter stripping pricing keys
│   │   └── utils/
│   │       └── rate_limiter.py
│   ├── tests/
│   │   ├── test_disruption.py
│   │   ├── test_tradeoffs.py
│   │   └── __init__.py
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── simulate_erp_mcp.py
│   ├── test_omni_layer.py
│   └── validate_mcp_environment.py
├── frontend/                 # Layer 1: Flutter Web/Desktop Application
│   ├── analysis_options.yaml
│   ├── devtools_options.yaml
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/               # Dart data classes mirroring Supabase tables
│   │   │   ├── disruption_models.dart
│   │   │   ├── node_edge.dart
│   │   │   ├── organization.dart
│   │   │   ├── supply_chain_node.dart
│   │   │   ├── telemetry_event.dart
│   │   │   └── tradeoff_models.dart
│   │   ├── services/
│   │   │   ├── api_client.dart           # Connects to FastAPI for AI / complex routing
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
│   │       │   ├── edge_painter.dart       # Draws routes between 1-Hop connections
│   │       │   ├── multiplayer_canvas.dart # The core visual node workspace
│   │       │   └── node_widget.dart        # Individual node rendering (Flash red logic)
│   │       ├── community/
│   │       │   └── community_screen.dart   # Marketplace for quick setups
│   │       ├── modals/
│   │       │   └── add_node_modal.dart     # The [+] unified search/invite modal
│   │       ├── panels/
│   │       │   ├── left_panel.dart         # Side bar icon tray and left panel sidebar
│   │       │   ├── mcp_generation_wizard.dart
│   │       │   ├── omni_ingestion_panel.dart
│   │       │   └── right_panel.dart        # Realtime AI Tradeoffs and Risk comparison UI
│   │       └── settings/
│   │           └── settings_page.dart      # Comprehensive dashboard UI
│   └── web/
│       ├── index.html
│       └── manifest.json
├── mcp-template/             # Zero-Trust Data Connector (Localized Docker Adapter)
│   ├── src/
│   │   ├── erp_connector.py          # Read-only pull logic for legacy databases
│   │   ├── main.py                   # Model Context Protocol (MCP) server script
│   │   ├── sqlite_buffer.py          # Local SQLite DB to prevent legacy system crashes
│   │   └── sync_worker.py            # Pushes append-only HTTPS webhooks to Backend Layer 2
│   ├── buffer.db                     # Local SQLite file (generated at runtime)
│   ├── Dockerfile                    # The localized container image
│   └── requirements.txt
└── supabase/                 # Layer 3: DB Schema, Migrations, and RLS
    ├── config.toml                   # Local Supabase configuration
    ├── seed.sql                      # Mock data for organizations, active/faded nodes
    └── migrations/
        ├── 20260407113300_initial_schema.sql
        └── 20260423012300_add_canvas_ui_coordinates.sql  # Adds ui_x/ui_y for canvas positions

**How to instruct your AI Agent next:**
1. Save the SQL you provided in the prompt as `supabase/migrations/20260407113300_initial_schema.sql`.
2. Instruct the agent to run `supabase init` and `supabase db push` to align your cloud environment with the structural foundation. 
3. Ask the agent to generate the `Pydantic` models in `backend/app/models/` specifically mapping to the Enums (like `node_type_enum` and `org_tier_enum`) from the SQL file.