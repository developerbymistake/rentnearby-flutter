import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../models/place_result_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_steps_a1.dart';
import 'trip_city_model.dart';
import 'trip_enquiry_model.dart';
import 'trip_spot_model.dart';

enum TripStepRole {
  gettingThere,
  comingBack;

  static TripStepRole? parse(Object? wire) => switch (wire) {
        'gettingThere' => gettingThere,
        'comingBack' => comingBack,
        _ => null,
      };

  TripStepRole get other => this == gettingThere ? comingBack : gettingThere;
}

enum TripStepStatus {
  notStarted,
  chosen,
  booked,
  own,
  skipped,
  notNeeded;

  static TripStepStatus parse(Object? wire) {
    for (final s in values) {
      if (s.name == wire) return s;
    }
    return notStarted;
  }

  bool get linksJourney => this == chosen || this == booked;
}

enum TripStepDisplay {
  notStarted,
  asked,
  chosen,
  booked,
  own,
  skipped,
  notNeeded;

  static TripStepDisplay? parse(Object? wire) {
    for (final s in values) {
      if (s.name == wire) return s;
    }
    return null;
  }
}

enum TripLeaveOn {
  checkOut,
  lastDayEvening;

  static TripLeaveOn? parse(Object? wire) => switch (wire) {
        'checkOut' => checkOut,
        'lastDayEvening' => lastDayEvening,
        _ => null,
      };
}

List<int> _carList(Object? raw) {
  if (raw is! List) return const [];
  final out = <int>{
    for (final v in raw)
      if (v is num && v.toInt() >= 1 && v.toInt() <= TripConstants.maxJourneyCars) v.toInt(),
  }.toList()
    ..sort();
  return out;
}

List<int> _withCar(List<int> cars, int car, bool own) {
  final out = {...cars};
  own ? out.add(car) : out.remove(car);
  return out.toList()..sort();
}

String? _noteOf(Object? raw) {
  final s = raw is String ? raw.trim() : null;
  if (s == null || s.isEmpty) return null;
  return s.length > TripConstants.noteMax ? s.substring(0, TripConstants.noteMax).trim() : s;
}

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _parseDay(Object? raw) {
  final d = raw is String ? DateTime.tryParse(raw) : null;
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

class TripStartFrom {
  final String name;
  final double lat;
  final double lon;

  const TripStartFrom({required this.name, required this.lat, required this.lon});

  PlaceResult get place => PlaceResult(name: name, subtitle: '', latLng: LatLng(lat, lon));

  bool sameAs(TripStartFrom? o) => o != null && o.name == name && o.lat == lat && o.lon == lon;

  static TripStartFrom? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final name = (raw['name'] as String?)?.trim() ?? '';
    final lat = (raw['lat'] as num?)?.toDouble();
    final lon = (raw['lon'] as num?)?.toDouble();
    if (name.isEmpty || lat == null || lon == null) return null;
    return TripStartFrom(name: name, lat: lat, lon: lon);
  }

  factory TripStartFrom.fromJson(Map<String, dynamic> json) =>
      tryParse(json) ?? const TripStartFrom(name: '', lat: 0, lon: 0);

  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lon': lon};
}

class TripStep {
  final TripStepStatus status;
  final String? journeyId;
  final String? note;
  final DateTime? date;
  final TripLeaveOn? leaveOn;
  final List<int> ownCars;
  final TripTravelHow? how;
  final String? ownName;
  final String? ownPhone;
  final String? leavesAt;

  const TripStep({
    this.status = TripStepStatus.notStarted,
    this.journeyId,
    this.note,
    this.date,
    this.leaveOn,
    this.ownCars = const [],
    this.how,
    this.ownName,
    this.ownPhone,
    this.leavesAt,
  });

  bool get hasJourney => status.linksJourney && journeyId != null && journeyId!.isNotEmpty;

  TripLeaveOn get leaveOnOrDefault => leaveOn ?? TripLeaveOn.checkOut;

