import '../utils/trip_format.dart';
import '../widgets/trip_status.dart';
import '../trip_strings.dart';
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
  });

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
      );

  bool get hasTravel =>
      gettingThere != null ||
      comingBack != null ||
      steps.gettingThere.status == TripStepStatus.own ||
      steps.comingBack.status == TripStepStatus.own;

  bool get isEmpty => nights.isEmpty && taxis.isEmpty && !hasTravel;

  bool get hasItinerary => days.any((d) => d.spots.isNotEmpty);

  bool get isBlank => isEmpty && !hasItinerary;
  int get people => adults + kids;
}
