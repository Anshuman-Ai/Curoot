import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NodeStatus { active, pending, delayed }
enum NodeType { oem, add, factory, supplier }

/// Default organisation UUID used throughout when no auth-scoped org is available.
const String kFrontendDefaultOrgId = '00000000-0000-0000-0000-000000000000';

/// Converts an arbitrary node string id to a deterministic, valid UUID string.
/// This lets us call backend endpoints (which require UUIDs) from mock-id nodes.
String nodeIdToUuid(String id) {
  // Simple deterministic hash → UUID v4-like string
  final code = id.codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7FFFFFFF);
  final hex = code.toRadixString(16).padLeft(8, '0');
  return '${hex.substring(0, 8)}-0000-4000-8000-${hex.padRight(12, '0').substring(0, 12)}';
}

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

  CanvasState({
    required this.nodes,
    required this.edges,
    this.selectedNodeId,
  });

  CanvasState copyWith({
    List<CanvasNode>? nodes,
    List<CanvasEdge>? edges,
    String? selectedNodeId,
  }) {
    return CanvasState(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      selectedNodeId: selectedNodeId ?? this.selectedNodeId,
    );
  }
}

class CanvasNotifier extends Notifier<CanvasState> {
  @override
  CanvasState build() {
    return CanvasState(
      selectedNodeId: 'add',
      nodes: [
        CanvasNode(
          id: 'you',
          label: 'You',
          type: NodeType.oem,
          status: NodeStatus.active,
          position: const Offset(5000, 5000),
        ),
        CanvasNode(
          id: 'supplier_taiwan',
          label: 'Taiwan Supplier',
          type: NodeType.supplier,
          status: NodeStatus.delayed, // triggers the critical state visualization indirectly if needed
          position: const Offset(4800, 5100),
        ),
        CanvasNode(
          id: 'enterprise_a',
          label: 'Enterprise A..',
          type: NodeType.supplier,
          status: NodeStatus.active,
          position: const Offset(4800, 4850),
        ),
        CanvasNode(
          id: 'enterprise_b',
          label: 'Enterprise B..',
          type: NodeType.factory,
          status: NodeStatus.pending,
          position: const Offset(5200, 4850),
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
        CanvasEdge(id: 'e2', sourceId: 'supplier_taiwan', targetId: 'you'),
      ],
    );
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

  void selectNode(String? id) {
    state = state.copyWith(selectedNodeId: id);
  }
}

final canvasProvider = NotifierProvider<CanvasNotifier, CanvasState>(() {
  return CanvasNotifier();
});