  bool get isDefault =>
      status == TripStepStatus.notStarted &&
      journeyId == null &&
      note == null &&
      date == null &&
      leaveOn == null &&
      ownCars.isEmpty;

  // A fresh step for the same role: only the traveller's leave-on choice survives.
  TripStep get cleared => TripStep(leaveOn: leaveOn);

  TripStep copyWith({
    TripStepStatus? status,
    String? journeyId,
    String? note,
    DateTime? date,
    TripLeaveOn? leaveOn,
    List<int>? ownCars,
    bool clearJourney = false,
    bool clearNote = false,
    bool clearDate = false,
    bool clearLeaveOn = false,
  }) {
    final next = status ?? this.status;
    final own = next == TripStepStatus.own;
    return TripStep(
      status: next,
      journeyId: clearJourney ? null : (journeyId ?? this.journeyId),
      note: clearNote ? null : (note ?? this.note),
      date: clearDate ? null : (date ?? this.date),
      leaveOn: clearLeaveOn ? null : (leaveOn ?? this.leaveOn),
      ownCars: clearJourney ? const [] : (ownCars ?? this.ownCars),
      how: own ? how : null,
      ownName: own ? ownName : null,
      ownPhone: own ? ownPhone : null,
      leavesAt: own ? leavesAt : null,
    );
  }

  TripStep withOwnCar(int car, bool own) => copyWith(ownCars: _withCar(ownCars, car, own));

  static String? _text(Object? raw) {
    final t = raw is String ? raw.trim() : null;
    return t == null || t.isEmpty ? null : t;
  }

