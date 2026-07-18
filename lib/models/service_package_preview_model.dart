/// Lightweight package shape embedded in ServiceDetailModel.packages — the
/// full ServicePackageModel (with Inclusions) is only fetched once the
/// consumer drills into the Package List screen. Mirrors
/// RentNearBy.Core.DTOs.Responses.ServicePackagePreviewDto field-for-field.
class ServicePackagePreviewModel {
  final String id;
  final String name;
  final int? price;
  final int? originalPrice;
  final int? discountPercent;
  final bool isStartingAtPrice;
  final int? durationDays;
  final int? durationNights;
  final String? priceUnit;
  final String thumbnailUrl;
  final bool isFeatured;
  final int sortOrder;

  ServicePackagePreviewModel({
    required this.id,
    required this.name,
    required this.price,
    required this.originalPrice,
    required this.discountPercent,
    required this.isStartingAtPrice,
    required this.durationDays,
    required this.durationNights,
    required this.priceUnit,
    required this.thumbnailUrl,
    required this.isFeatured,
    required this.sortOrder,
  });

  factory ServicePackagePreviewModel.fromJson(Map<String, dynamic> json) => ServicePackagePreviewModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toInt(),
        originalPrice: (json['originalPrice'] as num?)?.toInt(),
        discountPercent: (json['discountPercent'] as num?)?.toInt(),
        isStartingAtPrice: json['isStartingAtPrice'] == true,
        durationDays: (json['durationDays'] as num?)?.toInt(),
        durationNights: (json['durationNights'] as num?)?.toInt(),
        priceUnit: json['priceUnit'] as String?,
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        isFeatured: json['isFeatured'] == true,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
}
