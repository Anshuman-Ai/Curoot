-- ==========================================================================
-- Curoot — Fix Missing Columns (2026-04-26)
-- Resolves errors observed in backend logs:
--   - 42703: column macro_environment_signals.risk_level does not exist
--   - 23502: null value in column tradeoff_analyses.initiated_by (fixed in code)
-- ==========================================================================

-- ── 1. macro_environment_signals — restore columns the live DB is missing ──
-- The initial schema defined these but they may be absent in the live DB.
ALTER TABLE macro_environment_signals
    ADD COLUMN IF NOT EXISTS risk_level TEXT DEFAULT 'low',
    ADD COLUMN IF NOT EXISTS confidence DOUBLE PRECISION DEFAULT 0.5,
    ADD COLUMN IF NOT EXISTS primary_driver TEXT,
    ADD COLUMN IF NOT EXISTS signals_summary TEXT,
    ADD COLUMN IF NOT EXISTS raw_data JSONB DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS payload JSONB DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS recorded_at TIMESTAMPTZ DEFAULT now(),
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

-- ── 2. tradeoff_analyses — ensure initiated_by column exists (NOT NULL) ──
ALTER TABLE tradeoff_analyses
    ADD COLUMN IF NOT EXISTS initiated_by UUID;

-- Make it default to a sensible value for existing rows
UPDATE tradeoff_analyses
    SET initiated_by = organization_id
    WHERE initiated_by IS NULL;

-- ── 3. messages — ensure body/subject columns exist ──
-- Backend uses body/subject; original schema used content/message_type
ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS body TEXT,
    ADD COLUMN IF NOT EXISTS subject TEXT DEFAULT 'text',
    ADD COLUMN IF NOT EXISTS node_id UUID REFERENCES supply_chain_nodes(id),
    ADD COLUMN IF NOT EXISTS parsed_data JSONB,
    ADD COLUMN IF NOT EXISTS parse_confidence DOUBLE PRECISION DEFAULT 0.0;

-- ── 4. supply_chain_nodes — ensure all heartbeat columns exist ──
ALTER TABLE supply_chain_nodes
    ADD COLUMN IF NOT EXISTS historical_delay_rate DOUBLE PRECISION DEFAULT 0.0;

-- ── 5. Refresh PostgREST schema cache ──
NOTIFY pgrst, 'reload schema';
