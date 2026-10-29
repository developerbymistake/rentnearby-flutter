class TaxiVehicleTypeModel {
  final String id;
  final String name;
  final String category;
  final int? defaultSeats;
  final int sortOrder;
  final bool isActive;

  const TaxiVehicleTypeModel({
    required this.id,
    required this.name,
    required this.category,
    this.defaultSeats,
    required this.sortOrder,
    this.isActive = true,
  });

  factory TaxiVehicleTypeModel.fromJson(Map<String, dynamic> json) => TaxiVehicleTypeModel(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        defaultSeats: (json['defaultSeats'] as num?)?.toInt(),
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 999,
        isActive: json['isActive'] as bool? ?? true,
      );
}
