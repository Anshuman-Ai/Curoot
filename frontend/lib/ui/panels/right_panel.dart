import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/canvas_provider.dart';
import '../../state/disruption_provider.dart';
import '../../state/tradeoffs_provider.dart';
import '../../models/disruption_models.dart';
import '../../models/tradeoff_models.dart';
import 'heartbeat_panel.dart';

// ── Shared design tokens (mirrors login / signup pages) ──────────────────────
const _kPanelBg      = Colors.transparent;
const _kCardBorder   = Color(0x4D404944); // rgba(64,73,68,0.3)
const _kTileBg       = Color(0xFF313533);
const _kTileBorder   = Color(0xFF2D3449);
const _kDivider      = Color(0xFF2D3449);
const _kAccent       = Color(0xFF8083FF); // purple-indigo
const _kTeal         = Color(0xFF2DD4BF);
const _kLabelColor   = Colors.white;

// ── Text styles (Manrope) ─────────────────────────────────────────────────────
TextStyle _label({double size = 12, FontWeight w = FontWeight.w600,
    double spacing = 0.6, Color color = _kLabelColor}) =>
    GoogleFonts.manrope(
      fontSize: size,
      fontWeight: w,
      letterSpacing: spacing,
      color: color,
    );

TextStyle _body({double size = 13, FontWeight w = FontWeight.w400,
    Color color = Colors.white}) =>
    GoogleFonts.manrope(fontSize: size, fontWeight: w, color: color);

// ── Card decorator ────────────────────────────────────────────────────────────
BoxDecoration _cardDecoration() => BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment(-0.8, -0.8),
        end: Alignment(0.8, 0.8),
        stops: [0.2148, 0.5255, 0.8042],
        colors: [Color(0xFF000000), Color(0xCC333333), Color(0xFF000000)],
      ),
      border: const Border.fromBorderSide(
          BorderSide(color: _kCardBorder, width: 1)),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 40,
          offset: const Offset(0, 20),
        ),
      ],
    );

// ── Tile decorator (input-field style) ───────────────────────────────────────
BoxDecoration _tileDecoration({Color? border}) => BoxDecoration(
      color: _kTileBg,
      border: Border.all(color: border ?? _kTileBorder, width: 1),
      borderRadius: BorderRadius.circular(8),
    );

// ─────────────────────────────────────────────────────────────────────────────

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

    final nodeUuid = nodeIdToUuid(selectedNodeId);
    final nodeAlerts = ref.watch(alertsForNodeProvider(nodeUuid));
    final macroAsync = ref.watch(macroSignalsProvider);
    final alternatives = canvasState.nodes
        .where((n) => n.id != selectedNodeId && n.type != NodeType.add)
        .toList();

    return Container(
      width: 280,
      color: _kPanelBg,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── NODE DETAILS CARD ─────────────────────────────────────────
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section header
                    _sectionHeader('NODE DETAILS'),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: _kDivider),
                    const SizedBox(height: 16),

                    // Node name chip
                    _nodeChip(selectedNode.label),

                    // Disruption alerts
                    if (nodeAlerts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...nodeAlerts.map((a) => _alertBox(a)),
                    ] else if (selectedNode.status == NodeStatus.delayed) ...[
                      const SizedBox(height: 16),
                      _staticAlertBox(),
                    ],

                    const SizedBox(height: 16),

                    // Macro risk
                    macroAsync.when(
                      loading: () => _metricTile(
                          icon: Icons.public,
                          iconColor: Colors.white38,
                          label: 'MACRO RISK',
                          value: '…'),
                      error: (_, __) => _metricTile(
                          icon: Icons.public,
                          iconColor: Colors.white38,
                          label: 'MACRO RISK',
                          value: 'N/A'),
                      data: (signals) {
                        final top =
                            signals.isNotEmpty ? signals.first : null;
                        return _metricTile(
                          icon: Icons.public,
                          iconColor: _riskColor(top?.riskLevel),
                          label: 'MACRO RISK',
                          value: top?.riskLevel.toUpperCase() ?? 'LOW',
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    // Carbon ESG
                    _metricTile(
                      icon: Icons.energy_savings_leaf_outlined,
                      iconColor: _kTeal,
                      label: 'CARBON ESG',
                      value: '84T CO₂',
                    ),

                    const SizedBox(height: 10),

                    // Reliability bar
                    _reliabilityTile(47),
                  ],
                ),
              ),

              // ── HEARTBEAT PANEL (MODULE 2.7) ──────────────────────────────
              if (selectedNodeId != 'you' && selectedNodeId != 'add') ...[
                const SizedBox(height: 16),
                _card(
                  child: HeartbeatPanel(
                    nodeId: nodeUuid,
                    nodeName: selectedNode.label,
                    node: selectedNode,
                  ),
                ),
              ],

              // ── TRADE-OFFS CARD ───────────────────────────────────────────
              if (alternatives.isNotEmpty) ...[
                const SizedBox(height: 16),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionHeader('TRADE-OFFS'),
                      const SizedBox(height: 4),
                      Text(
                        'Tap an alternative node to compare',
                        textAlign: TextAlign.center,
                        style: _label(
                            size: 11,
                            w: FontWeight.w400,
                            spacing: 0,
                            color: Colors.white38),
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

  // ── HELPERS ─────────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        decoration: _cardDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: child,
      );

  Widget _sectionHeader(String title) => Center(
        child: Text(
          title,
          style: _label(
              size: 11,
              w: FontWeight.w700,
              spacing: 1.2,
              color: Colors.white),
        ),
      );

  Widget _nodeChip(String label) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: _tileDecoration(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: _body(size: 13, color: Colors.white70)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white54, size: 16),
            ],
          ),
        ),
      );

  Widget _alertBox(DisruptionAlert alert) {
    final isCritical =
        alert.severity == 'critical' || alert.severity == 'high';
    final borderColor =
        isCritical ? Colors.redAccent : Colors.orangeAccent;
    final bgColor = isCritical
        ? const Color(0xFF2A1A1A)
        : const Color(0xFF2A2010);
    final textColor =
        isCritical ? Colors.redAccent : Colors.orangeAccent;
    final icon =
        isCritical ? Icons.warning_amber_rounded : Icons.info_outline;
    final title =
        '${alert.severity.toUpperCase()} — ${alert.alertType.replaceAll('_', ' ').toUpperCase()}';
    final body = alert.payload['description'] as String? ??
        'Disruption detected near this node.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: borderColor.withValues(alpha: 0.35), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title,
                      style: _label(
                          size: 11,
                          w: FontWeight.w700,
                          spacing: 0.4,
                          color: textColor)),
                ),
                Icon(icon, color: textColor, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(body,
                style: _body(
                    size: 12,
                    color: Colors.white60)),
          ],
        ),
      ),
    );
  }

  Widget _staticAlertBox() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Colors.redAccent.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('CRITICAL ALERT',
                    style: _label(
                        size: 11,
                        w: FontWeight.w700,
                        spacing: 0.5,
                        color: Colors.redAccent)),
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Port congestion nearby.\nPotential 3-day delay on outbound shipments to Hamburg.',
              style: _body(size: 12, color: Colors.white60),
            ),
          ],
        ),
      );

  Widget _metricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _tileDecoration(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(label,
                  style: _label(
                      size: 10,
                      w: FontWeight.w600,
                      spacing: 0.8,
                      color: Colors.white70)),
              const SizedBox(width: 6),
              Icon(icon, color: iconColor, size: 13),
            ]),
            Text(value,
                style: _label(
                    size: 13,
                    w: FontWeight.w700,
                    spacing: 0,
                    color: Colors.white)),
          ],
        ),
      );

  Widget _reliabilityTile(int percent) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _tileDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('RELIABILITY',
                    style: _label(
                        size: 10,
                        w: FontWeight.w600,
                        spacing: 0.8,
                        color: Colors.white70)),
                Text('$percent%',
                    style: _label(
                        size: 13,
                        w: FontWeight.w700,
                        spacing: 0,
                        color: Colors.white)),
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
                        child: ColoredBox(color: Color(0xFF1E2228))),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Color _riskColor(String? level) {
    switch (level) {
      case 'critical':
        return Colors.redAccent;
      case 'high':
        return Colors.orangeAccent;
      case 'medium':
        return Colors.yellowAccent;
      default:
        return _kTeal;
    }
  }
}

