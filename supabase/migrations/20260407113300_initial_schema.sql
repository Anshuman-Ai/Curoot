-- ==========================================================================
-- Curoot Platform — Initial Schema Migration
-- Based on DB_Relation.md v1.0.0
-- ==========================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ==========================================================================
-- 1. ORGANIZATIONS (Root Entity)
-- ==========================================================================
CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE,
    industry TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- ==========================================================================
-- 2. ORGANIZATION MEMBERS
-- ==========================================================================
CREATE TABLE IF NOT EXISTS organization_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    role TEXT DEFAULT 'member',
    created_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(organization_id, user_id)
);

-- ==========================================================================
-- 3. SUPPLY CHAIN NODES (Core Graph Node)
-- ==========================================================================
CREATE TABLE IF NOT EXISTS supply_chain_nodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    partner_org_id UUID REFERENCES organizations(id),
    name TEXT NOT NULL,
    node_type TEXT NOT NULL DEFAULT 'supplier',
    status TEXT DEFAULT 'operational',
    location GEOGRAPHY(POINT, 4326),
    canvas_x DOUBLE PRECISION DEFAULT 0,
    canvas_y DOUBLE PRECISION DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_scn_org ON supply_chain_nodes(organization_id);
CREATE INDEX IF NOT EXISTS idx_scn_location ON supply_chain_nodes USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_scn_active ON supply_chain_nodes(organization_id) WHERE deleted_at IS NULL;

-- ==========================================================================
-- 4. NODE EDGES (Graph Edges — directed)
-- ==========================================================================
CREATE TABLE IF NOT EXISTS node_edges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    source_node_id UUID NOT NULL REFERENCES supply_chain_nodes(id) ON DELETE CASCADE,
    target_node_id UUID NOT NULL REFERENCES supply_chain_nodes(id) ON DELETE CASCADE,
    edge_type TEXT DEFAULT 'supplies_to',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT no_self_loop CHECK (source_node_id != target_node_id),
    UNIQUE(source_node_id, target_node_id, edge_type)
);

CREATE INDEX IF NOT EXISTS idx_ne_org ON node_edges(organization_id);
CREATE INDEX IF NOT EXISTS idx_ne_source ON node_edges(source_node_id);
CREATE INDEX IF NOT EXISTS idx_ne_target ON node_edges(target_node_id);

-- ==========================================================================
-- 5. INGESTION JOBS
-- ==========================================================================
CREATE TABLE IF NOT EXISTS ingestion_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    source_type TEXT NOT NULL,          -- 'cold_start', 'mcp_continuous_sync', 'webhook'
    source_ref TEXT,                    -- filename or connection string
    status TEXT DEFAULT 'pending',      -- pending, processing, completed, failed, active
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ij_org ON ingestion_jobs(organization_id);

-- ==========================================================================
-- 6. MCP CONTAINERS (One per org)
-- ==========================================================================
CREATE TABLE IF NOT EXISTS mcp_containers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    ingestion_job_id UUID REFERENCES ingestion_jobs(id),
    db_type TEXT NOT NULL,
    target_host TEXT NOT NULL,
    target_table TEXT NOT NULL,
    sync_frequency INTEGER DEFAULT 60,
    status TEXT DEFAULT 'generated',    -- generated, deployed, active, stopped
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(organization_id)
);

-- ==========================================================================
-- 7. TELEMETRY EVENTS (Time-Series, High-Volume)
-- ==========================================================================
CREATE TABLE IF NOT EXISTS telemetry_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    node_id UUID NOT NULL,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    event_type TEXT DEFAULT 'status_update',  -- status_update, location_update, crisis
    payload JSONB DEFAULT '{}',
    recorded_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_te_node ON telemetry_events(node_id);
CREATE INDEX IF NOT EXISTS idx_te_org ON telemetry_events(organization_id);
CREATE INDEX IF NOT EXISTS idx_te_time ON telemetry_events(recorded_at DESC);

