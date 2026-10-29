import 'taxi_owner_model.dart';

class TaxiDetailModel {
  final String id;
  final String userId;
  final String? slug;
  final String driverName;
  final String vehicleTypeName;
  final String? vehicleCategory;
  final int? seats;
  final String? numberPlate;
  final String plateDisplay;
  final String? platePhotoUrl;
  final double? latitude;
  final double? longitude;
  final String? districtName;
  final String? cityName;
  final List<TaxiRouteModel> routes;
  final int? minFare;
  final bool isAvailable;
  final String? contactPhone;
  final String? whatsAppNumber;
  final bool hasReported;
  final DateTime createdAt;

  TaxiDetailModel.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        userId = json['userId'] as String? ?? '',
        slug = json['slug'] as String?,
        driverName = json['driverName'] as String? ?? 'Driver',
        vehicleTypeName = json['vehicleTypeName'] as String? ?? 'Taxi',
        vehicleCategory = json['vehicleCategory'] as String?,
        seats = (json['seats'] as num?)?.toInt(),
        numberPlate = json['numberPlate'] as String?,
        plateDisplay = json['plateDisplay'] as String? ?? '',
        platePhotoUrl = json['platePhotoUrl'] as String?,
        latitude = (json['latitude'] as num?)?.toDouble(),
        longitude = (json['longitude'] as num?)?.toDouble(),
        districtName = json['districtName'] as String?,
        cityName = json['cityName'] as String?,
        routes = ((json['routes'] as List?) ?? const [])
            .map((e) => TaxiRouteModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        minFare = (json['minFare'] as num?)?.toInt(),
        isAvailable = json['isAvailable'] as bool? ?? false,
        contactPhone = _nonEmpty(json['contactPhone']),
        whatsAppNumber = _nonEmpty(json['whatsAppNumber']),
        hasReported = json['hasReported'] as bool? ?? false,
        createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();

  static String? _nonEmpty(Object? v) => v is String && v.isNotEmpty ? v : null;

  bool get hasContact => contactPhone != null;

  String get locality => [cityName, districtName].where((e) => e != null && e.isNotEmpty).join(', ');
}
