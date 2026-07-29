/// One append-only ledger entry in an Enquiry's status timeline — mirrors
/// RentNearBy.Core.DTOs.Responses.EnquiryStatusHistoryDto field-for-field.
/// Embedded inside EnquiryDetailModel.statusHistory, never fetched standalone
/// (matches CreditTransactionModel's shape, not a separately-paginated list).
class EnquiryStatusHistoryModel {
  final String id;
  final String enquiryId;
  final String status;
  final String? changedByAdminId;
  final String? changedByAdminName;
  final String? note;
  final DateTime createdAt;

  EnquiryStatusHistoryModel({
    required this.id,
    required this.enquiryId,
    required this.status,
    required this.changedByAdminId,
    required this.changedByAdminName,
    required this.note,
    required this.createdAt,
  });

  factory EnquiryStatusHistoryModel.fromJson(Map<String, dynamic> json) => EnquiryStatusHistoryModel(
        id: json['id'] as String,
        enquiryId: json['enquiryId'] as String? ?? '',
        status: json['status'] as String? ?? '',
        changedByAdminId: json['changedByAdminId'] as String?,
        changedByAdminName: json['changedByAdminName'] as String?,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
