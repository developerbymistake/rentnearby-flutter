/// A category within a ServiceSection (e.g. "Char Dham Yatra" under
/// "Explore Uttarakhand") — GET /services/categories?serviceSectionId=.
class ServiceCategoryModel {
  final String id;
  final String serviceSectionId;
  final String name;
  final String iconName;
  final int sortOrder;
  final bool isActive;

  ServiceCategoryModel({
    required this.id,
    required this.serviceSectionId,
    required this.name,
    required this.iconName,
    required this.sortOrder,
    required this.isActive,
  });

  factory ServiceCategoryModel.fromJson(Map<String, dynamic> json) => ServiceCategoryModel(
        id: json['id'] as String,
        serviceSectionId: json['serviceSectionId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        iconName: json['iconName'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] == true,
      );
}
