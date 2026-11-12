import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../models/place_result_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
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
  skipped;

  static TripStepStatus parse(Object? wire) {
    for (final s in values) {
      if (s.name == wire) return s;
    }
    return notStarted;
  }

  bool get linksJourney => this == chosen || this == booked;
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

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _parseDay(Object? raw) {
  final d = raw is String ? DateTime.tryParse(raw) : null;
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

enum TripRowMarkStatus {
  own,
  skipped;

  static TripRowMarkStatus? parse(Object? wire) => switch (wire) {
        'own' => own,
        'skipped' => skipped,
        _ => null,
      };
}

class TripRowMark {
  final TripRowMarkStatus status;

  const TripRowMark(this.status);

  const TripRowMark.own() : status = TripRowMarkStatus.own;

  const TripRowMark.skipped() : status = TripRowMarkStatus.skipped;

  bool get isOwn => status == TripRowMarkStatus.own;

  bool get isSkipped => status == TripRowMarkStatus.skipped;

  static TripRowMark? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final s = TripRowMarkStatus.parse(raw['status']);
    return s == null ? null : TripRowMark(s);
  }

  factory TripRowMark.fromJson(Map<String, dynamic> json) => tryParse(json) ?? const TripRowMark.skipped();

  Map<String, dynamic> toJson() => {'status': status.name};

  @override
  bool operator ==(Object other) => other is TripRowMark && other.status == status;

  @override
  int get hashCode => status.hashCode;
}

enum TripEasyRowKind { gettingThere, stay, between, taxi, comingBack }

class TripEasyRowKey {
  final TripEasyRowKind kind;
  final int? legIndex;

  const TripEasyRowKey(this.kind, [this.legIndex]);

  String get id => legIndex == null ? kind.name : '${kind.name}:$legIndex';

  static TripEasyRowKey? parse(String? id) {
    if (id == null || id.isEmpty) return null;
    final parts = id.split(':');
    TripEasyRowKind? kind;
    for (final k in TripEasyRowKind.values) {
      if (k.name == parts.first) kind = k;
    }
    if (kind == null) return null;
    if (parts.length == 1) return TripEasyRowKey(kind);
    final n = parts.length == 2 ? int.tryParse(parts[1]) : null;
    return n == null || n < 1 ? null : TripEasyRowKey(kind, n);
  }

  @override
  bool operator ==(Object other) => other is TripEasyRowKey && other.kind == kind && other.legIndex == legIndex;

  @override
  int get hashCode => Object.hash(kind, legIndex);

  @override
  String toString() => id;
}

enum TripRowState {
  todo,
  asked,
  offer,
  confirmed,
  booked,
  own,
  saved,
  skipped,
  attention;

  bool get isDone => this == confirmed || this == booked || this == own || this == saved;

  bool get inProgress => this == asked || this == offer;

  static TripRowState parse(Object? wire) {
    for (final s in values) {
      if (s.name == wire) return s;
    }
    return todo;
  }
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
  final DateTime? date;
  final TripLeaveOn? leaveOn;
  final List<int> ownCars;

  const TripStep({
    this.status = TripStepStatus.notStarted,
    this.journeyId,
    this.date,
    this.leaveOn,
    this.ownCars = const [],
  });

  bool get hasJourney => status.linksJourney && journeyId != null && journeyId!.isNotEmpty;

  TripLeaveOn get leaveOnOrDefault => leaveOn ?? TripLeaveOn.checkOut;

  bool get isDefault =>
      status == TripStepStatus.notStarted &&
      journeyId == null &&
      date == null &&
      leaveOn == null &&
      ownCars.isEmpty;

  // A fresh step for the same role: only the traveller's leave-on choice survives.
  TripStep get cleared => TripStep(leaveOn: leaveOn);

  TripStep copyWith({
    TripStepStatus? status,
    String? journeyId,
    DateTime? date,
    TripLeaveOn? leaveOn,
    List<int>? ownCars,
    bool clearJourney = false,
    bool clearDate = false,
    bool clearLeaveOn = false,
  }) =>
      TripStep(
        status: status ?? this.status,
        journeyId: clearJourney ? null : (journeyId ?? this.journeyId),
        date: clearDate ? null : (date ?? this.date),
        leaveOn: clearLeaveOn ? null : (leaveOn ?? this.leaveOn),
        ownCars: clearJourney ? const [] : (ownCars ?? this.ownCars),
      );

  TripStep withOwnCar(int car, bool own) => copyWith(ownCars: _withCar(ownCars, car, own));

