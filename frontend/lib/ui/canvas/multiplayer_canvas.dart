import 'package:flutter/material.dart';

class MultiplayerCanvas extends StatelessWidget {
  const MultiplayerCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Supply Chain Canvas'),
        backgroundColor: const Color(0xFF161616),
      ),
      body: const Center(
        child: Text(
          'Multiplayer Canvas / Main Workspace',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
