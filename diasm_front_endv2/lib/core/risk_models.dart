// lib/core/risk_models.dart

//import 'package:flutter/foundation.dart';

/// UI risk levels we show in the card
enum RiskLevel { low, moderate, high }

/// Map backend band string -> RiskLevel used in UI
RiskLevel mapBandToLevel(String band) {
  switch (band.toLowerCase()) {
    case 'low':
      return RiskLevel.low;
    case 'moderate':
    case 'medium':
      return RiskLevel.moderate;
    case 'high':
    default:
      return RiskLevel.high;
  }
}

/// Risk assessment model matching backend response for
/// GET /risk/assessments/latest
/// POST /risk/assessments
class RiskAssessment {
  final int id;
  final int toolId;
  final int total;
  final String band;
  final String message;
  final String messageBn;
  final DateTime? submittedAt;

  const RiskAssessment({
    required this.id,
    required this.toolId,
    required this.total,
    required this.band,
    required this.message,
    required this.messageBn,
    required this.submittedAt,
  });

  factory RiskAssessment.fromJson(Map<String, dynamic> json) {
    return RiskAssessment(
      id: json['id'] as int,
      toolId: (json['toolId'] ?? json['tool_id'] ?? 1) as int,
      total: json['total'] as int,
      band: json['band'] as String,
      message: json['message'] as String? ?? '',
      messageBn:
          json['message_bn'] as String? ?? json['messageBn'] as String? ?? '',
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'] as String)
          : (json['submitted_at'] != null
              ? DateTime.tryParse(json['submitted_at'] as String)
              : null),
    );
  }

  RiskAssessment copyWith({
    int? id,
    int? toolId,
    int? total,
    String? band,
    String? message,
    String? messageBn,
    DateTime? submittedAt,
  }) {
    return RiskAssessment(
      id: id ?? this.id,
      toolId: toolId ?? this.toolId,
      total: total ?? this.total,
      band: band ?? this.band,
      message: message ?? this.message,
      messageBn: messageBn ?? this.messageBn,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'toolId': toolId,
        'total': total,
        'band': band,
        'message': message,
        'message_bn': messageBn,
        'submittedAt': submittedAt?.toIso8601String(),
      };

  @override
  String toString() {
    return 'RiskAssessment(id: $id, toolId: $toolId, total: $total, band: $band)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RiskAssessment &&
        other.id == id &&
        other.toolId == toolId &&
        other.total == total &&
        other.band == band &&
        other.message == message &&
        other.messageBn == messageBn &&
        other.submittedAt == submittedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        toolId,
        total,
        band,
        message,
        messageBn,
        submittedAt,
      );
}
