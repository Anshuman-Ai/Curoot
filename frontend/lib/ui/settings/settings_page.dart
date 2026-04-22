import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/settings_provider.dart';

// Shared design tokens
const _kBg = Color(0xFF0F1115);
const _kPanelBg = Color(0xFF16181D);
const _kTileBg = Color(0xFF1E2128);
const _kBorder = Color(0xFF2A2D35);
const _kAccent = Color(0xFF8083FF);
const _kTeal = Color(0xFF2DD4BF);
const _kDanger = Color(0xFFFF5C5C);

TextStyle _headerStyle = GoogleFonts.manrope(
  fontSize: 22,
  fontWeight: FontWeight.w700,
  color: Colors.white,
  letterSpacing: -0.5,
);

TextStyle _subHeaderStyle = GoogleFonts.manrope(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: Colors.white70,
  letterSpacing: 0.5,
);

TextStyle _bodyStyle = GoogleFonts.manrope(
  fontSize: 13,
  fontWeight: FontWeight.w400,
  color: Colors.white60,
);

enum SettingsTab {
  organization,
  network,
  sovereignty,
  alerts,
  community,
}

class ActiveSettingsTabNotifier extends Notifier<SettingsTab> {
  @override
  SettingsTab build() => SettingsTab.organization;
  void setTab(SettingsTab tab) => state = tab;
}

