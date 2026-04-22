import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../state/canvas_provider.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  List<dynamic> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final client = ref.read(apiClientProvider);
      final templates = await client.fetchCommunityTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _autoApply(String templateId) async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.autoApplyTemplate(templateId, kFrontendDefaultOrgId);
      
      final imported = response['nodes_imported'] as List<dynamic>;
      double offsetX = 4850; // default offset placement
      for (var nodeData in imported) {
         NodeType parsedType = NodeType.supplier;
         try {
           parsedType = NodeType.values.firstWhere((e) => e.name == nodeData['type']);
         } catch (_) {}

         final newNode = CanvasNode(
           id: nodeData['id'].toString(),
           label: nodeData['name'],
           type: parsedType,
           status: NodeStatus.pending, // Drop in as pending instantly
           position: Offset(offsetX, 5150),
         );
         ref.read(canvasProvider.notifier).addNode(newNode);
         offsetX += 120;
         
         // Mock the background RFP status check over time for demo purposes
         Future.delayed(const Duration(seconds: 4), () {
           if (!mounted) return;
           if (nodeData['name'].toString().toLowerCase().contains('fail')) {
             ref.read(canvasProvider.notifier).updateNodeStatus(nodeData['id'].toString(), NodeStatus.delayed);
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
               content: Text('RFP Failed for ${nodeData['name']}. Suggesting Tier 3 Alternatives.'),
               backgroundColor: Colors.redAccent,
             ));
           } else {
             ref.read(canvasProvider.notifier).updateNodeStatus(nodeData['id'].toString(), NodeStatus.active);
           }
         });
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response['message'] ?? 'Template applied successfully.'),
        backgroundColor: Colors.green,
      ));
      
      // Go back to canvas after applying
      Navigator.of(context).pop();
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to apply template: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C), // Deep dark background
      appBar: AppBar(
        backgroundColor: const Color(0xFF121216),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.storefront, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text('Community Gallery', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.white12,
            height: 1.0,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Browse and auto-apply sanitized supply chain templates published by veteran organizations.',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  if (_templates.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No templates available.',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      children: _templates.map((tpl) {
                        return Container(
                          width: 400,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E24),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tpl['name'] ?? 'Unknown Template',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tpl['description'] ?? 'No description provided.',
                                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.tealAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Includes ${(tpl['nodes'] as List?)?.length ?? 0} validated RFPs via 1-Hop networking.',
                                  style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.tealAccent,
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.bolt, size: 20),
                                  label: const Text(
                                    'Auto-Apply Template',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                  onPressed: () => _autoApply(tpl['id'].toString()),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
    );
  }
}
