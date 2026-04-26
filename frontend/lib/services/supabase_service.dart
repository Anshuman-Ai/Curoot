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

  // --- Module 2.5: Disruption Alerts (L2 fix — live push instead of polling) ---

  /// Subscribe to disruption alert broadcasts for the org's canvas
  RealtimeChannel streamDisruptionAlerts(
    String organizationId,
    void Function(dynamic payload) onDisruptionAlert,
    void Function(dynamic payload) onMacroUpdate,
    void Function(dynamic payload) onUpstreamAlert,
  ) {
    final alertChannel = client.channel('org:$organizationId:alerts');
    alertChannel
      .onBroadcast(event: 'disruption_alert', callback: onDisruptionAlert)
      .subscribe();

    final macroChannel = client.channel('org:$organizationId:macro-panel');
    macroChannel
      .onBroadcast(event: 'macro_update', callback: onMacroUpdate)
      .subscribe();

    final upstreamChannel = client.channel('org:$organizationId:upstream-alerts');
    upstreamChannel
      .onBroadcast(event: 'upstream_alert', callback: onUpstreamAlert)
      .subscribe();

    return alertChannel; // Primary channel returned for lifecycle management
  }

  // --- Module 2.7: Heartbeat ---

  /// Subscribe to the org's heartbeat broadcast channel for live chat updates
  RealtimeChannel streamHeartbeat(
    String organizationId,
    void Function(dynamic payload) onHeartbeat,
    void Function(dynamic payload) onOemDispatch,
    void Function(dynamic payload) onAutoPing,
  ) {
    final channelName = 'org:$organizationId:heartbeat';
    final channel = client.channel(channelName);
    channel
      .onBroadcast(event: 'heartbeat_update', callback: onHeartbeat)
      .onBroadcast(event: 'oem_dispatch', callback: onOemDispatch)
      .onBroadcast(event: 'auto_ping_sent', callback: onAutoPing)
      .subscribe();
    return channel;
  }

  /// Subscribe to messages table changes for a specific node (chat updates)
  RealtimeChannel streamMessages(
    String nodeId,
    void Function(PostgresChangePayload payload) onData,
  ) {
    final channel = client.channel('public:messages:node_$nodeId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'node_id',
        value: nodeId,
      ),
      callback: onData,
    ).subscribe();
    return channel;
  }

  /// Fetch chat history for a specific node
  Future<List<Map<String, dynamic>>> fetchChatHistory(String nodeId, {int limit = 50}) async {
    final response = await client
        .from('messages')
        .select('id, content, message_type, parsed_data, parse_confidence, created_at')
        .eq('node_id', nodeId)
        .order('created_at', ascending: true)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetch dark nodes for an organisation
  Future<List<Map<String, dynamic>>> fetchDarkNodes(String organizationId) async {
    final response = await client
        .from('supply_chain_nodes')
        .select('id, name, status, is_dark_node, heartbeat_confidence, last_heartbeat_at, volume_weight')
        .eq('organization_id', organizationId)
        .eq('is_dark_node', true)
        .isFilter('deleted_at', null);
    return List<Map<String, dynamic>>.from(response);
  }
}
