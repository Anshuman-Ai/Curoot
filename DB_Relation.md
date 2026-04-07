# 🗄️ Database Schema & Relational Source of Truth
**Project Context:** Figma for Supply Chain / Resilient Logistics (Credible Create)
**Database:** PostgreSQL 16 (Hosted on Supabase Cloud)
**Important IDE Directive:** DO NOT generate SQL `CREATE TABLE` statements. The database is already built. Use this document strictly for writing `supabase-js` client queries, TypeScript types, and understanding relations.

---

## 🛑 STRICT AI IDE RULES
1. **Never Hallucinate Tables:** Only query the tables listed in this document. 
2. **Respect Enums:** Only use the exact string values defined in the Enums section.
3. **RLS is Active:** Do not write application logic to filter by `organization_id` if RLS already handles it.
4. **Soft Deletes:** Tables with `deleted_at` should be queried with `.is('deleted_at', null)`.
5. **UUIDs:** Primary keys are UUIDs (`gen_random_uuid()`).

---

## 1️⃣ Enums (Allowed Values)
* `org_tier_enum`: 'enterprise', 'growth', 'startup'
* `node_status_enum`: 'active', 'pending', 'faded', 'delayed', 'suspended', 'inactive'
* `node_type_enum`: 'oem', 'tier1_supplier', 'tier2_supplier', 'logistics_provider', 'distribution_center', 'customs_broker', 'port_authority', 'end_customer'
* `connection_type_enum`: 'upstream', 'downstream', 'logistics', 'peer'
* `ingestion_track_enum`: 'cold_start', 'continuous_sync', 'modern_push'
* `disruption_severity_enum`: 'critical', 'high', 'medium', 'low', 'resolved'
* `rfp_status_enum`: 'draft', 'sent', 'acknowledged', 'confirmed', 'rejected', 'expired'
* `tradeoff_metric_enum`: 'financial_cost', 'time_latency', 'carbon_footprint', 'historical_reliability'

---

## 2️⃣ Core Tables & Relations

### `organizations`
* **id** (UUID, PK)
* **name** (String)
* **slug** (String, Unique)
* **org_tier** (Enum: org_tier_enum)
* **settings** (JSONB)
* **RLS:** Users can only view their own org OR orgs they share an active edge with (1-Hop).

### `organization_members`
* **id** (UUID, PK)
* **organization_id** (UUID, FK -> organizations)
* **user_id** (UUID, FK -> Supabase auth.users)
* **role** (String)
* **Relations:** One `organization` has many `organization_members`.

### `supply_chain_nodes` (The Canvas Entities)
* **id** (UUID, PK)
* **organization_id** (UUID, FK -> organizations)
* **display_name** (String)
* **node_type** (Enum: node_type_enum)
* **node_status** (Enum: node_status_enum)
* **opacity** (Numeric: 0.250 to 1.000) - *Managed by DB Trigger*
* **location** (PostGIS Geography Point)
* **partner_org_id** (UUID, Nullable FK -> organizations)
* **metadata** (JSONB)
* **cached_alternatives** (JSONB)
* **RLS:** Only visible to the owning `organization_id`.

### `node_edges` (The Connections)
* **id** (UUID, PK)
* **organization_id** (UUID, FK -> organizations)
* **source_node_id** (UUID, FK -> supply_chain_nodes)
* **target_node_id** (UUID, FK -> supply_chain_nodes)
* **connection_type** (Enum: connection_type_enum)
* **lead_time_hours** (Numeric)
* **RLS:** Only visible to the owning `organization_id`. 
* **Rule:** DB Trigger prevents edges between unowned nodes.

### `community_templates`
* **id** (UUID, PK)
* **published_by_org** (UUID, FK -> organizations)
* **title** (String)
* **category_tags** (String[])
* **region_tags** (String[])
* **schema_version** (String)

### `rfp_requests`
* **id** (UUID, PK)
* **organization_id** (UUID, FK -> organizations)
* **target_node_id** (UUID, FK -> supply_chain_nodes)
* **status** (Enum: rfp_status_enum)
* **rfp_payload** (JSONB)

### `mcp_containers`
* **id** (UUID, PK)
* **organization_id** (UUID, FK -> organizations)
* **ingestion_track** (Enum: ingestion_track_enum)
* **erp_system_name** (String)
* **status** (String)

---

## 3️⃣ Time-Series & Analytics (Partitioned)
*IDE Note: Do not write queries that attempt to update/delete massive amounts of rows here. These are append-heavy.*

### `telemetry_events` (Partitioned by Month)
* **id** (UUID, PK)
* **recorded_at** (TIMESTAMPTZ, PK)
* **node_id** (UUID, FK -> supply_chain_nodes)
* **organization_id** (UUID, FK -> organizations)
* **event_type** (String)
* **status** (Enum: node_status_enum)
* **payload** (JSONB)

### `analytics.mv_node_reliability_30d` (Materialized View)
* **node_id** (UUID)
* **total_events** (Int)
* **disruption_events** (Int)
* **reliability_score** (Numeric)
* **Note:** Read-only view refreshed hourly via `pg_cron`. Do not write `INSERT/UPDATE` queries to this.

---

## 4️⃣ Disruptions & Tradeoffs

### `disruption_alerts`
* **id** (UUID, PK)
* **title** (String)
* **severity** (Enum: disruption_severity_enum)
* **affected_region** (PostGIS Geography Polygon)

### `tradeoff_metrics`
* **id** (UUID, PK)
* **analysis_id** (UUID, FK -> tradeoff_analyses)
* **candidate_node_id** (UUID, FK -> supply_chain_nodes)
* **metric_type** (Enum: tradeoff_metric_enum)
* **score_value** (Numeric)

---

## 💡 Common Supabase Query Patterns for this Schema

**1. Fetch Canvas Graph (Nodes + Edges):**
```typescript
const { data: nodes } = await supabase
  .from('supply_chain_nodes')
  .select('*, node_edges!source_node_id(*)')
  .is('deleted_at', null);
2. Insert Telemetry (Append Only):

TypeScript
const { error } = await supabase
  .from('telemetry_events')
  .insert({
    node_id: 'uuid',
    organization_id: 'uuid',
    event_type: 'latency_spike',
    status: 'delayed',
    source: 'mcp_sync'
  });