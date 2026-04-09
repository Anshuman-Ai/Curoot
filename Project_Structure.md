# Project Structure: Figma for Supply Chain

This document defines the monorepo file architecture for the platform. The system is divided into four main directories: `frontend` (Flutter), `backend` (FastAPI), `supabase` (DB/Auth/Realtime), and `mcp-template` (Localized Zero-Trust Edge Agent).

## Repository Root
```text
/
├── frontend/                 # Layer 1: Flutter Web/Desktop Application
├── backend/                  # Layer 2 & 4: Python/FastAPI API & AI/Routing Engine
├── supabase/                 # Layer 3: DB Schema, Migrations, and RLS
├── mcp-template/             # Zero-Trust Data Connector (Localized Docker Adapter)
├── .gitignore
├── docker-compose.yml        # For local dev (orchestrates FastAPI & Frontend)
└── README.md
/frontend
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── theme/            # Styling, Node Opacity logic (1.0, 0.5, 0.25)
│   │   ├── constants/        # Enums matching DB (org_tier, node_type, etc.)
│   │   └── utils/            # Geographic calculations, UUID generators
│   ├── models/               # Dart data classes mirroring Supabase tables
│   │   ├── organization.dart
│   │   ├── supply_chain_node.dart
│   │   ├── node_edge.dart
│   │   └── telemetry_event.dart
│   ├── services/
│   │   ├── supabase_service.dart     # WebSockets for real-time edge/node updates
│   │   ├── api_client.dart           # Connects to FastAPI for AI / complex routing
│   │   └── location_service.dart     # Priority 3 Google Maps fallback handler
│   ├── state/
│   │   └── canvas_provider.dart      # Manages the local 1-Hop Ego-centric view
│   ├── ui/
│   │   ├── canvas/
│   │   │   ├── multiplayer_canvas.dart # The core visual node workspace
│   │   │   ├── node_widget.dart        # Individual node rendering (Flash red logic)
│   │   │   └── edge_painter.dart       # Draws routes between 1-Hop connections
│   │   ├── modals/
│   │   │   └── add_node_modal.dart     # The [+] unified search/invite modal
│   │   ├── panels/
│   │   │   ├── left_panel.dart  # side bar icon tray cum left panel sidebar
│   │   │   └── right_panel.dart      # Realtime AI Tradeoffs and Risk comparison UI
│   │   └── auth/
│   └── pubspec.yaml
/backend
├── app/
│   ├── main.py                   # FastAPI application entry point
│   ├── core/
│   │   ├── config.py             # Environment variables (Supabase URL/Keys, Vertex AI)
│   │   └── security.py           # JWT validation, Universal Filter initialization
│   ├── db/
│   │   └── supabase.py           # Supabase service-role client (for backend bypasses)
│   ├── models/                   # Pydantic schemas validating API payloads
│   │   ├── enums.py              # Mirrors SQL enums (node_status_enum, etc.)
│   │   ├── telemetry.py          # Strict telemetry ingestion payloads
│   │   ├── ai_parser.py          # Multimodal ingestion schemas
│   │   └── tradeoffs.py
│   ├── api/                      # Routing logic
│   │   ├── v1/
│   │   │   ├── endpoints/
│   │   │   │   ├── ingestion.py  # Omni-Format AI / Unstructured Dumps -> Gemini
│   │   │   │   ├── telemetry.py  # Smart Router -> Direct to Supabase DB
│   │   │   │   ├── discovery.py  # Tri-Layer pull (Active -> Community -> Maps)
│   │   │   │   └── mcp_mgr.py    # Provisions / manages localized MCP containers
│   ├── services/
│   │   ├── ai_service.py         # Google Vertex AI / Gemini 2.5 logic (OCR/NLP)
│   │   ├── tradeoffs_engine.py   # Calculates Financial/Time/Carbon/Reliability math
│   │   └── webhooks.py           # Pydantic universal filter stripping pricing keys
│   └── utils/
├── requirements.txt
└── Dockerfile
/supabase
├── config.toml                   # Local Supabase configuration
├── migrations/
│   └── 20260407113300_initial_schema.sql  # *** YOUR PROVIDED SQL GOES HERE ***
│                                          # Contains extensions, schemas, tables, 
│                                          # RLS policies, triggers, and cron schedules.
├── seed.sql                      # Mock data for organizations, active/faded nodes
└── functions/                    # (Optional) Supabase Edge Functions
    └── send_whatsapp_invite/     # Handles Path B targeted provisioning
/mcp-template
├── Dockerfile                    # The localized container image
├── src/
│   ├── main.py                   # Model Context Protocol (MCP) server script
│   ├── erp_connector.py          # Read-only pull logic for legacy databases
│   ├── sqlite_buffer.py          # Local SQLite DB to prevent legacy system crashes
│   └── sync_worker.py            # Pushes append-only HTTPS webhooks to Backend Layer 2
├── requirements.txt
└── buffer.db                     # Local SQLite file (generated at runtime)

**How to instruct your AI Agent next:**
1. Save the SQL you provided in the prompt as `supabase/migrations/20260407113300_initial_schema.sql`.
2. Instruct the agent to run `supabase init` and `supabase db push` to align your cloud environment with the structural foundation. 
3. Ask the agent to generate the `Pydantic` models in `backend/app/models/` specifically mapping to the Enums (like `node_type_enum` and `org_tier_enum`) from the SQL file.