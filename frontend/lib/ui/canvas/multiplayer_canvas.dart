import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/canvas_provider.dart';
import 'edge_painter.dart';
import 'node_widget.dart';
import '../panels/left_panel.dart';
import '../panels/right_panel.dart';

class MultiplayerCanvas extends ConsumerStatefulWidget {
  const MultiplayerCanvas({super.key});

  @override
  ConsumerState<MultiplayerCanvas> createState() => _MultiplayerCanvasState();
}

class _MultiplayerCanvasState extends ConsumerState<MultiplayerCanvas> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animationController.addListener(() {
      if (_animation != null) {
        _transformationController.value = _animation!.value;
      }
    });

    // Start by centering on 'You' node after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recenter(animate: false);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _panToNode(Offset position, {bool animate = true}) {
    final screenSize = MediaQuery.of(context).size;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    final targetScale = currentScale; // Maintain current zoom level
    
    final xTranslation = screenCenter.dx - (position.dx * targetScale);
    final yTranslation = screenCenter.dy - (position.dy * targetScale);

    final targetMatrix = Matrix4.identity()
      ..setEntry(0, 0, targetScale)
      ..setEntry(1, 1, targetScale)
      ..setEntry(2, 2, targetScale)
      ..setEntry(0, 3, xTranslation)
      ..setEntry(1, 3, yTranslation);

    if (animate) {
      _animation = Matrix4Tween(
        begin: currentMatrix,
        end: targetMatrix,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ));

      _animationController.forward(from: 0);
    } else {
      _transformationController.value = targetMatrix;
    }
  }

  void _recenter({bool animate = true}) {
    final state = ref.read(canvasProvider);
    final youNode = state.nodes.where((n) => n.id == 'you').firstOrNull;
    if (youNode != null) {
      _panToNode(youNode.position, animate: animate);
    }
  }

  void _searchNodes() {
    final state = ref.read(canvasProvider);
    if (state.nodes.isEmpty) return;
    
    // Cycle/Dropdown to select a node (mocking search)
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 0, 0),
      items: state.nodes.map((node) {
        return PopupMenuItem(
          value: node,
          child: Text(node.label),
        );
      }).toList(),
    ).then((selectedNode) {
      if (selectedNode != null) {
        _panToNode(selectedNode.position);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF111111), // Very dark gray/almost black
      body: Stack(
        children: [
          // Background Infinite Grid Map
          AnimatedBuilder(
            animation: _transformationController,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: GridPainter(transform: _transformationController.value),
              );
            },
          ),
          
          // Infinite Canvas
          InteractiveViewer(
            transformationController: _transformationController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(5000),
            minScale: 0.1,
            maxScale: 4.0,
            child: SizedBox(
              width: 10000, // Massive explicit base anchor
              height: 10000,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Draw Edges overlapping the identical 0,0 coordinate system
                  Positioned.fill(
                    child: CustomPaint(
                      painter: EdgePainter(
                        nodes: canvasState.nodes,
                        edges: canvasState.edges,
                      ),
                    ),
                  ),

                  
                  // Draw Nodes
                  ...canvasState.nodes.map((node) {
                    // Offset widget so center of node matches `node.position`
                    // Node widget approx width = 56, height = 90
                    const double widgetWidth = 56.0;
                    const double widgetHeight = 90.0;

                    return Positioned(
                      left: node.position.dx - (widgetWidth / 2),
                      top: node.position.dy - (widgetHeight / 2),
                      child: NodeWidget(
                        node: node,
                        onTap: () => _panToNode(node.position),
                        onPanUpdate: (details) {
                          final scale = _transformationController.value.getMaxScaleOnAxis();
                          final dx = details.delta.dx / scale;
                          final dy = details.delta.dy / scale;
                          ref.read(canvasProvider.notifier).updateNodePosition(
                            node.id, 
                            Offset(node.position.dx + dx, node.position.dy + dy),
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          
          // UI Overlays
          Positioned(
            right: 344, // 320 (RightPanel width) + 24
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'searchBtn',
                  backgroundColor: const Color(0xFF22222A),
                  onPressed: _searchNodes,
                  tooltip: 'Search Node',
                  child: const Icon(Icons.search, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'centerBtn',
                  backgroundColor: Colors.tealAccent,
                  onPressed: _recenter,
                  tooltip: 'Recenter on You',
                  child: const Icon(Icons.my_location, color: Colors.black87),
                ),
              ],
            ),
          ),

          // Left Navigation Panel
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SafeArea(child: LeftPanel()),
          ),

          // Right AI Tradeoffs Panel
          const Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: SafeArea(child: RightPanel()),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Matrix4 transform;
  
  GridPainter({required this.transform});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = transform.getMaxScaleOnAxis();
    final offsetX = transform.getTranslation().x;
    final offsetY = transform.getTranslation().y;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    const baseSpacing = 50.0;
    final spacing = baseSpacing * scale;

    final startX = offsetX % spacing;
    final startY = offsetY % spacing;

    for (double x = startX; x < size.width; x += spacing) {
      for (double y = startY; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.transform != transform;
  }
}

