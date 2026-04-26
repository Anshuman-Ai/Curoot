-- ==========================================================================
-- Curoot Final Audit Resolving Migration (One-Shot)
-- Bundles all necessary schema updates into a single executable script.
-- ==========================================================================

-- --------------------------------------------------------------------------
-- 1. Invitation Expiry Enforcement (C3 Gap Fix)
-- --------------------------------------------------------------------------
-- Add token + expiry columns to node_invitations
ALTER TABLE node_invitations ADD COLUMN IF NOT EXISTS token TEXT;
ALTER TABLE node_invitations ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- Index for fast token lookup
CREATE INDEX IF NOT EXISTS idx_ni_token ON node_invitations(token) WHERE token IS NOT NULL;

-- Index for expiry cleanup
CREATE INDEX IF NOT EXISTS idx_ni_expires ON node_invitations(expires_at) WHERE status = 'pending';


-- --------------------------------------------------------------------------
-- 2. Telemetry Performance & Tradeoffs Engine (L1 & M5 Gap Fixes)
-- --------------------------------------------------------------------------
-- BRIN index on telemetry_events (time-range optimized for massive scaling)
CREATE INDEX IF NOT EXISTS idx_te_recorded_at_brin
    ON telemetry_events USING BRIN (recorded_at)
    WITH (pages_per_range = 32);

-- Telemetry cost/status columns for tradeoff engine
ALTER TABLE telemetry_events ADD COLUMN IF NOT EXISTS cost_usd DOUBLE PRECISION;
ALTER TABLE telemetry_events ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'on_time';

-- Composite index for tradeoff engine queries
CREATE INDEX IF NOT EXISTS idx_te_node_org_time
    ON telemetry_events (node_id, organization_id, recorded_at DESC);


-- --------------------------------------------------------------------------
-- 3. Heartbeat NLP Parsing 
-- --------------------------------------------------------------------------
-- Parsed data columns for messages (heartbeat NLP parser support)
ALTER TABLE messages ADD COLUMN IF NOT EXISTS parsed_data JSONB;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS parse_confidence DOUBLE PRECISION;
