class CityModel {
  final String id;
  final String name;
  final double? latitude;
  final double? longitude;

  CityModel({required this.id, required this.name, this.latitude, this.longitude});

  factory CityModel.fromJson(Map<String, dynamic> json) => CityModel(
        id: json['id'],
        name: json['name'],
        latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
        longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      );
}

class DistrictModel {
  final String id;
  final String cityId;
  final String name;

  DistrictModel({required this.id, required this.cityId, required this.name});

  factory DistrictModel.fromJson(Map<String, dynamic> json) => DistrictModel(
        id: json['id'],
        cityId: json['cityId'],
        name: json['name'],
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
