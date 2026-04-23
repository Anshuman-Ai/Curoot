-- ==========================================================================
-- Curoot — §2.3 Node Discovery & Onboarding Upgrades
-- ==========================================================================

-- ── node_invitations upgrades ─────────────────────────────────────────────
-- Add token, expiry, and invite link tracking for 7-day enforcement
ALTER TABLE public.node_invitations
    ADD COLUMN IF NOT EXISTS token       TEXT,
    ADD COLUMN IF NOT EXISTS expires_at  TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS invite_link TEXT,
    ADD COLUMN IF NOT EXISTS channel     TEXT DEFAULT 'email';  -- 'email' or 'whatsapp'

CREATE INDEX IF NOT EXISTS idx_ni_token
    ON public.node_invitations(token)
    WHERE token IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ni_expiry
    ON public.node_invitations(expires_at)
    WHERE status = 'pending';

-- ── discovery_cache — Tier 3 OSM local caching ───────────────────────────
-- Caches up to 2 alternative nodes per query to avoid re-hitting OSM API
CREATE TABLE IF NOT EXISTS public.discovery_cache (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    query_hash     TEXT NOT NULL,              -- MD5 hash of (query + radius)
    osm_id         TEXT,
    label          TEXT NOT NULL,
    lat            DOUBLE PRECISION,
    lon            DOUBLE PRECISION,
    raw_data       JSONB DEFAULT '{}',
    cached_at      TIMESTAMPTZ DEFAULT now(),
    expires_at     TIMESTAMPTZ DEFAULT (now() + interval '7 days')
);

CREATE INDEX IF NOT EXISTS idx_dc_query
    ON public.discovery_cache(organization_id, query_hash);

-- Auto-cleanup: expired cache rows can be purged by a scheduled job
-- or the application simply ignores rows past expires_at.

-- ── RLS for discovery_cache ───────────────────────────────────────────────
ALTER TABLE public.discovery_cache ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'discovery_cache'
      AND policyname = 'org_isolation_discovery_cache'
  ) THEN
    CREATE POLICY org_isolation_discovery_cache
      ON public.discovery_cache
      FOR ALL
      TO authenticated
      USING (organization_id = auth.uid())
      WITH CHECK (organization_id = auth.uid());
  END IF;
END
$$;
