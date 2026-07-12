class ListingReportModel {
  final String id;
  final String listingId;
  final String listingType; // 'Room' | 'Plot'
  final String reasonName;
  final String details;
  final String status; // 'Pending' | 'Resolved'
  final String? resolutionAction;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  ListingReportModel({
    required this.id,
    required this.listingId,
    required this.listingType,
    required this.reasonName,
    required this.details,
    required this.status,
    this.resolutionAction,
    required this.createdAt,
    this.resolvedAt,
  });

  factory ListingReportModel.fromJson(Map<String, dynamic> json) => ListingReportModel(
        id: json['id'],
        listingId: json['listingId'],
        listingType: json['listingType'],
        reasonName: json['reasonName'] ?? '',
        details: json['details'] ?? '',
        status: json['status'] ?? 'Pending',
        resolutionAction: json['resolutionAction'],
        createdAt: DateTime.parse(json['createdAt']),
        resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt']) : null,
      );
}
