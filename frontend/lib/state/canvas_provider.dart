import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

enum NodeStatus { active, pending, delayed, offline }
enum NodeType { oem, add, factory, supplier }

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

  CanvasNode({
    required this.id,
    required this.label,
    required this.type,
    required this.status,
    required this.position,
  });

  CanvasNode copyWith({
    String? id,
    String? label,
    NodeType? type,
    NodeStatus? status,
    Offset? position,
  }) {
    return CanvasNode(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      status: status ?? this.status,
      position: position ?? this.position,
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

  CanvasState({
    required this.nodes,
    required this.edges,
    this.selectedNodeId,
    this.isLoading = false,
  });

  CanvasState copyWith({
    List<CanvasNode>? nodes,
    List<CanvasEdge>? edges,
    String? selectedNodeId,
    bool? isLoading,
  }) {
    return CanvasState(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      selectedNodeId: selectedNodeId ?? this.selectedNodeId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CanvasNotifier extends Notifier<CanvasState> {
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _edgesRealtimeChannel;
  Timer? _debounce;

  @override
  CanvasState build() {
    ref.onDispose(() {
      _realtimeChannel?.unsubscribe();
      _edgesRealtimeChannel?.unsubscribe();
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

  Future<void> _initData() async {
    try {
      final supabase = SupabaseService();
      
      // Fetch nodes and edges for the 1-Hop environment
      final nodesData = await supabase.fetchSupplyChainNodes(kFrontendDefaultOrgId);
      final edgesData = await supabase.fetchNodeEdges(kFrontendDefaultOrgId);

      final fetchedNodes = nodesData.map((n) {
        // Fallback for unpositioned nodes is handled near the center (5000, 5000)
        final double x = n['ui_x']?.toDouble() ?? (5000.0 + (n['id'].hashCode % 200 - 100));
        final double y = n['ui_y']?.toDouble() ?? (4800.0 + (n['id'].hashCode % 200 - 100));
        
        return CanvasNode(
          id: n['id'].toString(),
          label: n['name'] ?? 'Unknown Node',
          type: _parseNodeType(n['node_type']),
          status: _parseNodeStatus(n['status']),
          position: Offset(x, y),
        );
      }).toList();

      final fetchedEdges = edgesData.map((e) {
        return CanvasEdge(
          id: e['id'].toString(),
          sourceId: e['source_node_id'].toString(),
          targetId: e['target_node_id'].toString(),
        );
      }).toList();

      // Merge fetched with default
      final mergedNodes = [...state.nodes, ...fetchedNodes];
      final mergedEdges = [...state.edges, ...fetchedEdges];

      state = state.copyWith(
        nodes: mergedNodes,
        edges: mergedEdges,
        isLoading: false,
      );

      // Setup Realtime for nodes
      _realtimeChannel = supabase.streamNodes(kFrontendDefaultOrgId, _handleRealtimeUpdate);

      // Setup Realtime for edges (so Cold Start / ingestion edges appear live)
      _edgesRealtimeChannel = supabase.streamEdges(kFrontendDefaultOrgId, _handleEdgeRealtimeUpdate);
    } catch (e) {
      debugPrint('Error initializing canvas data: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void _handleRealtimeUpdate(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.insert || payload.eventType == PostgresChangeEvent.update) {
      final data = payload.newRecord;
      final id = data['id'].toString();
      final double x = data['ui_x']?.toDouble() ?? 5000.0;
      final double y = data['ui_y']?.toDouble() ?? 4800.0;
      
      final updatedNode = CanvasNode(
        id: id,
        label: data['name'] ?? 'Unknown',
        type: _parseNodeType(data['node_type']),
        status: _parseNodeStatus(data['status']),
        position: Offset(x, y),
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
  /// Positions new nodes in a radial layout around 'You' if ui_x/ui_y absent.
  void addNodesFromIngestion(
    List<Map<String, dynamic>> rawNodes,
    List<Map<String, dynamic>> rawEdges,
  ) {
    final youNode = state.nodes.where((n) => n.id == 'you').firstOrNull;
    final center = youNode?.position ?? const Offset(5000, 5000);
    final rng = Random();
    final existingIds = state.nodes.map((n) => n.id).toSet();

    final newNodes = <CanvasNode>[];
    for (int i = 0; i < rawNodes.length; i++) {
      final n = rawNodes[i];
      final id = (n['id'] ?? n['node_id'] ?? '').toString();
      if (id.isEmpty || existingIds.contains(id)) continue;

      // Radial layout: spread around 'You' in a circle
      final angle = (2 * pi * i) / rawNodes.length;
      final radius = 180.0 + rng.nextDouble() * 40;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      newNodes.add(CanvasNode(
        id: id,
        label: n['name'] ?? 'Node',
        type: _parseNodeType(n['type'] ?? n['node_type']),
        status: NodeStatus.pending, // Always start as pending per SRS lifecycle
        position: Offset(x, y),
      ));
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

    if (newNodes.isNotEmpty || newEdges.isNotEmpty) {
      state = state.copyWith(
        nodes: [...state.nodes, ...newNodes],
        edges: [...state.edges, ...newEdges],
      );
    }
  }

  void selectNode(String? id) {
    state = state.copyWith(selectedNodeId: id);
  }
}

final canvasProvider = NotifierProvider<CanvasNotifier, CanvasState>(() {
  return CanvasNotifier();
});