final activeSettingsTabProvider = NotifierProvider<ActiveSettingsTabNotifier, SettingsTab>(() {
  return ActiveSettingsTabNotifier();
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(activeSettingsTabProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Row(
          children: [
            // Left Navigation Rail
            Container(
              width: 260,
              decoration: const BoxDecoration(
                color: _kPanelBg,
                border: Border(right: BorderSide(color: _kBorder, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Text('Settings', style: _headerStyle),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _NavTile(
                    title: 'Organization & Team',
                    icon: Icons.domain,
                    tab: SettingsTab.organization,
                    activeTab: activeTab,
                  ),
                  _NavTile(
                    title: 'Network & RFP',
                    icon: Icons.hub_outlined,
                    tab: SettingsTab.network,
                    activeTab: activeTab,
                  ),
                  _NavTile(
                    title: 'Data Sovereignty (MCP)',
                    icon: Icons.shield_outlined,
                    tab: SettingsTab.sovereignty,
                    activeTab: activeTab,
                  ),
                  _NavTile(
                    title: 'Alerts & Predictive Engine',
                    icon: Icons.online_prediction,
                    tab: SettingsTab.alerts,
                    activeTab: activeTab,
                  ),
                  _NavTile(
                    title: 'Community & Templates',
                    icon: Icons.storefront,
                    tab: SettingsTab.community,
                    activeTab: activeTab,
                  ),
                ],
              ),
            ),
            
            // Main Content Area
            Expanded(
              child: Container(
                color: _kBg,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 40.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: _buildContent(activeTab),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(SettingsTab tab) {
    switch (tab) {
      case SettingsTab.organization:
        return const _OrganizationSettings();
      case SettingsTab.network:
        return const _NetworkSettings();
      case SettingsTab.sovereignty:
        return const _SovereigntySettings();
      case SettingsTab.alerts:
        return const _AlertsSettings();
      case SettingsTab.community:
        return const _CommunitySettings();
    }
  }
}

class _NavTile extends ConsumerWidget {
  final String title;
  final IconData icon;
  final SettingsTab tab;
  final SettingsTab activeTab;

  const _NavTile({
    required this.title,
    required this.icon,
    required this.tab,
    required this.activeTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = tab == activeTab;
    return InkWell(
      onTap: () => ref.read(activeSettingsTabProvider.notifier).setTab(tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? _kTeal.withValues(alpha: 0.1) : Colors.transparent,
          border: isActive
              ? const Border(left: BorderSide(color: _kTeal, width: 3))
              : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? _kTeal : Colors.white54, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? Colors.white : Colors.white60,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 1. Organization & Team Management
class _OrganizationSettings extends ConsumerWidget {
  const _OrganizationSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(userOrganizationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Organization & Team Management', style: _headerStyle),
        const SizedBox(height: 8),
        Text('Manage your organization details and team members.', style: _bodyStyle),
        const SizedBox(height: 32),

        // Tenant Switcher
        _SectionCard(
          title: 'Active Workspace',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You can belong to multiple organizations. Switch context here.', style: _bodyStyle),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _kTileBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                child: orgsAsync.when(
                  loading: () => const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
                  error: (_, __) => const Text('Failed to load organizations', style: TextStyle(color: _kDanger)),
                  data: (orgs) {
                    if (orgs.isEmpty) return const Text('No organizations found', style: TextStyle(color: Colors.white54));
                    return DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: _kTileBg,
                        value: ref.watch(activeOrganizationIdProvider) ?? orgs.first['organization_id'],
                        items: orgs.map<DropdownMenuItem<String>>((org) {
                          final orgData = org['organizations'];
                          return DropdownMenuItem(
                            value: org['organization_id'],
                            child: Text(orgData?['name'] ?? 'Unknown Org', style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          ref.read(activeOrganizationIdProvider.notifier).setId(val);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Member Management Placeholder
        _SectionCard(
          title: 'Team Members',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Invite and assign roles to members.', style: _bodyStyle),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Invite Member'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _kTileBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder, width: 1, strokeAlign: BorderSide.strokeAlignOutside),
                ),
                child: const Center(
                  child: Text('Member list mapped to active organization_id RLS.', style: TextStyle(color: Colors.white54)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 2. Network & RFP Preferences
class _NetworkSettings extends ConsumerStatefulWidget {
  const _NetworkSettings();

  @override
  ConsumerState<_NetworkSettings> createState() => _NetworkSettingsState();
}

class _NetworkSettingsState extends ConsumerState<_NetworkSettings> {
  double _rfpMonths = 1.0;
  bool _rateLimitOverride = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Network & RFP Preferences', style: _headerStyle),
        const SizedBox(height: 8),
        Text('Configure Request for Proposal (RFP) timeouts and limits.', style: _bodyStyle),
        const SizedBox(height: 32),

        _SectionCard(
          title: 'Default RFP Timeframe',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set the standard wait time for RFP replies (in months).', style: _bodyStyle),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _rfpMonths,
                      min: 1.0,
                      max: 12.0,
                      divisions: 11,
                      activeColor: _kTeal,
                      inactiveColor: _kBorder,
                      onChanged: (val) => setState(() => _rfpMonths = val),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kTileBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Text('${_rfpMonths.toInt()} Month(s)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _SectionCard(
          title: 'Bot-Abuse & Rate Limiting',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Visibility into the 1-day cooldown period triggered after two immediate RFP requests.', style: _bodyStyle),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Admin Override Limit', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text('Allow exceeding 2 requests per day (Not recommended).', style: _bodyStyle.copyWith(fontSize: 12)),
                activeThumbColor: _kAccent,
                value: _rateLimitOverride,
                onChanged: (val) => setState(() => _rateLimitOverride = val),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 3. Data Sovereignty & Integrations
class _SovereigntySettings extends ConsumerStatefulWidget {
  const _SovereigntySettings();

  @override
  ConsumerState<_SovereigntySettings> createState() => _SovereigntySettingsState();
}

class _SovereigntySettingsState extends ConsumerState<_SovereigntySettings> {
  bool _killSwitch = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Data Sovereignty & Integrations', style: _headerStyle),
        const SizedBox(height: 8),
        Text('Manage the MCP (Model Context Protocol) connection to legacy ERPs.', style: _bodyStyle),
        const SizedBox(height: 32),

        _SectionCard(
          title: 'Master MCP Kill-Switch',
          borderColor: _kDanger.withValues(alpha: 0.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: _kDanger, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Terminate localized MCP Container Connection', 
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text('Instantly cut off all data pipelines to Oracle/SAP ERPs. Requires re-authentication to resume.', 
                          style: _bodyStyle),
                      ],
                    ),
                  ),
                  Switch(
                    value: _killSwitch,
                    activeThumbColor: _kDanger,
                    onChanged: (val) => setState(() => _killSwitch = val),
                  )
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _SectionCard(
          title: 'Universal Filter Rules (Pydantic Stripper)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Specify exact data keys strictly stripped from outgoing telemetry payloads.', style: _bodyStyle),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: _kTileBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                child: const TextField(
                  style: TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g., pricing, internal_margins, supplier_ids',
                    hintStyle: TextStyle(color: Colors.white38),
                    icon: Icon(Icons.code, color: Colors.white54, size: 20),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                children: [
                  _FilterChip(label: 'pricing'),
                  _FilterChip(label: 'internal_margins'),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  const _FilterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      backgroundColor: _kBg,
      side: const BorderSide(color: _kBorder),
      deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white54),
      onDeleted: () {},
    );
  }
}

// 4. Alerts & Predictive Engine Calibration
class _AlertsSettings extends ConsumerStatefulWidget {
  const _AlertsSettings();

  @override
  ConsumerState<_AlertsSettings> createState() => _AlertsSettingsState();
}

class _AlertsSettingsState extends ConsumerState<_AlertsSettings> {
  double _darkNodeThreshold = 85.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Alerts & Predictive Engine Calibration', style: _headerStyle),
        const SizedBox(height: 8),
        Text('Tune the sensitivity of the AI risk prediction engine.', style: _bodyStyle),
        const SizedBox(height: 32),

        _SectionCard(
          title: 'Macro-Environment Toggles',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subscribe to specific abstract risks for the side panel.', style: _bodyStyle),
              const SizedBox(height: 16),
              const _CheckboxRow(title: 'Geopolitical Shifts', value: true),
              const _CheckboxRow(title: 'Weather & Climate Anomalies', value: true),
              const _CheckboxRow(title: 'Financial Signals & Commodities', value: false),
              const _CheckboxRow(title: 'Social Media Sentiment', value: false),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _SectionCard(
          title: 'Dark Node Thresholds',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set the acceptable risk score limit (0-100) that triggers an automated conversational Magic Link "ping" to silent suppliers.', style: _bodyStyle),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _darkNodeThreshold,
                      min: 0,
                      max: 100,
                      activeColor: _kAccent,
                      inactiveColor: _kBorder,
                      onChanged: (val) => setState(() => _darkNodeThreshold = val),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kTileBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Text('${_darkNodeThreshold.toInt()}% Risk', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckboxRow extends StatefulWidget {
  final String title;
  final bool value;
  const _CheckboxRow({required this.title, required this.value});

  @override
  State<_CheckboxRow> createState() => _CheckboxRowState();
}

class _CheckboxRowState extends State<_CheckboxRow> {
  late bool _val;
  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      value: _val,
      activeColor: _kTeal,
      checkColor: _kBg,
      onChanged: (v) => setState(() => _val = v ?? false),
    );
  }
}

// 5. Community & Template Privacy
class _CommunitySettings extends ConsumerWidget {
  const _CommunitySettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Community & Template Privacy', style: _headerStyle),
        const SizedBox(height: 8),
        Text('Manage your organization\'s published supply chain setups.', style: _bodyStyle),
        const SizedBox(height: 32),

        _SectionCard(
          title: 'Published Templates',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard for supply chain setups published to the "Community-Driven Quick Setup" marketplace.', style: _bodyStyle),
              const SizedBox(height: 24),
              
              // Mock Template Item
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kTileBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Global EV Battery Sourcing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('Published: 2 weeks ago • 142 Forks', style: _bodyStyle.copyWith(fontSize: 12)),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _kBorder),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Update'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _kDanger.withValues(alpha: 0.5)),
                            foregroundColor: _kDanger,
                          ),
                          child: const Text('Unpublish'),
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}

// Shared Section Card Helper
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? borderColor;

  const _SectionCard({required this.title, required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _subHeaderStyle),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kPanelBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor ?? _kBorder, width: 1),
          ),
          child: child,
        ),
      ],
    );
  }
}
