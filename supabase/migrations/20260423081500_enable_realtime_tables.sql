-- ==========================================================================
-- Enable Supabase Realtime on tables required for §2.1 ↔ §2.4 bridge
--
-- Without this, the Flutter Realtime subscriptions (PostgresChanges)
-- silently receive zero events because the tables are not part of the
-- `supabase_realtime` publication.
-- ==========================================================================

-- Core canvas graph — nodes + edges must sync across multiplayer clients
ALTER PUBLICATION supabase_realtime ADD TABLE supply_chain_nodes;
ALTER PUBLICATION supabase_realtime ADD TABLE node_edges;

-- Disruption alerts — canvas nodes flash red/amber when alerts fire
ALTER PUBLICATION supabase_realtime ADD TABLE disruption_alerts;

-- Alert state — diff-based WebSocket sync for alert acknowledgement
ALTER PUBLICATION supabase_realtime ADD TABLE alert_state;

-- Telemetry events — crisis events push Co-Pilot advisories to canvas
ALTER PUBLICATION supabase_realtime ADD TABLE telemetry_events;

-- Ingestion jobs — track Cold Start / MCP progress in OmniIngestionPanel
ALTER PUBLICATION supabase_realtime ADD TABLE ingestion_jobs;

-- MCP containers — pipeline status (generated → deployed → active)
ALTER PUBLICATION supabase_realtime ADD TABLE mcp_containers;
