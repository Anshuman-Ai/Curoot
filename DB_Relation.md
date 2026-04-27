Figma for Supply Chain Platform — Database Relationships
Version: 1.0.0
Status: Production Ready

1. Overview

This document defines all relational mappings, cardinality, and data flow dependencies across the PostgreSQL schema.

The system follows a multi-tenant, graph-based architecture with strict 1-Hop data isolation, enforced through:

Foreign key constraints
Row-Level Security (RLS)
No cross-org joins for deeper tiers
2. Core Design Principles
2.1 Multi-Tenancy
Root table: organizations
Every table includes organization_id
Enforced via RLS
2.2 Graph Model
Nodes → supply_chain_nodes
Edges → node_edges
Directed relationships only
2.3 1-Hop Isolation
No direct FK to Tier-2+ suppliers
Upstream data passed via:
abstracted_payload (JSONB)
2.4 Soft Delete Pattern
deleted_at IS NULL → active records
3. High-Level Domain Relationships
organizations
│
├── organization_members
├── supply_chain_nodes
│   ├── node_edges
│   ├── telemetry_events
│   ├── disruption_alerts
│   ├── node_invitations
│   ├── rfp_requests
│   └── magic_link_tokens
│
├── community_templates
│   └── template_nodes
│
├── ingestion_jobs
│   └── mcp_containers
│
├── tradeoff_analyses
│   └── tradeoff_metrics
│
├── messages
├── communication_logs
└── audit.audit_log
4. Entity Relationships (Detailed)
4.1 organizations (Root Entity)

Primary Key: id

Relationships:
1 → N organization_members
1 → N supply_chain_nodes
1 → N node_edges
1 → N ingestion_jobs
1 → N rfp_requests
1 → N tradeoff_analyses
1 → N messages
1 → N communication_logs
4.2 organization_members

FKs:

organization_id → organizations.id

Cardinality:

Many members belong to one organization
A user can belong to multiple organizations
4.3 supply_chain_nodes (Core Graph Node)

FKs:

organization_id → organizations.id
partner_org_id → organizations.id (nullable)

Fields of Interest:
- `ui_x`, `ui_y` (decoupled visual coordinates)
- `country_code` (for macro environment mapping)
- `is_dark_node` (Boolean flag for silent/high-risk nodes)
- `heartbeat_confidence` (0.0 to 1.0)
- `last_heartbeat_at` (Last successful response)
- `status` (operational, pending, delayed, offline)
- `volume_weight`, `transport_mode`, `cascade_delay_hours`
- `abstracted_payload` (JSONB for 1-hop privacy)

Relationships:

1 → N node_edges (as source)
1 → N node_edges (as target)
1 → N telemetry_events
1 → N disruption_alerts
1 → N node_invitations
1 → N rfp_requests
4.4 node_edges (Graph Edges)

FKs:

organization_id → organizations.id
source_node_id → supply_chain_nodes.id
target_node_id → supply_chain_nodes.id

Fields of Interest:
- `edge_type` (default: 'supplies_to')

Cardinality:

Many edges per node
Directed relationship

Constraints:

No self-loop (source != target)
Unique edge per (source, target, type)
4.5 community_templates

FKs:

published_by_org → organizations.id

Relationships:

1 → N template_nodes
1 → N rfp_requests
4.6 template_nodes

FKs:

template_id → community_templates.id

Purpose:

Defines node structure inside templates
4.7 node_invitations

FKs:

organization_id → organizations.id
target_node_id → supply_chain_nodes.id
accepted_org_id → organizations.id

Lifecycle Flow:

Invite Created → Accepted → Organization Created → Node Activated
4.8 rfp_requests

FKs:

organization_id → organizations.id
target_node_id → supply_chain_nodes.id
template_id → community_templates.id

Constraints:

Max 2 submissions/day per node
Cooldown enforced
4.9 ingestion_jobs

FKs:

organization_id → organizations.id

Fields of Interest:
- `source_type` (cold_start, mcp_sync, push_api)
- `source_ref` (External file name or API ID)

Relationships:

1 → 1 mcp_containers
4.10 mcp_containers

FKs:

organization_id → organizations.id (UNIQUE)
ingestion_job_id → ingestion_jobs.id

