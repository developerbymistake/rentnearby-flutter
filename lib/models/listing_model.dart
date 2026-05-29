import '../config/app_constants.dart';

class ListingModel {
  final String id;
  final String userId;
  final String? description;
  final int? priceMonthly;
  final double latitude;
  final double longitude;
  final String? address;
  final String districtId;
  final String? districtName;
  final String? cityId;
  final String? cityName;
  final String roomTypeId;
  final String? roomTypeName;
  final bool isActive;
  final String? ownerName;
  final String? ownerPhone;
  final String? ownerEmail;
  final List<String> photos;
  final DateTime createdAt;
  final DateTime? validUntil;

  ListingModel({
    required this.id,
    required this.userId,
    this.description,
    this.priceMonthly,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.districtId,
    this.districtName,
    this.cityId,
    this.cityName,
    required this.roomTypeId,
    this.roomTypeName,
    required this.isActive,
    this.ownerName,
    this.ownerPhone,
    this.ownerEmail,
    required this.photos,
    required this.createdAt,
    this.validUntil,
  });

  factory ListingModel.fromJson(Map<String, dynamic> json) => ListingModel(
        id: json['id'],
        userId: json['userId'],
        description: json['description'],
        priceMonthly: json['priceMonthly'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        address: json['address'],
        districtId: json['districtId'],
        districtName: json['districtName'],
        cityId: json['cityId'],
        cityName: json['cityName'],
        roomTypeId: json['roomTypeId'],
        roomTypeName: json['roomTypeName'],
        isActive: json['isActive'] ?? true,
        ownerName: json['ownerName'],
        ownerPhone: json['ownerPhone'],
        ownerEmail: json['ownerEmail'],
        photos: (json['photos'] as List? ?? [])
            .map((p) => p.toString().startsWith('http') ? p.toString() : '${AppConstants.serverUrl}$p')
            .toList(),
        createdAt: DateTime.parse(json['createdAt']),
        validUntil: json['validUntil'] != null
            ? DateTime.parse(json['validUntil'] as String)
            : null,
      );

  String get priceDisplay =>
      priceMonthly != null ? '₹${_formatPrice(priceMonthly!)}/mo' : 'Price on request';

  String get shortPrice =>
      priceMonthly != null ? '₹${_formatPrice(priceMonthly!)}' : 'N/A';

  String _formatPrice(int price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(price % 1000 == 0 ? 0 : 1)}k';
    }
    return price.toString();
  }
}

class NearbyListingModel {
  final String id;
  final int? priceMonthly;
  final double latitude;
  final double longitude;
  final String? roomTypeName;
  final String? ownerName;
  final String? ownerPhone;
  final String? thumbnailUrl;
  final double distanceKm;
  final bool isActive;

  NearbyListingModel({
    required this.id,
    this.priceMonthly,
    required this.latitude,
    required this.longitude,
    this.roomTypeName,
    this.ownerName,
    this.ownerPhone,
    this.thumbnailUrl,
    required this.distanceKm,
    required this.isActive,
  });

  factory NearbyListingModel.fromJson(Map<String, dynamic> json) => NearbyListingModel(
        id: json['id'],
        priceMonthly: json['priceMonthly'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        roomTypeName: json['roomTypeName'],
        ownerName: json['ownerName'],
        ownerPhone: json['ownerPhone'],
        thumbnailUrl: json['thumbnailUrl'] == null
            ? null
            : json['thumbnailUrl'].toString().startsWith('http')
                ? json['thumbnailUrl']
                : '${AppConstants.serverUrl}${json['thumbnailUrl']}',
        distanceKm: (json['distanceKm'] as num).toDouble(),
        isActive: json['isActive'] ?? true,
      );

  String get shortPrice =>
      priceMonthly != null ? '₹${_formatPrice(priceMonthly!)}' : 'N/A';

  String _formatPrice(int price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(price % 1000 == 0 ? 0 : 1)}k';
    }
    return price.toString();
  }
}
