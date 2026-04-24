import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

enum NodeStatus { active, pending, delayed, offline }
enum NodeType { oem, add, factory, supplier }

/// Canvas filter modes
enum CanvasFilter { all, active, delayed, offline, suppliers, factories }

/// Default organisation UUID used throughout when no auth-scoped org is available.
const String kFrontendDefaultOrgId = '00000000-0000-0000-0000-000000000000';

/// Converts an arbitrary node string id to a deterministic, valid UUID string.
/// This lets us call backend endpoints (which require UUIDs) from mock-id nodes.
String nodeIdToUuid(String id) {
  // If already a valid UUID, return as-is
  if (_uuidRegex.hasMatch(id)) return id;
  // Simple deterministic hash → UUID v4-like string
  final code = id.codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7FFFFFFF);
  final hex = code.toRadixString(16).padLeft(8, '0');
  return '${hex.substring(0, 8)}-0000-4000-8000-${hex.padRight(12, '0').substring(0, 12)}';
}

/// Regex for a valid UUID v4-like string.
final _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Returns true if [id] is a valid UUID string (not a mock/local ID).
bool isValidUuid(String id) => _uuidRegex.hasMatch(id);

class CanvasNode {
  final String id;
  final String label;
  final NodeType type;
  final NodeStatus status;
  final Offset position;
  final bool isDarkNode;
  final double heartbeatConfidence;
  final String? lastHeartbeatAt;
  final Map<String, dynamic>? abstractedPayload;
  final double? cascadeDelayHours;

  CanvasNode({
    required this.id,
    required this.label,
    required this.type,
    required this.status,
    required this.position,
    this.isDarkNode = false,
    this.heartbeatConfidence = 1.0,
    this.lastHeartbeatAt,
    this.abstractedPayload,
    this.cascadeDelayHours,
  });

  CanvasNode copyWith({
    String? id,
    String? label,
    NodeType? type,
    NodeStatus? status,
    Offset? position,
    bool? isDarkNode,
    double? heartbeatConfidence,
    String? lastHeartbeatAt,
    Map<String, dynamic>? abstractedPayload,
    double? cascadeDelayHours,
  }) {
    return CanvasNode(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      status: status ?? this.status,
      position: position ?? this.position,
      isDarkNode: isDarkNode ?? this.isDarkNode,
      heartbeatConfidence: heartbeatConfidence ?? this.heartbeatConfidence,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      abstractedPayload: abstractedPayload ?? this.abstractedPayload,
      cascadeDelayHours: cascadeDelayHours ?? this.cascadeDelayHours,
    );
  }
}

class CanvasEdge {
  final String id;
  final String sourceId;
  final String targetId;

  CanvasEdge({
    required this.id,
    required this.sourceId,
    required this.targetId,
  });
}

class CanvasState {
  final List<CanvasNode> nodes;
  final List<CanvasEdge> edges;
  final String? selectedNodeId;
  final bool isLoading;
  final CanvasFilter filter;

  CanvasState({
    required this.nodes,
    required this.edges,
    this.selectedNodeId,
    this.isLoading = false,
    this.filter = CanvasFilter.all,
  });

  CanvasState copyWith({
    List<CanvasNode>? nodes,
    List<CanvasEdge>? edges,
    String? selectedNodeId,
    bool? isLoading,
    CanvasFilter? filter,
  }) {
    return CanvasState(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      selectedNodeId: selectedNodeId ?? this.selectedNodeId,
      isLoading: isLoading ?? this.isLoading,
      filter: filter ?? this.filter,
    );
  }

  /// Returns nodes filtered by current filter mode.
  List<CanvasNode> get filteredNodes {
    switch (filter) {
      case CanvasFilter.all:
        return nodes;
      case CanvasFilter.active:
        return nodes.where((n) =>
            n.status == NodeStatus.active || n.id == 'you' || n.id == 'add').toList();
      case CanvasFilter.delayed:
        return nodes.where((n) =>
            n.status == NodeStatus.delayed || n.id == 'you' || n.id == 'add').toList();
      case CanvasFilter.offline:
        return nodes.where((n) =>
            n.status == NodeStatus.offline || n.isDarkNode || n.id == 'you' || n.id == 'add').toList();
      case CanvasFilter.suppliers:
        return nodes.where((n) =>
            n.type == NodeType.supplier || n.id == 'you' || n.id == 'add').toList();
      case CanvasFilter.factories:
        return nodes.where((n) =>
            n.type == NodeType.factory || n.type == NodeType.oem || n.id == 'you' || n.id == 'add').toList();
    }
  }