Cardinality:

One container per organization
4.11 telemetry_events (Time-Series)

FKs:

node_id → supply_chain_nodes.id
organization_id → organizations.id

Characteristics:

Partitioned by recorded_at
High-volume append-only
4.12 disruption_alerts

FKs:

node_id → supply_chain_nodes.id (nullable)
edge_id → node_edges.id (nullable)
organization_id → organizations.id

Features:
- Submits `abstracted_payload` for Zero-Knowledge Tier-2+ disruptions
- `payload` (JSONB) stores AI-classified alert data

Rule:

Either node_id OR edge_id must exist
4.13 macro_environment_signals

No direct FK relationships

Linked logically via:

country_code

Fields of Interest:
- `risk_level` (low, medium, high, critical)
- `confidence`, `primary_driver`, `signals_summary`
- `payload`, `raw_data`
4.14 tradeoff_analyses

FKs:

organization_id → organizations.id
current_node_id → supply_chain_nodes.id
alternative_node_id → supply_chain_nodes.id
disruption_alert_id → disruption_alerts.id
initiated_by → organizations.id

Key Fields:
- `overall_recommendation` (switch/stay)
- `recommendation_confidence`

Relationships:

1 → N tradeoff_metrics
4.15 tradeoff_metrics

FKs:

analysis_id → tradeoff_analyses.id

Fields of Interest:
- `metric_type` (renamed from `metric`)
- `current_value`, `alternative_value`, `delta`

Constraint:

One row per metric_type per analysis
4.16 messages

FKs:

sender_org_id → organizations.id
recipient_org_id → organizations.id
node_id → supply_chain_nodes.id (optional)

Fields of Interest:
- `body`, `subject`
- `parsed_data`, `parse_confidence` (NLP output)
4.17 communication_logs

FKs:

organization_id → organizations.id
target_node_id → supply_chain_nodes.id
message_id → messages.id

Nature:

Immutable (append-only)
4.18 magic_link_tokens

FKs:

node_id → supply_chain_nodes.id
organization_id → organizations.id

Constraints:

Unique token
is_revoked boolean flag
4.19 downstream_alerts (Zero-Knowledge Abstraction)

FKs:

source_alert_id → disruption_alerts.id
source_org_id → organizations.id
target_org_id → organizations.id

Purpose:
- Handles private data sharing across the supply chain graph.
- Propagates delay data (`cascade_delay_hours`) without exposing internal supplier details.
4.20 audit.audit_log

FKs (logical, not enforced):

record_id → any table
changed_by_org → organizations.id

Characteristics:

Partitioned
Append-only
Regulatory retention (7 years)
5. Critical Relationship Patterns
5.1 Graph Traversal
supply_chain_nodes
    ↓
node_edges (source → target)
    ↓
supply_chain_nodes

Used for:

Route discovery
Dependency mapping
Risk propagation
5.2 Event Flow
telemetry_events
    ↓
disruption_alerts
    ↓
tradeoff_analyses
    ↓
tradeoff_metrics
5.3 Onboarding Flow
community_templates
    ↓
template_nodes
    ↓
rfp_requests
    ↓
node_invitations
    ↓
supply_chain_nodes
5.4 Data Ingestion Flow
ingestion_jobs
    ↓
mcp_containers
    ↓
telemetry_events
    ↓
supply_chain_nodes (updates)
6. Referential Integrity Rules
Rule	Description
Tenant Isolation	All rows scoped by organization_id
No Cross-Org Edges	Enforced in node_edges
Soft Delete	Never physically delete core data
Append-Only Logs	audit_log, communication_logs
Partitioned Tables	telemetry_events, audit_log
7. Performance Considerations
High-volume tables:
telemetry_events → partitioned
audit_log → partitioned
Indexes:
GIN → JSONB fields
GiST → geospatial (location)
BRIN → time-series
Query Patterns:
Always filter by organization_id
Use partial indexes for active records
8. Summary

This schema implements:

✅ Multi-tenant SaaS architecture
✅ Graph-based supply chain modeling
✅ Strong data isolation (1-Hop rule)
✅ Real-time + batch ingestion support
✅ Industrial-grade audit + compliance