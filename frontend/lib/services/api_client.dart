import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider((ref) => ApiClient());

class ApiClient {
  Future<Map<String, dynamic>> ingestUnstructured(String fileName, List<int> bytes) async {
    // Simulate network delay for unstructured ingestion
    await Future.delayed(const Duration(seconds: 2));
    
    // Return a structured test case matching the AIExtractionResult schema
    return {
      "confidence": 0.94,
      "nodes": [
        {
          "node_id": "EXTRACTED-NODE-01",
          "name": "\${fileName.replaceAll(RegExp(r'\\.[^.]*\$'), '')} - Extraction",
          "type": "warehouse",
          "location": {
            "lat": 34.0522,
            "lng": -118.2437
          },
          "status": "operational"
        }
      ]
    };
  }

  Future<Map<String, dynamic>> generateMcp(Map<String, String> config) async {
    // Simulate network delay for MCP generation
    await Future.delayed(const Duration(seconds: 3));
    
    // Return a structured test case matching the MCPSpecRequest response
    String dockerComposeYml = '''version: '3.8'
services:
  mcp_shock_absorber:
    image: curoot/mcp-connector:latest
    environment:
      - TARGET_DB_TYPE=\${TARGET_DB_TYPE}
      - TARGET_DB_IP=\${TARGET_DB_IP}
      - SYNC_FREQ=60
      - INGESTION_WEBHOOK=https://api.curoot.dev/v1/ingestion/telemetry
    volumes:
      - mcp_local_buffer:/app/buffer
volumes:
  mcp_local_buffer:''';

    return {
      "status": "success",
      "message": "MCP Config generated for test case.",
      "configuration": {
        "docker-compose.yml": dockerComposeYml,
        "instructions": "Place these files locally and run 'docker-compose up -d'."
      }
    };
  }
}
