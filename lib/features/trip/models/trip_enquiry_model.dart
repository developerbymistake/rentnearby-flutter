import 'package:dio/dio.dart';
import '../../../utils/dio_error_mapper.dart';
import '../trip_strings.dart';
import '../trip_strings_algo_aa.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_status.dart';
import 'trip_offer_model.dart';

DateTime? tripDate(Object? raw) {
  final d = DateTime.tryParse(raw is String ? raw : '');
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

DateTime? tripInstant(Object? raw) => DateTime.tryParse(raw is String ? raw : '');

class TripEnquiryStatuses {
  static const String asked = 'Asked';
  static const String offered = 'Offered';
  static const String countered = 'Countered';
  static const String confirmedByTraveller = 'ConfirmedByTraveller';
  static const String confirmedByBoth = 'ConfirmedByBoth';
  static const String fareSent = 'FareSent';
  static const String bookedByTraveller = 'BookedByTraveller';
  static const String closed = 'Closed';
  static const String notAvailable = 'NotAvailable';
  static const String expired = 'Expired';
  static const String declined = 'Declined';
  static const String cancelledByTraveller = 'CancelledByTraveller';
  static const String cancelledByOwner = 'CancelledByOwner';
  static const String failed = 'Failed';
  static const List<String> problem = [notAvailable, expired, failed, cancelledByOwner];
  static const List<String> open = [
    asked,
    offered,
    countered,
    confirmedByTraveller,
    confirmedByBoth,
    fareSent,
    bookedByTraveller,
  ];
  static const List<String> confirmed = [confirmedByTraveller, confirmedByBoth];
  static const List<String> withdrawable = [asked, offered, countered, fareSent];
  static const List<String> booked = [confirmedByTraveller, confirmedByBoth, bookedByTraveller];
}

class TripFailReasons {
  static const String hostDenied = 'HostDenied';
  static const String driverDenied = 'DriverDenied';
  static const String driverPaused = 'DriverPaused';
}

class TripEndReasons {
  static const String withdrawn = 'withdrawn';
  static const String bookedElsewhere = 'bookedElsewhere';
  static const String datesChanged = 'datesChanged';
  static const String tripDeleted = 'tripDeleted';
  static const String accountDeleted = 'accountDeleted';
  static const String adminClosed = 'adminClosed';
  static const String stayRemoved = 'stayRemoved';
  static const String stayPaused = 'stayPaused';
  static const String hostBlocked = 'hostBlocked';
  static const String hostNotAvailable = 'hostNotAvailable';
  static const String offerExpired = 'offerExpired';
  static const String noReply = 'noReply';
  static const String declinedByYou = 'declinedByYou';
  static const String cancelledByGuest = 'cancelledByGuest';
  static const String cancelledByHost = 'cancelledByHost';
  static const String problem = 'problem';
  static const String closed = 'closed';
}

class TripEnquiryKinds {
  static const String stay = 'Stay';
  static const String taxi = 'Taxi';
}

class TripSkipReasons {
  static const String alreadyOpen = 'AlreadyOpen';
  static const String notAvailable = 'NotAvailable';
  static const String blocked = 'Blocked';
  static const String limitReached = 'LimitReached';
  static const String alreadyBooked = 'AlreadyBooked';
  static const String openInAnotherTrip = 'OpenInAnotherTrip';
  static const String openForOtherNights = 'OpenForOtherNights';
  static const String fullOnDates = 'FullOnDates';
}

class TripContextDay {
  final int day;
  final DateTime? date;
  final int minutes;
  final List<String> spots;
  final String? start;

  const TripContextDay({required this.day, this.date, this.minutes = 0, this.spots = const [], this.start});

  factory TripContextDay.fromJson(Map<String, dynamic> json) => TripContextDay(
        day: (json['day'] as num?)?.toInt() ?? 0,
        date: tripDate(json['date']),
        minutes: (json['minutes'] as num?)?.toInt() ?? 0,
        spots: ((json['spots'] as List?) ?? const []).whereType<String>().toList(),
        start: json['start'] as String?,
      );
}

class TripEnquiryContext {
  final String city;
  final int? adults;
  final int? kids;
  final int? rooms;
  final String? travellerName;
  final List<TripContextDay> days;
  final String? pickupTime;
  final String? pickupPlace;
  final String text;
  final String? journeyId;
  final int? journeyLegIndex;
  final String? role;

  const TripEnquiryContext({
    this.city = '',
    this.adults,
    this.kids,
    this.rooms,
    this.travellerName,
    this.days = const [],
    this.pickupTime,
    this.pickupPlace,
    this.text = '',
    this.journeyId,
    this.journeyLegIndex,
    this.role,
  });

  String? get peopleLabel {
    final a = adults;
    if (a == null) return null;
    final k = kids ?? 0;
    final adultPart = a == 1 ? '1 adult' : '$a adults';
    return k > 0 ? '$adultPart, $k ${k == 1 ? 'kid' : 'kids'}' : adultPart;
  }

  String? get roomsLabel {
    final r = rooms;
    return r == null ? null : (r == 1 ? '1 room' : '$r rooms');
  }

  factory TripEnquiryContext.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TripEnquiryContext();
    return TripEnquiryContext(
      city: json['city'] as String? ?? '',
      adults: (json['adults'] as num?)?.toInt(),
      kids: (json['kids'] as num?)?.toInt(),
      rooms: (json['rooms'] as num?)?.toInt(),
      travellerName: json['travellerName'] as String?,
      days: ((json['days'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TripContextDay.fromJson)
          .toList(),
      pickupTime: json['pickupTime'] as String?,
      pickupPlace: json['pickupPlace'] as String?,
      text: json['text'] as String? ?? '',
      journeyId: (json['journeyId'] as String?)?.isEmpty ?? true ? null : json['journeyId'] as String,
      journeyLegIndex: (json['journeyLegIndex'] as num?)?.toInt(),
      role: (json['role'] as String?)?.isEmpty ?? true ? null : json['role'] as String,
    );
  }
}

class TripTaxiModel {
  final int? listedRate;
  final int? listedTotal;
  final int? driverFare;
  final String? driverNote;
  final DateTime? driverRepliedAt;
  final int fareEditCount;
  final int fareEditsLeft;
  final int? agreedFare;
  final bool tollExtra;
  final String? pickupTime;
  final String? pickupPlace;
  final DateTime? bookedAt;

  const TripTaxiModel({
    this.listedRate,
    this.listedTotal,
    this.driverFare,
    this.driverNote,
    this.driverRepliedAt,
    this.fareEditCount = 0,
    this.fareEditsLeft = 0,
    this.agreedFare,
    this.tollExtra = false,
    this.pickupTime,
    this.pickupPlace,
    this.bookedAt,
  });

  factory TripTaxiModel.fromJson(Map<String, dynamic> json) => TripTaxiModel(
        listedRate: (json['listedRate'] as num?)?.toInt(),
        listedTotal: (json['listedTotal'] as num?)?.toInt(),
        driverFare: (json['driverFare'] as num?)?.toInt(),
        driverNote: json['driverNote'] as String?,
        driverRepliedAt: tripInstant(json['driverRepliedAt']),
        fareEditCount: (json['fareEditCount'] as num?)?.toInt() ?? 0,
        fareEditsLeft: (json['fareEditsLeft'] as num?)?.toInt() ?? 0,
        agreedFare: (json['agreedFare'] as num?)?.toInt(),
        tollExtra: json['tollExtra'] == true,
        pickupTime: json['pickupTime'] as String?,
        pickupPlace: json['pickupPlace'] as String?,
        bookedAt: tripInstant(json['bookedAt']),
      );
}

class TripPartyModel {
  final String? id;
  final String? name;
  final String? phone;
  final String? whatsApp;

  const TripPartyModel({this.id, this.name, this.phone, this.whatsApp});

  factory TripPartyModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TripPartyModel();
    return TripPartyModel(
      id: json['id'] as String?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      whatsApp: json['whatsApp'] as String?,
    );
  }
}

class TripOwnerShare {
  final String? upiId;
  final String? whatsApp;
  final DateTime? sharedAt;

  const TripOwnerShare({this.upiId, this.whatsApp, this.sharedAt});

  static TripOwnerShare? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    String? text(String k) {
      final v = (raw[k] as String?)?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    return TripOwnerShare(upiId: text('upiId'), whatsApp: text('whatsApp'), sharedAt: tripInstant(raw['sharedAt']));
  }
}

class TripEnquiryModel {
  final String id;
  final String? tripId;
  final String kind;
  final String listingId;
  final String listingName;
  final double? listingLatitude;
  final double? listingLongitude;
  final int? day;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final DateTime? tripStartDate;
  final DateTime? tripCheckOutLimit;
  final int? serverNights;
  final String? conversationId;
  final String status;
  final String? failReason;
  final String displayStatusWire;
  final DateTime? expiresAt;
  final bool isUrgent;
  final int? agreedTotal;
  final int? listedPerNight;
  final TripOfferModel? acceptedOffer;
  final TripOfferModel? openOffer;
  final int offerCount;
  final TripEnquiryContext context;
  final TripPartyModel traveller;
  final TripPartyModel owner;
  final String? cancelledBy;
  final String? cancelReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final TripTaxiModel? taxi;
  final List<int> days;
  final TripOfferModel? pendingCounter;
  final TripOfferModel? pendingRevised;
  final TripOfferModel? pendingChange;
  final int counterCount;
  final int revisedCount;
  final bool wrongCity;
  final int wrongNights;
  final int wrongTotal;
  final int? wrongFirstDay;
  final String? wrongDayCity;
  final bool outsideTrip;
  final int? cityLeg;
  final bool isQuiet;
  final DateTime? quietAt;
  final String? stepKey;
  final String? endReason;
  final DateTime? undoUntil;
  final int? offersLeft;
  final int? waitingHours;
  final TripOwnerShare? ownerShare;
  final bool? _isSegment;

  const TripEnquiryModel({
    required this.id,
    this.tripId,
    this.kind = TripEnquiryKinds.stay,
    this.listingId = '',
    this.listingName = '',
    this.listingLatitude,
    this.listingLongitude,
    this.day,
    this.checkIn,
    this.checkOut,
    this.tripStartDate,
    this.tripCheckOutLimit,
    this.serverNights,
    this.conversationId,
    this.status = TripEnquiryStatuses.asked,
    this.failReason,
    this.displayStatusWire = 'asked',
    this.expiresAt,
    this.isUrgent = false,
    this.agreedTotal,
    this.listedPerNight,
    this.acceptedOffer,
    this.openOffer,
    this.offerCount = 0,
    this.context = const TripEnquiryContext(),
    this.traveller = const TripPartyModel(),
    this.owner = const TripPartyModel(),
    this.cancelledBy,
    this.cancelReason,
    this.createdAt,
    this.updatedAt,
    this.taxi,
    this.days = const [],
    this.pendingCounter,
    this.pendingRevised,
    this.pendingChange,
    this.counterCount = 0,
    this.revisedCount = 0,
    this.wrongCity = false,
    this.wrongNights = 0,
    this.wrongTotal = 0,
    this.wrongFirstDay,
    this.wrongDayCity,
    this.outsideTrip = false,
    this.cityLeg,
    this.isQuiet = false,
    this.quietAt,
    this.stepKey,
    this.endReason,
    this.undoUntil,
    this.offersLeft,
    this.waitingHours,
    this.ownerShare,
    bool? isSegment,
  }) : _isSegment = isSegment;

  bool get isSegment => _isSegment ?? (isTaxi && day != null && tripId != null && context.journeyId != null);

  TripDisplayStatus get display => TripDisplayStatus.parse(displayStatusWire);

  String get stepKeyOrLeg => stepKey ?? 'stay:${cityLeg ?? 1}';

  bool canUndoAt(DateTime now) => undoUntil != null && undoUntil!.isAfter(now);

  bool get hasPendingRevised => pendingRevised != null;

  bool get hasPendingChange => pendingChange != null;

  // The only price the UI shows for a confirmed stay; pending rows never move it.
  int? get agreedTotalLocked => agreedTotal;

  bool get isTaxi => kind == TripEnquiryKinds.taxi;

  bool get isBookedByYou => display == TripDisplayStatus.bookedByYou;

  bool get isFareSent => display == TripDisplayStatus.fareSent;

  bool get isConfirmedByBoth => status == TripEnquiryStatuses.confirmedByBoth;

  bool get isWithdrawable => TripEnquiryStatuses.withdrawable.contains(status);

  bool get isBooked => TripEnquiryStatuses.booked.contains(status);

  bool coversDay(int day) => days.contains(day);

  List<DateTime> get taxiDates {
    final ci = checkIn;
    if (ci == null || days.isEmpty) return const [];
    final first = days.reduce((a, b) => a < b ? a : b);
    return [for (final d in days) DateTime(ci.year, ci.month, ci.day + d - first)];
  }

  DateTime? get lastDate {
    if (isTaxi) {
      final dates = taxiDates;
      return dates.isEmpty ? null : dates.reduce((a, b) => a.isAfter(b) ? a : b);
    }
    final b = checkOut;
    return b == null ? null : DateTime(b.year, b.month, b.day - 1);
  }

  bool coversTaxiDate(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return taxiDates.any((t) => t == x);
  }

  bool get isOpen => TripEnquiryStatuses.open.contains(status);

  bool get isConfirmed => TripEnquiryStatuses.confirmed.contains(status);

  bool get isUnconfirmed =>
      status == TripEnquiryStatuses.asked ||
      status == TripEnquiryStatuses.offered ||
      status == TripEnquiryStatuses.countered;

  bool get isRed => display.isRed;

  bool get isProblem => TripEnquiryStatuses.problem.contains(status);


  int get nights {
    final a = checkIn;
    final b = checkOut;
    if (a != null && b != null) {
      final n = DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
      if (n > 0) return n;
    }
    return serverNights ?? 1;
  }

  String get datesLabel {
    final a = checkIn;
    final b = checkOut;
    if (a == null) return '';
    if (isTaxi) {
      final dates = taxiDates;
      if (dates.isNotEmpty) return TripFormat.dateSet(dates);
      final last = b == null ? a : DateTime(b.year, b.month, b.day - 1);
      return TripFormat.dateRange(a, last.isBefore(a) ? a : last);
    }
    return TripFormat.dateRange(a, b ?? a);
  }

  int get serviceDays {
    if (!isTaxi) return nights;
    final n = days.isNotEmpty ? days.toSet().length : nights;
    return n < 1 ? 1 : n;
  }

  String get countLabel => isTaxi ? TripStringsAlgoAa.days(serviceDays) : TripStrings.nights(nights);

  bool coversDate(DateTime d) {
    final a = checkIn;
    final b = checkOut;
    if (a == null || b == null) return false;
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(a) && x.isBefore(b);
  }

  bool overlaps(DateTime from, DateTime to) {
    final a = checkIn;
    final b = checkOut;
    if (a == null || b == null) return false;
    return a.isBefore(to) && from.isBefore(b);
  }

  factory TripEnquiryModel.fromJson(Map<String, dynamic> json) {
    TripOfferModel? offer(String key) {
      final raw = json[key];
      return raw is Map<String, dynamic> ? TripOfferModel.fromJson(raw) : null;
    }

    final tx = json['taxi'];
    final dayList = ((json['days'] as List?) ?? const []).whereType<num>().map((n) => n.toInt()).toList()..sort();
    return TripEnquiryModel(
      id: json['id'] as String? ?? '',
      tripId: json['tripId'] as String?,
      kind: json['kind'] as String? ?? TripEnquiryKinds.stay,
      listingId: json['listingId'] as String? ?? '',
      listingName: json['listingName'] as String? ?? '',
      listingLatitude: (json['listingLatitude'] as num?)?.toDouble(),
      listingLongitude: (json['listingLongitude'] as num?)?.toDouble(),
      day: (json['day'] as num?)?.toInt(),
      checkIn: tripDate(json['checkIn']),
      checkOut: tripDate(json['checkOut']),
      tripStartDate: tripDate(json['tripStartDate']),
      tripCheckOutLimit: tripDate(json['tripCheckOutLimit']),
      serverNights: (json['nights'] as num?)?.toInt(),
      conversationId: json['conversationId'] as String?,
      status: json['status'] as String? ?? TripEnquiryStatuses.asked,
      failReason: json['failReason'] as String?,
      displayStatusWire: json['displayStatus'] as String? ?? 'none',
      expiresAt: tripInstant(json['expiresAt']),
      isUrgent: json['isUrgent'] == true,
      agreedTotal: (json['agreedTotal'] as num?)?.toInt(),
      listedPerNight: json['listedPerNight'] is num && (json['listedPerNight'] as num) > 0 ? (json['listedPerNight'] as num).toInt() : null,
      acceptedOffer: offer('acceptedOffer'),
      openOffer: offer('openOffer'),
      offerCount: (json['offerCount'] as num?)?.toInt() ?? 0,
      context: TripEnquiryContext.fromJson(json['context'] as Map<String, dynamic>?),
      traveller: TripPartyModel.fromJson(json['traveller'] as Map<String, dynamic>?),
      owner: TripPartyModel.fromJson(json['owner'] as Map<String, dynamic>?),
      cancelledBy: json['cancelledBy'] as String?,
      cancelReason: json['cancelReason'] as String?,
      createdAt: tripInstant(json['createdAt']),
      updatedAt: tripInstant(json['updatedAt']),
      taxi: tx is Map<String, dynamic> ? TripTaxiModel.fromJson(tx) : null,
      days: dayList,
      pendingCounter: offer('pendingCounter'),
      pendingRevised: offer('pendingRevised'),
      pendingChange: offer('pendingChange'),
      counterCount: (json['counterCount'] as num?)?.toInt() ?? 0,
      revisedCount: (json['revisedCount'] as num?)?.toInt() ?? 0,
      wrongCity: json['wrongCity'] == true,
      wrongNights: (json['wrongNights'] as num?)?.toInt() ?? 0,
      wrongTotal: (json['wrongTotal'] as num?)?.toInt() ?? 0,
      wrongFirstDay: (json['wrongFirstDay'] as num?)?.toInt(),
      wrongDayCity: (json['wrongDayCity'] as String?)?.isEmpty ?? true ? null : json['wrongDayCity'] as String,
      outsideTrip: json['outsideTrip'] == true,
      cityLeg: (json['cityLeg'] as num?)?.toInt(),
      isQuiet: json['isQuiet'] == true,
      quietAt: tripInstant(json['quietAt']),
      stepKey: (json['stepKey'] as String?)?.isEmpty ?? true ? null : json['stepKey'] as String,
      endReason: (json['endReason'] as String?)?.isEmpty ?? true ? null : json['endReason'] as String,
      undoUntil: tripInstant(json['undoUntil']),
      offersLeft: (json['offersLeft'] as num?)?.toInt(),
      waitingHours: (json['waitingHours'] as num?)?.toInt(),
      ownerShare: TripOwnerShare.fromJson(json['ownerShare']),
      isSegment: json['isSegment'] is bool ? json['isSegment'] as bool : null,
    );
  }
}

class TripSkipped {
  final String listingId;
  final String reason;

  const TripSkipped({required this.listingId, required this.reason});

  factory TripSkipped.fromJson(Map<String, dynamic> json) =>
      TripSkipped(listingId: json['listingId'] as String? ?? '', reason: json['reason'] as String? ?? '');
}

List<TripEnquiryModel> _enquiryList(Object? raw) =>
    ((raw as List?) ?? const []).whereType<Map<String, dynamic>>().map(TripEnquiryModel.fromJson).toList();

class TripSendResult {
  final String listingId;
  final String status;
  final String? enquiryId;
  final String? reason;
  final String? otherTripId;
  final String? otherTripTitle;
  final String? otherEnquiryId;

  const TripSendResult({
    required this.listingId,
    required this.status,
    this.enquiryId,
    this.reason,
    this.otherTripId,
    this.otherTripTitle,
    this.otherEnquiryId,
  });

  bool get ok => status == 'Sent' || status == 'AlreadyOpen' || status == 'Replayed';

  bool get otherTrip => status == TripSkipReasons.openInAnotherTrip;

  bool get gone => status == 'NotAvailable' || status == 'Blocked';

  bool get created => status == 'Sent' || status == 'Replayed';

  bool get fullOnDates => reason == TripSkipReasons.fullOnDates;

  factory TripSendResult.fromJson(Map<String, dynamic> j) => TripSendResult(
        listingId: j['listingId'] as String? ?? j['taxiId'] as String? ?? '',
        status: j['status'] as String? ?? 'Failed',
        enquiryId: j['enquiryId'] as String?,
        reason: j['reason'] as String?,
        otherTripId: j['otherTripId'] as String?,
        otherTripTitle: j['otherTripTitle'] as String?,
        otherEnquiryId: j['otherEnquiryId'] as String?,
      );

  static List<TripSendResult> parseList(Object? raw) => [
        for (final m in ((raw as List?) ?? const []).whereType<Map<String, dynamic>>()) TripSendResult.fromJson(m),
      ];
}

class TripEnquiryBatch {
  final List<TripEnquiryModel> items;
  final List<TripSkipped> skipped;
  final bool veryShortNotice;
  final List<String> updated;
  final int? asksLeft;
  final List<TripSendResult> results;

  const TripEnquiryBatch({
    required this.items,
    required this.skipped,
    required this.veryShortNotice,
    this.updated = const [],
    this.asksLeft,
    this.results = const [],
  });

  List<TripSendResult> get perRecipient {
    if (results.isNotEmpty) return results;
    return [
      for (final e in items) TripSendResult(listingId: e.listingId, status: 'Sent', enquiryId: e.id),
      for (final s in skipped) TripSendResult(listingId: s.listingId, status: _statusOfSkip(s.reason), reason: s.reason),
    ];
  }

  static String _statusOfSkip(String reason) => switch (reason) {
        TripSkipReasons.alreadyOpen => 'AlreadyOpen',
        TripSkipReasons.openInAnotherTrip => 'OpenInAnotherTrip',
        TripSkipReasons.notAvailable => 'NotAvailable',
        TripSkipReasons.blocked => 'Blocked',
        TripSkipReasons.limitReached => 'LimitReached',
        TripSkipReasons.alreadyBooked => 'AlreadyBooked',
        TripSkipReasons.openForOtherNights => 'OpenForOtherNights',
        _ => 'Failed',
      };

  factory TripEnquiryBatch.fromJson(Map<String, dynamic> json, {int? asksLeft}) => TripEnquiryBatch(
        items: _enquiryList(json['items']),
        skipped: ((json['skipped'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TripSkipped.fromJson)
            .toList(),
        veryShortNotice: json['veryShortNotice'] == true,
        updated: ((json['updated'] as List?) ?? const []).whereType<String>().toList(),
        asksLeft: asksLeft,
        results: TripSendResult.parseList(json['results']),
      );

  bool isUpdated(String enquiryId) => updated.contains(enquiryId);
}

class TripOwnerCounts {
  final int newCount;
  final int offered;
  final int confirmed;
  final int closed;

  const TripOwnerCounts({this.newCount = 0, this.offered = 0, this.confirmed = 0, this.closed = 0});

  factory TripOwnerCounts.fromJson(Map<String, dynamic>? json) => TripOwnerCounts(
        newCount: (json?['new'] as num?)?.toInt() ?? 0,
        offered: (json?['offered'] as num?)?.toInt() ?? 0,
        confirmed: (json?['confirmed'] as num?)?.toInt() ?? 0,
        closed: (json?['closed'] as num?)?.toInt() ?? 0,
      );
}

class TripOwnerEnquiryPage {
  final List<TripEnquiryModel> items;
  final bool hasMore;
  final TripOwnerCounts counts;

  const TripOwnerEnquiryPage({required this.items, required this.hasMore, required this.counts});

  factory TripOwnerEnquiryPage.fromJson(Map<String, dynamic> json) => TripOwnerEnquiryPage(
        items: _enquiryList(json['items']),
        hasMore: json['hasMore'] == true,
        counts: TripOwnerCounts.fromJson(json['counts'] as Map<String, dynamic>?),
      );
}

class TripDriverCounts {
  final int newOnes;
  final int replied;
  final int booked;
  final int closed;

  const TripDriverCounts({this.newOnes = 0, this.replied = 0, this.booked = 0, this.closed = 0});

  factory TripDriverCounts.fromJson(Map<String, dynamic>? json) => TripDriverCounts(
        newOnes: (json?['new'] as num?)?.toInt() ?? 0,
        replied: (json?['replied'] as num?)?.toInt() ?? 0,
        booked: (json?['booked'] as num?)?.toInt() ?? 0,
        closed: (json?['closed'] as num?)?.toInt() ?? 0,
      );
}

class TripDriverLeadPage {
  final List<TripEnquiryModel> items;
  final bool hasMore;
  final TripDriverCounts counts;

  const TripDriverLeadPage({required this.items, required this.hasMore, required this.counts});

  factory TripDriverLeadPage.fromJson(Map<String, dynamic> json) => TripDriverLeadPage(
        items: _enquiryList(json['items']),
        hasMore: json['hasMore'] == true,
        counts: TripDriverCounts.fromJson(json['counts'] as Map<String, dynamic>?),
      );
}

class TripNightConflict {
  final String enquiryId;
  final String listingName;

  const TripNightConflict({required this.enquiryId, required this.listingName});
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

class TripStepFullAsk {
  final String enquiryId;
  final String listingId;
  final String? listingName;
  final DateTime? askedAt;

  const TripStepFullAsk({required this.enquiryId, required this.listingId, this.listingName, this.askedAt});

  factory TripStepFullAsk.fromJson(Map<String, dynamic> j) => TripStepFullAsk(
        enquiryId: j['enquiryId'] as String? ?? '',
        listingId: j['listingId'] as String? ?? '',
        listingName: j['listingName'] as String?,
        askedAt: tripInstant(j['askedAt']),
      );

  static List<TripStepFullAsk> listOf(Object? raw) => [
        for (final m in ((raw as List?) ?? const []).whereType<Map<String, dynamic>>())
          if ((m['enquiryId'] as String?)?.isNotEmpty ?? false) TripStepFullAsk.fromJson(m),
      ];
}

class TripStepFull {
  static const String errorType = 'StepFull';
  static const String totalCase = 'total';
  static const String waitingCase = 'waiting';

  final String kind;
  final int counted;
  final int quiet;
  final int shortlisted;
  final int free;
  final DateTime? nextQuietAt;
  final List<TripStepFullAsk> quietAsks;
  final List<TripStepFullAsk> waitingAsks;

  const TripStepFull({
    this.kind = waitingCase,
    this.counted = 0,
    this.quiet = 0,
    this.shortlisted = 0,
    this.free = 0,
    this.nextQuietAt,
    this.quietAsks = const [],
    this.waitingAsks = const [],
  });

  bool get totalLimit => kind == totalCase;

  factory TripStepFull.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const TripStepFull();
    return TripStepFull(
      kind: j['case'] == totalCase ? totalCase : waitingCase,
      counted: _int(j['counted']),
      quiet: _int(j['quiet']),
      shortlisted: _int(j['shortlisted']),
      free: _int(j['free']),
      nextQuietAt: tripInstant(j['nextQuietAt']),
      quietAsks: TripStepFullAsk.listOf(j['quietAsks']),
      waitingAsks: TripStepFullAsk.listOf(j['waitingAsks']),
    );
  }

  static TripStepFull? of(Object error) {
    if (error is! DioException || DioErrorMapper.errorType(error) != errorType) return null;
    final body = error.response?.data;
    final data = body is Map<String, dynamic> ? body['data'] : null;
    return TripStepFull.fromJson(data is Map<String, dynamic> ? data : null);
  }
}

class TripStepSlots {
  final String stepKey;
  final int counted;
  final int quiet;
  final int shortlisted;
  final int free;
  final DateTime? nextQuietAt;

  const TripStepSlots({required this.stepKey, this.counted = 0, this.quiet = 0, this.shortlisted = 0, this.free = 3, this.nextQuietAt});

  factory TripStepSlots.fromJson(Map<String, dynamic> j) => TripStepSlots(
        stepKey: j['stepKey'] as String? ?? '',
        counted: _int(j['counted']),
        quiet: _int(j['quiet']),
        shortlisted: _int(j['shortlisted']),
        free: (j['free'] as num?)?.toInt() ?? 3,
        nextQuietAt: tripInstant(j['nextQuietAt']),
      );

  static Map<String, TripStepSlots> mapOf(Object? raw) => {
        for (final m in ((raw as List?) ?? const []).whereType<Map<String, dynamic>>())
          if ((m['stepKey'] as String?)?.isNotEmpty ?? false) m['stepKey'] as String: TripStepSlots.fromJson(m),
      };
}

class MyEnquiryCounts {
  final int waiting;
  final int offers;
  final int booked;
  final int past;

  const MyEnquiryCounts({this.waiting = 0, this.offers = 0, this.booked = 0, this.past = 0});

  factory MyEnquiryCounts.fromJson(Map<String, dynamic> j) => MyEnquiryCounts(
        waiting: _int(j['waiting']),
        offers: _int(j['offers']),
        booked: _int(j['booked']),
        past: _int(j['past']),
      );
}

class MyEnquiryPage {
  final List<TripEnquiryModel> items;
  final bool hasMore;
  final String? nextCursor;
  final MyEnquiryCounts? counts;

  const MyEnquiryPage({required this.items, required this.hasMore, this.nextCursor, this.counts});

  factory MyEnquiryPage.fromJson(Map<String, dynamic> json) {
    final c = json['counts'];
    final cursor = json['nextCursor'] as String?;
    return MyEnquiryPage(
      items: _enquiryList(json['items']),
      hasMore: json['hasMore'] == true,
      nextCursor: cursor == null || cursor.isEmpty ? null : cursor,
      counts: c is Map<String, dynamic> ? MyEnquiryCounts.fromJson(c) : null,
    );
  }
}
