import '../trip_constants.dart';
import '../trip_strings.dart';
import 'trip_enquiry_model.dart';
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

class TripTaxiBooking {
  final int agreedFare;
  final bool tollExtra;
  final String? pickupTime;
  final String? pickupPlace;
  final List<int> days;
  final String? note;
  final DateTime? bookedAt;

  const TripTaxiBooking({
    required this.agreedFare,
    this.tollExtra = false,
    this.pickupTime,
    this.pickupPlace,
    required this.days,
    this.note,
    this.bookedAt,
  });

  factory TripTaxiBooking.fromJson(Map<String, dynamic> json) => TripTaxiBooking(
        agreedFare: (json['agreedFare'] as num?)?.toInt() ?? 0,
        tollExtra: json['tollExtra'] == true,
        pickupTime: json['pickupTime'] as String?,
        pickupPlace: json['pickupPlace'] as String?,
        days: ((json['days'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
        note: json['note'] as String?,
        bookedAt: DateTime.tryParse(json['bookedAt'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'agreedFare': agreedFare,
        'tollExtra': tollExtra,
        'pickupTime': ?pickupTime,
        'pickupPlace': ?pickupPlace,
        'days': days,
        'note': ?note,
        'bookedAt': ?bookedAt?.toUtc().toIso8601String(),
      };

  TripTaxiBooking copyWith({
    int? agreedFare,
    bool? tollExtra,
    String? pickupTime,
    String? pickupPlace,
    List<int>? days,
    String? note,
    DateTime? bookedAt,
  }) =>
      TripTaxiBooking(
        agreedFare: agreedFare ?? this.agreedFare,
        tollExtra: tollExtra ?? this.tollExtra,
        pickupTime: pickupTime ?? this.pickupTime,
        pickupPlace: pickupPlace ?? this.pickupPlace,
        days: days ?? this.days,
        note: note ?? this.note,
        bookedAt: bookedAt ?? this.bookedAt,
      );
}

class TripTaxiChoice {
  final String taxiId;
  final String name;
  final int? fare;
  final String? vehicleTypeName;
  final bool isOwn;
  final String? ownPhone;
  final String? note;
  final bool wholeTrip;
  final TripTaxiBooking? booking;

  const TripTaxiChoice({
    required this.taxiId,
    required this.name,
    this.fare,
    this.vehicleTypeName,
    this.isOwn = false,
    this.ownPhone,
    this.note,
    this.wholeTrip = false,
    this.booking,
  });

  bool get isBooked => booking != null;

  factory TripTaxiChoice.own({required String name, String? phone, String? note, int? fare}) => TripTaxiChoice(
        taxiId: '',
        name: name,
        fare: fare,
        isOwn: true,
        ownPhone: phone,
        note: note,
      );

  TripTaxiChoice copyWith({int? fare, TripTaxiBooking? booking, bool clearBooking = false}) => TripTaxiChoice(
        taxiId: taxiId,
        name: name,
        fare: fare ?? this.fare,
        vehicleTypeName: vehicleTypeName,
        isOwn: isOwn,
        ownPhone: ownPhone,
        note: note,
        wholeTrip: wholeTrip,
        booking: clearBooking ? null : (booking ?? this.booking),
      );

  factory TripTaxiChoice.fromJson(Map<String, dynamic> json) => TripTaxiChoice(
        taxiId: json['taxiId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        fare: (json['fare'] as num?)?.toInt(),
        vehicleTypeName: json['vehicleTypeName'] as String?,
        isOwn: json['isOwn'] == true,
        ownPhone: json['ownPhone'] as String?,
        note: json['note'] as String?,
        wholeTrip: json['wholeTrip'] == true,
        booking: json['booking'] is Map<String, dynamic>
            ? TripTaxiBooking.fromJson(json['booking'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        if (!isOwn) 'taxiId': taxiId,
        'name': name,
        'fare': ?fare,
        'vehicleTypeName': ?vehicleTypeName,
        if (isOwn) 'isOwn': true,
        'ownPhone': ?ownPhone,
        'note': ?note,
        if (wholeTrip) 'wholeTrip': true,
        'booking': ?booking?.toJson(),
      };
}

class TripStayChoice {
  final String stayId;
  final String name;
  final int? pricePerNight;
  final int? sameAsDay;
  final double? latitude;
  final double? longitude;
  final bool isOwn;
  final String? ownPhone;
  final String? note;
  final bool skipped;

  const TripStayChoice({
    required this.stayId,
    required this.name,
    this.pricePerNight,
    this.sameAsDay,
    this.latitude,
    this.longitude,
    this.isOwn = false,
    this.ownPhone,
    this.note,
    this.skipped = false,
  });

  const TripStayChoice.skippedNight()
      : stayId = '',
        name = TripStrings.noStayTonight,
        pricePerNight = null,
        sameAsDay = null,
        latitude = null,
        longitude = null,
        isOwn = false,
        ownPhone = null,
        note = null,
        skipped = true;

  bool get isSameStay => sameAsDay != null;

  bool get isSkipped => skipped;

  bool get hasListing => !isOwn && !skipped && stayId.isNotEmpty;

  bool get hasCoordinates => latitude != null && longitude != null;

  TripStayChoice copyWith({int? sameAsDay, bool clearSameAsDay = false, double? latitude, double? longitude}) =>
      TripStayChoice(
        stayId: stayId,
        name: name,
        pricePerNight: pricePerNight,
        sameAsDay: clearSameAsDay ? null : (sameAsDay ?? this.sameAsDay),
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        isOwn: isOwn,
        ownPhone: ownPhone,
        note: note,
        skipped: skipped,
      );

  factory TripStayChoice.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lon = (json['longitude'] as num?)?.toDouble();
    final both = lat != null && lon != null;
    return TripStayChoice(
      stayId: json['stayId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pricePerNight: (json['pricePerNight'] as num?)?.toInt(),
      sameAsDay: (json['sameAsDay'] as num?)?.toInt(),
      latitude: both ? lat : null,
      longitude: both ? lon : null,
      isOwn: json['isOwn'] == true,
      ownPhone: json['ownPhone'] as String?,
      note: json['note'] as String?,
      skipped: json['skipped'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        if (!isOwn && !skipped) 'stayId': stayId,
        'name': name,
        'pricePerNight': ?pricePerNight,
        'sameAsDay': ?sameAsDay,
        'latitude': ?latitude,
        'longitude': ?longitude,
        if (isOwn) 'isOwn': true,
        'ownPhone': ?ownPhone,
        'note': ?note,
        if (skipped) 'skipped': true,
      };
}

class TripStayShortlistItem {
  final String stayId;
  final String name;
  final int? pricePerNight;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final int? sameAsDay;

  const TripStayShortlistItem({
    required this.stayId,
    required this.name,
    this.pricePerNight,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.sameAsDay,
  });

  bool get isSameStay => sameAsDay != null;

  TripStayShortlistItem copyWith({int? sameAsDay, bool clearSameAsDay = false}) => TripStayShortlistItem(
        stayId: stayId,
        name: name,
        pricePerNight: pricePerNight,
        latitude: latitude,
        longitude: longitude,
        distanceKm: distanceKm,
        sameAsDay: clearSameAsDay ? null : (sameAsDay ?? this.sameAsDay),
      );

  factory TripStayShortlistItem.fromJson(Map<String, dynamic> json) => TripStayShortlistItem(
        stayId: json['stayId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        pricePerNight: (json['pricePerNight'] as num?)?.toInt(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        sameAsDay: (json['sameAsDay'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'stayId': stayId,
        'name': name,
        'pricePerNight': ?pricePerNight,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'distanceKm': ?distanceKm,
        'sameAsDay': ?sameAsDay,
      };
}

class TripTaxiShortlistItem {
  final String taxiId;
  final String name;
  final String? vehicleTypeName;
  final int? seats;
  final int? localDayRate;
  final bool wholeTrip;

  const TripTaxiShortlistItem({
    required this.taxiId,
    required this.name,
    this.vehicleTypeName,
    this.seats,
    this.localDayRate,
    this.wholeTrip = false,
  });

  factory TripTaxiShortlistItem.fromJson(Map<String, dynamic> json) => TripTaxiShortlistItem(
        taxiId: json['taxiId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        vehicleTypeName: json['vehicleTypeName'] as String?,
        seats: (json['seats'] as num?)?.toInt(),
        localDayRate: (json['localDayRate'] as num?)?.toInt(),
        wholeTrip: json['wholeTrip'] == true,
      );

  Map<String, dynamic> toJson() => {
        'taxiId': taxiId,
        'name': name,
        'vehicleTypeName': ?vehicleTypeName,
        'seats': ?seats,
        'localDayRate': ?localDayRate,
        if (wholeTrip) 'wholeTrip': true,
      };
}

class TripDay {
  final int day;
  final List<TripSpotRef> spots;
  final TripTaxiChoice? taxi;
  final TripStayChoice? stay;
  final List<TripStayShortlistItem> stayShortlist;
  final List<TripTaxiShortlistItem> taxiShortlist;

  const TripDay({
    required this.day,
    this.spots = const [],
    this.taxi,
    this.stay,
    this.stayShortlist = const [],
    this.taxiShortlist = const [],
  });

  int get visitMinutes => spots.fold(0, (sum, s) => sum + s.visitMinutes);

  TripDay copyWith({
    int? day,
    List<TripSpotRef>? spots,
    TripTaxiChoice? taxi,
    TripStayChoice? stay,
    bool clearTaxi = false,
    bool clearStay = false,
    List<TripStayShortlistItem>? stayShortlist,
    List<TripTaxiShortlistItem>? taxiShortlist,
  }) =>
      TripDay(
        day: day ?? this.day,
        spots: spots ?? this.spots,
        taxi: clearTaxi ? null : (taxi ?? this.taxi),
        stay: clearStay ? null : (stay ?? this.stay),
        stayShortlist: stayShortlist ?? this.stayShortlist,
        taxiShortlist: taxiShortlist ?? this.taxiShortlist,
      );

  factory TripDay.fromJson(Map<String, dynamic> json) => TripDay(
        day: (json['day'] as num).toInt(),
        spots: ((json['spots'] as List?) ?? const [])
            .map((e) => TripSpotRef.fromJson(e as Map<String, dynamic>))
            .toList(),
        taxi: json['taxi'] is Map<String, dynamic> ? TripTaxiChoice.fromJson(json['taxi'] as Map<String, dynamic>) : null,
        stay: json['stay'] is Map<String, dynamic> ? TripStayChoice.fromJson(json['stay'] as Map<String, dynamic>) : null,
        stayShortlist: ((json['stayShortlist'] as List?) ?? const [])
            .map((e) => TripStayShortlistItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        taxiShortlist: ((json['taxiShortlist'] as List?) ?? const [])
            .map((e) => TripTaxiShortlistItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'spots': spots.map((s) => s.toJson()).toList(),
        'taxi': ?taxi?.toJson(),
        'stay': ?stay?.toJson(),
        if (stayShortlist.isNotEmpty) 'stayShortlist': stayShortlist.map((e) => e.toJson()).toList(),
        if (taxiShortlist.isNotEmpty) 'taxiShortlist': taxiShortlist.map((e) => e.toJson()).toList(),
      };
}

class TripSettings {
  final int dayLimitMinutes;
  final DateTime? startDate;
  final int? adults;
  final int? kids;
  final int? rooms;
  final List<String> needs;
  final String? pickupTime;
  final String? pickupPlace;
  final int? maxDays;

  const TripSettings({
    this.dayLimitMinutes = TripConstants.dayLimitMinutes,
    this.startDate,
    this.adults,
    this.kids,
    this.rooms,
    this.needs = const [],
    this.pickupTime,
    this.pickupPlace,
    this.maxDays,
  });

  int get peopleCount => (adults ?? 0) + (kids ?? 0);

  bool get hasDates => startDate != null;

  bool get hasPeople => adults != null;

  String? get peopleSummary {
    final a = adults;
    if (a == null) return null;
    final k = kids ?? 0;
    final adultText = '$a ${a == 1 ? 'adult' : 'adults'}';
    return k == 0 ? adultText : '$adultText, $k ${k == 1 ? 'kid' : 'kids'}';
  }

  String? get roomsSummary {
    final r = rooms;
    return r == null ? null : '$r ${r == 1 ? 'room' : 'rooms'}';
  }

  String get paceLabel => dayLimitMinutes == TripPace.relaxed ? TripStrings.paceRelaxed : TripStrings.paceNormal;

  String? get startDateIso {
    final d = startDate;
    if (d == null) return null;
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  DateTime? dateOf(int day) {
    final d = startDate;
    return d == null ? null : DateTime(d.year, d.month, d.day + day - 1);
  }

  DateTime? endDate(int dayCount) => dateOf(dayCount < 1 ? 1 : dayCount);

  DateTime? checkOutDate(int dayCount) => dateOf((dayCount < 1 ? 1 : dayCount) + 1);

  TripSettings copyWith({
    int? dayLimitMinutes,
    DateTime? startDate,
    bool clearStartDate = false,
    int? adults,
    int? kids,
    int? rooms,
    List<String>? needs,
    String? pickupTime,
    String? pickupPlace,
    int? maxDays,
    bool clearMaxDays = false,
  }) =>
      TripSettings(
        dayLimitMinutes: dayLimitMinutes ?? this.dayLimitMinutes,
        startDate: clearStartDate ? null : (startDate ?? this.startDate),
        adults: adults ?? this.adults,
        kids: kids ?? this.kids,
        rooms: rooms ?? this.rooms,
        needs: needs ?? this.needs,
        pickupTime: pickupTime ?? this.pickupTime,
        pickupPlace: pickupPlace ?? this.pickupPlace,
        maxDays: clearMaxDays ? null : (maxDays ?? this.maxDays),
      );

  factory TripSettings.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['startDate'] as String? ?? '');
    return TripSettings(
      dayLimitMinutes: (json['dayLimitMinutes'] as num?)?.toInt() ?? TripConstants.dayLimitMinutes,
      startDate: start == null ? null : DateTime(start.year, start.month, start.day),
      adults: (json['adults'] as num?)?.toInt(),
      kids: (json['kids'] as num?)?.toInt(),
      rooms: (json['rooms'] as num?)?.toInt(),
      needs: ((json['needs'] as List?) ?? const []).whereType<String>().toList(),
      pickupTime: json['pickupTime'] as String?,
      pickupPlace: json['pickupPlace'] as String?,
      maxDays: _validMaxDays((json['maxDays'] as num?)?.toInt()),
    );
  }

  static int? _validMaxDays(int? v) => v == null || v < 1 || v > TripConstants.maxDaysCap ? null : v;

  Map<String, dynamic> toJson() => {
        'dayLimitMinutes': dayLimitMinutes,
        'startDate': ?startDateIso,
        'adults': ?adults,
        'kids': ?kids,
        'rooms': ?rooms,
        if (needs.isNotEmpty) 'needs': needs,
        'pickupTime': ?pickupTime,
        'pickupPlace': ?pickupPlace,
        'maxDays': ?maxDays,
      };
}

sealed class OwnSaveResult {
  const OwnSaveResult();
}

class OwnSaved extends OwnSaveResult {
  const OwnSaved();
}

class OwnNeedsWithdraw extends OwnSaveResult {
  final List<TripEnquiryModel> open;

  const OwnNeedsWithdraw(this.open);
}

class OwnBlockedByConfirmed extends OwnSaveResult {
  final TripEnquiryModel e;

  const OwnBlockedByConfirmed(this.e);
}

class SettingsSaveResult {
  final bool saved;
  final List<TripEnquiryModel> confirmedAffected;
  final List<TripEnquiryModel> openAffected;

  const SettingsSaveResult({
    required this.saved,
    this.confirmedAffected = const [],
    this.openAffected = const [],
  });

  bool get hasAffected => confirmedAffected.isNotEmpty || openAffected.isNotEmpty;
}

class DateChangeImpact {
  final List<TripEnquiryModel> booked;
  final List<TripEnquiryModel> open;

  const DateChangeImpact({this.booked = const [], this.open = const []});

  List<TripEnquiryModel> get all => [...booked, ...open];

  bool get isEmpty => booked.isEmpty && open.isEmpty;

  int get count => booked.length + open.length;
}

class EditImpact {
  final List<int> droppedDaysWithBookings;

  const EditImpact({this.droppedDaysWithBookings = const []});

  bool get isEmpty => droppedDaysWithBookings.isEmpty;
}

class TripPlan {
  final int version;
  final int cityKey;
  final String? districtId;
  final String cityName;
  final double? centreLatitude;
  final double? centreLongitude;
  final List<TripDay> days;
  final TripSettings settings;

  const TripPlan({
    this.version = TripConstants.planVersion,
    required this.cityKey,
    this.districtId,
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
    String? districtId,
    double? centreLatitude,
    double? centreLongitude,
    List<TripDay>? days,
    TripSettings? settings,
  }) =>
      TripPlan(
        version: version,
        cityKey: cityKey,
        districtId: districtId ?? this.districtId,
        cityName: cityName,
        centreLatitude: centreLatitude ?? this.centreLatitude,
        centreLongitude: centreLongitude ?? this.centreLongitude,
        days: days ?? this.days,
        settings: settings ?? this.settings,
      );

  factory TripPlan.fromJson(Map<String, dynamic> json) => TripPlan(
        version: (json['version'] as num?)?.toInt() ?? TripConstants.planVersion,
        cityKey: (json['cityKey'] as num).toInt(),
        districtId: json['districtId'] as String?,
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
        'cityKey': cityKey,
        'districtId': ?districtId,
        'cityName': cityName,
        'centreLatitude': ?centreLatitude,
        'centreLongitude': ?centreLongitude,
        'days': days.map((d) => d.toJson()).toList(),
        'settings': settings.toJson(),
      };
}
