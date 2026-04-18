import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/canvas_provider.dart';
import '../../state/disruption_provider.dart';
import '../../state/tradeoffs_provider.dart';
import '../../models/disruption_models.dart';
import '../../models/tradeoff_models.dart';

class RightPanel extends ConsumerWidget {
  const RightPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasProvider);
    final selectedNodeId = canvasState.selectedNodeId;

    if (selectedNodeId == null) return const SizedBox.shrink();

    final selectedNode =
        canvasState.nodes.where((n) => n.id == selectedNodeId).firstOrNull;
    if (selectedNode == null) return const SizedBox.shrink();

    // Convert frontend ID → UUID for backend lookups
    final nodeUuid = nodeIdToUuid(selectedNodeId);

    // Disruption alerts for this node (realtime stream)
    final nodeAlerts = ref.watch(alertsForNodeProvider(nodeUuid));

    // Macro environment signals (one-shot fetch)
    final macroAsync = ref.watch(macroSignalsProvider);

    // The currently-selected alternative node (all nodes except the selected one and the Add node)
    final alternatives = canvasState.nodes
        .where((n) => n.id != selectedNodeId && n.type != NodeType.add)
        .toList();

    return Container(
      width: 280,
      decoration: const BoxDecoration(color: Color(0xFF121212)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── NODE DETAILS CARD ──────────────────────────────────────
              _card(
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

                    // Node name chip
                    _nodeChip(selectedNode.label),

                    // ── DISRUPTION ALERTS ──────────────────────────────
                    if (nodeAlerts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...nodeAlerts.map((alert) => _alertBox(alert)),
                    ] else if (selectedNode.status == NodeStatus.delayed) ...[
                      // Fallback: show a static alert when the node is in
                      // delayed state but no backend alert exists yet.
                      const SizedBox(height: 16),
                      _staticAlertBox(),
                    ],

                    const SizedBox(height: 16),

                    // ── MACRO RISK BADGE ──────────────────────────────
                    macroAsync.when(
                      loading: () => _metricTile(
                        icon: Icons.public,
                        iconColor: Colors.white38,
                        label: 'MACRO RISK',
                        value: '…',
                      ),
                      error: (_, __) => _metricTile(
                        icon: Icons.public,
                        iconColor: Colors.white38,
                        label: 'MACRO RISK',
                        value: 'N/A',
                      ),
                      data: (signals) {
                        final top = signals.isNotEmpty ? signals.first : null;
                        return _metricTile(
                          icon: Icons.public,
                          iconColor: _riskColor(top?.riskLevel),
                          label: 'MACRO RISK',
                          value: top?.riskLevel.toUpperCase() ?? 'LOW',
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // ── CARBON ESG (static for now; Module 2.6 metric) ─
                    _metricTile(
                      icon: Icons.energy_savings_leaf_outlined,
                      iconColor: const Color(0xFF2DD4BF),
                      label: 'CARBON ESG',
                      value: '84T CO₂',
                    ),

                    const SizedBox(height: 12),

                    // ── RELIABILITY ────────────────────────────────────
                    _reliabilityTile(47),
                  ],
                ),
              ),

              // ── TRADE-OFFS CARD ────────────────────────────────────────
              if (alternatives.isNotEmpty) ...[
                const SizedBox(height: 16),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'Trade-offs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Center(
                        child: Text(
                          'Tap an alternative node to compare',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...alternatives.map(
                        (altNode) => _TradeoffNodeRow(
                          selectedNodeId: selectedNodeId,
                          alternativeNode: altNode,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: child,
    );
  }

  Widget _nodeChip(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  /// A dismissible, real-time disruption alert box fetched from the backend.
  Widget _alertBox(DisruptionAlert alert) {
    final isCritical = alert.severity == 'critical' || alert.severity == 'high';
    final Color borderColor =
        isCritical ? Colors.redAccent : Colors.orangeAccent;
    final Color bgColor =
        isCritical ? const Color(0xFF352024) : const Color(0xFF2D2210);
    final Color textColor =
        isCritical ? Colors.redAccent : Colors.orangeAccent;
    final IconData icon =
        isCritical ? Icons.warning_amber_rounded : Icons.info_outline;
    final String title =
        '${alert.severity.toUpperCase()} — ${alert.alertType.replaceAll('_', ' ').toUpperCase()}';
    final String body = alert.payload['description'] as String? ??
        'Disruption detected near this node.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor.withValues(alpha: 0.35), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Icon(icon, color: textColor, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Static fallback critical alert (shown when node is delayed locally but
  /// has no backend disruption record yet).
  Widget _staticAlertBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF352024),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1),
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
              Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 20),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Port congestion nearby.\nPotential 3-day delay on\noutbound shipments to\nHamburg.',
            style:
                TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _metricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
            const SizedBox(width: 6),
            Icon(icon, color: iconColor, size: 14),
          ]),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _reliabilityTile(int percent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('RELIABILITY',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              Text('$percent%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Row(
              children: [
                Expanded(
                  flex: percent,
                  child: const SizedBox(
                      height: 4,
                      child: ColoredBox(color: Colors.redAccent)),
                ),
                Expanded(
                  flex: 100 - percent,
                  child: const SizedBox(
                      height: 4,
                      child: ColoredBox(color: Color(0xFF1E1E24))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _riskColor(String? level) {
    switch (level) {
      case 'critical':
        return Colors.redAccent;
      case 'high':
        return Colors.orangeAccent;
      case 'medium':
        return Colors.yellowAccent;
      default:
        return Colors.greenAccent;
    }
  }
}

// ── TRADE-OFF ROW (stateful — tapping an alternative triggers backend call) ──

class _TradeoffNodeRow extends ConsumerStatefulWidget {
  const _TradeoffNodeRow({
    required this.selectedNodeId,
    required this.alternativeNode,
  });

  final String selectedNodeId;
  final CanvasNode alternativeNode;

  @override
  ConsumerState<_TradeoffNodeRow> createState() => _TradeoffNodeRowState();
}

class _TradeoffNodeRowState extends ConsumerState<_TradeoffNodeRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final params = {
      'current_node_id': widget.selectedNodeId,
      'alternative_node_id': widget.alternativeNode.id,
    };

    final tradeoffAsync = _expanded ? ref.watch(tradeoffProvider(params)) : null;



    final iconColor = widget.alternativeNode.status == NodeStatus.active
        ? Colors.greenAccent
        : Colors.white70;
    final icon = widget.alternativeNode.status == NodeStatus.active
        ? Icons.check_circle_outline
        : Icons.radio_button_unchecked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Node row button ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _expanded
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: _expanded
                    ? Border.all(
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.3))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.alternativeNode.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  Row(
                    children: [
                      Icon(icon, color: iconColor, size: 15),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: _expanded ? 0.5 : 0.0,
                        child: const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white54, size: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable tradeoff metrics panel ──
          if (_expanded)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: tradeoffAsync == null
                  ? const SizedBox.shrink()
                  : tradeoffAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2DD4BF),
                            ),
                          ),
                        ),
                      ),
                      error: (err, _) => _metricsError(err.toString()),
                      data: (analysis) => _metricsPanel(analysis),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _metricsError(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Text(
        'Could not reach backend.\n$message',
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
    );
  }

  Widget _metricsPanel(TradeoffAnalysisResponse analysis) {
    final recColor = analysis.overallRecommendation == 'switch'
        ? Colors.greenAccent
        : analysis.overallRecommendation == 'stay'
            ? Colors.redAccent
            : Colors.orangeAccent;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Recommendation badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('RECOMMENDATION',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: recColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  analysis.overallRecommendation.toUpperCase(),
                  style: TextStyle(
                    color: recColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...analysis.metrics.map((m) => _metricRow(m)),
        ],
      ),
    );
  }

  Widget _metricRow(MetricResult metric) {
    final label = _metricLabel(metric.metricType);
    final sign = metric.delta >= 0 ? '+' : '';
    final delta = '$sign${metric.delta.toStringAsFixed(1)} ${metric.unit}';
    final color = metric.isImprovement ? Colors.greenAccent : Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          Row(
            children: [
              Icon(
                metric.isImprovement
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                color: color,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(delta,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  String _metricLabel(String type) {
    switch (type) {
      case 'financial':
        return 'Cost Δ';
      case 'time':
        return 'Time Δ';
      case 'carbon':
        return 'Carbon Δ';
      case 'reliability':
        return 'Reliability Δ';
      default:
        return type;
    }
  }
}
