import 'inclusion_model.dart';
import 'service_package_preview_model.dart';

/// Full Service Detail — GET /services/{id}. Mirrors
/// RentNearBy.Core.DTOs.Responses.ServiceDetailDto field-for-field, including
/// the embedded package-preview list rendered on the "About" screen below
/// the hero photo, before the consumer drills into the full Package List.
class ServiceDetailModel {
  final String id;
  final String serviceCategoryId;
  // RentNearBy.Core.Models.ServiceCategoryFormTypes.* — decides which Enquiry Form fields to show.
  final String serviceCategoryFormType;
  final String name;
  // URL-friendly identifiers for the share/QR feature (developerbymistake.tech/go/s/{categorySlug}/{slug}
  // and the plain-text bakhli.com/services/{categorySlug}/{slug} link) — mirrors ListingModel.slug.
  final String slug;
  final String categorySlug;
  final String iconName;
  final String shortDescription;
  final String fullDescription;
  final String coverPhotoUrl;
  final int sortOrder;
  final bool isFeatured;
  final bool isActive;
  final List<ServicePackagePreviewModel> packages;
  // Service-scoped "What's Included" — every package/group-size tier shares the same set, so this
  // lives here, not per-package (see InclusionModel's doc comment).
  final List<InclusionModel> inclusions;
  final String? terrainType;
  final String? pickupDropLocation;
  final String? nightsBreakdown;
  final String? mealsNote;
  final String? itineraryDisclaimer;
  final List<ItineraryDayModel> itineraryDays;

  ServiceDetailModel({
    required this.id,
    required this.serviceCategoryId,
    required this.serviceCategoryFormType,
    required this.name,
    required this.slug,
    required this.categorySlug,
    required this.iconName,
    required this.shortDescription,
    required this.fullDescription,
    required this.coverPhotoUrl,
    required this.sortOrder,
    required this.isFeatured,
    required this.isActive,
    required this.packages,
    required this.inclusions,
    required this.terrainType,
    required this.pickupDropLocation,
    required this.nightsBreakdown,
    required this.mealsNote,
    required this.itineraryDisclaimer,
    required this.itineraryDays,
  });

  factory ServiceDetailModel.fromJson(Map<String, dynamic> json) => ServiceDetailModel(
        id: json['id'] as String,
        serviceCategoryId: json['serviceCategoryId'] as String? ?? '',
        serviceCategoryFormType: json['serviceCategoryFormType'] as String? ?? '',
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        categorySlug: json['categorySlug'] as String? ?? '',
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
        inclusions: (json['inclusions'] as List? ?? [])
            .map((e) => InclusionModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        terrainType: json['terrainType'] as String?,
        pickupDropLocation: json['pickupDropLocation'] as String?,
        nightsBreakdown: json['nightsBreakdown'] as String?,
        mealsNote: json['mealsNote'] as String?,
        itineraryDisclaimer: json['itineraryDisclaimer'] as String?,
        itineraryDays: (json['itineraryDays'] as List? ?? [])
            .map((e) => ItineraryDayModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One day's entry in a service's "See Your Journey" itinerary — GET
/// /services/{id} embeds these under itineraryDays, ordered by dayNumber.
class ItineraryDayModel {
  final int dayNumber;
  final String title;
  final String description;

  ItineraryDayModel({
    required this.dayNumber,
    required this.title,
    required this.description,
  });

  factory ItineraryDayModel.fromJson(Map<String, dynamic> json) => ItineraryDayModel(
        dayNumber: (json['dayNumber'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );
}
