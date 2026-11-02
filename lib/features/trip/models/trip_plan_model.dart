import '../trip_constants.dart';
import 'trip_spot_model.dart';

class TripSpotRef {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String category;
  final int visitMinutes;
  final String? imageUrl;
  final List<int>? closedDays;

  const TripSpotRef({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.visitMinutes,
    this.imageUrl,
    this.closedDays,
  });

  factory TripSpotRef.fromSpot(TripSpotModel s) => TripSpotRef(
        id: s.id,
        name: s.title,
        latitude: s.latitude,
        longitude: s.longitude,
        category: s.category,
        visitMinutes: s.visitMinutes,
        imageUrl: s.imageUrl,
      );

  factory TripSpotRef.fromJson(Map<String, dynamic> json) => TripSpotRef(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        category: json['category'] as String? ?? 'attraction',
        visitMinutes: (json['visitMinutes'] as num?)?.toInt() ?? 60,
        imageUrl: json['imageUrl'] as String?,
        closedDays: (json['closedDays'] as List?)?.map((e) => (e as num).toInt()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'visitMinutes': visitMinutes,
        'imageUrl': ?imageUrl,
        'closedDays': ?closedDays,
      };

  Map<String, dynamic> toPlanInput() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'visitMinutes': visitMinutes,
        'closedDays': ?closedDays,
      };
}

class TripTaxiChoice {
  final String taxiId;
  final String name;
  final int? fare;
  final String? vehicleTypeName;

  const TripTaxiChoice({required this.taxiId, required this.name, this.fare, this.vehicleTypeName});

  factory TripTaxiChoice.fromJson(Map<String, dynamic> json) => TripTaxiChoice(
        taxiId: json['taxiId'] as String,
        name: json['name'] as String? ?? '',
        fare: (json['fare'] as num?)?.toInt(),
        vehicleTypeName: json['vehicleTypeName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'taxiId': taxiId,
        'name': name,
        'fare': ?fare,
        'vehicleTypeName': ?vehicleTypeName,
      };
}

class TripStayChoice {
  final String stayId;
  final String name;
  final int? pricePerNight;
  final int? sameAsDay;

  const TripStayChoice({required this.stayId, required this.name, this.pricePerNight, this.sameAsDay});

  bool get isSameStay => sameAsDay != null;

  TripStayChoice copyWith({int? sameAsDay, bool clearSameAsDay = false}) => TripStayChoice(
        stayId: stayId,
        name: name,
        pricePerNight: pricePerNight,
        sameAsDay: clearSameAsDay ? null : (sameAsDay ?? this.sameAsDay),
      );

