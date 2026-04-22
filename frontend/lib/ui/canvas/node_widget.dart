import 'package:flutter/material.dart';
import '../../state/canvas_provider.dart';

class NodeWidget extends StatelessWidget {
  final CanvasNode node;
  final VoidCallback? onTap;
  final GestureDragUpdateCallback? onPanUpdate;

  const NodeWidget({
    super.key,
    required this.node,
    this.onTap,
    this.onPanUpdate,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    double nodeOpacity = 1.0;
    
    switch (node.status) {
      case NodeStatus.active:
        statusColor = Colors.tealAccent;
        break;
      case NodeStatus.pending:
        statusColor = Colors.white54;
        nodeOpacity = 0.5; // Faded if unverified/pending
        break;
      case NodeStatus.delayed:
        statusColor = Colors.redAccent;
        break;
    }

    IconData nodeIcon;
    switch (node.type) {
      case NodeType.oem:
        nodeIcon = Icons.factory;
        break;
      case NodeType.add:
        nodeIcon = Icons.add;
        break;
      case NodeType.factory:
        nodeIcon = Icons.precision_manufacturing;
        break;
      case NodeType.supplier:
        nodeIcon = Icons.local_shipping;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      onPanUpdate: onPanUpdate,
      child: Opacity(
        opacity: nodeOpacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label above node
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A35), // Slight contrast
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (node.status == NodeStatus.pending)
                    const Padding(
                      padding: EdgeInsets.only(right: 6.0),
                      child: Icon(Icons.hourglass_empty, color: Colors.amber, size: 12),
                    ),
                  Text(
                    node.label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Node Box
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF22222A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.2),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  nodeIcon,
                  color: statusColor,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

