class TaxiBrowseItem {
  final String id;
  final String driverName;
  final String vehicleTypeName;
  final String? vehicleCategory;
  final int? seats;
  final String plateDisplay;
  final String? cityName;
  final String? districtName;
  final int? minFare;
  final int routeCount;
  final int? matchedFare;
  final String? matchedFromName;
  final String? matchedToName;
  final String? matchedTripType;
  final bool matchReversed;
  final DateTime createdAt;
  final bool isFeatured;

  const TaxiBrowseItem({
    required this.id,
    required this.driverName,
    required this.vehicleTypeName,
    this.vehicleCategory,
    this.seats,
    required this.plateDisplay,
    this.cityName,
    this.districtName,
    this.minFare,
    required this.routeCount,
    this.matchedFare,
    this.matchedFromName,
    this.matchedToName,
    this.matchedTripType,
    required this.matchReversed,
    required this.createdAt,
    this.isFeatured = false,
  });

  factory TaxiBrowseItem.fromJson(Map<String, dynamic> json) => TaxiBrowseItem(
        id: json['id'] as String,
        driverName: json['driverName'] as String? ?? 'Driver',
        vehicleTypeName: json['vehicleTypeName'] as String? ?? 'Taxi',
        vehicleCategory: json['vehicleCategory'] as String?,
        seats: (json['seats'] as num?)?.toInt(),
        plateDisplay: json['plateDisplay'] as String? ?? '',
        cityName: json['cityName'] as String?,
        districtName: json['districtName'] as String?,
        minFare: (json['minFare'] as num?)?.toInt(),
        routeCount: (json['routeCount'] as num?)?.toInt() ?? 0,
        matchedFare: (json['matchedFare'] as num?)?.toInt(),
        matchedFromName: json['matchedFromName'] as String?,
        matchedToName: json['matchedToName'] as String?,
        matchedTripType: json['matchedTripType'] as String?,
        matchReversed: json['matchReversed'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        isFeatured: json['isFeatured'] == true,
      );

  bool get isMatch => matchedFare != null;

  String get locality => cityName ?? districtName ?? '';
}
