/// One append-only ledger entry in an Inquiry's status timeline — mirrors
/// RentNearBy.Core.DTOs.Responses.InquiryStatusHistoryDto field-for-field.
/// Embedded inside InquiryDetailModel.statusHistory, never fetched standalone
/// (matches CoinTransactionModel's shape, not a separately-paginated list).
class InquiryStatusHistoryModel {
  final String id;
  final String inquiryId;
  final String status;
  final String? changedByAdminId;
  final String? changedByAdminName;
  final String? note;
  final DateTime createdAt;

  InquiryStatusHistoryModel({
    required this.id,
    required this.inquiryId,
    required this.status,
    required this.changedByAdminId,
    required this.changedByAdminName,
    required this.note,
    required this.createdAt,
  });

  factory InquiryStatusHistoryModel.fromJson(Map<String, dynamic> json) => InquiryStatusHistoryModel(
        id: json['id'] as String,
        inquiryId: json['inquiryId'] as String? ?? '',
        status: json['status'] as String? ?? '',
        changedByAdminId: json['changedByAdminId'] as String?,
        changedByAdminName: json['changedByAdminName'] as String?,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
