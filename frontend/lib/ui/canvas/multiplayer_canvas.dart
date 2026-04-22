import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/canvas_provider.dart';
import 'edge_painter.dart';
import 'node_widget.dart';
import '../panels/left_panel.dart';
import '../panels/right_panel.dart';
import '../community/community_screen.dart';

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
      duration: const Duration(milliseconds: 600), // reduced duration for snappier dragging/panning
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

  void _panToNode(Offset position, {bool animate = true, double? targetZoom}) {
    final screenSize = MediaQuery.of(context).size;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    const defaultZoom = 1.2;
    final double computedScale = currentScale < defaultZoom ? defaultZoom : currentScale;
    final targetScale = targetZoom ?? computedScale;
    
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
        curve: Curves.easeOutCubic,
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
    // Removed ref.watch(canvasProvider) from root to dramatically increase FPS when dragging nodes
    // and animating canvas
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
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
          
          // Infinite Canvas — wrapped in Listener to enable 2-axis scroll
          Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                // Prevent InteractiveViewer from consuming this — apply
                // translation directly so both axes scroll freely.
                final m = _transformationController.value.clone();
                m.multiply(Matrix4.translationValues(
                  -event.scrollDelta.dx,
                  -event.scrollDelta.dy,
                  0.0,
                ));
                _transformationController.value = m;
              }
            },
            child: InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(5000),
              minScale: 0.1,
              maxScale: 4.0,
              // Disable built-in scroll-to-scale so our Listener can
              // intercept scroll events for free 2-axis panning instead.
              trackpadScrollCausesScale: false,
              child: SizedBox(
                width: 10000,
                height: 10000,
                child: Consumer(
                  builder: (context, ref, _) {
                    final canvasState = ref.watch(canvasProvider);
                    return Stack(
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
                          const double widgetWidth = 56.0;
                          const double widgetHeight = 90.0;

                          return Positioned(
                            left: node.position.dx - (widgetWidth / 2),
                            top: node.position.dy - (widgetHeight / 2),
                            child: NodeWidget(
                              node: node,
                              onTap: () {
                                ref.read(canvasProvider.notifier).selectNode(node.id);
                                _panToNode(node.position);
                                if (node.type == NodeType.add) {
                                  ref.read(leftPanelTabProvider.notifier).setTab(LeftPanelTab.addNode);
                                }
                              },
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
                    );
                  },
                ),
              ),
            ),
          ),
          

          
          // Top Right: Search + Recenter + Community — horizontal row
          Positioned(
            top: 24,
            right: 24,
            child: SafeArea(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.sensors, color: Colors.greenAccent),
                  const SizedBox(width: 16),

                  // ── Search button ──────────────────────────────────
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _searchNodes,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22222A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.search, color: Colors.white70, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ── Recenter / crosshair button ────────────────────
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _recenter,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.tealAccent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.my_location, color: Colors.black87, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ── Community button ───────────────────────────────
                  InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CommunityScreen())),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22222A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Community',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(Icons.storefront, color: Colors.amber, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Node Details / Trade Offs Panel
          Consumer(
            builder: (context, ref, _) {
              final canvasState = ref.watch(canvasProvider);
              if (canvasState.selectedNodeId != null) {
                return const Positioned(
                  right: 24,
                  top: 90, // Positioned below the top-right bar
                  bottom: 24,
                  child: SafeArea(child: RightPanel()),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Left Navigation Panel
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SafeArea(child: LeftPanel()),
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

    // Fill pure black background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000000),
    );

    // Dot grid — tight spacing, tiny dots, ultra-low opacity (matches design)
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    const baseSpacing = 24.0;
    final spacing = baseSpacing * scale;

    final startX = offsetX % spacing;
    final startY = offsetY % spacing;

    for (double x = startX; x < size.width; x += spacing) {
      for (double y = startY; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.transform != transform;
  }
}

