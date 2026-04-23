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

    // Guard: only call backend if BOTH node IDs are real Supabase UUIDs.
    // Local nodes ('you', 'add') and ingestion-temp IDs ('EXTRACTED-NODE-01')
    // produce fake deterministic UUIDs that don't exist in the DB.
    final currentUuid = nodeIdToUuid(currentNodeId);
    final altUuid = nodeIdToUuid(alternativeNodeId);

    if (!isValidUuid(currentNodeId) && !isValidUuid(currentUuid) ||
        !isValidUuid(alternativeNodeId) && !isValidUuid(altUuid)) {
      // Return a placeholder — the node hasn't synced to Supabase yet
      return TradeoffAnalysisResponse.placeholder(
        currentNodeId: currentUuid,
        alternativeNodeId: altUuid,
      );
    }

    // Map frontend mock string IDs → deterministic UUIDs the backend accepts
    final request = TradeoffRequest(
      currentNodeId: currentUuid,
      alternativeNodeId: altUuid,
      orgId: kFrontendDefaultOrgId,
      // Use a fixed sentinel alert ID. In production, the real alert UUID
      // is passed in from the disruption broadcast payload.
      disruptionAlertId: '00000000-0000-0000-0000-000000000001',
    );

    return apiClient.computeTradeoffs(request);
  },
);
