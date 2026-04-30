// lib/core/risk_submission_model.dart

class RiskAnswerPayload {
  final int questionId;
  final int optionId;

  const RiskAnswerPayload({
    required this.questionId,
    required this.optionId,
  });

  Map<String, dynamic> toJson() => {
        // MUST match backend Zod schema
        'questionId': questionId,
        'optionId': optionId,
      };
}


/// Response model for a submitted assessment
/// This matches the backend response you showed:
/// {
///   "id": 32,
///   "toolId": 1,
///   "total": 60,
///   "band": "High",
///   "submittedAt": "2025-09-04T05:18:48.000Z",
///   "message": "Your risk ...",
///   "message_bn": "আপনার ঝুঁকি ..."
/// }
class RiskSubmissionResult {
  final int id;
  final int toolId;
  final int total;
  final String band;
  final String message;
  final String messageBn;
  final DateTime? submittedAt;

  const RiskSubmissionResult({
    required this.id,
    required this.toolId,
    required this.total,
    required this.band,
    required this.message,
    required this.messageBn,
    required this.submittedAt,
  });

  factory RiskSubmissionResult.fromJson(Map<String, dynamic> json) {
    return RiskSubmissionResult(
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'toolId': toolId,
        'total': total,
        'band': band,
        'message': message,
        'message_bn': messageBn,
        'submittedAt': submittedAt?.toIso8601String(),
      };
}
