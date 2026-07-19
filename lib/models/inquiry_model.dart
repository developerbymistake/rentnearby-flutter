/// Row shape for "My Inquiries" (GET /inquiries/mine) — a flat, un-paginated
/// list (the whole catalog/lead-volume for one consumer is small, unlike the
/// admin-side paged list). Mirrors
/// RentNearBy.Core.DTOs.Responses.InquiryListItemDto field-for-field.
/// ServiceSectionName is what the "My Inquiries" row's small section badge
/// (e.g. "Explore Uttarakhand" vs "Expert Consultations") is derived from —
/// this is a SHARED list across both verticals, no per-vertical tab split.
class InquiryModel {
  final String id;
  final String serviceId;
  final String serviceName;
  final String serviceSectionId;
  final String serviceSectionName;
  final String servicePackageId;
  final String servicePackageName;
  final String fullName;
  final String mobile;
  final String status;
  // Multiple Agents can be assigned simultaneously — 0 means unassigned. Full names only live on
  // the Detail shape (InquiryDetailModel.assignedAgents).
  final int assignedAgentCount;
  // True while a "report an issue with my agent" is awaiting Admin review. Present since the DTO
  // shape is shared with the admin list, but not rendered on the consumer's own My Inquiries row.
  final bool hasPendingEscalation;
  final DateTime createdAt;
  final DateTime updatedAt;

  InquiryModel({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.serviceSectionId,
    required this.serviceSectionName,
    required this.servicePackageId,
    required this.servicePackageName,
    required this.fullName,
    required this.mobile,
    required this.status,
    required this.assignedAgentCount,
    required this.hasPendingEscalation,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Used only by InquiryController.applyStatusUpdate() to patch a single
  /// already-loaded row in place — never constructed directly by a screen.
  InquiryModel copyWith({
    String? status,
    int? assignedAgentCount,
    bool? hasPendingEscalation,
    DateTime? updatedAt,
  }) =>
      InquiryModel(
        id: id,
        serviceId: serviceId,
        serviceName: serviceName,
        serviceSectionId: serviceSectionId,
        serviceSectionName: serviceSectionName,
        servicePackageId: servicePackageId,
        servicePackageName: servicePackageName,
        fullName: fullName,
        mobile: mobile,
        status: status ?? this.status,
        assignedAgentCount: assignedAgentCount ?? this.assignedAgentCount,
        hasPendingEscalation: hasPendingEscalation ?? this.hasPendingEscalation,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory InquiryModel.fromJson(Map<String, dynamic> json) => InquiryModel(
        id: json['id'] as String,
        serviceId: json['serviceId'] as String? ?? '',
        serviceName: json['serviceName'] as String? ?? '',
        serviceSectionId: json['serviceSectionId'] as String? ?? '',
        serviceSectionName: json['serviceSectionName'] as String? ?? '',
        servicePackageId: json['servicePackageId'] as String? ?? '',
        servicePackageName: json['servicePackageName'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        status: json['status'] as String? ?? '',
        assignedAgentCount: (json['assignedAgentCount'] as num?)?.toInt() ?? 0,
        hasPendingEscalation: json['hasPendingEscalation'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
