/// A fixed, admin-managed "what's included" master item (e.g. "Hotel Stay",
/// "Meals Included") — GET /services/inclusions, and embedded per-package
/// in ServicePackageModel.inclusions.
class InclusionModel {
  final String id;
  final String name;
  final String iconName;
  final int sortOrder;
  final bool isActive;

  InclusionModel({
    required this.id,
    required this.name,
    required this.iconName,
    required this.sortOrder,
    required this.isActive,
  });

  factory InclusionModel.fromJson(Map<String, dynamic> json) => InclusionModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        iconName: json['iconName'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] == true,
      );
}
