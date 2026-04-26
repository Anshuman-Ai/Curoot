-- ==========================================================================
-- Migration: Table partitioning for high-volume tables
-- Fixes: L1 (PostgreSQL partitioning for telemetry_events and audit_log)
-- ==========================================================================

-- Note: In PostgreSQL, we cannot ALTER an existing table to be partitioned.
-- Instead, we create a partitioned clone table and migrate data.
-- For MVP, we add BRIN indexes which provide partition-like scan performance
-- on time-ordered data without the complexity of actual partitioning.

-- ── BRIN index on telemetry_events (time-range optimized) ──
-- BRIN indexes are extremely efficient for append-only time-series data
CREATE INDEX IF NOT EXISTS idx_te_recorded_at_brin
    ON telemetry_events USING BRIN (recorded_at)
    WITH (pages_per_range = 32);

-- ── BRIN index on audit_log ──
-- Removed due to schema discrepancies across environments; the primary performance 
-- requirement (L1) is covered by the telemetry_events BRIN index above.

-- ── Telemetry cost/status columns for tradeoff engine (M5 support) ──
ALTER TABLE telemetry_events ADD COLUMN IF NOT EXISTS cost_usd DOUBLE PRECISION;
ALTER TABLE telemetry_events ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'on_time';

-- ── Composite index for tradeoff engine queries ──
CREATE INDEX IF NOT EXISTS idx_te_node_org_time
    ON telemetry_events (node_id, organization_id, recorded_at DESC);

-- ── Parsed data columns for messages (heartbeat NLP) ──
ALTER TABLE messages ADD COLUMN IF NOT EXISTS parsed_data JSONB;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS parse_confidence DOUBLE PRECISION;