// ── TRADE-OFF ROW ─────────────────────────────────────────────────────────────

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
    final tradeoffAsync =
        _expanded ? ref.watch(tradeoffProvider(params)) : null;

    final isActive = widget.alternativeNode.status == NodeStatus.active;
    final iconColor = isActive ? _kTeal : Colors.white54;
    final statusIcon = isActive
        ? Icons.check_circle_outline
        : Icons.radio_button_unchecked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row button
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _expanded ? _kTileBg : const Color(0xFF1E2228),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _expanded
                      ? _kAccent.withValues(alpha: 0.5)
                      : _kTileBorder,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(widget.alternativeNode.label,
                        overflow: TextOverflow.ellipsis,
                        style: _body(
                            size: 13,
                            w: FontWeight.w500,
                            color: Colors.white)),
                  ),
                  const SizedBox(width: 6),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(statusIcon, color: iconColor, size: 14),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: _expanded ? 0.5 : 0.0,
                      child: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white38, size: 16),
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // Expandable metrics panel
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
                                strokeWidth: 2, color: _kTeal),
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

  Widget _metricsError(String message) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
        ),
        child: Text('Could not reach backend.\n$message',
            style: _body(size: 11, color: Colors.white38)),
      );

  Widget _metricsPanel(TradeoffAnalysisResponse analysis) {
    final recColor = analysis.overallRecommendation == 'switch'
        ? _kTeal
        : analysis.overallRecommendation == 'stay'
            ? Colors.redAccent
            : Colors.orangeAccent;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kTileBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kAccent.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECOMMENDATION',
                  style: _label(
                      size: 10,
                      w: FontWeight.w600,
                      spacing: 0.8,
                      color: Colors.white38)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: recColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: recColor.withValues(alpha: 0.4), width: 1),
                ),
                child: Text(
                  analysis.overallRecommendation.toUpperCase(),
                  style: _label(
                      size: 10,
                      w: FontWeight.w700,
                      spacing: 0.5,
                      color: recColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _kDivider),
          const SizedBox(height: 10),
          ...analysis.metrics.map((m) => _metricRow(m)),
        ],
      ),
    );
  }

  Widget _metricRow(MetricResult metric) {
    final label = _metricLabel(metric.metricType);
    final sign = metric.delta >= 0 ? '+' : '';
    final delta = '$sign${metric.delta.toStringAsFixed(1)} ${metric.unit}';
    final color =
        metric.isImprovement ? _kTeal : Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: _label(
                  size: 12,
                  w: FontWeight.w500,
                  spacing: 0,
                  color: Colors.white60)),
          Row(children: [
            Icon(
              metric.isImprovement
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              color: color,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(delta,
                style: _label(
                    size: 12,
                    w: FontWeight.w600,
                    spacing: 0,
                    color: color)),
          ]),
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
