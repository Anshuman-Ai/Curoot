import 'dart:math';
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
        // Determine style based on target node status
        Color lineColor;
        double strokeW = 2.0;
        bool useDash = false;

        switch (target.status) {
          case NodeStatus.active:
            lineColor = Colors.teal;
            break;
          case NodeStatus.pending:
            lineColor = Colors.white54;
            useDash = true; // Dashed for unverified
            break;
          case NodeStatus.delayed:
            lineColor = Colors.redAccent;
            strokeW = 2.5;
            break;
          case NodeStatus.offline:
            lineColor = Colors.white24;
            useDash = true; // Dashed for dark/offline
            break;
        }

        // Override for abstracted upstream exception nodes
        if (target.abstractedPayload != null) {
          lineColor = Colors.orangeAccent;
          strokeW = 2.0;
          useDash = true;
        }

        final paint = Paint()
          ..color = lineColor
          ..strokeWidth = strokeW
          ..style = PaintingStyle.stroke;

        // Build cubic bezier path
        final dx = target.position.dx - source.position.dx;

        final path = Path()
          ..moveTo(source.position.dx, source.position.dy)
          ..cubicTo(
            source.position.dx + dx * 0.5, source.position.dy,
            target.position.dx - dx * 0.5, target.position.dy,
            target.position.dx, target.position.dy,
          );

        if (useDash) {
          _drawDashedCurve(canvas, path, paint);
        } else {
          canvas.drawPath(path, paint);
        }

        // Draw arrowhead at target
        _drawArrowhead(
          canvas, 
          source.position, 
          target.position, 
          lineColor, 
          strokeW,
        );
      }
    }
  }

  /// Draws a small triangular arrowhead at the target end of the edge.
  void _drawArrowhead(
    Canvas canvas,
    Offset source,
    Offset target,
    Color color,
    double strokeWidth,
  ) {
    const arrowSize = 10.0;
    final dx = target.dx - source.dx;
    final dy = target.dy - source.dy;
    final angle = atan2(dy, dx);

    // Pull back arrowhead slightly so it doesn't overlap the node
    final tipX = target.dx - cos(angle) * 28;
    final tipY = target.dy - sin(angle) * 28;

    final path = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(
        tipX - arrowSize * cos(angle - 0.4),
        tipY - arrowSize * sin(angle - 0.4),
      )
      ..lineTo(
        tipX - arrowSize * cos(angle + 0.4),
        tipY - arrowSize * sin(angle + 0.4),
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void _drawDashedCurve(Canvas canvas, Path path, Paint basePaint) {
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