  factory TripStep.fromJson(Map<String, dynamic> json) {
    final id = json['journeyId'];
    final status = TripStepStatus.parse(json['status']);
    final own = status == TripStepStatus.own;
    return TripStep(
      status: status,
      journeyId: id is String && id.isNotEmpty ? id : null,
      note: _text(json['note']),
      date: _parseDay(json['date']),
      leaveOn: TripLeaveOn.parse(json['leaveOn']),
      ownCars: _carList(json['ownCars']),
      how: own ? TripTravelHow.parse(json['how']) : null,
      ownName: own ? _text(json['ownName']) : null,
      ownPhone: own ? _text(json['ownPhone']) : null,
      leavesAt: own ? _text(json['leavesAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': (status == TripStepStatus.notNeeded ? TripStepStatus.notStarted : status).name,
        if (journeyId != null && journeyId!.isNotEmpty) 'journeyId': journeyId,
        'note': ?note,
        if (date != null) 'date': _isoDay(date!),
        'leaveOn': ?leaveOn?.name,
        if (ownCars.isNotEmpty) 'ownCars': ownCars,
        'how': ?how?.wire,
        'ownName': ?ownName,
        'ownPhone': ?ownPhone,
        'leavesAt': ?leavesAt,
      };
}

class TripSteps {
  final TripStartFrom? startFrom;
  final TripStartFrom? goingHomeTo;
  final TripStep gettingThere;
  final TripStep comingBack;

  const TripSteps({
    this.startFrom,
    this.goingHomeTo,
    this.gettingThere = const TripStep(),
    this.comingBack = const TripStep(),
  });

  TripStartFrom? get homeEnd => goingHomeTo ?? startFrom;

  TripStartFrom? endOf(TripStepRole r) => r == TripStepRole.comingBack ? homeEnd : startFrom;

  TripStep of(TripStepRole r) => r == TripStepRole.gettingThere ? gettingThere : comingBack;

  TripSteps withStep(TripStepRole r, TripStep s) => TripSteps(
        startFrom: startFrom,
        goingHomeTo: goingHomeTo,
        gettingThere: r == TripStepRole.gettingThere ? s : gettingThere,
        comingBack: r == TripStepRole.comingBack ? s : comingBack,
      );

  TripSteps copyWith({
    TripStartFrom? startFrom,
    bool clearStartFrom = false,
    TripStartFrom? goingHomeTo,
    bool clearGoingHomeTo = false,
  }) =>
      TripSteps(
        startFrom: clearStartFrom ? null : (startFrom ?? this.startFrom),
        goingHomeTo: clearGoingHomeTo ? null : (goingHomeTo ?? this.goingHomeTo),
        gettingThere: gettingThere,
        comingBack: comingBack,
      );

  factory TripSteps.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TripSteps();
    final g = json['gettingThere'];
    final c = json['comingBack'];
    return TripSteps(
      startFrom: TripStartFrom.tryParse(json['startFrom']),
      goingHomeTo: TripStartFrom.tryParse(json['goingHomeTo']),
      gettingThere: g is Map<String, dynamic> ? TripStep.fromJson(g) : const TripStep(),
      comingBack: c is Map<String, dynamic> ? TripStep.fromJson(c) : const TripStep(),
    );
  }

  Map<String, dynamic> toJson() => {
        'startFrom': ?startFrom?.toJson(),
        'goingHomeTo': ?goingHomeTo?.toJson(),
        if (!gettingThere.isDefault) 'gettingThere': gettingThere.toJson(),
        if (!comingBack.isDefault) 'comingBack': comingBack.toJson(),
      };
}

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
  final bool skipped;

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
    this.skipped = false,
  });

  const TripTaxiChoice.skippedDay({this.note})
      : taxiId = '',
        name = TripStringsStepsA1.noTaxiThisDay,
        fare = null,
        vehicleTypeName = null,
        isOwn = false,
        ownPhone = null,
        wholeTrip = false,
        booking = null,
        skipped = true;

  bool get isBooked => booking != null;

  bool get isSkipped => skipped;

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
        skipped: skipped,
      );

  factory TripTaxiChoice.fromJson(Map<String, dynamic> json) => json['skipped'] == true
      ? TripTaxiChoice.skippedDay(note: _noteOf(json['note']))
      : TripTaxiChoice(
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

  Map<String, dynamic> toJson() => skipped
      ? {'skipped': true, 'name': name, 'note': ?note}
      : {
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
  final bool leaveMoved;

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
    this.leaveMoved = false,
  });

  const TripStayChoice.skippedNight({this.note, this.leaveMoved = false})
      : stayId = '',
        name = TripStrings.noStayTonight,
        pricePerNight = null,
        sameAsDay = null,
        latitude = null,
        longitude = null,
        isOwn = false,
        ownPhone = null,
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
        leaveMoved: leaveMoved,
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
      leaveMoved: json['skipped'] == true && json['leaveMoved'] == true,
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
        if (skipped && leaveMoved) 'leaveMoved': true,
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

enum TripTravelHow {
  car,
  bus,
  train,
  flight,
  other;

  static TripTravelHow? parse(Object? wire) {
    for (final h in values) {
      if (h.name == wire) return h;
    }
    return null;
  }

  String get wire => name;
}

class TripOwnPhone {
  static final _valid = RegExp(r'^[6-9]\d{9}$');

  static String? normalise(String? raw) {
    var d = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (d.length == 12 && d.startsWith('91')) {
      d = d.substring(2);
    } else if (d.length == 11 && d.startsWith('0')) {
      d = d.substring(1);
    }
    return _valid.hasMatch(d) ? d : null;
  }
}

class TripTravelModes {
  static const String own = 'own';
  static const String journey = 'journey';
}

class TripTravel {
  final String mode;
  final String fromName;
  final TripTravelHow? how;
  final String? ownName;
  final String? ownPhone;
  final String? leavesAt;
  final int? roadMinutes;
  final String? note;
  final String? journeyId;
  final String? planKey;
  final int? cars;
  final int? listedTotal;
  final String? hubName;
  final List<int> ownCars;

  const TripTravel.own({
    required this.fromName,
    this.how,
    this.ownName,
    this.ownPhone,
    this.leavesAt,
    this.roadMinutes,
    this.note,
    this.hubName,
  })  : mode = TripTravelModes.own,
        journeyId = null,
        planKey = null,
        cars = null,
        listedTotal = null,
        ownCars = const [];

