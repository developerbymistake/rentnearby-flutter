import '../config/app_constants.dart';

class ListingModel {
  final String id;
  final String userId;
  final String? slug;
  final String? description;
  final int? priceMonthly;
  final double latitude;
  final double longitude;
  final String? address;
  final String districtId;
  final String? districtName;
  final String? cityId;
  final String? cityName;
  final String roomTypeId;
  final String? roomTypeName;
  final bool isActive;
  final String? ownerName;
  final String? ownerPhone;
  final List<String> photos;
  final DateTime createdAt;
  final DateTime? validUntil;
  final String furnishedStatus;
  final bool? isAc;
  final int? securityDeposit;
  final int? floor;
  final bool hasReported;
  final int pendingReportCount;
  final String? moderationStatus;
  final String? rejectionReason;
  final String? pauseReason;
  final int priorityRank;
  final bool isFeatured;

  ListingModel({
    required this.id,
    required this.userId,
    this.slug,
    this.description,
    this.priceMonthly,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.districtId,
    this.districtName,
    this.cityId,
    this.cityName,
    required this.roomTypeId,
    this.roomTypeName,
    required this.isActive,
    this.ownerName,
    this.ownerPhone,
    required this.photos,
    required this.createdAt,
    this.validUntil,
    this.furnishedStatus = 'None',
    this.isAc,
    this.securityDeposit,
    this.floor,
    this.hasReported = false,
    this.pendingReportCount = 0,
    this.moderationStatus,
    this.rejectionReason,
    this.pauseReason,
    this.priorityRank = 0,
    this.isFeatured = false,
  });

  factory ListingModel.fromJson(Map<String, dynamic> json) => ListingModel(
        id: json['id'],
        userId: json['userId'],
        slug: json['slug'] as String?,
        description: json['description'],
        priceMonthly: json['priceMonthly'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        address: json['address'],
        districtId: json['districtId'],
        districtName: json['districtName'],
        cityId: json['cityId'],
        cityName: json['cityName'],
        roomTypeId: json['roomTypeId'],
        roomTypeName: json['roomTypeName'],
        isActive: json['isActive'] ?? true,
        ownerName: json['ownerName'],
        ownerPhone: json['ownerPhone'],
        photos: (json['photos'] as List? ?? [])
            .map((p) => p.toString().startsWith('http') ? p.toString() : '${AppConstants.serverUrl}$p')
            .toList(),
        createdAt: DateTime.parse(json['createdAt']),
        validUntil: json['validUntil'] != null
            ? DateTime.parse(json['validUntil'] as String)
            : null,
        furnishedStatus: json['furnishedStatus'] ?? 'None',
        isAc: json['isAc'] as bool?,
        securityDeposit: (json['securityDeposit'] as num?)?.toInt(),
        floor: (json['floor'] as num?)?.toInt(),
        hasReported: json['hasReported'] ?? false,
        pendingReportCount: json['pendingReportCount'] ?? 0,
        // GoLiveRequestStatuses.* ("Pending"/"Approved"/"Rejected") or null if never requested.
        moderationStatus: json['liveRequestStatus'] as String?,
        rejectionReason: json['rejectedReason'] as String?,
        pauseReason: json['pauseReason'] as String?,
        priorityRank: (json['priorityRank'] as num?)?.toInt() ?? 0,
        isFeatured: json['isFeatured'] == true,
      );

  bool get isPendingReview => moderationStatus == 'Pending';
  bool get isApproved => moderationStatus == 'Approved';
  bool get isRejected => moderationStatus == 'Rejected';
  bool get isPausedByPlan => pauseReason == 'Plan' && !isActive;
  bool get isPausedByAdmin => pauseReason == 'Admin' && !isActive;
  bool get isSuspended => pauseReason == 'Suspended' && !isActive;
  bool get canGoLive => !isActive && !isPendingReview && !isRejected && !isPausedByAdmin && !isSuspended;

  String get priceDisplay =>
      priceMonthly != null ? '₹${_formatPrice(priceMonthly!)}/mo' : 'Price on request';

  String get shortPrice =>
      priceMonthly != null ? '₹${_formatPrice(priceMonthly!)}' : 'N/A';

  String _formatPrice(int price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(price % 1000 == 0 ? 0 : 1)}k';
    }
    return price.toString();
  }
}

class NearbyListingModel {
  final String id;
  final int? priceMonthly;
  final double latitude;
  final double longitude;
  final String? roomTypeName;
  final String? ownerName;
  final String? ownerPhone;
  final String? thumbnailUrl;
  final double distanceKm;
  final bool isActive;
  final String furnishedStatus;
  final bool? isAc;
  final int priorityRank;
  final bool isFeatured;

  NearbyListingModel({
    required this.id,
    this.priceMonthly,
    required this.latitude,
    required this.longitude,
    this.roomTypeName,
    this.ownerName,
    this.ownerPhone,
    this.thumbnailUrl,
    required this.distanceKm,
    required this.isActive,
    this.furnishedStatus = 'None',
    this.isAc,
    this.priorityRank = 0,
    this.isFeatured = false,
  });

  factory NearbyListingModel.fromJson(Map<String, dynamic> json) => NearbyListingModel(
        id: json['id'],
        priceMonthly: json['priceMonthly'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        roomTypeName: json['roomTypeName'],
        ownerName: json['ownerName'],
        ownerPhone: json['ownerPhone'],
        thumbnailUrl: json['thumbnailUrl'] == null
            ? null
            : json['thumbnailUrl'].toString().startsWith('http')
                ? json['thumbnailUrl']
                : '${AppConstants.serverUrl}${json['thumbnailUrl']}',
        distanceKm: (json['distanceKm'] as num).toDouble(),
        isActive: json['isActive'] ?? true,
        furnishedStatus: json['furnishedStatus'] ?? 'None',
        isAc: json['isAc'] as bool?,
        priorityRank: (json['priorityRank'] as num?)?.toInt() ?? 0,
        isFeatured: json['isFeatured'] == true,
      );

  String get shortPrice =>
      priceMonthly != null ? '₹${_formatPrice(priceMonthly!)}' : 'N/A';

  String _formatPrice(int price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(price % 1000 == 0 ? 0 : 1)}k';
    }
    return price.toString();
  }
}
