import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../state/canvas_provider.dart';

class AddNodePanel extends ConsumerStatefulWidget {
  const AddNodePanel({super.key});

  @override
  ConsumerState<AddNodePanel> createState() => _AddNodePanelState();
}

class _AddNodePanelState extends ConsumerState<AddNodePanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _selectedConnectionType = 'supplier';
  double _radius = 50.0;
  List<dynamic> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (_searchController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _searchResults = [];
    });
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.searchDiscoveryNodes(
        query: _searchController.text,
        orgId: kFrontendDefaultOrgId,
      // radius: _radius,
      );
      setState(() {
        _searchResults = response['results'] ?? [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendInvite() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.sendDirectInvite(
        orgId: kFrontendDefaultOrgId,
        name: _nameController.text,
        email: _emailController.text,
        connectionType: _selectedConnectionType,
      );
      
      NodeType parsedType = NodeType.supplier;
      try {
        parsedType = NodeType.values.firstWhere((e) => e.name == _selectedConnectionType);
      } catch (_) {}

      final newNode = CanvasNode(
        id: response['node_id'],
        label: _nameController.text,
        type: parsedType,
        status: NodeStatus.pending,
        position: const Offset(5100, 5000), 
      );
      ref.read(canvasProvider.notifier).addNode(newNode);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite sent! Node placed on canvas.')));
      _nameController.clear();
      _emailController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invite error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Add Node',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.tealAccent,
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'Search'),
              Tab(text: 'Invite'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSearchTab(),
                _buildInviteTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Search node (Tier 1/2/3)',
              labelStyle: const TextStyle(color: Colors.white54),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.tealAccent),
                onPressed: _performSearch,
              ),
              enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
            ),
            onSubmitted: (_) => _performSearch(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Radius:', style: TextStyle(color: Colors.white54)),
              Expanded(
                child: Slider(
                  value: _radius,
                  min: 10,
                  max: 200,
                  activeColor: Colors.tealAccent,
                  inactiveColor: Colors.white24,
                  onChanged: (val) => setState(() => _radius = val),
                ),
              ),
              Text('${_radius.toInt()}km', style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading) const CircularProgressIndicator(color: Colors.tealAccent),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final item = _searchResults[index];
                return ListTile(
                  title: Text(item['label'] ?? '', style: const TextStyle(color: Colors.white)),
                  subtitle: Text('Tier: ${item['tier']} | Type: ${item['type']}', style: const TextStyle(color: Colors.white54)),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.tealAccent),
                    onPressed: () {
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
                       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Node imported. Pending handshake.')));
                    },
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInviteTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Company/Node Name',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Contact Email',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedConnectionType,
            dropdownColor: const Color(0xFF22222A),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Connection Type',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
            ),
            items: const [
              DropdownMenuItem(value: 'supplier', child: Text('Supplier')),
              DropdownMenuItem(value: 'factory', child: Text('Factory')),
              DropdownMenuItem(value: 'oem', child: Text('OEM')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedConnectionType = val);
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _isLoading ? null : _sendInvite,
            child: _isLoading ? const CircularProgressIndicator(color: Colors.black87) : const Text('Send Invite & Place Node'),
          ),
        ],
      ),
    );
  }
}