  factory TripStayChoice.fromJson(Map<String, dynamic> json) => TripStayChoice(
        stayId: json['stayId'] as String,
        name: json['name'] as String? ?? '',
        pricePerNight: (json['pricePerNight'] as num?)?.toInt(),
        sameAsDay: (json['sameAsDay'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'stayId': stayId,
        'name': name,
        'pricePerNight': ?pricePerNight,
        'sameAsDay': ?sameAsDay,
      };
}

class TripDay {
  final int day;
  final List<TripSpotRef> spots;
  final TripTaxiChoice? taxi;
  final TripStayChoice? stay;

  const TripDay({required this.day, this.spots = const [], this.taxi, this.stay});

  int get visitMinutes => spots.fold(0, (sum, s) => sum + s.visitMinutes);

  TripDay copyWith({
    int? day,
    List<TripSpotRef>? spots,
    TripTaxiChoice? taxi,
    TripStayChoice? stay,
    bool clearTaxi = false,
    bool clearStay = false,
  }) =>
      TripDay(
        day: day ?? this.day,
        spots: spots ?? this.spots,
        taxi: clearTaxi ? null : (taxi ?? this.taxi),
        stay: clearStay ? null : (stay ?? this.stay),
      );

  factory TripDay.fromJson(Map<String, dynamic> json) => TripDay(
        day: (json['day'] as num).toInt(),
        spots: ((json['spots'] as List?) ?? const [])
            .map((e) => TripSpotRef.fromJson(e as Map<String, dynamic>))
            .toList(),
        taxi: json['taxi'] is Map<String, dynamic> ? TripTaxiChoice.fromJson(json['taxi'] as Map<String, dynamic>) : null,
        stay: json['stay'] is Map<String, dynamic> ? TripStayChoice.fromJson(json['stay'] as Map<String, dynamic>) : null,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'spots': spots.map((s) => s.toJson()).toList(),
        'taxi': ?taxi?.toJson(),
        'stay': ?stay?.toJson(),
      };
}

class TripSettings {
  final int dayLimitMinutes;
  final DateTime? startDate;

  const TripSettings({this.dayLimitMinutes = TripConstants.dayLimitMinutes, this.startDate});

  String? get startDateIso {
    final d = startDate;
    if (d == null) return null;
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  factory TripSettings.fromJson(Map<String, dynamic> json) => TripSettings(
        dayLimitMinutes: (json['dayLimitMinutes'] as num?)?.toInt() ?? TripConstants.dayLimitMinutes,
        startDate: DateTime.tryParse(json['startDate'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {'dayLimitMinutes': dayLimitMinutes, 'startDate': ?startDateIso};
}

class TripPlan {
  final int version;
  final String cityId;
  final String districtId;
  final int? cityKey;
  final String cityName;
  final double? centreLatitude;
  final double? centreLongitude;
  final List<TripDay> days;
  final TripSettings settings;

  const TripPlan({
    this.version = 1,
    required this.cityId,
    required this.districtId,
    this.cityKey,
    required this.cityName,
    this.centreLatitude,
    this.centreLongitude,
    this.days = const [],
    this.settings = const TripSettings(),
  });

  List<TripSpotRef> get allSpots => [for (final d in days) ...d.spots];

  int get spotCount => days.fold(0, (sum, d) => sum + d.spots.length);

  Set<String> get spotIds => {for (final d in days) ...d.spots.map((s) => s.id)};

  TripDay? dayAt(int day) {
    for (final d in days) {
      if (d.day == day) return d;
    }
    return null;
  }

  int? dayOfSpot(String spotId) {
    for (final d in days) {
      if (d.spots.any((s) => s.id == spotId)) return d.day;
    }
    return null;
  }

  TripSpotRef? spotById(String spotId) {
    for (final d in days) {
      for (final s in d.spots) {
        if (s.id == spotId) return s;
      }
    }
    return null;
  }

  TripPlan copyWith({
    double? centreLatitude,
    double? centreLongitude,
    List<TripDay>? days,
    TripSettings? settings,
  }) =>
      TripPlan(
        version: version,
        cityId: cityId,
        districtId: districtId,
        cityKey: cityKey,
        cityName: cityName,
        centreLatitude: centreLatitude ?? this.centreLatitude,
        centreLongitude: centreLongitude ?? this.centreLongitude,
        days: days ?? this.days,
        settings: settings ?? this.settings,
      );

  factory TripPlan.fromJson(Map<String, dynamic> json) => TripPlan(
        version: (json['version'] as num?)?.toInt() ?? 1,
        cityId: json['cityId'] as String,
        districtId: json['districtId'] as String,
        cityKey: (json['cityKey'] as num?)?.toInt(),
        cityName: json['cityName'] as String? ?? '',
        centreLatitude: (json['centreLatitude'] as num?)?.toDouble(),
        centreLongitude: (json['centreLongitude'] as num?)?.toDouble(),
        days: ((json['days'] as List?) ?? const [])
            .map((e) => TripDay.fromJson(e as Map<String, dynamic>))
            .toList(),
        settings: json['settings'] is Map<String, dynamic>
            ? TripSettings.fromJson(json['settings'] as Map<String, dynamic>)
            : const TripSettings(),
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'cityId': cityId,
        'districtId': districtId,
        'cityKey': ?cityKey,
        'cityName': cityName,
        'centreLatitude': ?centreLatitude,
        'centreLongitude': ?centreLongitude,
        'days': days.map((d) => d.toJson()).toList(),
        'settings': settings.toJson(),
      };
}
