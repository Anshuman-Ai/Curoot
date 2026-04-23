-- ==========================================================================
-- Heartbeat Module (SRS §2.7) — Schema Migration
-- ==========================================================================

-- 1. Magic Link Tokens
-- Stores secure, time-boxed tokens tied to specific supply chain nodes.
-- Suppliers access the conversational PWA via these tokens.
CREATE TABLE IF NOT EXISTS magic_link_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    token TEXT UNIQUE NOT NULL,
    node_id UUID NOT NULL REFERENCES supply_chain_nodes(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    created_by UUID,                             -- OEM user who generated
    expires_at TIMESTAMPTZ NOT NULL,
    is_revoked BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mlt_token ON magic_link_tokens(token);
CREATE INDEX IF NOT EXISTS idx_mlt_node ON magic_link_tokens(node_id);
CREATE INDEX IF NOT EXISTS idx_mlt_org ON magic_link_tokens(organization_id);

-- 2. Add heartbeat tracking columns to supply_chain_nodes
ALTER TABLE supply_chain_nodes
    ADD COLUMN IF NOT EXISTS last_heartbeat_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS heartbeat_confidence DOUBLE PRECISION DEFAULT 1.0,
    ADD COLUMN IF NOT EXISTS is_dark_node BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS historical_delay_rate DOUBLE PRECISION DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS volume_weight DOUBLE PRECISION DEFAULT 1.0;

-- 3. Add parsed_data columns to messages for structured schema updates
ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS parsed_data JSONB DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS parse_confidence DOUBLE PRECISION DEFAULT 0.0;

-- 4. Enable RLS on magic_link_tokens
ALTER TABLE magic_link_tokens ENABLE ROW LEVEL SECURITY;

-- 5. Enable realtime on messages (for live chat updates)
DO $$
BEGIN
    -- Only add if not already part of the publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE messages;
    END IF;
END;
$$;
