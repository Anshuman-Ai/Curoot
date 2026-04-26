-- ==========================================================================
-- Migration: Add invitation expiry enforcement columns
-- Fixes: C3 (invitation expiry), M6 (country_code)
-- ==========================================================================

-- Add token + expiry columns to node_invitations
ALTER TABLE node_invitations ADD COLUMN IF NOT EXISTS token TEXT;
ALTER TABLE node_invitations ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- Index for fast token lookup
CREATE INDEX IF NOT EXISTS idx_ni_token ON node_invitations(token) WHERE token IS NOT NULL;

-- Index for expiry cleanup
CREATE INDEX IF NOT EXISTS idx_ni_expires ON node_invitations(expires_at) WHERE status = 'pending';
