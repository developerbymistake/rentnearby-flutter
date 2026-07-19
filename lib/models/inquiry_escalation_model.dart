/// A consumer's self-service "report an issue with my agent" record — mirrors
/// RentNearBy.Core.DTOs.Responses.InquiryEscalationDto field-for-field. Never seen by the assigned
/// agent(s), only the reporting consumer (their own inquiry) and Admin.
class InquiryEscalationModel {
  final String id;
  final String reason;
  final String? note;
  final String status; // 'Pending' | 'Resolved'
  final DateTime createdAt;
  final DateTime? resolvedAt;

  InquiryEscalationModel({
    required this.id,
    required this.reason,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.resolvedAt,
  });

  factory InquiryEscalationModel.fromJson(Map<String, dynamic> json) => InquiryEscalationModel(
        id: json['id'] as String,
        reason: json['reason'] as String? ?? '',
        note: json['note'] as String?,
        status: json['status'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        resolvedAt: json['resolvedAt'] == null ? null : DateTime.parse(json['resolvedAt'] as String),
      );
}
