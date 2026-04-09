import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NodeStatus { active, pending, delayed }
enum NodeType { oem, add, factory, supplier }

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

  CanvasState({
    required this.nodes,
    required this.edges,
  });

  CanvasState copyWith({
    List<CanvasNode>? nodes,
    List<CanvasEdge>? edges,
  }) {
    return CanvasState(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
    );
  }
}

class CanvasNotifier extends Notifier<CanvasState> {
  @override
  CanvasState build() {
    return CanvasState(
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
}

final canvasProvider = NotifierProvider<CanvasNotifier, CanvasState>(() {
  return CanvasNotifier();
});