  /// Returns edges where both endpoints are in filtered nodes.
  List<CanvasEdge> get filteredEdges {
    final visibleIds = filteredNodes.map((n) => n.id).toSet();
    return edges.where((e) =>
        visibleIds.contains(e.sourceId) && visibleIds.contains(e.targetId)).toList();
  }
}

class CanvasNotifier extends Notifier<CanvasState> {
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _edgesRealtimeChannel;
  RealtimeChannel? _heartbeatChannel;
  Timer? _debounce;

  @override
  CanvasState build() {
    ref.onDispose(() {
      _realtimeChannel?.unsubscribe();
      _edgesRealtimeChannel?.unsubscribe();
      _heartbeatChannel?.unsubscribe();
      _debounce?.cancel();
    });

    // Keep 'You' and 'Add' as defaults
    final initialState = CanvasState(
      selectedNodeId: 'add',
      isLoading: true,
      nodes: [
        CanvasNode(
          id: 'you',
          label: 'You',
          type: NodeType.oem,
          status: NodeStatus.active,
          position: const Offset(5000, 5000),
        ),
        CanvasNode(
          id: 'add',
          label: 'Add',
          type: NodeType.add,
          status: NodeStatus.pending,
          position: const Offset(5250, 5000),
        ),
      ],
      edges: [
        CanvasEdge(id: 'e1', sourceId: 'you', targetId: 'add'),
      ],
    );

    _initData();
    return initialState;
  }

  // ── Filter ────────────────────────────────────────────────────────────
  void setFilter(CanvasFilter filter) {
    state = state.copyWith(filter: filter);
  }

