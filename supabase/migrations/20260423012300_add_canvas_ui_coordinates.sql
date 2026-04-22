-- Add ui_x and ui_y columns for the 2D infinite canvas positions
-- These are distinct from geographic lat/lon to avoid overwriting them
ALTER TABLE public.supply_chain_nodes
ADD COLUMN ui_x DOUBLE PRECISION,
ADD COLUMN ui_y DOUBLE PRECISION;
