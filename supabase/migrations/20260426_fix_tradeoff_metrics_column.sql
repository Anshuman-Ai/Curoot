-- ==========================================================================
-- Curoot — Fix tradeoff_metrics.metric_type missing from schema cache
-- Error: PGRST204 "Could not find the 'metric_type' column"
-- ==========================================================================

-- Ensure all columns the backend writes actually exist
ALTER TABLE tradeoff_metrics ADD COLUMN IF NOT EXISTS metric_type TEXT;
ALTER TABLE tradeoff_metrics ADD COLUMN IF NOT EXISTS current_value DOUBLE PRECISION;
ALTER TABLE tradeoff_metrics ADD COLUMN IF NOT EXISTS alternative_value DOUBLE PRECISION;
ALTER TABLE tradeoff_metrics ADD COLUMN IF NOT EXISTS delta DOUBLE PRECISION;
ALTER TABLE tradeoff_metrics ADD COLUMN IF NOT EXISTS unit TEXT;

-- Drop and re-create the unique constraint (may fail if metric_type was missing)
ALTER TABLE tradeoff_metrics DROP CONSTRAINT IF EXISTS tradeoff_metrics_analysis_id_metric_type_key;
ALTER TABLE tradeoff_metrics ADD CONSTRAINT tradeoff_metrics_analysis_id_metric_type_key
    UNIQUE (analysis_id, metric_type);

-- Reload PostgREST schema cache so the new/existing columns are visible
NOTIFY pgrst, 'reload schema';
