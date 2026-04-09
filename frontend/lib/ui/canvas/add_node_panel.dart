import 'package:flutter/material.dart';

class AddNodePanel extends StatelessWidget {
  const AddNodePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48.0, left: 16.0, right: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Node',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Discovery & Onboarding workflow',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
