import 'inclusion_model.dart';

/// Full package shape (with its Inclusion badges) — GET /services/packages
/// ?serviceId= and GET /services/packages/{id}. Mirrors
/// RentNearBy.Core.DTOs.Responses.ServicePackageDto field-for-field.
///
/// Pricing semantics (confirmed, copied field-for-field from the entity's
/// own doc comment — NOT the same role assignment as CoinPlan/
/// go_live_plan_sheet.dart, where the naming is reversed):
///   - price == null            -> "Get Custom Quote" (Diet Plans/Financial
///     Planning packages never render a rupee amount).
///   - price set                -> the actual/current amount, rendered as
///     "Starting at ₹X" when isStartingAtPrice is true, otherwise a bare
///     "₹X".
///   - originalPrice + discountPercent set (price also set) -> originalPrice
///     is the pre-discount "was" price, shown struck through next to the
///     "X% Savings" badge. Independent of isStartingAtPrice — both can be
///     true/set at once.
class ServicePackageModel {
  final String id;
  final String serviceId;
  final String name;
  final int? price;
  final int? originalPrice;
  final int? discountPercent;
  final bool isStartingAtPrice;
  final int? durationDays;
  final int? durationNights;
  final String? priceUnit;
  final String thumbnailUrl;
  final int sortOrder;
  final bool isFeatured;
  final bool isActive;
  final List<InclusionModel> inclusions;

  ServicePackageModel({
    required this.id,
    required this.serviceId,
    required this.name,
    required this.price,
    required this.originalPrice,
    required this.discountPercent,
    required this.isStartingAtPrice,
    required this.durationDays,
    required this.durationNights,
    required this.priceUnit,
    required this.thumbnailUrl,
    required this.sortOrder,
    required this.isFeatured,
    required this.isActive,
    required this.inclusions,
  });

  factory ServicePackageModel.fromJson(Map<String, dynamic> json) => ServicePackageModel(
        id: json['id'] as String,
        serviceId: json['serviceId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toInt(),
        originalPrice: (json['originalPrice'] as num?)?.toInt(),
        discountPercent: (json['discountPercent'] as num?)?.toInt(),
        isStartingAtPrice: json['isStartingAtPrice'] == true,
        durationDays: (json['durationDays'] as num?)?.toInt(),
        durationNights: (json['durationNights'] as num?)?.toInt(),
        priceUnit: json['priceUnit'] as String?,
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isFeatured: json['isFeatured'] == true,
        isActive: json['isActive'] == true,
        inclusions: (json['inclusions'] as List? ?? [])
            .map((e) => InclusionModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