  Future<void> _initData() async {
    try {
      final supabase = SupabaseService();
      
      // Fetch nodes and edges for the 1-Hop environment
      final nodesData = await supabase.fetchSupplyChainNodes(kFrontendDefaultOrgId);
      final edgesData = await supabase.fetchNodeEdges(kFrontendDefaultOrgId);

      // Track which nodes have NO saved position (need auto-layout)
      final needsLayout = <String>{};

      final fetchedNodes = nodesData.map((n) {
        final bool hasSavedPos = n['ui_x'] != null && n['ui_y'] != null;
        final double x = n['ui_x']?.toDouble() ?? 5000.0;
        final double y = n['ui_y']?.toDouble() ?? 5000.0;
        final bool isDark = n['is_dark_node'] == true;
        final double hbConf = (n['heartbeat_confidence'] ?? 1.0).toDouble();
        final nodeId = n['id'].toString();
        
        if (!hasSavedPos) needsLayout.add(nodeId);

        return CanvasNode(
          id: nodeId,
          label: n['name'] ?? 'Unknown Node',
          type: _parseNodeType(n['node_type']),
          status: isDark ? NodeStatus.offline : _parseNodeStatus(n['status']),
          position: Offset(x, y),
          isDarkNode: isDark,
          heartbeatConfidence: hbConf,
          lastHeartbeatAt: n['last_heartbeat_at']?.toString(),
          abstractedPayload: n['abstracted_payload'],
          cascadeDelayHours: (n['cascade_delay_hours'] as num?)?.toDouble(),
        );
      }).toList();

      final fetchedEdges = edgesData.map((e) {
        return CanvasEdge(
          id: e['id'].toString(),
          sourceId: e['source_node_id'].toString(),
          targetId: e['target_node_id'].toString(),
        );
      }).toList();

      // Merge fetched with default nodes
      var mergedNodes = [...state.nodes, ...fetchedNodes];
      var mergedEdges = [...state.edges, ...fetchedEdges];

      // ── Auto-connect: create edges from 'you' to root nodes ──────────
      // A "root node" is any DB node that has no inbound edge from another DB node.
      final allTargetIds = mergedEdges.map((e) => e.targetId).toSet();
      for (final node in fetchedNodes) {
        // Skip if this node already has an inbound edge
        if (allTargetIds.contains(node.id)) continue;
        // Create synthetic edge from 'you' to this root node
        final synEdgeId = 'auto-you-${node.id}';
        if (!mergedEdges.any((e) => e.id == synEdgeId)) {
          mergedEdges.add(CanvasEdge(
            id: synEdgeId,
            sourceId: 'you',
            targetId: node.id,
          ));
        }
      }

      // ── Hierarchical Radial Layout for unpositioned nodes ────────────
      if (needsLayout.isNotEmpty) {
        mergedNodes = _applyRadialLayout(mergedNodes, mergedEdges, needsLayout);
      }

      // ── Collision avoidance pass ─────────────────────────────────────
      mergedNodes = _resolveCollisions(mergedNodes);

      state = state.copyWith(
        nodes: mergedNodes,
        edges: mergedEdges,
        isLoading: false,
      );

      // Setup Realtime for nodes
      _realtimeChannel = supabase.streamNodes(kFrontendDefaultOrgId, _handleRealtimeUpdate);

      // Setup Realtime for edges (so Cold Start / ingestion edges appear live)
      _edgesRealtimeChannel = supabase.streamEdges(kFrontendDefaultOrgId, _handleEdgeRealtimeUpdate);

      // Setup Realtime for heartbeat updates (Module 2.7)
      _heartbeatChannel = supabase.streamHeartbeat(
        kFrontendDefaultOrgId,
        _handleHeartbeatUpdate,
        _handleOemDispatch,
        _handleAutoPing,
      );
    } catch (e) {
      debugPrint('Error initializing canvas data: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Hierarchical Radial Layout Algorithm
  // ═══════════════════════════════════════════════════════════════════════

  /// Arranges unpositioned nodes in concentric rings using BFS from 'you'.
  /// Tier 1 = directly connected to 'you' → ring at 280px
  /// Tier 2 = connected to Tier 1 nodes  → ring at 500px
  /// Tier N = further                     → ring at 280 + (N-1)*220
  List<CanvasNode> _applyRadialLayout(
    List<CanvasNode> nodes,
    List<CanvasEdge> edges,
    Set<String> needsLayout,
  ) {
    const center = Offset(5000, 5000);
    const baseRadius = 280.0;
    const ringGap = 220.0;
    
    // Build adjacency from edges (undirected for layout purposes)
    final adj = <String, Set<String>>{};
    for (final e in edges) {
      adj.putIfAbsent(e.sourceId, () => {}).add(e.targetId);
      adj.putIfAbsent(e.targetId, () => {}).add(e.sourceId);
    }

    // BFS from 'you' to determine tiers
    final tiers = <String, int>{};
    final queue = <String>['you'];
    tiers['you'] = 0;
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentTier = tiers[current]!;
      for (final neighbor in (adj[current] ?? <String>{})) {
        if (!tiers.containsKey(neighbor) && neighbor != 'add') {
          tiers[neighbor] = currentTier + 1;
          queue.add(neighbor);
        }
      }
    }

    // Assign unconnected nodes to tier 1 (they'll be connected via auto-edges)
    for (final node in nodes) {
      if (!tiers.containsKey(node.id) && node.id != 'add' && needsLayout.contains(node.id)) {
        tiers[node.id] = 1;
      }
    }

    // Group by tier
    final tierGroups = <int, List<String>>{};
    for (final entry in tiers.entries) {
      if (entry.value == 0) continue; // skip 'you'
      tierGroups.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    // Position each tier in a ring
    final posMap = <String, Offset>{};
    for (final entry in tierGroups.entries) {
      final tier = entry.key;
      final ids = entry.value;
      final radius = baseRadius + (tier - 1) * ringGap;
      final angleStep = (2 * pi) / ids.length;
      // Start from top (-pi/2) and go clockwise
      const startAngle = -pi / 2;
      for (int i = 0; i < ids.length; i++) {
        final angle = startAngle + angleStep * i;
        posMap[ids[i]] = Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        );
      }
    }

    // Place 'add' node to the right of 'you'
    posMap['add'] = Offset(center.dx + 160, center.dy);

    // Apply positions to nodes that need layout
    return nodes.map((n) {
      if (needsLayout.contains(n.id) && posMap.containsKey(n.id)) {
        return n.copyWith(position: posMap[n.id]);
      }
      if (n.id == 'add' && posMap.containsKey('add')) {
        return n.copyWith(position: posMap['add']);
      }
      return n;
    }).toList();
  }

  /// Push apart any two nodes closer than minDistance.
  List<CanvasNode> _resolveCollisions(List<CanvasNode> nodes, {double minDistance = 120.0}) {
    final positions = {for (final n in nodes) n.id: n.position};
    const iterations = 5;
    for (int iter = 0; iter < iterations; iter++) {
      for (int i = 0; i < nodes.length; i++) {
        for (int j = i + 1; j < nodes.length; j++) {
          final a = nodes[i].id;
          final b = nodes[j].id;
          // Don't push 'you' — it's the anchor
          if (a == 'you' || b == 'you') continue;
          final pa = positions[a]!;
          final pb = positions[b]!;
          final dx = pb.dx - pa.dx;
          final dy = pb.dy - pa.dy;
          final dist = sqrt(dx * dx + dy * dy);
          if (dist < minDistance && dist > 0) {
            final overlap = (minDistance - dist) / 2;
            final nx = dx / dist;
            final ny = dy / dist;
            positions[a] = Offset(pa.dx - nx * overlap, pa.dy - ny * overlap);
            positions[b] = Offset(pb.dx + nx * overlap, pb.dy + ny * overlap);
          }
        }
      }
    }
    return nodes.map((n) => n.copyWith(position: positions[n.id])).toList();
  }

  /// Re-run layout on all DB nodes (triggered by auto-organize button).
  void autoOrganize() {
    final dbNodeIds = state.nodes
        .where((n) => n.id != 'you' && n.id != 'add')
        .map((n) => n.id)
        .toSet();
    var organized = _applyRadialLayout(state.nodes, state.edges, dbNodeIds);
    organized = _resolveCollisions(organized);
    state = state.copyWith(nodes: organized);
    // Save new positions for all DB nodes
    for (final n in organized) {
      if (isValidUuid(n.id)) {
        saveNodePosition(n.id, n.position);
      }
    }
  }

  void _handleRealtimeUpdate(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.insert || payload.eventType == PostgresChangeEvent.update) {
      final data = payload.newRecord;
      final id = data['id'].toString();
      final double x = data['ui_x']?.toDouble() ?? 5000.0;
      final double y = data['ui_y']?.toDouble() ?? 4800.0;
      final bool isDark = data['is_dark_node'] == true;
      final double hbConf = (data['heartbeat_confidence'] ?? 1.0).toDouble();
      
      final updatedNode = CanvasNode(
        id: id,
        label: data['name'] ?? 'Unknown',
        type: _parseNodeType(data['node_type']),
        status: isDark ? NodeStatus.offline : _parseNodeStatus(data['status']),
        position: Offset(x, y),
        isDarkNode: isDark,
        heartbeatConfidence: hbConf,
        lastHeartbeatAt: data['last_heartbeat_at']?.toString(),
        abstractedPayload: data['abstracted_payload'],
        cascadeDelayHours: (data['cascade_delay_hours'] as num?)?.toDouble(),
      );

      final exists = state.nodes.any((n) => n.id == id);
      if (exists) {
        state = state.copyWith(
          nodes: state.nodes.map((n) => n.id == id ? updatedNode : n).toList(),
        );
      } else {
        state = state.copyWith(nodes: [...state.nodes, updatedNode]);
      }
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      final id = payload.oldRecord['id'].toString();
      state = state.copyWith(
        nodes: state.nodes.where((n) => n.id != id).toList(),
      );
    }
  }

  // --- Module 2.7: Heartbeat Realtime handlers ---

  void _handleHeartbeatUpdate(dynamic payload) {
    final data = payload is Map ? payload : {};
    final nodeId = data['node_id']?.toString() ?? '';
    if (nodeId.isEmpty) return;
    final newStatus = _parseNodeStatus(data['status']?.toString());
    state = state.copyWith(
      nodes: state.nodes.map((n) {
        if (n.id == nodeId) {
          return n.copyWith(
            status: newStatus,
            isDarkNode: false,
            heartbeatConfidence: 1.0,
          );
        }
        return n;
      }).toList(),
    );
  }

  void _handleOemDispatch(dynamic payload) {
    // OEM dispatch — no visual change needed, chat panel handles it
    debugPrint('[Heartbeat] OEM dispatch received: $payload');
  }

  void _handleAutoPing(dynamic payload) {
    final data = payload is Map ? payload : {};
    final pingedIds = List<String>.from(data['pinged_node_ids'] ?? []);
    if (pingedIds.isEmpty) return;
    debugPrint('[Heartbeat] Auto-ping sent to: $pingedIds');
  }

  NodeType _parseNodeType(String? type) {
    switch (type?.toLowerCase()) {
      case 'factory': return NodeType.factory;
      case 'supplier': return NodeType.supplier;
      default: return NodeType.supplier;
    }
  }

  NodeStatus _parseNodeStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'operational':
        return NodeStatus.active;
      case 'pending': return NodeStatus.pending;
      case 'delayed': return NodeStatus.delayed;
      case 'offline': return NodeStatus.offline;
      default: return NodeStatus.pending;
    }
  }

  void _handleEdgeRealtimeUpdate(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.insert) {
      final data = payload.newRecord;
      final edge = CanvasEdge(
        id: data['id'].toString(),
        sourceId: data['source_node_id'].toString(),
        targetId: data['target_node_id'].toString(),
      );
      if (!state.edges.any((e) => e.id == edge.id)) {
        state = state.copyWith(edges: [...state.edges, edge]);
      }
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      final id = payload.oldRecord['id'].toString();
      state = state.copyWith(
        edges: state.edges.where((e) => e.id != id).toList(),
      );
    }
  }

  void updateNodePosition(String id, Offset newPosition) {
    state = state.copyWith(
      nodes: state.nodes.map((n) {
        if (n.id == id) {
          return n.copyWith(position: newPosition);
        }
        return n;
      }).toList(),
    );
  }

  void saveNodePosition(String id, Offset newPosition) {
    // Only save if it's a real DB node (valid UUID), not local or ingestion-temp IDs
    if (id == 'you' || id == 'add') return;
    if (!isValidUuid(id)) return; // Skip non-UUID IDs (e.g. "EXTRACTED-NODE-01")

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await SupabaseService().updateNodePosition(id, newPosition.dx, newPosition.dy);
      } catch (e) {
        debugPrint('Failed to save node position: $e');
      }
    });
  }

  void updateNodeStatus(String id, NodeStatus newStatus) {
    state = state.copyWith(
      nodes: state.nodes.map((n) {
        if (n.id == id) {
          return n.copyWith(status: newStatus);
        }
        return n;
      }).toList(),
    );
  }

  void addNode(CanvasNode node) {
    if (!state.nodes.any((n) => n.id == node.id)) {
      state = state.copyWith(nodes: [...state.nodes, node]);
    }
  }

  void addEdge(CanvasEdge edge) {
    if (!state.edges.any((e) => e.id == edge.id)) {
      state = state.copyWith(edges: [...state.edges, edge]);
    }
  }

  /// Batch-add nodes and edges from an Omni Ingestion API response.
  /// Uses hierarchical radial layout and auto-connects to 'You'.
  void addNodesFromIngestion(
    List<Map<String, dynamic>> rawNodes,
    List<Map<String, dynamic>> rawEdges,
  ) {
    final existingIds = state.nodes.map((n) => n.id).toSet();

    final newNodes = <CanvasNode>[];
    final newNodeIds = <String>{};
    for (int i = 0; i < rawNodes.length; i++) {
      final n = rawNodes[i];
      final id = (n['id'] ?? n['node_id'] ?? '').toString();
      if (id.isEmpty || existingIds.contains(id)) continue;

      newNodes.add(CanvasNode(
        id: id,
        label: n['name'] ?? 'Node',
        type: _parseNodeType(n['type'] ?? n['node_type']),
        status: NodeStatus.pending,
        position: const Offset(5000, 5000), // Placeholder; layout will fix
      ));
      newNodeIds.add(id);
    }

    final newEdges = <CanvasEdge>[];
    final existingEdgeIds = state.edges.map((e) => e.id).toSet();
    for (final e in rawEdges) {
      final id = (e['id'] ?? '').toString();
      if (id.isEmpty || existingEdgeIds.contains(id)) continue;
      newEdges.add(CanvasEdge(
        id: id,
        sourceId: (e['source_node_id'] ?? '').toString(),
        targetId: (e['target_node_id'] ?? '').toString(),
      ));
    }

    if (newNodes.isEmpty && newEdges.isEmpty) return;

    var mergedNodes = [...state.nodes, ...newNodes];
    var mergedEdges = [...state.edges, ...newEdges];

    // Auto-connect root nodes to 'you'
    final allTargetIds = mergedEdges.map((e) => e.targetId).toSet();
    for (final node in newNodes) {
      if (!allTargetIds.contains(node.id)) {
        final synEdgeId = 'auto-you-${node.id}';
        mergedEdges.add(CanvasEdge(id: synEdgeId, sourceId: 'you', targetId: node.id));
      }
    }

    // Apply layout to new nodes only
    mergedNodes = _applyRadialLayout(mergedNodes, mergedEdges, newNodeIds);
    mergedNodes = _resolveCollisions(mergedNodes);

    state = state.copyWith(
      nodes: mergedNodes,
      edges: mergedEdges,
    );
  }

  void selectNode(String? id) {
    state = state.copyWith(selectedNodeId: id);
  }
}

final canvasProvider = NotifierProvider<CanvasNotifier, CanvasState>(() {
  return CanvasNotifier();
});
