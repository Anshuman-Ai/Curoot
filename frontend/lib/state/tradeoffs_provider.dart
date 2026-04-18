import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tradeoff_models.dart';
import '../services/api_client.dart';
import 'canvas_provider.dart';

// ---------------------------------------------------------------------------
// Tradeoff compute — calls POST /api/v1/tradeoffs/compute.
// Key: map of {current_node_id, alternative_node_id} (frontend string ids).
// ---------------------------------------------------------------------------

final tradeoffProvider = FutureProvider.family<TradeoffAnalysisResponse, Map<String, String>>(
  (ref, params) async {
    final apiClient = ref.read(apiClientProvider);
    final currentNodeId  = params['current_node_id']!;
    final alternativeNodeId = params['alternative_node_id']!;

    // Map frontend mock string IDs → deterministic UUIDs the backend accepts
    final request = TradeoffRequest(
      currentNodeId: nodeIdToUuid(currentNodeId),
      alternativeNodeId: nodeIdToUuid(alternativeNodeId),
      orgId: kFrontendDefaultOrgId,
      // Use a fixed sentinel alert ID. In production, the real alert UUID
      // is passed in from the disruption broadcast payload.
      disruptionAlertId: '00000000-0000-0000-0000-000000000001',
    );

    return apiClient.computeTradeoffs(request);
  },
);
