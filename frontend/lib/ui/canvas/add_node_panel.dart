import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_client.dart';
import '../../state/canvas_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AddNodePanel — unified Search/Invite interface (§2.3 Phase 1–3)
// ─────────────────────────────────────────────────────────────────────────────

class AddNodePanel extends ConsumerStatefulWidget {
  const AddNodePanel({super.key});
  @override
  ConsumerState<AddNodePanel> createState() => _AddNodePanelState();
}

class _AddNodePanelState extends ConsumerState<AddNodePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Search tab
  final _searchController = TextEditingController();
  double _radius = 50.0;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  // Invite tab
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _connectionType = 'supplier';
  String _channel = 'email';
  bool _isInviting = false;

  // Last sent invite (for link dispatch)
  Map<String, dynamic>? _lastInviteResponse;

  static const _teal = Color(0xFF2DD4BF);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Tier-1/2/3 Search with radius ────────────────────────────────────────
  Future<void> _performSearch() async {
    if (_searchController.text.isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchResults = [];
    });
    try {
      final response = await ref.read(apiClientProvider).searchDiscoveryNodes(
            query: _searchController.text,
            orgId: kFrontendDefaultOrgId,
            radius: _radius, // ✅ Radius now wired
          );
      setState(() => _searchResults = response['results'] ?? []);
    } catch (e) {
      if (mounted) _snack('Search failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── Add a discovered node to the canvas ──────────────────────────────────
  void _addDiscoveredNode(dynamic item) {
    NodeType parsedType = NodeType.supplier;
    try {
      parsedType = NodeType.values.firstWhere((e) => e.name == item['type']);
    } catch (_) {}

    final newNode = CanvasNode(
      id: item['id'],
      label: item['label'],
      type: parsedType,
      status: NodeStatus.pending,
      position: const Offset(5150, 4950),
    );
    ref.read(canvasProvider.notifier).addNode(newNode);
    _snack('Node added. Pending verification.');
  }

  // ── Send invite ───────────────────────────────────────────────────────────
  Future<void> _sendInvite() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty) {
      _snack('Name and email are required.', error: true);
      return;
    }
    if (_channel == 'whatsapp' && _phoneCtrl.text.isEmpty) {
      _snack('Phone number required for WhatsApp.', error: true);
      return;
    }
    setState(() => _isInviting = true);
    try {
      final response = await ref.read(apiClientProvider).sendDirectInvite(
            orgId: kFrontendDefaultOrgId,
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            connectionType: _connectionType,
            phone: _phoneCtrl.text.trim().isNotEmpty
                ? _phoneCtrl.text.trim()
                : null,
            channel: _channel,
          );

      // Drop pending node on canvas immediately
      NodeType parsedType = NodeType.supplier;
      try {
        parsedType =
            NodeType.values.firstWhere((e) => e.name == _connectionType);
      } catch (_) {}
      ref.read(canvasProvider.notifier).addNode(CanvasNode(
            id: response['node_id'],
            label: _nameCtrl.text.trim(),
            type: parsedType,
            status: NodeStatus.pending,
            position: const Offset(5100, 5000),
          ));

      setState(() => _lastInviteResponse = response);
      _nameCtrl.clear();
      _emailCtrl.clear();
      _phoneCtrl.clear();
    } catch (e) {
      if (mounted) _snack('Invite failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  // ── Open dispatch link ────────────────────────────────────────────────────
  Future<void> _openDispatchLink() async {
    final resp = _lastInviteResponse;
    if (resp == null) return;

    String? rawUrl;
    if (_channel == 'whatsapp' && resp['whatsapp_link'] != null) {
      rawUrl = resp['whatsapp_link'];
    } else {
      // Fallback: open mailto
      final email = resp['email'] ?? '';
      final link = resp['invite_link'] ?? '';
      rawUrl = 'mailto:$email?subject=Curoot%20Supply%20Chain%20Invitation'
          '&body=You%20have%20been%20invited.%20Click%20here%3A%20$link';
    }

    if (rawUrl != null) {
      final uri = Uri.parse(rawUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) _snack('Could not open link.', error: true);
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : Colors.green.shade700,
    ));
  }

  // ── Tier badge ────────────────────────────────────────────────────────────
  Widget _tierBadge(dynamic item) {
    final tier = item['tier'] as int? ?? 3;
    final cached = item['cached'] == true;
    final label = tier == 1
        ? 'Active'
        : tier == 2
            ? 'Community'
            : cached
                ? 'OSM Cache'
                : 'OSM';
    final color = tier == 1
        ? _teal
        : tier == 2
            ? Colors.purple.shade300
            : Colors.orange.shade300;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Add Node',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),
        TabBar(
          controller: _tabController,
          indicatorColor: _teal,
          labelColor: _teal,
          unselectedLabelColor: Colors.white38,
          tabs: const [Tab(text: 'Search'), Tab(text: 'Invite')],
        ),
        Expanded(
            child: TabBarView(
          controller: _tabController,
          children: [_buildSearchTab(), _buildInviteTab()],
        )),
      ]),
    );
  }

  // ── Search Tab ────────────────────────────────────────────────────────────
  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        // Search field
        TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          onSubmitted: (_) => _performSearch(),
          decoration: InputDecoration(
            hintText: 'Search supplier, factory…',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search, color: _teal, size: 20),
              onPressed: _performSearch,
            ),
            filled: true,
            fillColor: const Color(0xFF13131A),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _teal)),
          ),
        ),
        const SizedBox(height: 10),

        // Radius slider ✅ wired
        Row(children: [
          const Icon(Icons.radar, color: Colors.white38, size: 14),
          const SizedBox(width: 4),
          const Text('Radius:',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          Expanded(
              child: Slider(
            value: _radius,
            min: 10,
            max: 500,
            divisions: 49,
            activeColor: _teal,
            inactiveColor: Colors.white12,
            onChanged: (v) => setState(() => _radius = v),
          )),
          Text('${_radius.toInt()} km',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),

        if (_isSearching)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(color: _teal, strokeWidth: 2)),

        // Tier legend
        if (_searchResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              _tierBadge({'tier': 1}),
              const SizedBox(width: 6),
              _tierBadge({'tier': 2}),
              const SizedBox(width: 6),
              _tierBadge({'tier': 3}),
              const Spacer(),
              Text('${_searchResults.length} result(s)',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),

        Expanded(
            child: ListView.builder(
          itemCount: _searchResults.length,
          itemBuilder: (context, i) {
            final item = _searchResults[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF13131A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                title: Text(item['label'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: Row(children: [
                  _tierBadge(item),
                  const SizedBox(width: 6),
                  Text(item['type'] ?? '',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: _teal, size: 20),
                  onPressed: () => _addDiscoveredNode(item),
                ),
              ),
            );
          },
        )),
      ]),
    );
  }

  // ── Invite Tab ────────────────────────────────────────────────────────────
  Widget _buildInviteTab() {
    InputDecoration dec(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF13131A),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _teal)),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: dec('Company / Node Name')),
        const SizedBox(height: 10),
        TextField(
            controller: _emailCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            keyboardType: TextInputType.emailAddress,
            decoration: dec('Contact Email')),
        const SizedBox(height: 10),

        // Channel toggle
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            const Text('Channel:',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            ChoiceChip(
              label: const Text('Email'),
              selected: _channel == 'email',
              onSelected: (_) => setState(() => _channel = 'email'),
              selectedColor: _teal,
              backgroundColor: const Color(0xFF1A1A22),
              labelStyle: TextStyle(
                  color: _channel == 'email' ? Colors.black87 : Colors.white54,
                  fontSize: 12),
            ),
            ChoiceChip(
              label: const Text('WhatsApp'),
              selected: _channel == 'whatsapp',
              onSelected: (_) => setState(() => _channel = 'whatsapp'),
              selectedColor: Colors.green.shade400,
              backgroundColor: const Color(0xFF1A1A22),
              labelStyle: TextStyle(
                  color: _channel == 'whatsapp' ? Colors.black87 : Colors.white54,
                  fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Phone field (shown only for WhatsApp)
        if (_channel == 'whatsapp') ...[
          TextField(
              controller: _phoneCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              keyboardType: TextInputType.phone,
              decoration:
                  dec('Phone (with country code)', hint: '+91 98765 43210')),
          const SizedBox(height: 10),
        ],

        // Connection type
        DropdownButtonFormField<String>(
          initialValue: _connectionType,
          dropdownColor: const Color(0xFF1E1E26),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: dec('Connection Type'),
          items: const [
            DropdownMenuItem(value: 'supplier', child: Text('Supplier')),
            DropdownMenuItem(value: 'factory', child: Text('Factory')),
            DropdownMenuItem(value: 'oem', child: Text('OEM')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _connectionType = v);
          },
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isInviting ? null : _sendInvite,
          icon: _isInviting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.black87, strokeWidth: 2))
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(_isInviting ? 'Sending…' : 'Send Invite & Place Node',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),

        // Post-invite dispatch card
        if (_lastInviteResponse != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade900.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.green.shade700.withValues(alpha: 0.4)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.check_circle_outline,
                    color: Colors.greenAccent, size: 16),
                SizedBox(width: 6),
                Text('Invite Created',
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              Text(
                'Expires: ${_lastInviteResponse!['expires_at']?.toString().substring(0, 10) ?? '7 days'}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        _channel == 'whatsapp' ? Colors.greenAccent : _teal,
                    side: BorderSide(
                        color: _channel == 'whatsapp'
                            ? Colors.greenAccent
                            : _teal),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(
                      _channel == 'whatsapp'
                          ? Icons.chat_rounded
                          : Icons.email_outlined,
                      size: 16),
                  label: Text(
                    _channel == 'whatsapp'
                        ? 'Open WhatsApp'
                        : 'Open Email Client',
                    style: const TextStyle(fontSize: 13),
                  ),
                  onPressed: _openDispatchLink,
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
