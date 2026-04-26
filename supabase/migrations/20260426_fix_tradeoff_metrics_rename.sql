-- ==========================================================================
-- Fix: the live table has column "metric" (NOT NULL) but code writes "metric_type"
-- Solution: drop the duplicate metric_type we just added, rename metric -> metric_type
-- ==========================================================================

-- 1. Drop the duplicate metric_type column we added (nullable copy)
ALTER TABLE tradeoff_metrics DROP COLUMN IF EXISTS metric_type;

-- 2. Rename the original 'metric' column to 'metric_type'
ALTER TABLE tradeoff_metrics RENAME COLUMN metric TO metric_type;

-- 3. Re-create the unique constraint with the correct column name
ALTER TABLE tradeoff_metrics DROP CONSTRAINT IF EXISTS tradeoff_metrics_analysis_id_metric_type_key;
ALTER TABLE tradeoff_metrics DROP CONSTRAINT IF EXISTS tradeoff_metrics_analysis_id_metric_key;
ALTER TABLE tradeoff_metrics ADD CONSTRAINT tradeoff_metrics_analysis_id_metric_type_key
    UNIQUE (analysis_id, metric_type);

-- 4. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
