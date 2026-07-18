/// Row shape for the descriptive-list screen (icon+title+one-liner+chevron)
/// and Home-rail preview cards — GET /services?serviceCategoryId=.
/// Mirrors RentNearBy.Core.DTOs.Responses.ServiceListItemDto field-for-field.
class ServiceListItemModel {
  final String id;
  final String serviceCategoryId;
  final String name;
  final String iconName;
  final String shortDescription;
  final String coverPhotoUrl;
  final int sortOrder;
  final bool isFeatured;
  final bool isActive;

  ServiceListItemModel({
    required this.id,
    required this.serviceCategoryId,
    required this.name,
    required this.iconName,
    required this.shortDescription,
    required this.coverPhotoUrl,
    required this.sortOrder,
    required this.isFeatured,
    required this.isActive,
  });

  factory ServiceListItemModel.fromJson(Map<String, dynamic> json) => ServiceListItemModel(
        id: json['id'] as String,
        serviceCategoryId: json['serviceCategoryId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        iconName: json['iconName'] as String? ?? '',
        shortDescription: json['shortDescription'] as String? ?? '',
        coverPhotoUrl: json['coverPhotoUrl'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isFeatured: json['isFeatured'] == true,
        isActive: json['isActive'] == true,
      );
}