  factory TripStep.fromJson(Map<String, dynamic> json) {
    final id = json['journeyId'];
    return TripStep(
      status: TripStepStatus.parse(json['status']),
      journeyId: id is String && id.isNotEmpty ? id : null,
      date: _parseDay(json['date']),
      leaveOn: TripLeaveOn.parse(json['leaveOn']),
      ownCars: _carList(json['ownCars']),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        if (journeyId != null && journeyId!.isNotEmpty) 'journeyId': journeyId,
        if (date != null) 'date': _isoDay(date!),
        'leaveOn': ?leaveOn?.name,
        if (ownCars.isNotEmpty) 'ownCars': ownCars,
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

class TripTravel {
  final String fromName;
  final String journeyId;
  final String? planKey;
  final int? cars;
  final int? listedTotal;
  final int? roadMinutes;
  final List<int> ownCars;

  const TripTravel({
    required this.fromName,
    required this.journeyId,
    this.planKey,
    this.cars,
    this.listedTotal,
    this.roadMinutes,
    this.ownCars = const [],
  });

  TripTravel withOwnCar(int car, bool own) => copyWith(ownCars: _withCar(ownCars, car, own));

  TripTravel copyWith({
    String? fromName,
    int? roadMinutes,
    String? journeyId,
    String? planKey,
    int? cars,
    int? listedTotal,
    List<int>? ownCars,
  }) =>
      TripTravel(
        fromName: fromName ?? this.fromName,
        journeyId: journeyId ?? this.journeyId,
        planKey: planKey ?? this.planKey,
        cars: cars ?? this.cars,
        listedTotal: listedTotal ?? this.listedTotal,
        roadMinutes: roadMinutes ?? this.roadMinutes,
        ownCars: journeyId != null && journeyId != this.journeyId ? const [] : (ownCars ?? this.ownCars),
      );

  static String? _text(Object? raw) {
    final s = raw is String ? raw.trim() : null;
    return s == null || s.isEmpty ? null : s;
  }

  static TripTravel? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = _text(raw['journeyId']);
    if (id == null) return null;
    return TripTravel(
      fromName: _text(raw['fromName']) ?? '',
      journeyId: id,
      planKey: _text(raw['planKey']),
      cars: (raw['cars'] as num?)?.toInt(),
      listedTotal: (raw['listedTotal'] as num?)?.toInt(),
      roadMinutes: (raw['roadMinutes'] as num?)?.toInt(),
      ownCars: _carList(raw['ownCars']),
    );
  }

  Map<String, dynamic> toJson() => {
        'fromName': fromName,
        'journeyId': journeyId,
        'planKey': ?planKey,
        'cars': ?cars,
        'listedTotal': ?listedTotal,
        'roadMinutes': ?roadMinutes,
        if (ownCars.isNotEmpty) 'ownCars': ownCars,
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
  final TripRowMark? stayMark;
  final TripRowMark? travelMark;

  const TripCityLeg({
    required this.index,
    required this.cityKey,
    required this.cityName,
    this.districtId,
    required this.latitude,
    required this.longitude,
    this.notReady = false,
    this.arrival,
    this.stayMark,
    this.travelMark,
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
    TripRowMark? stayMark,
    bool clearStayMark = false,
    TripRowMark? travelMark,
    bool clearTravelMark = false,
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
        stayMark: clearStayMark ? null : (stayMark ?? this.stayMark),
        travelMark: clearTravelMark ? null : (travelMark ?? this.travelMark),
      );

  factory TripCityLeg.fromJson(Map<String, dynamic> json) {
    final index = (json['index'] as num?)?.toInt() ?? 1;
    return TripCityLeg(
      index: index,
      cityKey: (json['cityKey'] as num?)?.toInt() ?? 0,
      cityName: json['cityName'] as String? ?? '',
      districtId: json['districtId'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      notReady: json['notReady'] == true,
      arrival: index >= 2 ? TripTravel.tryParse(json['arrival']) : null,
      stayMark: TripRowMark.tryParse(json['stayMark']),
      travelMark: index >= 2 ? TripRowMark.tryParse(json['travelMark']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'cityKey': cityKey,
        'cityName': cityName,
        'districtId': ?districtId,
        'latitude': latitude,
        'longitude': longitude,
        if (notReady) 'notReady': true,
        if (index >= 2) 'arrival': ?arrival?.toJson(),
        'stayMark': ?stayMark?.toJson(),
        if (index >= 2 && arrival == null) 'travelMark': ?travelMark?.toJson(),
      };
}

enum TripLegEditBlock { none, onlyLeg, maxLegs, noDays, duplicate, offline, readOnly, running, bookings, edge }

enum TripLegRemoveMode { shift, keepLaterDates }

class TripDay {
  final int day;
  final int leg;
  final List<TripSpotRef> spots;
  final bool restDay;

  const TripDay({
    required this.day,
    this.leg = 1,
    this.spots = const [],
    this.restDay = false,
  });

  int get visitMinutes => spots.fold(0, (sum, s) => sum + s.visitMinutes);

  TripDay copyWith({
    int? day,
    int? leg,
    List<TripSpotRef>? spots,
    bool? restDay,
  }) =>
      TripDay(
        day: day ?? this.day,
        leg: leg ?? this.leg,
        spots: spots ?? this.spots,
        restDay: restDay ?? this.restDay,
      );

  factory TripDay.fromJson(Map<String, dynamic> json) => TripDay(
        day: (json['day'] as num).toInt(),
        leg: (json['leg'] as num?)?.toInt() ?? 1,
        spots: ((json['spots'] as List?) ?? const [])
            .map((e) => TripSpotRef.fromJson(e as Map<String, dynamic>))
            .toList(),
        restDay: json['restDay'] == true,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'leg': leg,
        'spots': spots.map((s) => s.toJson()).toList(),
        if (restDay) 'restDay': true,
      };
}

class TripSettings {
  final int dayLimitMinutes;
  final DateTime? startDate;
  final int? adults;
  final int? kids;
  final int? maxDays;

  const TripSettings({
    this.dayLimitMinutes = TripConstants.dayLimitMinutes,
    this.startDate,
    this.adults,
    this.kids,
    this.maxDays,
  });

  int get peopleCount => (adults ?? 0) + (kids ?? 0);

  bool get hasDates => startDate != null;

  bool get hasPeople => adults != null;

  bool get isRelaxed => dayLimitMinutes <= TripPace.relaxed;

  String? get peopleSummary {
    final a = adults;
    if (a == null) return null;
    final k = kids ?? 0;
    final adultText = '$a ${a == 1 ? 'adult' : 'adults'}';
    return k == 0 ? adultText : '$adultText, $k ${k == 1 ? 'kid' : 'kids'}';
  }

  String get paceLabel => isRelaxed ? TripStrings.paceRelaxed : TripStrings.paceNormal;

  String? get startDateIso {
    final d = startDate;
    if (d == null) return null;
    return _isoDay(d);
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
    int? maxDays,
    bool clearMaxDays = false,
  }) =>
      TripSettings(
        dayLimitMinutes: dayLimitMinutes ?? this.dayLimitMinutes,
        startDate: clearStartDate ? null : (startDate ?? this.startDate),
        adults: adults ?? this.adults,
        kids: kids ?? this.kids,
        maxDays: clearMaxDays ? null : (maxDays ?? this.maxDays),
      );

  factory TripSettings.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['startDate'] as String? ?? '');
    return TripSettings(
      dayLimitMinutes: (json['dayLimitMinutes'] as num?)?.toInt() ?? TripConstants.dayLimitMinutes,
      startDate: start == null ? null : DateTime(start.year, start.month, start.day),
      adults: (json['adults'] as num?)?.toInt(),
      kids: (json['kids'] as num?)?.toInt(),
      maxDays: _validMaxDays((json['maxDays'] as num?)?.toInt()),
    );
  }

  static int? _validMaxDays(int? v) => v == null || v < 1 || v > TripConstants.maxDaysCap ? null : v;

  Map<String, dynamic> toJson() => {
        'dayLimitMinutes': dayLimitMinutes,
        'startDate': ?startDateIso,
        'adults': ?adults,
        'kids': ?kids,
        'maxDays': ?maxDays,
      };
}

sealed class TripMarkResult {
  const TripMarkResult();
}

class TripMarked extends TripMarkResult {
  const TripMarked();
}

class TripMarkNeedsWithdraw extends TripMarkResult {
  final List<TripEnquiryModel> open;

  const TripMarkNeedsWithdraw(this.open);
}

class TripMarkBlocked extends TripMarkResult {
  final TripEnquiryModel confirmed;

  const TripMarkBlocked(this.confirmed);
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

enum TripGuideChoice {
  find,
  own,
  skip;

  static TripGuideChoice? parse(Object? wire) {
    for (final c in values) {
      if (c.name == wire) return c;
    }
    return null;
  }
}

class TripGuide {
  static final RegExp stepPattern = RegExp(r'^(gettingThere|comingBack|taxi|stay:[1-9][0-9]?|between:[2-9][0-9]?)$');
  static const int maxChoices = 30;

  final String step;
  final Map<String, TripGuideChoice> choices;
  final bool overview;

  const TripGuide({this.step = '', this.choices = const {}, this.overview = false});

  bool get isDefault => step.isEmpty && choices.isEmpty && !overview;

  TripGuide copyWith({String? step, Map<String, TripGuideChoice>? choices, bool? overview}) =>
      TripGuide(step: step ?? this.step, choices: choices ?? this.choices, overview: overview ?? this.overview);

  TripGuide withChoice(String step, TripGuideChoice? choice) {
    final next = {...choices};
    if (choice == null) {
      next.remove(step);
    } else {
      if (!next.containsKey(step) && next.length >= maxChoices) return this;
      next[step] = choice;
    }
    return copyWith(choices: next);
  }

  static TripGuide? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final s = raw['step'];
    final step = s is String && stepPattern.hasMatch(s) ? s : '';
    final out = <String, TripGuideChoice>{};
    final c = raw['choices'];
    if (c is Map) {
      for (final e in c.entries) {
        final k = e.key;
        final v = TripGuideChoice.parse(e.value);
        if (k is String && v != null && stepPattern.hasMatch(k) && out.length < maxChoices) out[k] = v;
      }
    }
    final g = TripGuide(step: step, choices: out, overview: raw['overview'] == true);
    return g.isDefault ? null : g;
  }

  Map<String, dynamic> toJson() => {
        if (step.isNotEmpty) 'step': step,
        'choices': {for (final e in choices.entries) e.key: e.value.name},
        if (overview) 'overview': true,
      };

  @override
  bool operator ==(Object other) =>
      other is TripGuide &&
      other.step == step &&
      other.overview == overview &&
      other.choices.length == choices.length &&
      choices.entries.every((e) => other.choices[e.key] == e.value);

  @override
  int get hashCode => Object.hash(step, overview, choices.length);
}

class TripPlan {
  final int version;
  final List<TripCityLeg> legs;
  final List<TripDay> days;
  final TripSettings settings;
  final TripSteps steps;
  final TripRowMark? taxiMark;
  final List<String> dismissedEnquiryIds;
  final TripGuide? guide;

  const TripPlan({
    this.version = TripConstants.planVersion,
    required this.legs,
    this.days = const [],
    this.settings = const TripSettings(),
    this.steps = const TripSteps(),
    this.taxiMark,
    this.dismissedEnquiryIds = const [],
    this.guide,
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

  bool isSingleDayLeg(int legIndex) => legDayCount(legIndex) == 1;

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
          legs[i].index == i + 1 && (i > 0 || (legs[i].arrival == null && legs[i].travelMark == null))
              ? legs[i]
              : legs[i].copyWith(index: i + 1, clearArrival: i == 0, clearTravelMark: i == 0),
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
        l.index == legIndex
            ? l.copyWith(arrival: arrival, clearArrival: arrival == null, clearTravelMark: arrival != null)
            : l,
    ]);
  }

  TripPlan withStayMark(int legIndex, TripRowMark? m) {
    if (legAt(legIndex) == null) return this;
    return copyWith(legs: [
      for (final l in legs) l.index == legIndex ? l.copyWith(stayMark: m, clearStayMark: m == null) : l,
    ]);
  }

  TripPlan withTravelMark(int legIndex, TripRowMark? m) {
    if (legIndex < 2 || legAt(legIndex) == null) return this;
    return copyWith(legs: [
      for (final l in legs)
        l.index == legIndex
            ? l.copyWith(travelMark: m, clearTravelMark: m == null, clearArrival: m != null)
            : l,
    ]);
  }

  TripPlan withTaxiMark(TripRowMark? m) => copyWith(taxiMark: m, clearTaxiMark: m == null);

  int? segmentLegOf(String journeyId) {
    if (journeyId.isEmpty) return null;
    for (final l in legs) {
      final a = l.arrival;
      if (l.index >= 2 && a != null && a.journeyId == journeyId) return l.index;
    }
    return null;
  }

  List<String> get segmentJourneyIds => [
        for (final l in legs)
          if (l.index >= 2 && l.arrival != null) l.arrival!.journeyId,
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
    TripRowMark? taxiMark,
    bool clearTaxiMark = false,
    List<String>? dismissedEnquiryIds,
    TripGuide? guide,
    bool clearGuide = false,
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
      taxiMark: clearTaxiMark ? null : (taxiMark ?? this.taxiMark),
      dismissedEnquiryIds: dismissedEnquiryIds ?? this.dismissedEnquiryIds,
      guide: clearGuide ? null : (guide ?? this.guide),
    );
  }

  TripPlan withGuide(TripGuide? g) => copyWith(guide: g, clearGuide: g == null || g.isDefault);

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
      taxiMark: TripRowMark.tryParse(json['taxiMark']),
      dismissedEnquiryIds: _ids(json['dismissedEnquiryIds']),
      guide: TripGuide.tryParse(json['guide']),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': TripConstants.planVersion,
        'cityKey': cityKey,
        'districtId': ?districtId,
        'cityName': cityName,
        'centreLatitude': ?centreLatitude,
        'centreLongitude': ?centreLongitude,
        'legs': [for (final l in legs) l.toJson()],
        'days': days.map((d) => d.toJson()).toList(),
        'settings': settings.toJson(),
        'steps': steps.toJson(),
        'taxiMark': ?taxiMark?.toJson(),
        'dismissedEnquiryIds': dismissedEnquiryIds,
        if (guide != null && !guide!.isDefault) 'guide': guide!.toJson(),
      };
}