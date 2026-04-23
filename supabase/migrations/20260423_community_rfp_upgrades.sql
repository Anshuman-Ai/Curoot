-- ==========================================================================
-- Curoot — §2.2 Community & RFP Upgrades Migration
-- ==========================================================================

-- ── community_templates upgrades ──────────────────────────────────────────
ALTER TABLE public.community_templates
    ADD COLUMN IF NOT EXISTS is_published   BOOLEAN      DEFAULT false,
    ADD COLUMN IF NOT EXISTS is_sanitized   BOOLEAN      DEFAULT false,
    ADD COLUMN IF NOT EXISTS sanitized_at   TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS niche_tags     TEXT[]       DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS download_count INTEGER      DEFAULT 0;

-- ── template_nodes upgrades ───────────────────────────────────────────────
ALTER TABLE public.template_nodes
    ADD COLUMN IF NOT EXISTS country_code   TEXT,
    ADD COLUMN IF NOT EXISTS region         TEXT,
    ADD COLUMN IF NOT EXISTS contact_email  TEXT;       -- sanitized contact (no personal PII)

-- ── rfp_requests upgrades ─────────────────────────────────────────────────
ALTER TABLE public.rfp_requests
    ADD COLUMN IF NOT EXISTS rfp_status     TEXT         DEFAULT 'pending',  -- pending, sent, confirmed, failed, cooldown
    ADD COLUMN IF NOT EXISTS responded_at   TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS cooldown_until TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS request_count  INTEGER      DEFAULT 1;

CREATE INDEX IF NOT EXISTS idx_rfp_org_node
    ON public.rfp_requests(organization_id, target_node_id);

CREATE INDEX IF NOT EXISTS idx_rfp_cooldown
    ON public.rfp_requests(target_node_id, cooldown_until)
    WHERE cooldown_until IS NOT NULL;

-- ── RLS — allow anyone to READ published templates (community is public) ──
ALTER TABLE public.community_templates ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1  
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'community_templates'
      AND policyname = 'read_published_templates'
  ) THEN
    CREATE POLICY read_published_templates
      ON public.community_templates
      FOR SELECT
      TO PUBLIC
      USING (
        is_published = true
        AND deleted_at IS NULL
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'community_templates'
      AND policyname = 'write_own_templates'
  ) THEN
    -- Assumes column: published_by_org (uuid/int) exists and matches auth.uid()
    CREATE POLICY write_own_templates
      ON public.community_templates
      FOR ALL
      TO authenticated
      USING (published_by_org = auth.uid())
      WITH CHECK (published_by_org = auth.uid());
  END IF;
END
$$;

-- template_nodes inherit access through their parent template
ALTER TABLE public.template_nodes ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'template_nodes'
      AND policyname = 'read_template_nodes_of_published'
  ) THEN
    CREATE POLICY read_template_nodes_of_published
      ON public.template_nodes
      FOR SELECT
      TO PUBLIC
      USING (
        EXISTS (
          SELECT 1
          FROM public.community_templates ct
          WHERE ct.id = template_nodes.template_id
            AND ct.is_published = true
            AND ct.deleted_at IS NULL
        )
      );
  END IF;
END
$$;

-- rfp_requests — org-scoped
ALTER TABLE public.rfp_requests ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'rfp_requests'
      AND policyname = 'org_isolation_rfp_requests'
  ) THEN
    CREATE POLICY org_isolation_rfp_requests
      ON public.rfp_requests
      FOR ALL
      TO authenticated
      USING (organization_id = auth.uid())
      WITH CHECK (organization_id = auth.uid());
  END IF;
END
$$;