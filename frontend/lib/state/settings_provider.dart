import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveOrganizationIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setId(String? id) => state = id;
}

final activeOrganizationIdProvider = NotifierProvider<ActiveOrganizationIdNotifier, String?>(() {
  return ActiveOrganizationIdNotifier();
});

// Settings State Model
class OrganizationSettings {
  final String id;
  final String name;
  final int rfpTimeframeMonths;
  final bool rateLimitingEnabled;
  final bool mcpKillSwitchEngaged;
  final List<String> telemetryFilterKeys;
  final Map<String, bool> macroToggles;
  final double darkNodeRiskThreshold;

  OrganizationSettings({
    required this.id,
    required this.name,
    required this.rfpTimeframeMonths,
    required this.rateLimitingEnabled,
    required this.mcpKillSwitchEngaged,
    required this.telemetryFilterKeys,
    required this.macroToggles,
    required this.darkNodeRiskThreshold,
  });

  factory OrganizationSettings.fromJson(Map<String, dynamic> json) {
    return OrganizationSettings(
      id: json['id'] as String,
      name: json['name'] as String,
      rfpTimeframeMonths: json['rfp_timeframe_months'] as int? ?? 1,
      rateLimitingEnabled: json['rate_limiting_enabled'] as bool? ?? true,
      mcpKillSwitchEngaged: json['mcp_kill_switch_engaged'] as bool? ?? false,
      telemetryFilterKeys: List<String>.from(json['telemetry_filter_keys'] ?? []),
      macroToggles: Map<String, bool>.from(json['macro_toggles'] ?? {}),
      darkNodeRiskThreshold: (json['dark_node_risk_threshold'] as num?)?.toDouble() ?? 80.0,
    );
  }
}

// Fetch settings for the active organization
final organizationSettingsProvider = FutureProvider<OrganizationSettings?>((ref) async {
  final orgId = ref.watch(activeOrganizationIdProvider);
  if (orgId == null) return null;

  final supabase = Supabase.instance.client;
  
  // Note: All queries strictly enforce multi-tenant RLS by filtering by organization_id
  final response = await supabase
      .from('organizations')
      .select()
      .eq('id', orgId)
      .single();

  return OrganizationSettings.fromJson(response);
});

// Members Fetcher
final organizationMembersProvider = FutureProvider<List<dynamic>>((ref) async {
  final orgId = ref.watch(activeOrganizationIdProvider);
  if (orgId == null) return [];

  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('organization_members')
      .select('*, profiles(*)')
      .eq('organization_id', orgId);

  return response as List<dynamic>;
});

// User's Organizations (for Tenant Switcher)
final userOrganizationsProvider = FutureProvider<List<dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final response = await supabase
      .from('organization_members')
      .select('organization_id, organizations(*)')
      .eq('user_id', userId);

  return response as List<dynamic>;
});

// Community Templates
final organizationTemplatesProvider = FutureProvider<List<dynamic>>((ref) async {
  final orgId = ref.watch(activeOrganizationIdProvider);
  if (orgId == null) return [];

  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('community_templates')
      .select()
      .eq('organization_id', orgId);

  return response as List<dynamic>;
});
