class RoleModel {
  final String key;
  final String name;
  final String description;
  final int sortOrder;

  const RoleModel({
    required this.key,
    required this.name,
    required this.description,
    required this.sortOrder,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) => RoleModel(
        key: json['key'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        sortOrder: json['sortOrder'] as int? ?? 0,
      );
}
