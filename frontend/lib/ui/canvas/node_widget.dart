import 'package:flutter/material.dart';
import '../../state/canvas_provider.dart';

class NodeWidget extends StatefulWidget {
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
  State<NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends State<NodeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _updatePulse();
  }

  @override
  void didUpdateWidget(covariant NodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.status != widget.node.status) {
      _updatePulse();
    }
  }

  void _updatePulse() {
    if (widget.node.status == NodeStatus.delayed) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    double nodeOpacity = 1.0;
    IconData? statusIndicator;

    switch (widget.node.status) {
      case NodeStatus.active:
        statusColor = Colors.tealAccent;
        break;
      case NodeStatus.pending:
        statusColor = Colors.amber;
        nodeOpacity = 0.5; // Faded if unverified/pending (SRS §2.3)
        statusIndicator = Icons.hourglass_empty;
        break;
      case NodeStatus.delayed:
        statusColor = Colors.redAccent;
        break;
      case NodeStatus.offline:
        statusColor = const Color(0xFF555555);
        nodeOpacity = 0.30; // Dark Node — very faded (SRS §2.7.3)
        statusIndicator = Icons.signal_wifi_off;
        break;
    }

    IconData nodeIcon;
    switch (widget.node.type) {
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
      onTap: widget.onTap,
      onPanUpdate: widget.onPanUpdate,
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
                  if (statusIndicator != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Icon(
                        statusIndicator,
                        color: widget.node.status == NodeStatus.offline
                            ? Colors.grey
                            : Colors.amber,
                        size: 12,
                      ),
                    ),
                  Text(
                    widget.node.label,
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
            // Node Box with optional pulse animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final glowAlpha = widget.node.status == NodeStatus.delayed
                    ? _pulseAnimation.value * 0.6
                    : (widget.node.status == NodeStatus.active ? 0.2 : 0.1);

                return Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22222A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: glowAlpha),
                        blurRadius: widget.node.status == NodeStatus.delayed
                            ? 15 + (_pulseAnimation.value * 10)
                            : 15,
                        spreadRadius: widget.node.status == NodeStatus.delayed
                            ? 2 + (_pulseAnimation.value * 4)
                            : 2,
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
