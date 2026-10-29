class StayTypeModel {
  final String id;
  final String name;
  final String? description;
  final int sortOrder;

  const StayTypeModel({required this.id, required this.name, this.description, required this.sortOrder});

  factory StayTypeModel.fromJson(Map<String, dynamic> json) => StayTypeModel(
        id: json['id'].toString(),
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
}
