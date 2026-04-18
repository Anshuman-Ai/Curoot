class TradeoffRequest {
  final String currentNodeId;
  final String alternativeNodeId;
  final String orgId;
  final String disruptionAlertId;

  TradeoffRequest({
    required this.currentNodeId,
    required this.alternativeNodeId,
    required this.orgId,
    required this.disruptionAlertId,
  });

  Map<String, dynamic> toJson() {
    return {
      'current_node_id': currentNodeId,
      'alternative_node_id': alternativeNodeId,
      'org_id': orgId,
      'disruption_alert_id': disruptionAlertId,
    };
  }
}

class MetricResult {
  final String metricType;
  final double currentValue;
  final double alternativeValue;
  final double delta;
  final String unit;
  final bool isImprovement;

  MetricResult({
    required this.metricType,
    required this.currentValue,
    required this.alternativeValue,
    required this.delta,
    required this.unit,
    required this.isImprovement,
  });

  factory MetricResult.fromJson(Map<String, dynamic> json) {
    return MetricResult(
      metricType: json['metric_type'],
      currentValue: (json['current_value'] as num).toDouble(),
      alternativeValue: (json['alternative_value'] as num).toDouble(),
      delta: (json['delta'] as num).toDouble(),
      unit: json['unit'],
      isImprovement: json['is_improvement'],
    );
  }
}

class TradeoffAnalysisResponse {
  final String analysisId;
  final String orgId;
  final String currentNodeId;
  final String alternativeNodeId;
  final String disruptionAlertId;
  final List<MetricResult> metrics;
  final String overallRecommendation;
  final double recommendationConfidence;

  TradeoffAnalysisResponse({
    required this.analysisId,
    required this.orgId,
    required this.currentNodeId,
    required this.alternativeNodeId,
    required this.disruptionAlertId,
    required this.metrics,
    required this.overallRecommendation,
    required this.recommendationConfidence,
  });

  factory TradeoffAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return TradeoffAnalysisResponse(
      analysisId: json['analysis_id'],
      orgId: json['org_id'],
      currentNodeId: json['current_node_id'],
      alternativeNodeId: json['alternative_node_id'],
      disruptionAlertId: json['disruption_alert_id'],
      metrics: (json['metrics'] as List).map((m) => MetricResult.fromJson(m)).toList(),
      overallRecommendation: json['overall_recommendation'],
      recommendationConfidence: (json['recommendation_confidence'] as num).toDouble(),
    );
  }
}
