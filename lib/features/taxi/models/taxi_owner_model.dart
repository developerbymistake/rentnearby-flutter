import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/json/owner_json.dart';
import '../taxi_option_sets.dart';

class TaxiRoutePlace {
  final String name;
  final String? label;
  final double lat;
  final double lng;
  final int? cityKey;
  final bool other;
  const TaxiRoutePlace({required this.name, this.label, required this.lat, required this.lng, this.cityKey, this.other = false});

  bool get named => cityKey != null || other;
}

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
  final int? fromCityKey;
  final int? toCityKey;
  final bool fromOtherPlace;
  final bool toOtherPlace;
  final bool? serverActive;

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
    this.fromCityKey,
    this.toCityKey,
    this.fromOtherPlace = false,
    this.toOtherPlace = false,
    this.serverActive,
  });

  bool get roundTrip => tripType.toLowerCase().contains('round');

  Map<String, dynamic> toPayload({int? fare, String? tripType, TaxiRoutePlace? from, TaxiRoutePlace? to}) {
    final f = from ?? TaxiRoutePlace(name: fromName, label: fromLabel, lat: fromLatitude, lng: fromLongitude, cityKey: fromCityKey, other: fromOtherPlace);
    final t = to ?? TaxiRoutePlace(name: toName, label: toLabel, lat: toLatitude, lng: toLongitude, cityKey: toCityKey, other: toOtherPlace);
    return {
      'id': id,
      'fromName': f.name,
      'fromLabel': f.label,
      'fromLatitude': f.lat,
      'fromLongitude': f.lng,
      'toName': t.name,
      'toLabel': t.label,
      'toLatitude': t.lat,
      'toLongitude': t.lng,
      'fare': fare ?? this.fare,
      'tripType': tripType ?? this.tripType,
      if (f.named && t.named) ...{
        'fromCityKey': f.cityKey,
        'toCityKey': t.cityKey,
        'fromOtherPlace': f.cityKey == null,
        'toOtherPlace': t.cityKey == null,
      },
    };
  }

  bool get activeInRequests => serverActive ?? (fromCityKey != null && toCityKey != null);

  static int? _key(Object? v) => v is num && v > 0 ? v.toInt() : null;

  factory TaxiRouteModel.fromJson(Map<String, dynamic> json) => TaxiRouteModel(
        id: json['id']?.toString() ?? '',
        routeIndex: OwnerJson.integer(json['routeIndex'], 1),
        fromName: OwnerJson.str(json['fromName'], ''),
        fromLabel: OwnerJson.strOrNull(json['fromLabel']),
        fromLatitude: (OwnerJson.doubleOrNull(json['fromLatitude']) ?? 0),
        fromLongitude: (OwnerJson.doubleOrNull(json['fromLongitude']) ?? 0),
        toName: OwnerJson.str(json['toName'], ''),
        toLabel: OwnerJson.strOrNull(json['toLabel']),
        toLatitude: (OwnerJson.doubleOrNull(json['toLatitude']) ?? 0),
        toLongitude: (OwnerJson.doubleOrNull(json['toLongitude']) ?? 0),
        fare: OwnerJson.integer(json['fare'], 0),
        tripType: OwnerJson.str(json['tripType'], 'OneWay'),
        fromCityKey: _key(json['fromCityKey']),
        toCityKey: _key(json['toCityKey']),
        fromOtherPlace: json['fromOtherPlace'] == true,
        toOtherPlace: json['toOtherPlace'] == true,
        serverActive: OwnerJson.boolOrNull(json['activeInRequests']),
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
  final bool everApproved;
  final int? localDayRate;
  final int? localDayKm;
  final List<TaxiRouteModel> hiddenRoutes;
  final List<Meter> meters;
  final int activeBookingCount;
  final int? ringWeight;
  final bool? remindersOn;
  final int reportCount;
  final bool isFeatured;
  final Meter? routesMeter;
  final bool? paymentEnabled;
  final bool? canUpgrade;

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
    this.everApproved = false,
    this.localDayRate,
    this.localDayKm,
    this.hiddenRoutes = const [],
    this.meters = const [],
    this.activeBookingCount = 0,
    this.ringWeight,
    this.remindersOn,
    this.reportCount = 0,
    this.isFeatured = false,
    this.routesMeter,
    this.paymentEnabled,
    this.canUpgrade,
  });

  Meter? meter(String key) => Meter.find(meters, key);
  int get shownReportCount => reportCount > 0 ? reportCount : pendingReportCount;
  bool get hasDeclaredRate => localDayRate != null && localDayKm != null;

  bool get isDraft => status == TaxiStatus.draft;
  bool get isPendingReview => status == TaxiStatus.pendingReview;
  bool get isApproved => status == TaxiStatus.approved;
  bool get isRejected => status == TaxiStatus.rejected;
  bool get canEditSetup => !isPendingReview;
  bool get identityDone => hasDrivingLicence && hasDateOfBirth;
  bool get hasLocalRate => localDayRate != null;

  String get locality => cityName ?? districtName ?? '';

  String get baseLabel =>
      [cityName, districtName].where((e) => e != null && e.isNotEmpty).toSet().join(', ');

  factory TaxiOwnerModel.fromJson(Map<String, dynamic> json) {
    final routes = OwnerJson.list(json['routes'], TaxiRouteModel.fromJson)..sort((a, b) => a.routeIndex.compareTo(b.routeIndex));
    final hidden = OwnerJson.list(json['hiddenRoutes'], TaxiRouteModel.fromJson)..sort((a, b) => a.routeIndex.compareTo(b.routeIndex));
    return TaxiOwnerModel(
      id: json['id']?.toString() ?? '',
      status: OwnerJson.str(json['status'], TaxiStatus.draft),
      percent: OwnerJson.integer(json['percent'], 0),
      step1Done: json['step1Done'] == true,
      routesDone: json['routesDone'] == true,
      submitted: json['submitted'] == true,
      vehicleTypeId: json['vehicleTypeId']?.toString(),
      vehicleTypeName: OwnerJson.strOrNull(json['vehicleTypeName']),
      vehicleCategory: OwnerJson.strOrNull(json['vehicleCategory']),
      seats: OwnerJson.intOrNull(json['seats']),
      numberPlate: OwnerJson.strOrNull(json['numberPlate']),
      plateDisplay: OwnerJson.strOrNull(json['plateDisplay']),
      platePhotoUrl: OwnerJson.strOrNull(json['platePhotoUrl']),
      contactPhone: OwnerJson.strOrNull(json['contactPhone']),
      whatsAppNumber: OwnerJson.strOrNull(json['whatsAppNumber']),
      latitude: OwnerJson.doubleOrNull(json['latitude']),
      longitude: OwnerJson.doubleOrNull(json['longitude']),
      districtId: json['districtId']?.toString(),
      districtName: OwnerJson.strOrNull(json['districtName']),
      cityId: json['cityId']?.toString(),
      cityName: OwnerJson.strOrNull(json['cityName']),
      routes: routes,
      isAvailable: OwnerJson.boolOrNull(json['isAvailable']) ?? true,
      rejectedReason: OwnerJson.strOrNull(json['rejectedReason']),
      minFare: OwnerJson.intOrNull(json['minFare']),
      slug: OwnerJson.strOrNull(json['slug']),
      submittedAt: json['submittedAt'] != null ? DateTime.tryParse(json['submittedAt'].toString()) : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      pendingReportCount: OwnerJson.integer(json['pendingReportCount'], 0),
      hasDrivingLicence: json['hasDrivingLicence'] == true,
      hasDateOfBirth: json['hasDateOfBirth'] == true,
      everApproved: json['everApproved'] == true,
      localDayRate: OwnerJson.intOrNull(json['localDayRate']),
      localDayKm: OwnerJson.intOrNull(json['localDayKm']),
      hiddenRoutes: hidden,
      meters: Meter.listOf(json['meters']),
      activeBookingCount: OwnerJson.integer(json['activeBookingCount']),
      ringWeight: OwnerJson.intOrNull(json['ringWeight']),
      remindersOn: OwnerJson.boolOrNull(json['remindersOn']),
      reportCount: OwnerJson.integer(json['reportCount']),
      isFeatured: OwnerJson.boolean(json['isFeatured']),
      routesMeter: Meter.maybe(json['routesMeter']),
      paymentEnabled: OwnerJson.boolOrNull(json['paymentEnabled']),
      canUpgrade: OwnerJson.boolOrNull(json['canUpgrade']),
    );
  }
}
