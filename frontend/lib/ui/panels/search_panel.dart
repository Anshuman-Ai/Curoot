import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/canvas_provider.dart';

class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({super.key});

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);
    final nodes = canvasState.nodes;
    
    // Filter nodes based on query
    final filteredNodes = nodes.where((n) {
      final labelMatch = n.label.toLowerCase().contains(_query.toLowerCase());
      final idMatch = n.id.toLowerCase().contains(_query.toLowerCase());
      return labelMatch || idMatch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── SEARCH BAR ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NODE DISCOVERY',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: Colors.white30,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _query = val),
                  style: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by node name or ID...',
                    hintStyle: GoogleFonts.manrope(color: Colors.white24, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Colors.white12),

        // ── RESULTS LIST ─────────────────────────────────────────────────────
        Expanded(
          child: filteredNodes.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: filteredNodes.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                  itemBuilder: (context, index) {
                    final node = filteredNodes[index];
                    return _NodeResultTile(node: node);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _query.isEmpty ? Icons.manage_search : Icons.search_off,
            size: 48,
            color: Colors.white10,
          ),
          const SizedBox(height: 16),
          Text(
            _query.isEmpty ? 'Type to start searching' : 'No nodes found for "$_query"',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Colors.white24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeResultTile extends ConsumerWidget {
  final CanvasNode node;
  const _NodeResultTile({required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Select and Focus node
          ref.read(canvasProvider.notifier).selectNode(node.id);
          // Note: The recenter logic is in MultiplayerCanvas, 
          // but we can trigger a notification or use a global key if needed.
          // For now, selecting it will highlight it in the RightPanel.
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getNodeIcon(node.type),
                  color: _getNodeColor(node.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.label,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'ID: ${node.id}',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: Colors.white38,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNodeIcon(NodeType type) {
    switch (type) {
      case NodeType.oem: return Icons.person;
      case NodeType.supplier: return Icons.local_shipping;
      case NodeType.factory: return Icons.factory;
      case NodeType.add: return Icons.add;
    }
  }

  Color _getNodeColor(NodeType type) {
    switch (type) {
      case NodeType.oem: return Colors.tealAccent;
      case NodeType.supplier: return Colors.orangeAccent;
      case NodeType.factory: return Colors.blueAccent;
      case NodeType.add: return Colors.white54;
    }
  }
}
