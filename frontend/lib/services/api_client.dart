import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/tradeoff_models.dart';
import '../models/disruption_models.dart';

final apiClientProvider = Provider((ref) => ApiClient());

class ApiClient {
  String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api/v1';

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

  // --- New Methods for Module 2.5 and 2.6 ---

  Future<TradeoffAnalysisResponse> computeTradeoffs(TradeoffRequest request) async {
    final response = await http.post(
      Uri.parse('\$baseUrl/tradeoffs/compute'),
      headers: {
        'Content-Type': 'application/json',
        'X-Org-Id': request.orgId,
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      return TradeoffAnalysisResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to compute tradeoffs: \${response.body}');
    }
  }

  Future<List<MacroEnvSignalResponse>> getMacroSignals(String orgId, [String? countryCode]) async {
    var uri = Uri.parse('\$baseUrl/macro-env/signals?org_id=\$orgId');
    if (countryCode != null) {
      uri = Uri.parse('\$baseUrl/macro-env/signals?org_id=\$orgId&country_code=\$countryCode');
    }

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Org-Id': orgId,
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((j) => MacroEnvSignalResponse.fromJson(j)).toList();
    } else {
      throw Exception('Failed to fetch macro signals: \${response.body}');
    }
  }
}
