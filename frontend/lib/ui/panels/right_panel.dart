import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/canvas_provider.dart';

class RightPanel extends ConsumerWidget {
  const RightPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasProvider);
    final selectedNodeId = canvasState.selectedNodeId;
    
    if (selectedNodeId == null) {
      return const SizedBox.shrink();
    }

    final selectedNode = canvasState.nodes.where((n) => n.id == selectedNodeId).firstOrNull;
    final nodeName = selectedNode?.label ?? 'Unknown';

    // Currently no data nodes exist except placeholder, so hide these sections until real nodes are dynamically loaded.
    bool showCriticalAlert = selectedNode?.type == NodeType.supplier;
    bool showTradeoffs = canvasState.nodes.length > 2;

    return SizedBox(
      width: 280,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Node Details Card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24), // Matches the dark grey theme
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  const Center(
                    child: Text(
                      'Node Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 16),

                  // Dropdown mock
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            nodeName,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  ),
                  if (showCriticalAlert) ...[
                    const SizedBox(height: 16),
                    // Critical Alert Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF352024), // Dark reddish tint
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'CRITICAL ALERT',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Port congestion nearby.\nPotential 3-day delay on\noutbound shipments to\nHamburg.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Carbon ESG
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text('CARBON ESG', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            SizedBox(width: 6),
                            Icon(Icons.energy_savings_leaf_outlined, color: Colors.white70, size: 14),
                          ],
                        ),
                        Text('84T', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Reliability
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('RELIABILITY', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            Text('47%', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 47,
                              child: ColoredBox(color: Colors.redAccent, child: SizedBox(height: 4)),
                            ),
                            Expanded(
                              flex: 53,
                              child: ColoredBox(color: Color(0xFF1E1E24), child: SizedBox(height: 4)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            if (showTradeoffs) ...[
              const SizedBox(height: 16),
              // Trade offs Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24), // Matches the dark grey theme
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text(
                        'Trade offs',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Enterprise Node Buttons
                    ...canvasState.nodes.map((node) {
                      final isSelected = node.id == selectedNodeId;
                      final iconColor = isSelected ? Colors.redAccent : (node.status == NodeStatus.active ? Colors.greenAccent : Colors.amber);
                      final icon = isSelected ? Icons.trending_down : (node.status == NodeStatus.active ? Icons.trending_up : Icons.trending_flat);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: InkWell(
                          onTap: () {
                            ref.read(canvasProvider.notifier).selectNode(node.id);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A35),
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected ? Border.all(color: Colors.white24) : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  node.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Icon(icon, color: iconColor, size: 16),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
