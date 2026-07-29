/// Row shape for "My Enquiries" (GET /enquiries/mine) — a flat, un-paginated
/// list (the whole catalog/lead-volume for one consumer is small, unlike the
/// admin-side paged list). Mirrors
/// RentNearBy.Core.DTOs.Responses.EnquiryListItemDto field-for-field.
/// ServiceCategoryName is what the "My Enquiries" row's small category badge
/// (e.g. "Char Dham Yatra" vs "Yoga & Diet") is derived from — this is a
/// SHARED list across all categories, no per-category tab split.
class EnquiryModel {
  final String id;
  final String serviceId;
  final String serviceName;
  final String serviceCategoryId;
  final String serviceCategoryName;
  // Admin-editable word shown instead of "Agent" for this category (e.g. "Travel Expert",
  // "Instructor") — see RoleLabelFormat for pluralization/article helpers.
  final String agentRoleLabel;
  final String servicePackageId;
  final String servicePackageName;
  final String fullName;
  final String mobile;
  final String status;
  // Multiple Agents can be assigned simultaneously — 0 means unassigned. Full names only live on
  // the Detail shape (EnquiryDetailModel.assignedAgents).
  final int assignedAgentCount;
  // True while a "report an issue with my agent" is awaiting Admin review. Drives the "Report
  // under review" chip on the consumer's own My Enquiries row (see my_enquiries_screen.dart).
  final bool hasPendingEscalation;
  final DateTime createdAt;
  final DateTime updatedAt;

  EnquiryModel({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.serviceCategoryId,
    required this.serviceCategoryName,
    required this.agentRoleLabel,
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

  /// Used only by EnquiryController.applyStatusUpdate() to patch a single
  /// already-loaded row in place — never constructed directly by a screen.
  EnquiryModel copyWith({
    String? status,
    int? assignedAgentCount,
    bool? hasPendingEscalation,
    DateTime? updatedAt,
  }) =>
      EnquiryModel(
        id: id,
        serviceId: serviceId,
        serviceName: serviceName,
        serviceCategoryId: serviceCategoryId,
        serviceCategoryName: serviceCategoryName,
        agentRoleLabel: agentRoleLabel,
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

  factory EnquiryModel.fromJson(Map<String, dynamic> json) => EnquiryModel(
        id: json['id'] as String,
        serviceId: json['serviceId'] as String? ?? '',
        serviceName: json['serviceName'] as String? ?? '',
        serviceCategoryId: json['serviceCategoryId'] as String? ?? '',
        serviceCategoryName: json['serviceCategoryName'] as String? ?? '',
        agentRoleLabel: json['serviceCategoryAgentRoleLabel'] as String? ?? 'Agent',
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
