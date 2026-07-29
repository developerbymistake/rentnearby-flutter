import 'agent_model.dart';
import 'enquiry_escalation_model.dart';
import 'enquiry_status_history_model.dart';

/// Full Enquiry Detail shape — GET /enquiries/{id}, and the response body of
/// POST /enquiries (create). Mirrors
/// RentNearBy.Core.DTOs.Responses.EnquiryDetailDto field-for-field, including
/// the embedded AssignedAgents (identity-only cards — an Enquiry can have
/// multiple simultaneous Agents, see AgentModel's own doc comment for why
/// there's no Call/WhatsApp here) and the full append-only StatusHistory
/// ledger (for the vertical status stepper — Submitted -> Contacted ->
/// Confirmed, with Cancelled/Rejected as terminal red states).
class EnquiryDetailModel {
  final String id;
  final String userId;
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
  final String? email;
  final DateTime? preferredDateOrTripStart;
  final int? numberOfPeople;
  final String? message;
  final String status;
  // Every Agent currently assigned — never null, empty when unassigned. An Enquiry can have
  // multiple simultaneous Agents.
  final List<AgentModel> assignedAgents;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<EnquiryStatusHistoryModel> statusHistory;
  // Newest first, never null — this consumer's own "report an issue with my agent" history.
  final List<EnquiryEscalationModel> escalations;

  bool get hasPendingEscalation => escalations.any((e) => e.status == 'Pending');

  EnquiryDetailModel({
    required this.id,
    required this.userId,
    required this.serviceId,
    required this.serviceName,
    required this.serviceCategoryId,
    required this.serviceCategoryName,
    required this.agentRoleLabel,
    required this.servicePackageId,
    required this.servicePackageName,
    required this.fullName,
    required this.mobile,
    required this.email,
    required this.preferredDateOrTripStart,
    required this.numberOfPeople,
    required this.message,
    required this.status,
    required this.assignedAgents,
    required this.createdAt,
    required this.updatedAt,
    required this.statusHistory,
    this.escalations = const [],
  });

  /// Used only by EnquiryController.applyStatusUpdate() to patch the
  /// currently-open detail screen's state from a minimal push payload
  /// (status only — the push event doesn't carry agent details/history, so
  /// those stay as last-fetched until the next explicit reload).
  EnquiryDetailModel copyWith({String? status, DateTime? updatedAt}) => EnquiryDetailModel(
        id: id,
        userId: userId,
        serviceId: serviceId,
        serviceName: serviceName,
        serviceCategoryId: serviceCategoryId,
        serviceCategoryName: serviceCategoryName,
        agentRoleLabel: agentRoleLabel,
        servicePackageId: servicePackageId,
        servicePackageName: servicePackageName,
        fullName: fullName,
        mobile: mobile,
        email: email,
        preferredDateOrTripStart: preferredDateOrTripStart,
        numberOfPeople: numberOfPeople,
        message: message,
        status: status ?? this.status,
        assignedAgents: assignedAgents,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        statusHistory: statusHistory,
        escalations: escalations,
      );

  factory EnquiryDetailModel.fromJson(Map<String, dynamic> json) => EnquiryDetailModel(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '',
        serviceId: json['serviceId'] as String? ?? '',
        serviceName: json['serviceName'] as String? ?? '',
        serviceCategoryId: json['serviceCategoryId'] as String? ?? '',
        serviceCategoryName: json['serviceCategoryName'] as String? ?? '',
        agentRoleLabel: json['serviceCategoryAgentRoleLabel'] as String? ?? 'Agent',
        servicePackageId: json['servicePackageId'] as String? ?? '',
        servicePackageName: json['servicePackageName'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        email: json['email'] as String?,
        preferredDateOrTripStart: json['preferredDateOrTripStart'] == null
            ? null
            : DateTime.parse(json['preferredDateOrTripStart'] as String),
        numberOfPeople: (json['numberOfPeople'] as num?)?.toInt(),
        message: json['message'] as String?,
        status: json['status'] as String? ?? '',
        assignedAgents: (json['assignedAgents'] as List? ?? [])
            .map((e) => AgentModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        statusHistory: (json['statusHistory'] as List? ?? [])
            .map((e) => EnquiryStatusHistoryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        escalations: (json['escalations'] as List? ?? [])
            .map((e) => EnquiryEscalationModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
