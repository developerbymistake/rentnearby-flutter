class DistrictModel {
  final String id;
  final String name;
  final double? latitude;
  final double? longitude;

  DistrictModel({required this.id, required this.name, this.latitude, this.longitude});

  factory DistrictModel.fromJson(Map<String, dynamic> json) => DistrictModel(
        id: json['id'],
        name: json['name'],
        latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
        longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      );
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
}

class RoomTypeModel {
  final String id;
  final String name;
  final String? description;

  RoomTypeModel({required this.id, required this.name, this.description});

  factory RoomTypeModel.fromJson(Map<String, dynamic> json) => RoomTypeModel(
        id: json['id'],
        name: json['name'],
        description: json['description'],
      );
}
