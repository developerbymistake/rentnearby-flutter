/// Row shape for "My Inquiries" (GET /inquiries/mine) — a flat, un-paginated
/// list (the whole catalog/lead-volume for one consumer is small, unlike the
/// admin-side paged list). Mirrors
/// RentNearBy.Core.DTOs.Responses.InquiryListItemDto field-for-field.
/// ServiceCategoryName is what the "My Inquiries" row's small category badge
/// (e.g. "Char Dham Yatra" vs "Yoga & Diet") is derived from — this is a
/// SHARED list across all categories, no per-category tab split.
class InquiryModel {
  final String id;
  final String serviceId;
  final String serviceName;
  final String serviceCategoryId;
  final String serviceCategoryName;
  final String servicePackageId;
  final String servicePackageName;
  final String fullName;
  final String mobile;
  final String status;
  // Multiple Agents can be assigned simultaneously — 0 means unassigned. Full names only live on
  // the Detail shape (InquiryDetailModel.assignedAgents).
  final int assignedAgentCount;
  // True while a "report an issue with my agent" is awaiting Admin review. Drives the "Report
  // under review" chip on the consumer's own My Inquiries row (see my_inquiries_screen.dart).
  final bool hasPendingEscalation;
  final DateTime createdAt;
  final DateTime updatedAt;

  InquiryModel({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.serviceCategoryId,
    required this.serviceCategoryName,
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
        serviceCategoryId: serviceCategoryId,
        serviceCategoryName: serviceCategoryName,
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
        serviceCategoryId: json['serviceCategoryId'] as String? ?? '',
        serviceCategoryName: json['serviceCategoryName'] as String? ?? '',
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
