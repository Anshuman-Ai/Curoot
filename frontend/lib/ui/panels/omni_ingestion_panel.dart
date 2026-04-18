import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../services/api_client.dart';
import 'mcp_generation_wizard.dart';

class OmniIngestionPanel extends ConsumerStatefulWidget {
  const OmniIngestionPanel({super.key});

  @override
  ConsumerState<OmniIngestionPanel> createState() => _OmniIngestionPanelState();
}

class _OmniIngestionPanelState extends ConsumerState<OmniIngestionPanel> {
  bool _isDragging = false;
  bool _isUploading = false;
  String _uploadStatus = "";

  Future<void> _pickFiles() async {
    if (_isUploading) return;
    
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'csv', 'doc', 'docx', 'txt'],
      withData: true,
    );

    if (result != null) {
      if (result.files.single.bytes != null) {
        _startUpload(result.files.single.name, result.files.single.bytes!);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not load file data. Note: Drag & Drop sometimes lacks data access on desktop. Please use the upload click instead.'),
              backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
            ),
          );
        }
      }
    }
  }

  void _startUpload(String name, List<int> bytes) async {
    setState(() {
      _isUploading = true;
      _uploadStatus = "Multimodal AI Parsing...";
    });
    
    Map<String, dynamic>? extractionResult;
    try {
      extractionResult = await ref.read(apiClientProvider).ingestUnstructured(name, bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _uploadStatus = "Upload complete.";
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
          if (extractionResult != null) _showExtractionResult(name, extractionResult);
        }
      });
    }
  }

  void _showExtractionResult(String fileName, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
             filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
             child: Container(
               width: 450,
               padding: const EdgeInsets.all(24),
               decoration: BoxDecoration(
                 color: const Color(0xFF1A1A1A).withValues(alpha: 0.95), // Match LeftPanel modal
                 borderRadius: BorderRadius.circular(16),
                 border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                 boxShadow: [
                   BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 10)
                 ]
               ),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   Row(
                     children: [
                       const Icon(Icons.check_circle_outline, color: Color(0xFF2DD4BF)),
                       const SizedBox(width: 8),
                       Expanded(
                         child: Text(
                           "AI Extraction Profile: $fileName",
                           style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 16),
                   Container(
                     padding: const EdgeInsets.all(12),
                     height: 150,
                     decoration: BoxDecoration(
                       color: Colors.black.withValues(alpha: 0.5),
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                     ),
                     child: SingleChildScrollView(
                       child: Text(
                         _formatJson(result),
                         style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12),
                       ),
                     ),
                   ),
                   const SizedBox(height: 24),
                   Align(
                     alignment: Alignment.centerRight,
                     child: TextButton(
                       style: TextButton.styleFrom(
                         foregroundColor: Colors.white,
                         backgroundColor: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                       ),
                       onPressed: () => Navigator.of(context).pop(),
                       child: const Text('Acknowledge'),
                     ),
                   )
                 ]
               ),
             ),
          ),
        ),
      ),
    );
  }

  String _formatJson(Map<String, dynamic> json) {
    String out = "";
    // VERY primitive mock pretty-print for dart without extra packages
    json.forEach((key, value) {
      if (value is List) {
        out += '"$key": [\n';
        for (var item in value) {
           out += '  {\n';
           if (item is Map) {
             item.forEach((ik, iv) {
               out += '    "$ik": "$iv",\n';
             });
           }
           out += '  }\n';
        }
        out += ']\n';
      } else {
        out += '"$key": "$value",\n';
      }
    });
    return out;
  }

  void _showWebhookConfigDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: 440,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withValues(alpha: 0.95), // Match LeftPanel modal
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Direct Zero-Trust Webhook",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Send continuous JSON telemetry compliant with the UniversalFilter schema to this endpoint.",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'POST /api/v1/ingestion/telemetry',
                      style: TextStyle(color: Color(0xFF2DD4BF), fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: const Text(
                      '{\n  "node_id": "ST-01",\n  "status": "operational",\n  "crisis_message": "String (optional NLP routing)"\n}',
                      style: TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Endpoint'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A), // Matches the dark grey theme
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text(
                  'Omni Ingestion',
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
              
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: Color(0xFF2DD4BF)),
                      SizedBox(width: 8),
                      Text(
                        'Gemini API Attached',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              _buildDragDropZone(),
              
              const SizedBox(height: 16),
              
              _buildListTileButton(
                'Configure Webhook',
                 _showWebhookConfigDialog,
              ),
              
              const SizedBox(height: 12),
              
              _buildListTileButton(
                'Enterprise MCP Generator',
                () {
                  showDialog(
                    context: context,
                    builder: (_) => const McpGenerationWizard(),
                  );
                },
                isWifiIcon: true,
              ),
              
              const SizedBox(height: 16),
              
              _buildCopyToConfigureBox(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragDropZone() {
    return DropTarget(
      onDragDone: (detail) {
        if (detail.files.isNotEmpty && !_isUploading) {
          final file = detail.files.first;
          file.readAsBytes().then((bytes) {
            _startUpload(file.name, bytes);
          });
        }
      },
      onDragEntered: (detail) => setState(() => _isDragging = true),
      onDragExited: (detail) => setState(() => _isDragging = false),
      child: GestureDetector(
        onTap: _pickFiles,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 120, // More compact to fit expanded side panel effectively
            decoration: BoxDecoration(
              color: _isDragging 
                  ? Colors.white.withValues(alpha: 0.1) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isDragging ? [
                BoxShadow(color: const Color(0xFF2DD4BF).withValues(alpha: 0.1), blurRadius: 20)
              ] : null,
            ),
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: _isDragging ? const Color(0xFF2DD4BF) : Colors.white.withValues(alpha: 0.2),
                borderRadius: 12,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!_isUploading)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_rounded,
                          size: 28,
                          color: _isDragging ? const Color(0xFF2DD4BF) : Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Upload Files',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  if (_isUploading)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.3),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Color(0xFF2DD4BF)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _uploadStatus,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListTileButton(String title, VoidCallback onTap, {bool isWifiIcon = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isWifiIcon ? Icons.developer_board : Icons.webhook_rounded, 
              size: 16, 
              color: Colors.white70
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyToConfigureBox() {
    final activePipeline = ref.watch(activeMcpPipelineProvider);

    if (activePipeline != null) {
      return Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3)),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: 12,
              right: 12,
              child: Icon(Icons.check_circle, size: 20, color: Color(0xFF2DD4BF)),
            ),
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Active Pipeline',
                    style: TextStyle(
                      color: Color(0xFF2DD4BF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enterprise ERP ($activePipeline)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 80,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Stack(
        children: [
          Positioned(
            top: 12,
            right: 12,
            child: Icon(Icons.memory, size: 20, color: Colors.white24),
          ),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Awaiting configuration pipeline...',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;

  _DashedBorderPainter({required this.color, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // A simple dash implementation using path metrics
    Path path = Path()..addRRect(rrect);
    Path dashPath = Path();

    double dashWidth = 6.0;
    double dashSpace = 6.0;
    double distance = 0.0;

    for (var metric in path.computeMetrics()) {
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
      distance = 0.0;
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
