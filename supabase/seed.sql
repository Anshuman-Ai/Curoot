-- ==========================================================================
-- Curoot Platform — Seed Data
-- Populates demo organization with sample nodes, edges, templates,
-- and macro signals for first-run experience.
-- ==========================================================================

-- Ensure demo org exists
INSERT INTO organizations (id, name, slug, industry, metadata)
VALUES ('00000000-0000-0000-0000-000000000000', 'Demo Organization', 'demo', 'Manufacturing', '{"tier": "enterprise"}')
ON CONFLICT (id) DO NOTHING;

-- ==========================================================================
-- Supply Chain Nodes (Demo Network)
-- ==========================================================================
INSERT INTO supply_chain_nodes (id, organization_id, name, node_type, status, canvas_x, canvas_y, metadata)
VALUES
  ('11111111-1111-1111-1111-111111111001', '00000000-0000-0000-0000-000000000000',
   'Shanghai Steel Works', 'supplier', 'operational', 4750, 4720,
   '{"country_code": "CN", "email": "ops@shanghaisteelworks.cn"}'),

  ('11111111-1111-1111-1111-111111111002', '00000000-0000-0000-0000-000000000000',
   'Munich Precision GmbH', 'factory', 'operational', 5250, 4720,
   '{"country_code": "EU", "email": "contact@munichprecision.de"}'),

  ('11111111-1111-1111-1111-111111111003', '00000000-0000-0000-0000-000000000000',
   'Tata Logistics Hub', 'supplier', 'operational', 4750, 5280,
   '{"country_code": "IN", "email": "hub@tatalogistics.in"}'),

  ('11111111-1111-1111-1111-111111111004', '00000000-0000-0000-0000-000000000000',
   'São Paulo Polymers', 'supplier', 'delayed', 5250, 5280,
   '{"country_code": "BR", "email": "vendas@sppolymers.com.br"}'),

  ('11111111-1111-1111-1111-111111111005', '00000000-0000-0000-0000-000000000000',
   'Nagoya Electronics', 'factory', 'operational', 5000, 4500,
   '{"country_code": "JP", "email": "info@nagoyaelec.jp"}')
ON CONFLICT (id) DO NOTHING;

-- ==========================================================================
-- Node Edges (Directed Supply Flow)
-- ==========================================================================
INSERT INTO node_edges (id, organization_id, source_node_id, target_node_id, edge_type)
VALUES
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeee0001', '00000000-0000-0000-0000-000000000000',
   '11111111-1111-1111-1111-111111111001', '11111111-1111-1111-1111-111111111002', 'supplies_to'),

  ('eeeeeeee-eeee-eeee-eeee-eeeeeeee0002', '00000000-0000-0000-0000-000000000000',
   '11111111-1111-1111-1111-111111111003', '11111111-1111-1111-1111-111111111004', 'supplies_to'),

  ('eeeeeeee-eeee-eeee-eeee-eeeeeeee0003', '00000000-0000-0000-0000-000000000000',
   '11111111-1111-1111-1111-111111111005', '11111111-1111-1111-1111-111111111001', 'supplies_to')
ON CONFLICT DO NOTHING;

-- ==========================================================================
-- Community Templates (Marketplace)
-- ==========================================================================
INSERT INTO community_templates (id, published_by_org, name, description, industry, node_count, metadata)
VALUES
  ('cccccccc-cccc-cccc-cccc-cccccccc0001', '00000000-0000-0000-0000-000000000000',
   'Ethical Sourcing Textiles - South Asia',
   'A vetted multi-tier network of sustainable cotton suppliers and ethical manufacturers in South Asia.',
   'Textiles', 3,
   '{"verified": true, "forks": 142}'),

  ('cccccccc-cccc-cccc-cccc-cccccccc0002', '00000000-0000-0000-0000-000000000000',
   'Semiconductor Fab Network - EU',
   'Pre-vetted European semiconductor fabrication channels with low disruption risk.',
   'Electronics', 2,
   '{"verified": true, "forks": 87}')
ON CONFLICT (id) DO NOTHING;

-- Template Nodes
INSERT INTO template_nodes (id, template_id, name, node_type, relative_x, relative_y, metadata)
VALUES
  ('tttttttt-tttt-tttt-tttt-tttttttt0001', 'cccccccc-cccc-cccc-cccc-cccccccc0001',
   'Organic Cotton Farm', 'supplier', -200, -100, '{}'),
  ('tttttttt-tttt-tttt-tttt-tttttttt0002', 'cccccccc-cccc-cccc-cccc-cccccccc0001',
   'FairTrade Dye Factory', 'factory', 0, 100, '{}'),
  ('tttttttt-tttt-tttt-tttt-tttttttt0003', 'cccccccc-cccc-cccc-cccc-cccccccc0001',
   'Certified Textile Mill', 'factory', 200, -100, '{}'),

  ('tttttttt-tttt-tttt-tttt-tttttttt0004', 'cccccccc-cccc-cccc-cccc-cccccccc0002',
   'Silica Mine Co.', 'supplier', -150, 0, '{}'),
  ('tttttttt-tttt-tttt-tttt-tttttttt0005', 'cccccccc-cccc-cccc-cccc-cccccccc0002',
   'EuroFab 3nm', 'factory', 150, 0, '{}')
ON CONFLICT (id) DO NOTHING;

-- ==========================================================================
-- Macro Environment Signals (Initial Data)
-- ==========================================================================
INSERT INTO macro_environment_signals (id, country_code, signal_type, risk_level, confidence, primary_driver, signals_summary)
VALUES
  ('dddddddd-dddd-dddd-dddd-dddddddd0001', 'CN', 'geopolitical',
   'medium', 0.65, 'Trade policy uncertainty',
   'Ongoing trade tensions affecting export regulations for raw materials.'),

  ('dddddddd-dddd-dddd-dddd-dddddddd0002', 'IN', 'weather',
   'low', 0.80, 'Monsoon season forecast',
   'Normal monsoon patterns expected. Low disruption probability for inland logistics.'),

  ('dddddddd-dddd-dddd-dddd-dddddddd0003', 'BR', 'financial',
   'high', 0.72, 'Currency volatility',
   'BRL/USD exchange rate instability impacting polymer import costs.'),

  ('dddddddd-dddd-dddd-dddd-dddddddd0004', 'EU', 'regulatory',
   'low', 0.90, 'CBAM compliance',
   'Carbon Border Adjustment Mechanism Phase 2 enforcement in effect. All EU suppliers compliant.'),

  ('dddddddd-dddd-dddd-dddd-dddddddd0005', 'JP', 'seismic',
   'medium', 0.55, 'Seismic activity monitoring',
   'Elevated seismic readings in Tokai region. Monitoring infrastructure resilience.')
ON CONFLICT (id) DO NOTHING;
