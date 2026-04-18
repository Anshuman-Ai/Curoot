class MacroEnvSignalResponse {
  final String? id;
  final String countryCode;
  final String riskLevel;
  final double confidence;
  final String primaryDriver;
  final List<String> affectedNodeIds;
  final Map<String, dynamic> signalsSummary;
  final String classifiedAt;

  MacroEnvSignalResponse({
    this.id,
    required this.countryCode,
    required this.riskLevel,
    required this.confidence,
    required this.primaryDriver,
    required this.affectedNodeIds,
    required this.signalsSummary,
    required this.classifiedAt,
  });

  factory MacroEnvSignalResponse.fromJson(Map<String, dynamic> json) {
    return MacroEnvSignalResponse(
      id: json['id'],
      countryCode: json['country_code'],
      riskLevel: json['risk_level'],
      confidence: (json['confidence'] as num).toDouble(),
      primaryDriver: json['primary_driver'] ?? '',
      affectedNodeIds: (json['affected_node_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      signalsSummary: json['signals_summary'] ?? {},
      classifiedAt: json['classified_at'],
    );
  }
}

class DisruptionAlert {
  final String id;
  final String organizationId;
  final String? nodeId;
  final String? edgeId;
  final String alertType;
  final String severity;
  final Map<String, dynamic> payload;
  final String createdAt;

  DisruptionAlert({
    required this.id,
    required this.organizationId,
    this.nodeId,
    this.edgeId,
    required this.alertType,
    required this.severity,
    required this.payload,
    required this.createdAt,
  });

  factory DisruptionAlert.fromJson(Map<String, dynamic> json) {
    return DisruptionAlert(
      id: json['id'],
      organizationId: json['organization_id'],
      nodeId: json['node_id'],
      edgeId: json['edge_id'],
      alertType: json['alert_type'],
      severity: json['severity'],
      payload: json['payload'] ?? {},
      createdAt: json['created_at'],
    );
  }
}
