-- ==========================================================================
-- Curoot Platform — Zero-Knowledge Abstraction Module (SRS §2.4)
-- ==========================================================================

-- 1. Add fields to supply_chain_nodes for upstream exceptions
ALTER TABLE public.supply_chain_nodes
    ADD COLUMN IF NOT EXISTS abstracted_payload JSONB DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS cascade_delay_hours DOUBLE PRECISION DEFAULT NULL;

-- 2. Create downstream_alerts table for cross-org abstracted events
CREATE TABLE IF NOT EXISTS public.downstream_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    target_org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    target_node_id UUID NOT NULL REFERENCES supply_chain_nodes(id) ON DELETE CASCADE,
    abstracted_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for querying alerts meant for a specific target organization
CREATE INDEX IF NOT EXISTS idx_dsa_target_org ON public.downstream_alerts(target_org_id);

-- 3. RLS for downstream_alerts
ALTER TABLE public.downstream_alerts ENABLE ROW LEVEL SECURITY;

-- Target organizations can view alerts sent to them
CREATE POLICY "Target orgs can view their downstream alerts"
    ON public.downstream_alerts FOR SELECT
    USING (target_org_id = auth.uid());

-- Source organizations can insert alerts
CREATE POLICY "Source orgs can insert downstream alerts"
    ON public.downstream_alerts FOR INSERT
    WITH CHECK (source_org_id = auth.uid());

-- Enable Realtime for downstream_alerts
ALTER PUBLICATION supabase_realtime ADD TABLE public.downstream_alerts;
