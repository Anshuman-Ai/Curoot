import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../state/canvas_provider.dart';

// ---------------------------------------------------------------------------
// Chat message model
// ---------------------------------------------------------------------------

class ChatMessage {
  final String id;
  final String senderType; // 'supplier', 'oem', 'system', 'auto_ping'
  final String content;
  final Map<String, dynamic> parsedData;
  final double parseConfidence;
  final String createdAt;

  ChatMessage({
    required this.id,
    required this.senderType,
    required this.content,
    this.parsedData = const {},
    this.parseConfidence = 0.0,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final msgType = json['message_type'] ?? json['sender_type'] ?? 'system';
    final senderMap = {
      'supplier_chat': 'supplier',
      'oem_dispatch': 'oem',
      'auto_ping': 'system',
    };
    return ChatMessage(
      id: json['id'] ?? '',
      senderType: senderMap[msgType] ?? json['sender_type'] ?? 'system',
      content: json['content'] ?? '',
      parsedData: Map<String, dynamic>.from(json['parsed_data'] ?? {}),
      parseConfidence: (json['parse_confidence'] ?? 0.0).toDouble(),
      createdAt: json['created_at'] ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// Dark Node model
// ---------------------------------------------------------------------------

class DarkNodeInfo {
  final String nodeId;
  final String nodeName;
  final double compositeScore;
  final double heartbeatConfidence;
  final String? lastHeartbeatAt;
  final bool isDarkNode;

  DarkNodeInfo({
    required this.nodeId,
    required this.nodeName,
    required this.compositeScore,
    required this.heartbeatConfidence,
    this.lastHeartbeatAt,
    required this.isDarkNode,
  });

  factory DarkNodeInfo.fromJson(Map<String, dynamic> json) {
    return DarkNodeInfo(
      nodeId: json['id']?.toString() ?? json['node_id']?.toString() ?? '',
      nodeName: json['name'] ?? json['node_name'] ?? 'Unknown',
      compositeScore: 1.0 - (json['heartbeat_confidence'] ?? 1.0).toDouble(),
      heartbeatConfidence: (json['heartbeat_confidence'] ?? 1.0).toDouble(),
      lastHeartbeatAt: json['last_heartbeat_at']?.toString(),
      isDarkNode: json['is_dark_node'] ?? false,
    );
  }
}

// ---------------------------------------------------------------------------
// Chat History Provider (per node)
// ---------------------------------------------------------------------------

final chatHistoryProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, nodeId) async {
  if (nodeId.isEmpty || nodeId == 'you' || nodeId == 'add') {
    return [];
  }
  try {
    final apiClient = ref.read(apiClientProvider);
    final data = await apiClient.fetchChatHistory(nodeId);
    final messages = data['messages'] as List<dynamic>? ?? [];
    return messages.map((m) => ChatMessage.fromJson(m)).toList();
  } catch (e) {
    debugPrint('Error fetching chat history: $e');
    return [];
  }
});

// ---------------------------------------------------------------------------
// Dark Nodes Provider
// ---------------------------------------------------------------------------

final darkNodesProvider =
    FutureProvider<List<DarkNodeInfo>>((ref) async {
  try {
    final apiClient = ref.read(apiClientProvider);
    final data = await apiClient.fetchDarkNodes(kFrontendDefaultOrgId);
    final nodes = data['dark_nodes'] as List<dynamic>? ?? [];
    return nodes.map((n) => DarkNodeInfo.fromJson(n)).toList();
  } catch (e) {
    debugPrint('Error fetching dark nodes: $e');
    return [];
  }
});

// ---------------------------------------------------------------------------
// Magic Link Provider (per node)
// ---------------------------------------------------------------------------

final magicLinkProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, nodeId) async {
  if (nodeId.isEmpty || nodeId == 'you' || nodeId == 'add') {
    return null;
  }
  if (!isValidUuid(nodeId)) return null;
  try {
    final apiClient = ref.read(apiClientProvider);
    final data = await apiClient.generateMagicLink(
      nodeIds: [nodeId],
      orgId: kFrontendDefaultOrgId,
    );
    final links = data['links'] as List<dynamic>? ?? [];
    if (links.isNotEmpty) {
      return Map<String, dynamic>.from(links.first);
    }
    return null;
  } catch (e) {
    debugPrint('Error generating magic link: $e');
    return null;
  }
});