-- ==========================================================================
-- 8. DISRUPTION ALERTS
-- ==========================================================================
CREATE TABLE IF NOT EXISTS disruption_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    node_id UUID REFERENCES supply_chain_nodes(id),
    edge_id UUID REFERENCES node_edges(id),
    alert_type TEXT NOT NULL,
    severity TEXT DEFAULT 'medium',
    title TEXT,
    description TEXT,
    source TEXT,
    affected_countries TEXT[],
    metadata JSONB DEFAULT '{}',
    status TEXT DEFAULT 'active',       -- active, acknowledged, resolved
    created_at TIMESTAMPTZ DEFAULT now(),
    resolved_at TIMESTAMPTZ,
    CONSTRAINT alert_target CHECK (node_id IS NOT NULL OR edge_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_da_org ON disruption_alerts(organization_id);
CREATE INDEX IF NOT EXISTS idx_da_active ON disruption_alerts(organization_id) WHERE status = 'active';

-- ==========================================================================
-- 9. ALERT STATE (for Flutter diff-based WebSocket sync)
-- ==========================================================================
CREATE TABLE IF NOT EXISTS alert_state (
    alert_id UUID PRIMARY KEY REFERENCES disruption_alerts(id),
    status TEXT DEFAULT 'active',
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================================================
-- 10. MACRO ENVIRONMENT SIGNALS
-- ==========================================================================
CREATE TABLE IF NOT EXISTS macro_environment_signals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    country_code TEXT NOT NULL,
    signal_type TEXT NOT NULL,
    risk_level TEXT DEFAULT 'low',
    confidence DOUBLE PRECISION DEFAULT 0.5,
    primary_driver TEXT,
    signals_summary TEXT,
    raw_data JSONB DEFAULT '{}',
    recorded_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mes_country ON macro_environment_signals(country_code);

-- ==========================================================================
-- 11. COMMUNITY TEMPLATES
-- ==========================================================================
CREATE TABLE IF NOT EXISTS community_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    published_by_org UUID REFERENCES organizations(id),
    name TEXT NOT NULL,
    description TEXT,
    industry TEXT,
    node_count INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- ==========================================================================
-- 12. TEMPLATE NODES
-- ==========================================================================
CREATE TABLE IF NOT EXISTS template_nodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_id UUID NOT NULL REFERENCES community_templates(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    node_type TEXT NOT NULL,
    relative_x DOUBLE PRECISION DEFAULT 0,
    relative_y DOUBLE PRECISION DEFAULT 0,
    metadata JSONB DEFAULT '{}'
);

-- ==========================================================================
-- 13. NODE INVITATIONS
-- ==========================================================================
CREATE TABLE IF NOT EXISTS node_invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    target_node_id UUID REFERENCES supply_chain_nodes(id),
    accepted_org_id UUID REFERENCES organizations(id),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    connection_type TEXT DEFAULT 'supplier',
    status TEXT DEFAULT 'pending',      -- pending, accepted, declined, expired
    created_at TIMESTAMPTZ DEFAULT now(),
    accepted_at TIMESTAMPTZ
);

-- ==========================================================================
-- 14. RFP REQUESTS
-- ==========================================================================
CREATE TABLE IF NOT EXISTS rfp_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    target_node_id UUID REFERENCES supply_chain_nodes(id),
    template_id UUID REFERENCES community_templates(id),
    status TEXT DEFAULT 'pending',
    message TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================================================
-- 15. TRADEOFF ANALYSES
-- ==========================================================================
CREATE TABLE IF NOT EXISTS tradeoff_analyses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    current_node_id UUID REFERENCES supply_chain_nodes(id),
    alternative_node_id UUID REFERENCES supply_chain_nodes(id),
    disruption_alert_id UUID REFERENCES disruption_alerts(id),
    analysis_type TEXT DEFAULT 'reroute',
    result JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================================================
-- 16. TRADEOFF METRICS
-- ==========================================================================
CREATE TABLE IF NOT EXISTS tradeoff_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    analysis_id UUID NOT NULL REFERENCES tradeoff_analyses(id) ON DELETE CASCADE,
    metric_type TEXT NOT NULL,
    value DOUBLE PRECISION,
    unit TEXT,
    metadata JSONB DEFAULT '{}',
    UNIQUE(analysis_id, metric_type)
);

-- ==========================================================================
-- 17. MESSAGES
-- ==========================================================================
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_org_id UUID NOT NULL REFERENCES organizations(id),
    recipient_org_id UUID NOT NULL REFERENCES organizations(id),
    node_id UUID REFERENCES supply_chain_nodes(id),
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================================================
-- 18. COMMUNICATION LOGS (Immutable, Append-Only)
-- ==========================================================================
CREATE TABLE IF NOT EXISTS communication_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    target_node_id UUID REFERENCES supply_chain_nodes(id),
    message_id UUID REFERENCES messages(id),
    action TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================================================
-- 19. AUDIT LOG (Append-Only, Regulatory)
-- ==========================================================================
CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE IF NOT EXISTS audit.audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL,
    record_id UUID,
    action TEXT NOT NULL,           -- INSERT, UPDATE, DELETE
    old_data JSONB,
    new_data JSONB,
    changed_by_org UUID,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_table ON audit.audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_time ON audit.audit_log(created_at DESC);

-- ==========================================================================
-- 20. ROW-LEVEL SECURITY (RLS)
-- ==========================================================================
-- Enable RLS on all tenant-scoped tables
ALTER TABLE supply_chain_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE node_edges ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingestion_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE mcp_containers ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE disruption_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE node_invitations ENABLE ROW LEVEL SECURITY;

-- Default org isolation policy (applied per table)
-- Users can only see rows belonging to their organization
DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOR tbl IN SELECT unnest(ARRAY[
        'supply_chain_nodes', 'node_edges', 'ingestion_jobs',
        'mcp_containers', 'telemetry_events', 'disruption_alerts',
        'node_invitations'
    ])
    LOOP
        EXECUTE format(
            'CREATE POLICY IF NOT EXISTS org_isolation_%I ON %I FOR ALL USING (organization_id = auth.uid())',
            tbl, tbl
        );
    END LOOP;
END;
$$;

-- ==========================================================================
-- Insert default demo organization
-- ==========================================================================
INSERT INTO organizations (id, name, slug)
VALUES ('00000000-0000-0000-0000-000000000000', 'Demo Organization', 'demo')
ON CONFLICT (id) DO NOTHING;