  const TripTravel.journey({
    required this.fromName,
    required String this.journeyId,
    this.planKey,
    this.cars,
    this.listedTotal,
    this.roadMinutes,
    this.ownCars = const [],
  })  : mode = TripTravelModes.journey,
        how = null,
        ownName = null,
        ownPhone = null,
        leavesAt = null,
        note = null,
        hubName = null;

  bool get isJourney => mode == TripTravelModes.journey;

  bool get isOwn => !isJourney;

  bool get hasPhone => ownPhone != null && ownPhone!.isNotEmpty;

  TripTravel withOwnCar(int car, bool own) => isJourney ? copyWith(ownCars: _withCar(ownCars, car, own)) : this;

  TripTravel copyWith({
    String? fromName,
    TripTravelHow? how,
    String? ownName,
    String? ownPhone,
    String? leavesAt,
    int? roadMinutes,
    String? note,
    String? hubName,
    String? journeyId,
    String? planKey,
    int? cars,
    int? listedTotal,
    List<int>? ownCars,
  }) =>
      isJourney
          ? TripTravel.journey(
              fromName: fromName ?? this.fromName,
              journeyId: journeyId ?? this.journeyId!,
              planKey: planKey ?? this.planKey,
              cars: cars ?? this.cars,
              listedTotal: listedTotal ?? this.listedTotal,
              roadMinutes: roadMinutes ?? this.roadMinutes,
              ownCars: journeyId != null && journeyId != this.journeyId ? const [] : (ownCars ?? this.ownCars),
            )
          : TripTravel.own(
              fromName: fromName ?? this.fromName,
              how: how ?? this.how,
              ownName: ownName ?? this.ownName,
              ownPhone: ownPhone ?? this.ownPhone,
              leavesAt: leavesAt ?? this.leavesAt,
              roadMinutes: roadMinutes ?? this.roadMinutes,
              note: note ?? this.note,
              hubName: hubName ?? this.hubName,
            );

  static String? _text(Object? raw) {
    final s = raw is String ? raw.trim() : null;
    return s == null || s.isEmpty ? null : s;
  }

  factory TripTravel.fromJson(Map<String, dynamic> json) {
    final id = _text(json['journeyId']);
    if (json['mode'] == TripTravelModes.journey && id != null) {
      return TripTravel.journey(
        fromName: _text(json['fromName']) ?? '',
        journeyId: id,
        planKey: _text(json['planKey']),
        cars: (json['cars'] as num?)?.toInt(),
        listedTotal: (json['listedTotal'] as num?)?.toInt(),
        roadMinutes: (json['roadMinutes'] as num?)?.toInt(),
        ownCars: _carList(json['ownCars']),
      );
    }
    return TripTravel.own(
      fromName: _text(json['fromName']) ?? '',
      how: TripTravelHow.parse(json['how']),
      ownName: _text(json['ownName']),
      ownPhone: _text(json['ownPhone']),
      leavesAt: _text(json['leavesAt']),
      roadMinutes: (json['roadMinutes'] as num?)?.toInt(),
      note: _text(json['note']),
      hubName: _text(json['hubName']),
    );
  }

  Map<String, dynamic> toJson() => isJourney
      ? {
          'mode': mode,
          'fromName': fromName,
          'journeyId': journeyId,
          'planKey': ?planKey,
          'cars': ?cars,
          'listedTotal': ?listedTotal,
          'roadMinutes': ?roadMinutes,
          if (ownCars.isNotEmpty) 'ownCars': ownCars,
        }
      : {
          'mode': mode,
          'fromName': fromName,
          'how': ?how?.wire,
          'ownName': ?ownName,
          'ownPhone': ?ownPhone,
          'leavesAt': ?leavesAt,
          'roadMinutes': ?roadMinutes,
          'note': ?note,
          'hubName': ?hubName,
        };
}

