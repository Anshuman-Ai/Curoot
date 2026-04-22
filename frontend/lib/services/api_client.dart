import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/tradeoff_models.dart';
import '../models/disruption_models.dart';

final apiClientProvider = Provider((ref) => ApiClient());

class ApiClient {
  String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8000/api/v1';

  Future<Map<String, dynamic>> ingestUnstructured(String fileName, List<int> bytes) async {
    var uri = Uri.parse('$baseUrl/ingestion/unstructured');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final response = await request.send();
    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      return jsonDecode(body);
    } else {
      throw Exception('Failed to ingest unstructured file. Status: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> generateMcp(Map<String, String> config) async {
    final response = await http.post(
      Uri.parse('$baseUrl/mcp_mgr/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'db_type': config['dbType'],
        'ip_address': config['ip'],
        'table_name': config['table'] ?? 'default_table',
        'sync_frequency_seconds': int.tryParse(config['freq'] ?? '60') ?? 60,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to generate MCP configuration. Status: ${response.statusCode} - ${response.body}');
    }
  }

  // --- New Methods for Module 2.5 and 2.6 ---

  Future<TradeoffAnalysisResponse> computeTradeoffs(TradeoffRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tradeoffs/compute'),
      headers: {
        'Content-Type': 'application/json',
        'X-Org-Id': request.orgId,
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      return TradeoffAnalysisResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to compute tradeoffs: ${response.body}');
    }
  }

  Future<List<MacroEnvSignalResponse>> getMacroSignals(String orgId, [String? countryCode]) async {
    var uri = Uri.parse('$baseUrl/macro-env/signals?org_id=$orgId');
    if (countryCode != null) {
      uri = Uri.parse('$baseUrl/macro-env/signals?org_id=$orgId&country_code=$countryCode');
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
      throw Exception('Failed to fetch macro signals: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> searchDiscoveryNodes({
    required String query,
    required String orgId,
    double radius = 50.0,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/discovery/search'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'query': query,
        'organization_id': orgId,
        'radius': radius,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to search discovery nodes: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> sendDirectInvite({
    required String orgId,
    required String name,
    required String email,
    required String connectionType,
    double? lat,
    double? lon,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/invitations/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'organization_id': orgId,
        'name': name,
        'email': email,
        'connection_type': connectionType,
        'lat': lat,
        'lon': lon,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send direct invite: ${response.body}');
    }
  }

  Future<List<dynamic>> fetchCommunityTemplates() async {
    final response = await http.get(Uri.parse('$baseUrl/marketplace/templates'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load templates');
    }
  }

  Future<Map<String, dynamic>> autoApplyTemplate(String templateId, String orgId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/marketplace/auto-apply'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'template_id': templateId,
        'organization_id': orgId,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 202) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to auto-apply template');
    }
  }
}
