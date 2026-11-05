class DistrictModel {
  final String id;
  final String name;
  final String? stateName;
  final bool isActive;
  // Null = unknown (old server or cached context); only false blocks.
  final bool? businessOnboardingEnabled;

  DistrictModel({
    required this.id,
    required this.name,
    this.stateName,
    this.isActive = true,
    this.businessOnboardingEnabled,
  });

  factory DistrictModel.fromJson(Map<String, dynamic> json) => DistrictModel(
        id: json['id'],
        name: json['name'],
        stateName: json['stateName'] as String?,
        // Absent on /locations/context (that endpoint only ever returns an
        // already-active district), present on /admin/districts.
        isActive: json['isActive'] as bool? ?? true,
        businessOnboardingEnabled: json['businessOnboardingEnabled'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'stateName': stateName,
        'isActive': isActive,
        'businessOnboardingEnabled': businessOnboardingEnabled,
      };
}

class CityModel {
  final String id;
  final String districtId;
  final String name;
  final double? latitude;
  final double? longitude;

  CityModel({required this.id, required this.districtId, required this.name, this.latitude, this.longitude});

  factory CityModel.fromJson(Map<String, dynamic> json) => CityModel(
        id: json['id'],
        districtId: json['districtId'],
        name: json['name'],
        latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
        longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'districtId': districtId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      };
}

class ReportReasonModel {
  final String id;
  final String name;

  ReportReasonModel({required this.id, required this.name});

  factory ReportReasonModel.fromJson(Map<String, dynamic> json) => ReportReasonModel(
        id: json['id'],
        name: json['name'],
      );
}
