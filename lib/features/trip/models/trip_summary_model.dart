import '../utils/trip_format.dart';
import '../utils/trip_travel_rules.dart';
import '../widgets/trip_status.dart';
import '../trip_strings.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mca_a4.dart';
import 'trip_enquiry_model.dart';
import 'trip_journey_model.dart';
import 'trip_plan_model.dart';

class TripSummaryRoom {
  final String? roomName;
  final int units;
  final int guests;

  const TripSummaryRoom({this.roomName, this.units = 1, this.guests = 0});

  factory TripSummaryRoom.fromJson(Map<String, dynamic> json) => TripSummaryRoom(
        roomName: json['roomName'] as String?,
        units: (json['units'] as num?)?.toInt() ?? 1,
        guests: (json['guests'] as num?)?.toInt() ?? 0,
      );
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) build) =>
    ((raw as List?) ?? const []).whereType<Map<String, dynamic>>().map(build).toList();

List<String>? _citiesOf(Object? raw) {
  if (raw is! List) return null;
  final out = raw.whereType<String>().where((c) => c.isNotEmpty).toList();
  return out.isEmpty ? null : out;
}

String _confirmedLine(String? confirmedBy, DateTime? at) {
  if (confirmedBy == null || at == null) return TripStrings.notConfirmedYet;
  final d = TripFormat.shortDate(at.toLocal());
  return confirmedBy == 'both' ? TripStrings.byBothOn(d) : TripStrings.byYouOn(d);
}

class TripSummaryNight {
  final int night;
  final DateTime? date;
  final String listingName;
  final String? enquiryId;
  final String displayStatus;
  final List<TripSummaryRoom> roomLines;
  final int? agreedTotal;
  final String? advanceStatus;
  final int? advanceAmount;
  final String? cancellationText;
  final bool? gstInvoice;
  final String? confirmedBy;
  final DateTime? confirmedAt;
  final String? cancelledBy;

  const TripSummaryNight({
    required this.night,
    this.date,
    this.listingName = '',
    this.enquiryId,
    this.displayStatus = 'none',
    this.roomLines = const [],
    this.agreedTotal,
    this.advanceStatus,
    this.advanceAmount,
    this.cancellationText,
    this.gstInvoice,
    this.confirmedBy,
    this.confirmedAt,
    this.cancelledBy,
  });

  factory TripSummaryNight.fromJson(Map<String, dynamic> json) => TripSummaryNight(
        night: (json['night'] as num?)?.toInt() ?? 0,
        date: tripDate(json['date']),
        listingName: json['listingName'] as String? ?? '',
        enquiryId: json['enquiryId'] as String?,
        displayStatus: json['displayStatus'] as String? ?? 'none',
        roomLines: _list(json['roomLines'], TripSummaryRoom.fromJson),
        agreedTotal: (json['agreedTotal'] as num?)?.toInt(),
        advanceStatus: json['advanceStatus'] as String?,
        advanceAmount: (json['advanceAmount'] as num?)?.toInt(),
        cancellationText: json['cancellationText'] as String?,
        gstInvoice: json['gstInvoice'] as bool?,
        confirmedBy: json['confirmedBy'] as String?,
        confirmedAt: tripInstant(json['confirmedAt']),
        cancelledBy: json['cancelledBy'] as String?,
      );

  TripDisplayStatus get display => TripDisplayStatus.parse(displayStatus);
  bool get isCancelled => cancelledBy != null || display == TripDisplayStatus.cancelled;
  String confirmedLine() => _confirmedLine(confirmedBy, confirmedAt);
}

class TripSummaryNightGroup {
  final List<TripSummaryNight> nights;

  const TripSummaryNightGroup(this.nights);

  TripSummaryNight get first => nights.first;
  TripSummaryNight get last => nights.last;
  bool get isRange => nights.length > 1;

  int? get agreedTotal {
    for (final n in nights) {
      if (n.agreedTotal != null) return n.agreedTotal;
    }
    return null;
  }
}

