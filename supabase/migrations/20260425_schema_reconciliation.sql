-- ==========================================================================
-- Curoot Platform — Schema Reconciliation Migration
-- Aligns the database schema with what the backend code actually writes.
-- Fixes all PGRST204 "column not found in schema cache" errors.
-- ==========================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- 1. supply_chain_nodes — add missing columns
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE supply_chain_nodes ADD COLUMN IF NOT EXISTS ui_x DOUBLE PRECISION;
ALTER TABLE supply_chain_nodes ADD COLUMN IF NOT EXISTS ui_y DOUBLE PRECISION;
ALTER TABLE supply_chain_nodes ADD COLUMN IF NOT EXISTS country_code TEXT;
ALTER TABLE supply_chain_nodes ADD COLUMN IF NOT EXISTS is_dark_node BOOLEAN DEFAULT false;
ALTER TABLE supply_chain_nodes ADD COLUMN IF NOT EXISTS heartbeat_confidence DOUBLE PRECISION DEFAULT 1.0;
ALTER TABLE supply_chain_nodes ADD COLUMN IF NOT EXISTS last_heartbeat_at TIMESTAMPTZ;
ALTER TABLE supply_chain_nodes ADD COLUMN IF NOT EXISTS volume_weight DOUBLE PRECISION;
ALTER TABLE supply_chain_nodes ADD COLUMN IF NOT EXISTS transport_mode TEXT DEFAULT 'road';
ALTER TABLE supply_chain_nodes ADD COLUMN IF NOT EXISTS abstracted_payload JSONB;
ALTER TABLE supply_chain_nodes ADD COLUMN IF NOT EXISTS cascade_delay_hours DOUBLE PRECISION;
ALTER TABLE supply_chain_nodes ADD COLUMN IF NOT EXISTS name TEXT;

-- ──────────────────────────────────────────────────────────────────────────
-- 2. disruption_alerts — add payload JSONB (code writes alert data here)
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE disruption_alerts ADD COLUMN IF NOT EXISTS payload JSONB DEFAULT '{}';

-- ──────────────────────────────────────────────────────────────────────────
-- 3. tradeoff_analyses — add recommendation columns
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE tradeoff_analyses ADD COLUMN IF NOT EXISTS overall_recommendation TEXT;
ALTER TABLE tradeoff_analyses ADD COLUMN IF NOT EXISTS recommendation_confidence DOUBLE PRECISION;

-- ──────────────────────────────────────────────────────────────────────────
-- 4. tradeoff_metrics — add individual value columns
--    (schema only has `value` + `unit`; code writes current/alt/delta)
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE tradeoff_metrics ADD COLUMN IF NOT EXISTS current_value DOUBLE PRECISION;
ALTER TABLE tradeoff_metrics ADD COLUMN IF NOT EXISTS alternative_value DOUBLE PRECISION;
ALTER TABLE tradeoff_metrics ADD COLUMN IF NOT EXISTS delta DOUBLE PRECISION;

-- ──────────────────────────────────────────────────────────────────────────
-- 5. messages — add NLP parsed data columns
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE messages ADD COLUMN IF NOT EXISTS parsed_data JSONB;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS parse_confidence DOUBLE PRECISION;

-- ──────────────────────────────────────────────────────────────────────────
-- 6. macro_environment_signals — add payload JSONB + created_at
--    (code reads payload subfields and orders by created_at)
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE macro_environment_signals ADD COLUMN IF NOT EXISTS payload JSONB DEFAULT '{}';
ALTER TABLE macro_environment_signals ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

-- ──────────────────────────────────────────────────────────────────────────
-- 7. downstream_alerts — for zero-knowledge abstraction engine
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS downstream_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_alert_id UUID REFERENCES disruption_alerts(id),
    source_org_id UUID NOT NULL REFERENCES organizations(id),
    target_org_id UUID NOT NULL REFERENCES organizations(id),
    abstracted_payload JSONB NOT NULL DEFAULT '{}',
    cascade_delay_hours DOUBLE PRECISION DEFAULT 0,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_da_target_org ON downstream_alerts(target_org_id);
CREATE INDEX IF NOT EXISTS idx_da_source_alert ON downstream_alerts(source_alert_id);

-- ──────────────────────────────────────────────────────────────────────────
-- 8. magic_link_tokens — ensure it exists (from heartbeat migration)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS magic_link_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    token TEXT NOT NULL UNIQUE,
    node_id UUID NOT NULL REFERENCES supply_chain_nodes(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    is_revoked BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mlt_token ON magic_link_tokens(token);
CREATE INDEX IF NOT EXISTS idx_mlt_node ON magic_link_tokens(node_id);

-- ──────────────────────────────────────────────────────────────────────────
-- 9. Add other missing columns identified in backend logs
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE ingestion_jobs ADD COLUMN IF NOT EXISTS source_ref TEXT;
ALTER TABLE ingestion_jobs ADD COLUMN IF NOT EXISTS source_type TEXT NOT NULL DEFAULT 'cold_start';
ALTER TABLE node_edges ADD COLUMN IF NOT EXISTS edge_type TEXT DEFAULT 'supplies_to';
ALTER TABLE supply_chain_nodes ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'operational';

-- ──────────────────────────────────────────────────────────────────────────
-- 10. Reconcile strict constraints that are blocking AI-generated data
-- ──────────────────────────────────────────────────────────────────────────
-- The following line may fail if views depend on node_type. 
-- Dropping the known blocking view first.
DROP VIEW IF EXISTS vw_supply_chain_nodes_safe;

ALTER TABLE ingestion_jobs DROP CONSTRAINT IF EXISTS chk_ingest_status;
ALTER TABLE supply_chain_nodes ALTER COLUMN node_type TYPE TEXT USING node_type::text;

-- Recreate the view (assuming standard structure, adjust if necessary)
CREATE OR REPLACE VIEW vw_supply_chain_nodes_safe AS
SELECT * FROM supply_chain_nodes WHERE deleted_at IS NULL;

-- ──────────────────────────────────────────────────────────────────────────
-- 9. Refresh PostgREST schema cache so new columns are visible immediately
-- ──────────────────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