class TripCityLeg {
  final int index;
  final int cityKey;
  final String cityName;
  final String? districtId;
  final double latitude;
  final double longitude;
  final bool notReady;
  final TripTravel? arrival;

  const TripCityLeg({
    required this.index,
    required this.cityKey,
    required this.cityName,
    this.districtId,
    required this.latitude,
    required this.longitude,
    this.notReady = false,
    this.arrival,
  });

  factory TripCityLeg.fromCity(int index, TripCityModel c) => TripCityLeg(
        index: index,
        cityKey: c.cityKey,
        cityName: c.name,
        latitude: c.latitude,
        longitude: c.longitude,
        notReady: !c.isReady,
      );

  bool get hasPoint => !(latitude == 0 && longitude == 0);

  PlaceResult get place => PlaceResult(name: cityName, subtitle: '', latLng: LatLng(latitude, longitude));

  TripCityModel get city => TripCityModel(
        cityKey: cityKey,
        name: cityName,
        latitude: latitude,
        longitude: longitude,
        status: notReady ? TripCityStatus.notReady : TripCityStatus.ready,
      );

  TripCityLeg copyWith({
    int? index,
    String? districtId,
    double? latitude,
    double? longitude,
    TripTravel? arrival,
    bool clearArrival = false,
    bool? notReady,
  }) =>
      TripCityLeg(
        index: index ?? this.index,
        cityKey: cityKey,
        cityName: cityName,
        districtId: districtId ?? this.districtId,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        notReady: notReady ?? this.notReady,
        arrival: clearArrival ? null : (arrival ?? this.arrival),
      );

