import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/disruption_models.dart';
import '../services/api_client.dart';
import 'canvas_provider.dart' show kFrontendDefaultOrgId;

// ---------------------------------------------------------------------------
// Disruption alerts — Supabase Realtime stream from disruption_alerts table.
// Filtered by the default org ID. Yields a fresh list on every DB insert.
// ---------------------------------------------------------------------------

final disruptionAlertsStreamProvider = StreamProvider<List<DisruptionAlert>>((ref) {
  final supabase = Supabase.instance.client;

  return supabase
      .from('disruption_alerts')
      .stream(primaryKey: ['id'])
      .eq('organization_id', kFrontendDefaultOrgId)
      .order('created_at', ascending: false)
      .map((rows) => rows
          .map((row) => DisruptionAlert.fromJson(row))
          .toList());
});

// ---------------------------------------------------------------------------
// Active disruption alerts for a specific node UUID (already-converted UUID).
// ---------------------------------------------------------------------------

final alertsForNodeProvider = Provider.family<List<DisruptionAlert>, String>(
  (ref, nodeUuid) {
    final alertsAsync = ref.watch(disruptionAlertsStreamProvider);
    return alertsAsync.when(
      data: (alerts) => alerts.where((a) => a.nodeId == nodeUuid).toList(),
      loading: () => [],
      error: (_, __) => [],
    );
  },
);

// ---------------------------------------------------------------------------
// Macro-environment signals — one-shot HTTP fetch from backend.
// ---------------------------------------------------------------------------

final macroSignalsProvider = FutureProvider<List<MacroEnvSignalResponse>>((ref) async {
  final client = ref.read(apiClientProvider);
  try {
    return await client.getMacroSignals(kFrontendDefaultOrgId);
  } catch (_) {
    return [];
  }
});
