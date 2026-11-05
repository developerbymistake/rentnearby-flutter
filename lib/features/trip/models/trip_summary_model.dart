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
  final bool isOwn;
  final String? ownPhone;
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
    this.isOwn = false,
    this.ownPhone,
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
        isOwn: json['isOwn'] == true,
        ownPhone: json['ownPhone'] as String?,
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
  final bool isOwn;
  final String? ownPhone;
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
    this.isOwn = false,
    this.ownPhone,
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
        isOwn: json['isOwn'] == true,
        ownPhone: json['ownPhone'] as String?,
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
  final List<String> spots;
  final int minutes;

  const TripSummaryDay({required this.day, this.date, this.spots = const [], this.minutes = 0});

  factory TripSummaryDay.fromJson(Map<String, dynamic> json) => TripSummaryDay(
        day: (json['day'] as num?)?.toInt() ?? 0,
        date: tripDate(json['date']),
        spots: ((json['spots'] as List?) ?? const []).whereType<String>().toList(),
        minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      );
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
  final String? how;
  final String? ownName;
  final String? ownPhone;
  final String? leavesAt;
  final String? hubName;
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
    this.how,
    this.ownName,
    this.ownPhone,
    this.leavesAt,
    this.hubName,
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
      how: _text(json['how']),
      ownName: _text(json['ownName']),
      ownPhone: _text(json['ownPhone']),
      leavesAt: _text(json['leavesAt']),
      hubName: _text(json['hubName']),
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

  String? get howLabel => switch (how) {
        'car' => TripStringsMcaA3.car,
        'bus' => TripStringsMcaA3.bus,
        'train' => TripStringsMcaA3.train,
        'other' => TripStringsMcaA3.other,
        _ => null,
      };
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

class TripSummaryRecord {
  final String tripId;
  final String title;
  final String city;
  final DateTime? startDate;
  final DateTime? endDate;
  final int adults;
  final int kids;
  final String bookingState;
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

  const TripSummaryRecord({
    required this.tripId,
    this.title = '',
    this.city = '',
    this.startDate,
    this.endDate,
    this.adults = 0,
    this.kids = 0,
    this.bookingState = 'draft',
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
      );

  bool get isMultiCity => legs.length > 1;

  bool get hasLegTravel => legs.any((l) => l.travel != null);

  bool get hasTravelCars => legs.any((l) => l.travel?.cars.isNotEmpty == true);

  bool get hasTravel =>
      hasLegTravel ||
      gettingThere != null ||
      comingBack != null ||
      steps.gettingThere.status == TripStepStatus.own ||
      steps.comingBack.status == TripStepStatus.own;

  bool get isEmpty => nights.isEmpty && taxis.isEmpty && !hasTravel;

  bool get hasItinerary => days.any((d) => d.spots.isNotEmpty);

  bool get isBlank => isEmpty && !hasItinerary;
  int get people => adults + kids;
}
