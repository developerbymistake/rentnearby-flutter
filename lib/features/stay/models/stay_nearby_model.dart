import '../../../config/app_constants.dart';

class StayNearbyModel {
  final String id;
  final String? name;
  final String? stayTypeName;
  final double latitude;
  final double longitude;
  final int? minPricePerNight;
  final String? thumbnailUrl;
  final double distanceKm;
  final String? ownerName;
  final String? ownerPhone;
  final bool isActive;
  final bool isFeatured;

  StayNearbyModel({
    required this.id,
    this.name,
    this.stayTypeName,
    required this.latitude,
    required this.longitude,
    this.minPricePerNight,
    this.thumbnailUrl,
    required this.distanceKm,
    this.ownerName,
    this.ownerPhone,
    required this.isActive,
    this.isFeatured = false,
  });

  String get title => (name == null || name!.isEmpty) ? 'Stay' : name!;

  factory StayNearbyModel.fromJson(Map<String, dynamic> json) => StayNearbyModel(
        id: json['id'] as String,
        name: json['name'] as String?,
        stayTypeName: json['stayTypeName'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        minPricePerNight: (json['minPricePerNight'] as num?)?.toInt(),
        thumbnailUrl: json['thumbnailUrl'] == null
            ? null
            : json['thumbnailUrl'].toString().startsWith('http')
                ? json['thumbnailUrl'] as String
                : '${AppConstants.serverUrl}${json['thumbnailUrl']}',
        distanceKm: (json['distanceKm'] as num).toDouble(),
        ownerName: json['ownerName'] as String?,
        ownerPhone: json['ownerPhone'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        isFeatured: json['isFeatured'] == true,
      );
}