  factory TripCityLeg.fromJson(Map<String, dynamic> json) => TripCityLeg(
        index: (json['index'] as num?)?.toInt() ?? 1,
        cityKey: (json['cityKey'] as num?)?.toInt() ?? 0,
        cityName: json['cityName'] as String? ?? '',
        districtId: json['districtId'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        notReady: json['notReady'] == true,
        arrival: json['arrival'] is Map<String, dynamic>
            ? TripTravel.fromJson(json['arrival'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'index': index,
        'cityKey': cityKey,
        'cityName': cityName,
        'districtId': ?districtId,
        'latitude': latitude,
        'longitude': longitude,
        if (notReady) 'notReady': true,
        if (index >= 2) 'arrival': ?arrival?.toJson(),
      };
}

enum TripLegEditBlock { none, onlyLeg, maxLegs, noDays, duplicate, offline, readOnly, running, bookings, edge }

enum TripLegRemoveMode { shift, keepLaterDates }

class TripDay {
  final int day;
  final int leg;
  final List<TripSpotRef> spots;
  final TripTaxiChoice? taxi;
  final TripStayChoice? stay;
  final List<TripStayShortlistItem> stayShortlist;
  final List<TripTaxiShortlistItem> taxiShortlist;
  final bool restDay;

  const TripDay({
    required this.day,
    this.leg = 1,
    this.spots = const [],
    this.taxi,
    this.stay,
    this.stayShortlist = const [],
    this.taxiShortlist = const [],
    this.restDay = false,
  });

  int get visitMinutes => spots.fold(0, (sum, s) => sum + s.visitMinutes);

  TripDay copyWith({
    int? day,
    int? leg,
    List<TripSpotRef>? spots,
    TripTaxiChoice? taxi,
    TripStayChoice? stay,
    bool clearTaxi = false,
    bool clearStay = false,
    List<TripStayShortlistItem>? stayShortlist,
    List<TripTaxiShortlistItem>? taxiShortlist,
    bool? restDay,
  }) =>
      TripDay(
        day: day ?? this.day,
        leg: leg ?? this.leg,
        spots: spots ?? this.spots,
        taxi: clearTaxi ? null : (taxi ?? this.taxi),
        stay: clearStay ? null : (stay ?? this.stay),
        stayShortlist: stayShortlist ?? this.stayShortlist,
        taxiShortlist: taxiShortlist ?? this.taxiShortlist,
        restDay: restDay ?? this.restDay,
      );

  factory TripDay.fromJson(Map<String, dynamic> json) => TripDay(
        day: (json['day'] as num).toInt(),
        leg: (json['leg'] as num?)?.toInt() ?? 1,
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
        restDay: json['restDay'] == true,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'leg': leg,
        'spots': spots.map((s) => s.toJson()).toList(),
        'taxi': ?taxi?.toJson(),
        'stay': ?stay?.toJson(),
        if (stayShortlist.isNotEmpty) 'stayShortlist': stayShortlist.map((e) => e.toJson()).toList(),
        if (taxiShortlist.isNotEmpty) 'taxiShortlist': taxiShortlist.map((e) => e.toJson()).toList(),
        if (restDay) 'restDay': true,
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

class OwnNothingToSave extends OwnSaveResult {
  const OwnNothingToSave();
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
  final List<TripEnquiryModel> bookedTaxiAffected;
  final List<TripEnquiryModel> openTaxiAffected;

  const SettingsSaveResult({
    required this.saved,
    this.confirmedAffected = const [],
    this.openAffected = const [],
    this.bookedTaxiAffected = const [],
    this.openTaxiAffected = const [],
  });

  bool get hasAffected =>
      confirmedAffected.isNotEmpty ||
      openAffected.isNotEmpty ||
      bookedTaxiAffected.isNotEmpty ||
      openTaxiAffected.isNotEmpty;
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

class LegImpact {
  final List<TripEnquiryModel> open;
  final List<TripEnquiryModel> booked;
  final List<TripEnquiryModel> cars;
  final List<int> travelLegs;
  final bool laterKeepDates;
  final List<String> laterCities;
  final bool carsBlockKeep;

  const LegImpact({
    this.open = const [],
    this.booked = const [],
    this.cars = const [],
    this.travelLegs = const [],
    this.laterKeepDates = false,
    this.laterCities = const [],
    this.carsBlockKeep = false,
  });

  const LegImpact.empty()
      : open = const [],
        booked = const [],
        cars = const [],
        travelLegs = const [],
        laterKeepDates = false,
        laterCities = const [],
        carsBlockKeep = false;

  static bool _carBooked(TripEnquiryModel e) =>
      e.status == TripEnquiryStatuses.bookedByTraveller || e.status == TripEnquiryStatuses.confirmedByBoth;

  int get openCount => open.length + cars.where((e) => !_carBooked(e)).length;

  int get bookedCount => booked.length + cars.where(_carBooked).length;

  int get hosts => {for (final e in [...open, ...booked]) if (!e.isTaxi) e.id}.length;

  int get drivers => {for (final e in [...open, ...booked, ...cars]) if (e.isTaxi) e.id}.length;

  bool get isEmpty => open.isEmpty && booked.isEmpty && cars.isEmpty;

  bool get hasBooked => bookedCount > 0;
}

class LegCancelResult {
  final int closed;
  final int failed;

  const LegCancelResult({this.closed = 0, this.failed = 0});

  bool get ok => failed == 0;
}

enum NoStayBlock { none, readOnly, hasEnquiry, hasOwn }

enum NoTaxiBlock { none, readOnly, hasEnquiry, hasOwn }

class TripPlan {
  final int version;
  final List<TripCityLeg> legs;
  final List<TripDay> days;
  final TripSettings settings;
  final TripSteps steps;
  final List<String> dismissedEnquiryIds;

  const TripPlan({
    this.version = TripConstants.planVersion,
    required this.legs,
    this.days = const [],
    this.settings = const TripSettings(),
    this.steps = const TripSteps(),
    this.dismissedEnquiryIds = const [],
  });

  factory TripPlan.singleCity({
    required int cityKey,
    required String cityName,
    String? districtId,
    double? centreLatitude,
    double? centreLongitude,
    List<TripDay> days = const [],
    TripSettings settings = const TripSettings(),
    TripSteps steps = const TripSteps(),
  }) =>
      TripPlan(
        legs: [
          TripCityLeg(
            index: 1,
            cityKey: cityKey,
            cityName: cityName,
            districtId: districtId,
            latitude: centreLatitude ?? 0,
            longitude: centreLongitude ?? 0,
          ),
        ],
        days: days,
        settings: settings,
        steps: steps,
      );

  static const TripCityLeg _noLeg = TripCityLeg(index: 1, cityKey: 0, cityName: '', latitude: 0, longitude: 0);

  TripCityLeg get _first => legs.isEmpty ? _noLeg : legs.first;

  int get cityKey => _first.cityKey;

  String get cityName => _first.cityName;

  String? get districtId => _first.districtId;

  double? get centreLatitude => legs.isEmpty || !_first.hasPoint ? null : _first.latitude;

  double? get centreLongitude => legs.isEmpty || !_first.hasPoint ? null : _first.longitude;

  int get legCount => legs.isEmpty ? 1 : legs.length;

  bool get isMultiCity => legs.length > 1;

  List<String> get legCities => legs.isEmpty ? [cityName] : [for (final l in legs) l.cityName];

  TripCityLeg? legAt(int index) => index >= 1 && index <= legs.length ? legs[index - 1] : null;

  int legIndexOf(int day) {
    final d = dayAt(day);
    if (d == null || legs.isEmpty) return 1;
    return d.leg.clamp(1, legs.length);
  }

  TripCityLeg legOf(int day) => legAt(legIndexOf(day)) ?? _first;

  List<TripDay> daysOf(int legIndex) => [
        for (final d in days)
          if (d.leg == legIndex) d,
      ];

  int legStart(int legIndex) {
    for (final d in days) {
      if (d.leg == legIndex) return d.day;
    }
    return 0;
  }

  int legEnd(int legIndex) {
    var end = 0;
    for (final d in days) {
      if (d.leg == legIndex) end = d.day;
    }
    return end;
  }

  int legDayCount(int legIndex) => days.where((d) => d.leg == legIndex).length;

  int legSpotCount(int legIndex) =>
      days.where((d) => d.leg == legIndex).fold(0, (sum, d) => sum + d.spots.length);

  bool isTravelDay(int day) {
    if (dayAt(day) == null) return false;
    final k = legIndexOf(day);
    return k >= 2 && legStart(k) == day;
  }

  String? districtIdOf(int day) => legOf(day).districtId;

  String cityNameOf(int day) => legOf(day).cityName;

  int? legIndexOfCity(int cityKey) {
    for (final l in legs) {
      if (l.cityKey == cityKey) return l.index;
    }
    return null;
  }

  static List<TripCityLeg> reindex(List<TripCityLeg> legs) => [
        for (var i = 0; i < legs.length; i++)
          legs[i].index == i + 1 && (i > 0 || legs[i].arrival == null)
              ? legs[i]
              : legs[i].copyWith(index: i + 1, clearArrival: i == 0),
      ];

  TripPlan withLegs(List<TripCityLeg> legs) => copyWith(legs: reindex(legs));

  TripPlan withLegDistrict(int legIndex, String districtId) {
    if (legAt(legIndex) == null) return this;
    return copyWith(legs: [
      for (final l in legs) l.index == legIndex ? l.copyWith(districtId: districtId) : l,
    ]);
  }

  TripPlan withArrival(int legIndex, TripTravel? arrival) {
    if (legIndex < 2 || legAt(legIndex) == null) return this;
    return copyWith(legs: [
      for (final l in legs)
        l.index == legIndex ? l.copyWith(arrival: arrival, clearArrival: arrival == null) : l,
    ]);
  }

  int? segmentLegOf(String journeyId) {
    if (journeyId.isEmpty) return null;
    for (final l in legs) {
      final a = l.arrival;
      if (l.index >= 2 && a != null && a.isJourney && a.journeyId == journeyId) return l.index;
    }
    return null;
  }

  List<String> get segmentJourneyIds => [
        for (final l in legs)
          if (l.index >= 2 && (l.arrival?.isJourney ?? false)) l.arrival!.journeyId!,
      ];

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
    List<TripCityLeg>? legs,
    List<TripDay>? days,
    TripSettings? settings,
    TripSteps? steps,
    List<String>? dismissedEnquiryIds,
    String? districtId,
    double? centreLatitude,
    double? centreLongitude,
  }) {
    var next = legs ?? this.legs;
    if ((districtId != null || centreLatitude != null || centreLongitude != null) && next.isNotEmpty) {
      next = [
        next.first.copyWith(districtId: districtId, latitude: centreLatitude, longitude: centreLongitude),
        ...next.skip(1),
      ];
    }
    return TripPlan(
      version: version,
      legs: next,
      days: days ?? this.days,
      settings: settings ?? this.settings,
      steps: steps ?? this.steps,
      dismissedEnquiryIds: dismissedEnquiryIds ?? this.dismissedEnquiryIds,
    );
  }

  TripPlan withDismissed(String enquiryId) {
    if (enquiryId.isEmpty || dismissedEnquiryIds.contains(enquiryId)) return this;
    final next = [...dismissedEnquiryIds, enquiryId];
    final over = next.length - TripConstants.maxDismissed;
    return copyWith(dismissedEnquiryIds: over > 0 ? next.sublist(over) : next);
  }

  static List<String> _ids(Object? raw) => raw is List
      ? [
          for (final v in raw)
            if (v is String && v.isNotEmpty) v,
        ].toSet().toList()
      : const [];

  factory TripPlan.fromJson(Map<String, dynamic> json) {
    final rawLegs = json['legs'] is List ? json['legs'] as List : const [];
    var legs = <TripCityLeg>[
      for (final e in rawLegs)
        if (e is Map<String, dynamic>) TripCityLeg.fromJson(e),
    ];
    if (legs.isEmpty) {
      legs = [
        TripCityLeg(
          index: 1,
          cityKey: (json['cityKey'] as num?)?.toInt() ?? 0,
          cityName: json['cityName'] as String? ?? '',
          districtId: json['districtId'] as String?,
          latitude: (json['centreLatitude'] as num?)?.toDouble() ?? 0,
          longitude: (json['centreLongitude'] as num?)?.toDouble() ?? 0,
        ),
      ];
    }
    legs = reindex(legs);
    final rawDays = json['days'] is List ? json['days'] as List : const [];
    final days = <TripDay>[];
    var prev = 1;
    for (final e in rawDays) {
      if (e is! Map<String, dynamic>) continue;
      final raw = (e['leg'] as num?)?.toInt();
      var leg = days.isEmpty ? 1 : (raw ?? prev);
      if (leg > legs.length) leg = legs.length;
      if (leg < prev) leg = prev;
      prev = leg;
      days.add(TripDay.fromJson(e).copyWith(leg: leg));
    }
    return TripPlan(
      version: (json['version'] as num?)?.toInt() ?? TripConstants.planVersion,
      legs: legs,
      days: days,
      settings: json['settings'] is Map<String, dynamic>
          ? TripSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : const TripSettings(),
      steps: TripSteps.fromJson(json['steps'] is Map<String, dynamic> ? json['steps'] as Map<String, dynamic> : null),
      dismissedEnquiryIds: _ids(json['dismissedEnquiryIds']),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version < TripConstants.planVersion ? TripConstants.planVersion : version,
        'cityKey': cityKey,
        'districtId': ?districtId,
        'cityName': cityName,
        'centreLatitude': ?centreLatitude,
        'centreLongitude': ?centreLongitude,
        'legs': [for (final l in legs) l.toJson()],
        'days': days.map((d) => d.toJson()).toList(),
        'settings': settings.toJson(),
        'steps': steps.toJson(),
        'dismissedEnquiryIds': dismissedEnquiryIds,
      };
}
