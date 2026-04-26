-- ==========================================================================
-- Curoot — Fix Tradeoff Constraints (2026-04-26)
-- Resolves:
--   chk_tradeoff_recommendation rejecting valid 'stay'/'investigate' values
--   fk_ta_initiated_by blocking inserts (initiated_by -> wrong table)
-- ==========================================================================

-- 1. Drop the overly restrictive check constraint on overall_recommendation
ALTER TABLE tradeoff_analyses DROP CONSTRAINT IF EXISTS chk_tradeoff_recommendation;

-- 2. Re-create with the correct allowed values (switch, stay, investigate)
ALTER TABLE tradeoff_analyses ADD CONSTRAINT chk_tradeoff_recommendation
  CHECK (overall_recommendation IN ('switch', 'stay', 'investigate', 'monitor', 'reroute'));

-- 3. Drop the foreign key on initiated_by (it references a table the backend
--    doesn't populate — the field is set to org_id which lives in organizations,
--    not in whatever table fk_ta_initiated_by points to)
ALTER TABLE tradeoff_analyses DROP CONSTRAINT IF EXISTS fk_ta_initiated_by;

-- 4. Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
