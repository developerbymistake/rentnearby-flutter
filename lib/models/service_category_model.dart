/// The catalog's top level (e.g. "Char Dham Yatra") — one consumer rail per
/// active category. GET /services/categories.
class ServiceCategoryModel {
  final String id;
  final String name;
  final String iconName;
  final String coverPhotoUrl;
  final int sortOrder;
  final bool isActive;

  ServiceCategoryModel({
    required this.id,
    required this.name,
    required this.iconName,
    required this.coverPhotoUrl,
    required this.sortOrder,
    required this.isActive,
  });

  factory ServiceCategoryModel.fromJson(Map<String, dynamic> json) => ServiceCategoryModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        iconName: json['iconName'] as String? ?? '',
        coverPhotoUrl: json['coverPhotoUrl'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] == true,
      );
}
