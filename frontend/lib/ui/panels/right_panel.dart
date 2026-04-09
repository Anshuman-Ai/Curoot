import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RightPanel extends ConsumerWidget {
  const RightPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 320, // Fixed width
      decoration: BoxDecoration(
        color: const Color(0xFF161618), // Dark charcoal
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'AI Tradeoffs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF39FF14),
                  size: 20,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          
          // Empty Content Area
          Expanded(
            child: Container(),
          ),
        ],
      ),
    );
  }
}
