/// One top-level vertical of the services marketplace (e.g. "Explore
/// Uttarakhand", "Expert Consultations") — GET /services/sections.
/// Home screen loops over whatever active sections the API returns to build
/// its rails, so a new section (a "3rd vertical") needs zero app code.
class ServiceSectionModel {
  final String id;
  final String name;
  final String iconName;
  final int sortOrder;
  final bool isActive;

  ServiceSectionModel({
    required this.id,
    required this.name,
    required this.iconName,
    required this.sortOrder,
    required this.isActive,
  });

  factory ServiceSectionModel.fromJson(Map<String, dynamic> json) => ServiceSectionModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        iconName: json['iconName'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] == true,
      );
}
