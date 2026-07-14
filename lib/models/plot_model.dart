import '../config/app_constants.dart';

String _formatArea(double value, String unit) {
  final display = value == value.truncate() ? value.toInt().toString() : value.toString();
  return '$display $unit';
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
    'bigha' => areaValue * 27000,
    'acre'  => areaValue * 43560,
    'nali'  => areaValue * 2152.78,
    _       => areaValue,
  };

  String get areaDisplay => _formatArea(areaValue, areaUnit);
}

/// "Find Near Me" tour result — same shape as [NearbyPlotModel] plus
/// [plotTypeId], needed so a tour started under a type filter can hand off
/// into View All pre-filtered to the same type.
class NearMePlotModel {
  final String id;
  final double areaValue;
  final String areaUnit;
  final String plotTypeId;
  final String plotType;
  final double latitude;
  final double longitude;
  final String? thumbnailUrl;
  final String? ownerName;
  final String? ownerPhone;
  final double distanceKm;
  final bool isActive;

  NearMePlotModel({
    required this.id,
    required this.areaValue,
    required this.areaUnit,
    required this.plotTypeId,
    required this.plotType,
    required this.latitude,
    required this.longitude,
    this.thumbnailUrl,
    this.ownerName,
    this.ownerPhone,
    required this.distanceKm,
    required this.isActive,
  });

  factory NearMePlotModel.fromJson(Map<String, dynamic> json) => NearMePlotModel(
        id: json['id'],
        areaValue: (json['areaValue'] as num).toDouble(),
        areaUnit: json['areaUnit'],
        plotTypeId: json['plotTypeId'],
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
    'bigha' => areaValue * 27000,
    'acre'  => areaValue * 43560,
    'nali'  => areaValue * 2152.78,
    _       => areaValue,
  };

  String get areaDisplay => _formatArea(areaValue, areaUnit);
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
  final bool hasReported;
  final int pendingReportCount;

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
    this.hasReported = false,
    this.pendingReportCount = 0,
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
        hasReported: json['hasReported'] ?? false,
        pendingReportCount: json['pendingReportCount'] ?? 0,
      );

  String get areaDisplay => _formatArea(areaValue, areaUnit);
}
