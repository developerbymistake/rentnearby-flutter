import 'service_package_preview_model.dart';

/// Full Service Detail — GET /services/{id}. Mirrors
/// RentNearBy.Core.DTOs.Responses.ServiceDetailDto field-for-field, including
/// the embedded package-preview list rendered on the "About" screen below
/// the hero photo, before the consumer drills into the full Package List.
class ServiceDetailModel {
  final String id;
  final String serviceCategoryId;
  final String serviceSectionId;
  final String serviceSectionName;
  final String name;
  final String iconName;
  final String shortDescription;
  final String fullDescription;
  final String coverPhotoUrl;
  final int sortOrder;
  final bool isFeatured;
  final bool isActive;
  final List<ServicePackagePreviewModel> packages;

  ServiceDetailModel({
    required this.id,
    required this.serviceCategoryId,
    required this.serviceSectionId,
    required this.serviceSectionName,
    required this.name,
    required this.iconName,
    required this.shortDescription,
    required this.fullDescription,
    required this.coverPhotoUrl,
    required this.sortOrder,
    required this.isFeatured,
    required this.isActive,
    required this.packages,
  });

  factory ServiceDetailModel.fromJson(Map<String, dynamic> json) => ServiceDetailModel(
        id: json['id'] as String,
        serviceCategoryId: json['serviceCategoryId'] as String? ?? '',
        serviceSectionId: json['serviceSectionId'] as String? ?? '',
        serviceSectionName: json['serviceSectionName'] as String? ?? '',
        name: json['name'] as String? ?? '',
        iconName: json['iconName'] as String? ?? '',
        shortDescription: json['shortDescription'] as String? ?? '',
        fullDescription: json['fullDescription'] as String? ?? '',
        coverPhotoUrl: json['coverPhotoUrl'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isFeatured: json['isFeatured'] == true,
        isActive: json['isActive'] == true,
        packages: (json['packages'] as List? ?? [])
            .map((e) => ServicePackagePreviewModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
