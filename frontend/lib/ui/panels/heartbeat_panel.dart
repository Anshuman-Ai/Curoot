import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/canvas_provider.dart';
import '../../services/api_client.dart';

// ── Design tokens (matches right_panel.dart) ──────────────────────────────
const _kTileBg = Color(0xFF313533);
const _kTileBorder = Color(0xFF2D3449);
const _kTeal = Color(0xFF2DD4BF);

TextStyle _label({
  double size = 12,
  FontWeight w = FontWeight.w600,
  double spacing = 0.6,
  Color color = Colors.white,
}) =>
    GoogleFonts.manrope(
      fontSize: size,
      fontWeight: w,
      letterSpacing: spacing,
      color: color,
    );

TextStyle _body({
  double size = 13,
  FontWeight w = FontWeight.w400,
  Color color = Colors.white,
}) =>
    GoogleFonts.manrope(fontSize: size, fontWeight: w, color: color);

BoxDecoration _tileDecoration({Color? border}) => BoxDecoration(
      color: _kTileBg,
      border: Border.all(color: border ?? _kTileBorder, width: 1),
      borderRadius: BorderRadius.circular(8),
    );

// ── Heartbeat Panel ───────────────────────────────────────────────────────

class HeartbeatPanel extends ConsumerStatefulWidget {
  final String nodeId;
  final String nodeName;
  final CanvasNode node;

  const HeartbeatPanel({
    super.key,
    required this.nodeId,
    required this.nodeName,
    required this.node,
  });

  @override
  ConsumerState<HeartbeatPanel> createState() => _HeartbeatPanelState();
}

class _HeartbeatPanelState extends ConsumerState<HeartbeatPanel> {
  final _messageController = TextEditingController();
  bool _isSending = false;
  bool _linkGenerating = false;
  String? _copiedLink;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show for local/mock nodes
    if (widget.nodeId == 'you' ||
        widget.nodeId == 'add' ||
        !isValidUuid(widget.nodeId)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──────────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.link, color: _kTeal, size: 16),
            const SizedBox(width: 8),
            Text(
              'MAGIC LINK MODULE',
              style: _label(
                size: 11,
                w: FontWeight.w700,
                spacing: 1.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Status Bar ──────────────────────────────────────
        _buildStatusBar(),
        const SizedBox(height: 10),

        // ── Magic Link ──────────────────────────────────────
        _buildMagicLinkButton(),
        const SizedBox(height: 10),

        // ── Send Message ────────────────────────────────────
        _buildMessageInput(),
      ],
    );
  }

  // ── Status bar with heartbeat info ──────────────────────────────────────

  Widget _buildStatusBar() {
    final isDark = widget.node.isDarkNode;
    final confidence = widget.node.heartbeatConfidence;
    final lastHb = widget.node.lastHeartbeatAt;

    final statusColor = isDark ? Colors.redAccent : _kTeal;
    final statusText = isDark ? 'DARK NODE' : 'CONNECTED';
    final confText = '${(confidence * 100).toInt()}%';

    String timeAgo = 'Never';
    if (lastHb != null && lastHb.isNotEmpty) {
      try {
        final dt = DateTime.parse(lastHb);
        final diff = DateTime.now().toUtc().difference(dt);
        if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          timeAgo = '${diff.inHours}h ago';
        } else {
          timeAgo = '${diff.inDays}d ago';
        }
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: _tileDecoration(
        border: isDark ? Colors.redAccent.withValues(alpha: 0.3) : _kTileBorder,
      ),
      child: Row(
        children: [
          // Pulsing dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(statusText,
              style: _label(size: 10, w: FontWeight.w700, spacing: 0.8, color: statusColor)),
          const Spacer(),
          Text('CONF $confText',
              style: _label(size: 9, w: FontWeight.w500, spacing: 0, color: Colors.white38)),
          const SizedBox(width: 6),
          const Icon(Icons.access_time, size: 10, color: Colors.white38),
          const SizedBox(width: 3),
          Text(timeAgo,
              style: _label(size: 9, w: FontWeight.w500, spacing: 0, color: Colors.white38)),
        ],
      ),
    );
  }

  // ── Magic link button ───────────────────────────────────────────────────

  Widget _buildMagicLinkButton() {
    return InkWell(
      onTap: _linkGenerating ? null : _generateAndCopyLink,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _copiedLink != null
              ? _kTeal.withValues(alpha: 0.08)
              : const Color(0xFF1E2228),
          border: Border.all(
            color: _copiedLink != null
                ? _kTeal.withValues(alpha: 0.3)
                : _kTileBorder,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_linkGenerating)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kTeal),
              )
            else
              Icon(
                _copiedLink != null ? Icons.check : Icons.link,
                color: _copiedLink != null ? _kTeal : Colors.white54,
                size: 14,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _copiedLink != null
                    ? 'Magic Link Copied!'
                    : 'Generate Supplier Magic Link',
                overflow: TextOverflow.ellipsis,
                style: _label(
                  size: 11,
                  w: FontWeight.w600,
                  spacing: 0.3,
                  color: _copiedLink != null ? _kTeal : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndCopyLink() async {
    setState(() => _linkGenerating = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final data = await apiClient.generateMagicLink(
        nodeIds: [widget.nodeId],
        orgId: kFrontendDefaultOrgId,
      );
      final links = data['links'] as List<dynamic>? ?? [];
      if (links.isNotEmpty) {
        final url = links.first['url'] ?? '';
        await Clipboard.setData(ClipboardData(text: url));
        setState(() {
          _copiedLink = url;
          _linkGenerating = false;
        });
        // Reset after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _copiedLink = null);
        });
      }
    } catch (e) {
      debugPrint('Error generating magic link: $e');
      setState(() => _linkGenerating = false);
    }
  }



  // ── Message input ───────────────────────────────────────────────────────

  Widget _buildMessageInput() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kTileBorder),
            ),
            child: TextField(
              controller: _messageController,
              style: _body(size: 12, color: Colors.white),
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'Message supplier…',
                hintStyle: _body(size: 12, color: Colors.white24),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: _isSending ? null : _sendMessage,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kTeal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isSending
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.black, size: 16),
          ),
        ),
      ],
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.sendOemMessage(
        orgId: kFrontendDefaultOrgId,
        nodeIds: [widget.nodeId],
        message: text,
      );
      _messageController.clear();
      // No local chat history refresh needed anymore
    } catch (e) {
      debugPrint('Error sending OEM message: $e');
    }
    if (mounted) setState(() => _isSending = false);
  }
}
