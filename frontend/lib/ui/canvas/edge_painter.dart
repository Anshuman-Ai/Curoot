import 'package:flutter/material.dart';
import '../../state/canvas_provider.dart';

class EdgePainter extends CustomPainter {
  final List<CanvasNode> nodes;
  final List<CanvasEdge> edges;

  EdgePainter({required this.nodes, required this.edges});

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final source = nodes.where((n) => n.id == edge.sourceId).firstOrNull;
      final target = nodes.where((n) => n.id == edge.targetId).firstOrNull;

      if (source != null && target != null) {
        // Find color based on target node status
        Color lineColor;
        switch (target.status) {
          case NodeStatus.active:
            lineColor = Colors.teal;
            break;
          case NodeStatus.pending:
            lineColor = Colors.white54;
            break;
          case NodeStatus.delayed:
            lineColor = Colors.redAccent;
            break;
        }

        final paint = Paint()
          ..color = lineColor
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

        final dx = target.position.dx - source.position.dx;
        
        final path = Path()
          ..moveTo(source.position.dx, source.position.dy)
          ..cubicTo(
            source.position.dx + dx * 0.5, source.position.dy,
            target.position.dx - dx * 0.5, target.position.dy,
            target.position.dx, target.position.dy,
          );

        _drawDashedCurve(canvas, path, paint);
      }
    }
  }

  void _drawDashedCurve(Canvas canvas, Path path, Paint basePaint) {
    // Draw Dashed line on top
    const double dashWidth = 8.0;
    const double dashSpace = 8.0;
    
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double length = dashWidth.clamp(0.0, metric.length - distance).toDouble();
        final extractPath = metric.extractPath(distance, distance + length);
        canvas.drawPath(extractPath, basePaint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant EdgePainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.edges != edges;
  }
}
