import '../config/app_constants.dart';

String _formatArea(double value, String unit) {
  final display = value == value.truncate() ? value.toInt().toString() : value.toString();
  return '$display $unit';
}

String _toSqftLabel(double value, String unit) {
  if (unit == 'sqft') return '${value.toInt()} sqft';
  final sqft = switch (unit) {
    'sqm'   => value * 10.764,
    'marla' => value * 272.25,
    'bigha' => value * 27000,
    'acre'  => value * 43560,
    'kanal' => value * 5445,
    _       => value,
  };
  if (sqft >= 100000) return '≈ ${(sqft / 100000).toStringAsFixed(1)} lakh sqft';
  final n = sqft.toInt();
  final formatted = n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return '≈ $formatted sqft';
}

class NearbyPlotModel {
  final String id;
  final double areaValue;
  final String areaUnit;
  final String plotType;
  final double latitude;
  final double longitude;
  final String? thumbnailUrl;
  final String? ownerName;
  final String? ownerPhone;
  final double distanceKm;
  final bool isActive;

  NearbyPlotModel({
    required this.id,
    required this.areaValue,
    required this.areaUnit,
    required this.plotType,
    required this.latitude,
    required this.longitude,
    this.thumbnailUrl,
    this.ownerName,
    this.ownerPhone,
    required this.distanceKm,
    required this.isActive,
  });

  factory NearbyPlotModel.fromJson(Map<String, dynamic> json) => NearbyPlotModel(
        id: json['id'],
        areaValue: (json['areaValue'] as num).toDouble(),
        areaUnit: json['areaUnit'],
        plotType: json['plotType'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        thumbnailUrl: json['thumbnailUrl'] == null
            ? null
            : json['thumbnailUrl'].toString().startsWith('http')
                ? json['thumbnailUrl']
                : '${AppConstants.serverUrl}${json['thumbnailUrl']}',
        ownerName: json['ownerName'],
        ownerPhone: json['ownerPhone'],
        distanceKm: (json['distanceKm'] as num).toDouble(),
        isActive: json['isActive'] ?? true,
      );

  double get areaSqft => switch (areaUnit) {
    'sqm'   => areaValue * 10.764,
    'marla' => areaValue * 272.25,
    'bigha' => areaValue * 27000,
    'acre'  => areaValue * 43560,
    'kanal' => areaValue * 5445,
    _       => areaValue,
  };

  String get areaDisplay => _formatArea(areaValue, areaUnit);
  String get sqftLabel => _toSqftLabel(areaValue, areaUnit);
}

class PlotModel {
  final String id;
  final String userId;
  final double areaValue;
  final String areaUnit;
  final double areaSqft;
  final String plotType;
  final String? description;
  final double latitude;
  final double longitude;
  final String? address;
  final String districtId;
  final String? districtName;
  final String? cityId;
  final String? cityName;
  final bool isActive;
  final String? ownerName;
  final String? ownerPhone;
  final List<String> photos;
  final DateTime? validUntil;
  final DateTime createdAt;

  PlotModel({
    required this.id,
    required this.userId,
    required this.areaValue,
    required this.areaUnit,
    required this.areaSqft,
    required this.plotType,
    this.description,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.districtId,
    this.districtName,
    this.cityId,
    this.cityName,
    required this.isActive,
    this.ownerName,
    this.ownerPhone,
    required this.photos,
    this.validUntil,
    required this.createdAt,
  });

  factory PlotModel.fromJson(Map<String, dynamic> json) => PlotModel(
        id: json['id'],
        userId: json['userId'],
        areaValue: (json['areaValue'] as num).toDouble(),
        areaUnit: json['areaUnit'],
        areaSqft: (json['areaSqft'] as num).toDouble(),
        plotType: json['plotType'],
        description: json['description'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        address: json['address'],
        districtId: json['districtId'],
        districtName: json['districtName'],
        cityId: json['cityId'],
        cityName: json['cityName'],
        isActive: json['isActive'] ?? false,
        ownerName: json['ownerName'],
        ownerPhone: json['ownerPhone'],
        photos: (json['photos'] as List? ?? [])
            .map((p) => p.toString().startsWith('http') ? p.toString() : '${AppConstants.serverUrl}$p')
            .toList(),
        validUntil: json['validUntil'] != null ? DateTime.parse(json['validUntil']) : null,
        createdAt: DateTime.parse(json['createdAt']),
      );

  String get areaDisplay => _formatArea(areaValue, areaUnit);
  String get sqftLabel => _toSqftLabel(areaValue, areaUnit);
}
