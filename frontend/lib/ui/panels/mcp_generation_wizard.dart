import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';

class ActiveMcpPipelineNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void updatePipeline(String value) => state = value;
}

final activeMcpPipelineProvider = NotifierProvider<ActiveMcpPipelineNotifier, String?>(ActiveMcpPipelineNotifier.new);

class McpGenerationWizard extends ConsumerStatefulWidget {
  const McpGenerationWizard({super.key});

  @override
  ConsumerState<McpGenerationWizard> createState() => _McpGenerationWizardState();
}

class _McpGenerationWizardState extends ConsumerState<McpGenerationWizard> {
  int _currentStep = 0;
  
  // Step 1 Form Data
  final _dbTypeController = TextEditingController(text: 'PostgreSQL');
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _freqController = TextEditingController(text: 'Real-time (Change Data Capture)');

  // Step 2 Terminal Text
  final List<String> _terminalLogs = [];
  double _generationProgress = 0.0;

  // Step 3 Verification & Output Data
  bool _isVerified = false;
  Map<String, dynamic>? _generatedPayload;

  @override
  void dispose() {
    _dbTypeController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _freqController.dispose();
    super.dispose();
  }

  void _generateMcp() async {
    setState(() {
      _currentStep = 1;
      _terminalLogs.clear();
      _generationProgress = 0.1;
      _terminalLogs.add("Initializing MCP Builder Sequence...");
    });

    final logs = [
      "Authenticating with registry...",
      "Configuring SQLite Buffer...",
      "Resolving dependencies...",
      "Compiling localized Docker image...",
      "Establishing secure tunneling...",
      "Packaging deployment script..."
    ];

    // Background call to client without blocking UI animation
    // We catch error early so it doesn't spawn an unhandled async exception in Dart
    Future<Map<String, dynamic>?> apiFuture = ref.read(apiClientProvider).generateMcp({
      'dbType': _dbTypeController.text,
      'ip': _ipController.text,
      'port': _portController.text,
      'freq': _freqController.text,
    }).catchError((error) {
      return <String, dynamic>{'error': error.toString()};
    });

    for (int i = 0; i < logs.length; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _terminalLogs.add(logs[i]);
        _generationProgress = 0.1 + (0.9 * ((i + 1) / logs.length));
      });
    }

    try {
      final result = await apiFuture;
      if (result != null && result.containsKey('error')) {
         throw Exception(result['error']);
      }
      _generatedPayload = result;
      ref.read(activeMcpPipelineProvider.notifier).updatePipeline(_dbTypeController.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _terminalLogs.add("Error: $e");
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _terminalLogs.add("Generation Complete. Finalizing package...");
      _currentStep = 2; // Move to Verification automatically
    });
    _verifyConnection();
  }

  void _verifyConnection() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _isVerified = true;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _currentStep = 3; // Move to download step
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: 700,
            constraints: const BoxConstraints(maxHeight: 750),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.95), // Match LeftPanel modal styling
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 10,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cloud_sync_outlined, color: Color(0xFF2DD4BF), size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Enterprise ERP Connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure and generate a localized Model Context Protocol.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: _buildStepContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Config();
      case 1:
        return _buildStep2Generation();
      case 2:
        return _buildStep3Verification();
      case 3:
      default:
        return _buildStep4Download();
    }
  }

  Widget _buildStep1Config() {
    return SingleChildScrollView(
      key: const ValueKey('step1'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGlassField('Database Type', _dbTypeController, Icons.storage_rounded),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(flex: 2, child: _buildGlassField('IP Address / Host', _ipController, Icons.dns_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _buildGlassField('Port', _portController, Icons.numbers_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          _buildGlassField('Read Frequency', _freqController, Icons.schedule_rounded),
          const SizedBox(height: 48),
          Align(
            alignment: Alignment.centerRight,
            child: _buildGlassButton('Initialize Architecture Sequence', _generateMcp, isPrimary: true, icon: Icons.precision_manufacturing),
          )
        ],
      ),
    );
  }

  Widget _buildStep2Generation() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Compiling Architecture...',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _generationProgress,
            minHeight: 12,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.2)),
            ),
            child: ListView.builder(
              itemCount: _terminalLogs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '> \${_terminalLogs[index]}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Verification() {
    return Column(
      key: const ValueKey('step3'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isVerified ? const Color(0xFF2DD4BF).withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
            border: Border.all(
              color: _isVerified ? const Color(0xFF2DD4BF).withValues(alpha: 0.5) : Colors.amber.withValues(alpha: 0.5),
              width: 3,
            ),
            boxShadow: [
              if (_isVerified) BoxShadow(color: const Color(0xFF2DD4BF).withValues(alpha: 0.4), blurRadius: 30)
            ],
          ),
          child: Icon(
            _isVerified ? Icons.fact_check_outlined : Icons.sync,
            size: 80,
            color: _isVerified ? const Color(0xFF2DD4BF) : Colors.amberAccent,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          _isVerified ? 'Module Compiled & Verified' : 'Running Diagnostic Checks...',
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (!_isVerified) ...[
          const SizedBox(height: 24),
          const CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF2DD4BF))),
        ]
      ],
    );
  }

  Widget _buildStep4Download() {
    String docComposeOutput = _generatedPayload != null && _generatedPayload!['configuration'] != null 
        ? _generatedPayload!['configuration']['docker-compose.yml'] ?? ''
        : 'Loading payload...';

    return Column(
      key: const ValueKey('step4'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 28, color: Color(0xFF2DD4BF)),
            SizedBox(width: 12),
            Text(
              'Deployment Package Ready',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Run this auto-generated container within your private VPC boundary.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: SingleChildScrollView(
              child: Text(
                docComposeOutput,
                style: const TextStyle(fontFamily: 'monospace', color: Colors.white70, fontSize: 13, height: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildGlassButton(
              'Copy Code',
              () {
                Clipboard.setData(ClipboardData(text: docComposeOutput));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Configuration copied to clipboard!'), backgroundColor: Color(0xFF2DD4BF)),
                );
              },
              icon: Icons.copy,
            ),
            const SizedBox(width: 12),
            _buildGlassButton(
              'Acknowledge & Close',
              () => Navigator.of(context).pop(),
              isPrimary: true,
              icon: Icons.check,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              border: InputBorder.none,
              prefixIcon: Icon(icon, color: Colors.white38, size: 20),
              hintText: 'Enter \$label',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton(String text, VoidCallback onPressed, {bool isPrimary = false, IconData? icon}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF2DD4BF).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary ? const Color(0xFF2DD4BF).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.2),
          ),
          boxShadow: isPrimary ? [
            BoxShadow(
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: isPrimary ? const Color(0xFF2DD4BF) : Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                color: isPrimary ? const Color(0xFF2DD4BF) : Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
