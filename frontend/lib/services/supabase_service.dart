import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Singleton instance
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  // Expose the Supabase client
  final SupabaseClient client = Supabase.instance.client;

  // Real-time getters, auth wrappers, and Database queries can be added here
  
  Future<void> signUp(String email, String password) async {
    await client.auth.signUp(email: email, password: password);
  }

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // --- Canvas Data Methods ---

  Future<List<Map<String, dynamic>>> fetchSupplyChainNodes(String organizationId) async {
    final response = await client
        .from('supply_chain_nodes')
        .select()
        .eq('organization_id', organizationId)
        .isFilter('deleted_at', null);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchNodeEdges(String organizationId) async {
    final response = await client
        .from('node_edges')
        .select()
        .eq('organization_id', organizationId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateNodePosition(String nodeId, double x, double y) async {
    await client
        .from('supply_chain_nodes')
        .update({'ui_x': x, 'ui_y': y})
        .eq('id', nodeId);
  }

  // Set up a Realtime subscription to the nodes table for the org
  RealtimeChannel streamNodes(String organizationId, void Function(PostgresChangePayload payload) onData) {
    final channel = client.channel('public:supply_chain_nodes:org_$organizationId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'supply_chain_nodes',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'organization_id',
        value: organizationId,
      ),
      callback: onData,
    ).subscribe();
    return channel;
  }

  // Set up a Realtime subscription to the edges table for the org
  RealtimeChannel streamEdges(String organizationId, void Function(PostgresChangePayload payload) onData) {
    final channel = client.channel('public:node_edges:org_$organizationId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'node_edges',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'organization_id',
        value: organizationId,
      ),
      callback: onData,
    ).subscribe();
    return channel;
  }
}
