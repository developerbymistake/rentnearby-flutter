import '../taxi_option_sets.dart';

class TaxiRouteModel {
  final String id;
  final int routeIndex;
  final String fromName;
  final String? fromLabel;
  final double fromLatitude;
  final double fromLongitude;
  final String toName;
  final String? toLabel;
  final double toLatitude;
  final double toLongitude;
  final int fare;
  final String tripType;

  const TaxiRouteModel({
    required this.id,
    required this.routeIndex,
    required this.fromName,
    this.fromLabel,
    required this.fromLatitude,
    required this.fromLongitude,
    required this.toName,
    this.toLabel,
    required this.toLatitude,
    required this.toLongitude,
    required this.fare,
    required this.tripType,
  });

  factory TaxiRouteModel.fromJson(Map<String, dynamic> json) => TaxiRouteModel(
        id: json['id']?.toString() ?? '',
        routeIndex: (json['routeIndex'] as num?)?.toInt() ?? 1,
        fromName: json['fromName'] as String? ?? '',
        fromLabel: json['fromLabel'] as String?,
        fromLatitude: (json['fromLatitude'] as num?)?.toDouble() ?? 0,
        fromLongitude: (json['fromLongitude'] as num?)?.toDouble() ?? 0,
        toName: json['toName'] as String? ?? '',
        toLabel: json['toLabel'] as String?,
        toLatitude: (json['toLatitude'] as num?)?.toDouble() ?? 0,
        toLongitude: (json['toLongitude'] as num?)?.toDouble() ?? 0,
        fare: (json['fare'] as num?)?.toInt() ?? 0,
        tripType: json['tripType'] as String? ?? 'OneWay',
      );
}

class TaxiOwnerModel {
  final String id;
  final String status;
  final int percent;
  final bool step1Done;
  final bool routesDone;
  final bool submitted;
  final String? vehicleTypeId;
  final String? vehicleTypeName;
  final String? vehicleCategory;
  final int? seats;
  final String? numberPlate;
  final String? plateDisplay;
  final String? platePhotoUrl;
  final String? contactPhone;
  final String? whatsAppNumber;
  final double? latitude;
  final double? longitude;
  final String? districtId;
  final String? districtName;
  final String? cityId;
  final String? cityName;
  final List<TaxiRouteModel> routes;
  final bool isAvailable;
  final String? rejectedReason;
  final int? minFare;
  final String? slug;
  final DateTime? submittedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int pendingReportCount;
  final bool hasDrivingLicence;
  final bool hasDateOfBirth;

  const TaxiOwnerModel({
    required this.id,
    required this.status,
    this.percent = 0,
    required this.step1Done,
    required this.routesDone,
    this.submitted = false,
    this.vehicleTypeId,
    this.vehicleTypeName,
    this.vehicleCategory,
    this.seats,
    this.numberPlate,
    this.plateDisplay,
    this.platePhotoUrl,
    this.contactPhone,
    this.whatsAppNumber,
    this.latitude,
    this.longitude,
    this.districtId,
    this.districtName,
    this.cityId,
    this.cityName,
    this.routes = const [],
    this.isAvailable = true,
    this.rejectedReason,
    this.minFare,
    this.slug,
    this.submittedAt,
    required this.createdAt,
    this.updatedAt,
    this.pendingReportCount = 0,
    this.hasDrivingLicence = false,
    this.hasDateOfBirth = false,
  });

  bool get isDraft => status == TaxiStatus.draft;
  bool get isPendingReview => status == TaxiStatus.pendingReview;
  bool get isApproved => status == TaxiStatus.approved;
  bool get isRejected => status == TaxiStatus.rejected;
  bool get canEditSetup => !isPendingReview;
  bool get identityDone => hasDrivingLicence && hasDateOfBirth;

  String get locality => cityName ?? districtName ?? '';

  String get baseLabel =>
      [cityName, districtName].where((e) => e != null && e.isNotEmpty).toSet().join(', ');

  factory TaxiOwnerModel.fromJson(Map<String, dynamic> json) {
    final routes = (json['routes'] as List? ?? [])
        .map((e) => TaxiRouteModel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.routeIndex.compareTo(b.routeIndex));
    return TaxiOwnerModel(
      id: json['id']?.toString() ?? '',
      status: json['status'] as String? ?? TaxiStatus.draft,
      percent: (json['percent'] as num?)?.toInt() ?? 0,
      step1Done: json['step1Done'] == true,
      routesDone: json['routesDone'] == true,
      submitted: json['submitted'] == true,
      vehicleTypeId: json['vehicleTypeId']?.toString(),
      vehicleTypeName: json['vehicleTypeName'] as String?,
      vehicleCategory: json['vehicleCategory'] as String?,
      seats: (json['seats'] as num?)?.toInt(),
      numberPlate: json['numberPlate'] as String?,
      plateDisplay: json['plateDisplay'] as String?,
      platePhotoUrl: json['platePhotoUrl'] as String?,
      contactPhone: json['contactPhone'] as String?,
      whatsAppNumber: json['whatsAppNumber'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      districtId: json['districtId']?.toString(),
      districtName: json['districtName'] as String?,
      cityId: json['cityId']?.toString(),
      cityName: json['cityName'] as String?,
      routes: routes,
      isAvailable: json['isAvailable'] as bool? ?? true,
      rejectedReason: json['rejectedReason'] as String?,
      minFare: (json['minFare'] as num?)?.toInt(),
      slug: json['slug'] as String?,
      submittedAt: json['submittedAt'] != null ? DateTime.tryParse(json['submittedAt'].toString()) : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      pendingReportCount: (json['pendingReportCount'] as num?)?.toInt() ?? 0,
      hasDrivingLicence: json['hasDrivingLicence'] == true,
      hasDateOfBirth: json['hasDateOfBirth'] == true,
    );
  }
}