class TripSummaryTaxi {
  final String? enquiryId;
  final String listingName;
  final String? vehicleTypeName;
  final List<int> days;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String displayStatus;
  final int? agreedFare;
  final bool tollExtra;
  final String? pickupTime;
  final String? pickupPlace;
  final String? confirmedBy;
  final DateTime? confirmedAt;
  final String? cancelledBy;

  const TripSummaryTaxi({
    this.enquiryId,
    this.listingName = '',
    this.vehicleTypeName,
    this.days = const [],
    this.checkIn,
    this.checkOut,
    this.displayStatus = 'none',
    this.agreedFare,
    this.tollExtra = false,
    this.pickupTime,
    this.pickupPlace,
    this.confirmedBy,
    this.confirmedAt,
    this.cancelledBy,
  });

  factory TripSummaryTaxi.fromJson(Map<String, dynamic> json) => TripSummaryTaxi(
        enquiryId: json['enquiryId'] as String?,
        listingName: json['listingName'] as String? ?? '',
        vehicleTypeName: json['vehicleTypeName'] as String?,
        days: ((json['days'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toList(),
        checkIn: tripDate(json['checkIn']),
        checkOut: tripDate(json['checkOut']),
        displayStatus: json['displayStatus'] as String? ?? 'none',
        agreedFare: (json['agreedFare'] as num?)?.toInt(),
        tollExtra: json['tollExtra'] == true,
        pickupTime: json['pickupTime'] as String?,
        pickupPlace: json['pickupPlace'] as String?,
        confirmedBy: json['confirmedBy'] as String?,
        confirmedAt: tripInstant(json['confirmedAt']),
        cancelledBy: json['cancelledBy'] as String?,
      );

  TripDisplayStatus get display => TripDisplayStatus.parse(displayStatus);
  bool get isCancelled => cancelledBy != null || display == TripDisplayStatus.cancelled;
  String confirmedLine() => _confirmedLine(confirmedBy, confirmedAt);
}

class TripSummaryDay {
  final int day;
  final DateTime? date;
  final String? city;
  final List<String> spots;
  final int minutes;
  final List<int> starts;

  const TripSummaryDay({required this.day, this.date, this.city, this.spots = const [], this.minutes = 0, this.starts = const []});

  bool get hasTimes => starts.isNotEmpty && starts.length == spots.length;

  factory TripSummaryDay.fromJson(Map<String, dynamic> json) => TripSummaryDay(
        day: (json['day'] as num?)?.toInt() ?? 0,
        date: tripDate(json['date']),
        city: (json['city'] as String?)?.trim().isEmpty ?? true ? null : (json['city'] as String).trim(),
        spots: ((json['spots'] as List?) ?? const []).whereType<String>().toList(),
        minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      );

  TripSummaryDay withMinutes(int value) =>
      TripSummaryDay(day: day, date: date, city: city, spots: spots, minutes: value, starts: starts);

  TripSummaryDay withStarts(List<int> value) =>
      TripSummaryDay(day: day, date: date, city: city, spots: spots, minutes: minutes, starts: value);
}

class TripSummaryTravelModes {
  static const String own = 'own';
  static const String journey = 'journey';
}

class TripSummaryTravelCar {
  final int car;
  final String driverName;
  final String? vehicleTypeName;
  final String fromName;
  final String toName;
  final int? agreedFare;
  final int? listedFare;
  final int? lastQuotedFare;
  final String displayStatus;
  final String? confirmedBy;
  final String? enquiryId;
  final String? pickupTime;
  final bool tollExtra;
  final String? cancelledBy;
  final String? taxiId;

  const TripSummaryTravelCar({
    required this.car,
    this.driverName = '',
    this.vehicleTypeName,
    this.fromName = '',
    this.toName = '',
    this.agreedFare,
    this.listedFare,
    this.lastQuotedFare,
    this.displayStatus = 'none',
    this.confirmedBy,
    this.enquiryId,
    this.pickupTime,
    this.tollExtra = false,
    this.cancelledBy,
    this.taxiId,
  });

  factory TripSummaryTravelCar.fromJson(Map<String, dynamic> json) => TripSummaryTravelCar(
        car: (json['car'] as num?)?.toInt() ?? 1,
        driverName: json['driverName'] as String? ?? '',
        vehicleTypeName: json['vehicleTypeName'] as String?,
        fromName: json['fromName'] as String? ?? '',
        toName: json['toName'] as String? ?? '',
        agreedFare: (json['agreedFare'] as num?)?.toInt(),
        listedFare: (json['listedFare'] as num?)?.toInt(),
        lastQuotedFare: (json['lastQuotedFare'] as num?)?.toInt(),
        displayStatus: json['displayStatus'] as String? ?? 'none',
        confirmedBy: json['confirmedBy'] as String?,
        enquiryId: json['enquiryId'] as String?,
        pickupTime: json['pickupTime'] as String?,
        tollExtra: json['tollExtra'] == true,
        cancelledBy: json['cancelledBy'] as String?,
        taxiId: json['taxiId'] as String?,
      );

  TripDisplayStatus get display => TripDisplayStatus.parse(displayStatus);

  bool get isNotAsked => displayStatus == 'none';

  bool get isBooked =>
      cancelledBy == null && (display == TripDisplayStatus.bookedByYou || display == TripDisplayStatus.confirmedByBoth);

  int? get fare {
    for (final f in [agreedFare, lastQuotedFare, listedFare]) {
      if (f != null && f > 0) return f;
    }
    return null;
  }

  String confirmedLine() => isBooked ? TripStatusVisuals.label(display, taxi: true) : TripStrings.notConfirmedYet;
}

class TripSummaryTravel {
  final String mode;
  final String fromName;
  final String toName;
  final int day;
  final DateTime? date;
  final TripTravelState? state;
  final int carCount;
  final int? listedTotal;
  final List<TripSummaryTravelCar> cars;
  final int? roadMinutes;
  final String? journeyId;

  const TripSummaryTravel({
    this.mode = TripSummaryTravelModes.journey,
    this.fromName = '',
    this.toName = '',
    this.day = 0,
    this.date,
    this.state,
    this.carCount = 0,
    this.listedTotal,
    this.cars = const [],
    this.roadMinutes,
    this.journeyId,
  });

  static String? _text(Object? raw) {
    final s = raw is String ? raw.trim() : null;
    return s == null || s.isEmpty ? null : s;
  }

  factory TripSummaryTravel.fromJson(Map<String, dynamic> json) {
    final cars = _list(json['cars'], TripSummaryTravelCar.fromJson)..sort((a, b) => a.car.compareTo(b.car));
    final own = json['mode'] == TripSummaryTravelModes.own;
    return TripSummaryTravel(
      mode: own ? TripSummaryTravelModes.own : TripSummaryTravelModes.journey,
      fromName: json['fromName'] as String? ?? '',
      toName: json['toName'] as String? ?? '',
      day: (json['day'] as num?)?.toInt() ?? 0,
      date: tripDate(json['date']),
      state: TripTravelState.parse(json['state']),
      carCount: own ? 0 : ((json['carCount'] as num?)?.toInt() ?? cars.length),
      listedTotal: (json['listedTotal'] as num?)?.toInt(),
      cars: own ? const [] : cars,
      roadMinutes: (json['roadMinutes'] as num?)?.toInt(),
      journeyId: _text(json['journeyId']),
    );
  }

  bool get isOwn => mode == TripSummaryTravelModes.own;

  bool get isJourney => !isOwn;

  int get shownCars => isOwn ? 0 : (carCount > 0 ? carCount : cars.length);

  List<String> get places => [
        fromName,
        if (cars.isEmpty) toName else ...cars.map((c) => c.toName),
      ].where((p) => p.isNotEmpty).toList();
}

class TripSummaryLeg {
  final int index;
  final String cityName;
  final int startDay;
  final int endDay;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<TripSummaryNight> nights;
  final List<TripSummaryTaxi> taxis;
  final TripSummaryTravel? travel;

  const TripSummaryLeg({
    required this.index,
    this.cityName = '',
    this.startDay = 0,
    this.endDay = 0,
    this.startDate,
    this.endDate,
    this.nights = const [],
    this.taxis = const [],
    this.travel,
  });

  factory TripSummaryLeg.fromJson(Map<String, dynamic> json) => TripSummaryLeg(
        index: (json['index'] as num?)?.toInt() ?? 1,
        cityName: json['cityName'] as String? ?? '',
        startDay: (json['startDay'] as num?)?.toInt() ?? 0,
        endDay: (json['endDay'] as num?)?.toInt() ?? 0,
        startDate: tripDate(json['startDate']),
        endDate: tripDate(json['endDate']),
        nights: _list(json['nights'], TripSummaryNight.fromJson),
        taxis: _list(json['taxis'], TripSummaryTaxi.fromJson),
        travel: json['travel'] is Map<String, dynamic>
            ? TripSummaryTravel.fromJson(json['travel'] as Map<String, dynamic>)
            : null,
      );

  String get dates {
    final a = startDate;
    if (a == null) return '';
    return TripStringsMcaA3.dateSpan(a, endDate ?? a);
  }
}

class TripSummaryArrangement {
  final TripEasyRowKey key;
  final String title;
  final TripRowState state;
  final String? detail;
  final bool partial;
  final int? nightsCovered;
  final int? nightsTotal;

  const TripSummaryArrangement({
    required this.key,
    this.title = '',
    this.state = TripRowState.todo,
    this.detail,
    this.partial = false,
    this.nightsCovered,
    this.nightsTotal,
  });

  bool get isDone => state.isDone && !partial;

  String? get detailLine {
    final d = detail;
    if (d != null && d.isNotEmpty) return d;
    if (partial && nightsCovered != null && nightsTotal != null) return '$nightsCovered of $nightsTotal nights';
    return null;
  }

  static TripSummaryArrangement? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['key'];
    final key = TripEasyRowKey.parse(id is String ? id : null);
    if (key == null) return null;
    final detail = raw['detail'];
    final covered = (raw['nightsCovered'] as num?)?.toInt();
    final total = (raw['nightsTotal'] as num?)?.toInt();
    final partial = raw['partial'] is bool
        ? raw['partial'] as bool
        : (total != null && total > 0 && covered != null && covered < total);
    return TripSummaryArrangement(
      key: key,
      title: raw['title'] as String? ?? '',
      state: TripRowState.parse(raw['state']),
      detail: detail is String && detail.trim().isNotEmpty ? detail.trim() : null,
      partial: partial,
      nightsCovered: covered,
      nightsTotal: total,
    );
  }
}

class TripSummaryRecord {
  final String tripId;
  final String title;
  final String city;
  final DateTime? startDate;
  final DateTime? endDate;
  final int adults;
  final int kids;
  final String bookingState;
  final String status;
  final int agreedTotal;
  final DateTime? generatedAt;
  final List<TripSummaryNight> nights;
  final List<TripSummaryTaxi> taxis;
  final List<TripSummaryDay> days;
  final TripSteps steps;
  final TripJourney? gettingThere;
  final TripJourney? comingBack;
  final List<String>? _cities;
  final List<TripSummaryLeg> legs;
  final List<TripSummaryArrangement> arrangements;

  const TripSummaryRecord({
    required this.tripId,
    this.title = '',
    this.city = '',
    this.startDate,
    this.endDate,
    this.adults = 0,
    this.kids = 0,
    this.bookingState = 'draft',
    this.status = '',
    this.agreedTotal = 0,
    this.generatedAt,
    this.nights = const [],
    this.taxis = const [],
    this.days = const [],
    this.steps = const TripSteps(),
    this.gettingThere,
    this.comingBack,
    List<String>? cities,
    this.legs = const [],
    this.arrangements = const [],
  }) : _cities = cities;

  List<String> get cities => _cities ?? [city];
  String get routeLine => cities.length > 1 ? TripStringsMcaA4.routeOf(cities) : city;

  TripJourney? journeyOf(TripStepRole r) => r == TripStepRole.gettingThere ? gettingThere : comingBack;

  factory TripSummaryRecord.fromJson(Map<String, dynamic> json) => TripSummaryRecord(
        tripId: json['tripId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        city: json['city'] as String? ?? '',
        startDate: tripDate(json['startDate']),
        endDate: tripDate(json['endDate']),
        adults: (json['adults'] as num?)?.toInt() ?? 0,
        kids: (json['kids'] as num?)?.toInt() ?? 0,
        bookingState: json['bookingState'] as String? ?? 'draft',
        status: json['status'] as String? ?? '',
        agreedTotal: (json['agreedTotal'] as num?)?.toInt() ?? 0,
        generatedAt: tripInstant(json['generatedAt']),
        nights: _list(json['nights'], TripSummaryNight.fromJson),
        taxis: _list(json['taxis'], TripSummaryTaxi.fromJson),
        days: _list(json['days'], TripSummaryDay.fromJson),
        steps: TripSteps.fromJson(json['steps'] is Map<String, dynamic> ? json['steps'] as Map<String, dynamic> : null),
        gettingThere: json['gettingThere'] is Map<String, dynamic>
            ? TripJourney.fromJson(json['gettingThere'] as Map<String, dynamic>)
            : null,
        comingBack: json['comingBack'] is Map<String, dynamic>
            ? TripJourney.fromJson(json['comingBack'] as Map<String, dynamic>)
            : null,
        cities: _citiesOf(json['legCities']),
        legs: _list(json['legs'], TripSummaryLeg.fromJson)..sort((a, b) => a.index.compareTo(b.index)),
        arrangements: [
          if (json['arrangements'] is List)
            for (final a in json['arrangements'] as List)
              if (TripSummaryArrangement.tryParse(a) case final m?) m,
        ],
      );

  bool get isMultiCity => legs.length > 1;

  TripSummaryRecord withDayMinutes(Map<int, int> byDay, {Map<int, List<int>> starts = const {}}) {
    if (byDay.isEmpty && starts.isEmpty) return this;
    return TripSummaryRecord(
      tripId: tripId,
      title: title,
      city: city,
      startDate: startDate,
      endDate: endDate,
      adults: adults,
      kids: kids,
      bookingState: bookingState,
      status: status,
      agreedTotal: agreedTotal,
      generatedAt: generatedAt,
      nights: nights,
      taxis: taxis,
      days: [
        for (final d in days)
          () {
            final m = byDay[d.day] == null ? d : d.withMinutes(byDay[d.day]!);
            final s = starts[d.day];
            return s == null ? m : m.withStarts(s);
          }(),
      ],
      steps: steps,
      gettingThere: gettingThere,
      comingBack: comingBack,
      cities: _cities,
      legs: legs,
      arrangements: arrangements,
    );
  }

  bool get hasLegTravel => legs.any((l) => l.travel != null);

  bool get hasTravelCars => legs.any((l) => l.travel?.cars.isNotEmpty == true);

  bool get hasTravel =>
      hasLegTravel ||
      gettingThere != null ||
      comingBack != null ||
      steps.gettingThere.status == TripStepStatus.own ||
      steps.comingBack.status == TripStepStatus.own;

  bool get isEmpty => nights.isEmpty && taxis.isEmpty && arrangements.isEmpty && !hasTravel;

  bool get hasItinerary => days.any((d) => d.spots.isNotEmpty);

  bool get isBlank => isEmpty && !hasItinerary;
  int get people => adults + kids;
}

extension TripSummaryProgress on TripSummaryRecord {
  List<TripSummaryArrangement> get shownRows => [for (final a in arrangements) if (a.state != TripRowState.skipped) a];

  List<TripSummaryArrangement> get stillToDo => [for (final a in shownRows) if (!a.isDone) a];

  bool get isPast {
    final end = endDate ?? startDate;
    if (end == null) return false;
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateTime(end.year, end.month, end.day).isBefore(DateTime(now.year, now.month, now.day));
  }

  bool get isCompleted => bookingState.toLowerCase() == 'completed' || status.toLowerCase() == 'completed' || isPast;

  int? get percentDone {
    final rows = shownRows;
    if (rows.isEmpty) return null;
    return (rows.where((a) => a.isDone).length * 100 / rows.length).round();
  }

  List<TripSummaryNight> get allNights => isMultiCity ? [for (final l in legs) ...l.nights] : nights;

  List<TripSummaryTaxi> get allTaxis => isMultiCity ? [for (final l in legs) ...l.taxis] : taxis;
}
