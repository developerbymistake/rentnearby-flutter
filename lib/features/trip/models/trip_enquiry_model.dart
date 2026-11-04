import '../trip_constants.dart';
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

class TripAdvanceStatuses {
  static const String none = 'None';
  static const String pending = 'Pending';
  static const String proofSent = 'ProofSent';
  static const String received = 'Received';
  static const String holdExpired = 'HoldExpired';
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
}

class TripContextDay {
  final int day;
  final DateTime? date;
  final int minutes;
  final List<String> spots;

  const TripContextDay({required this.day, this.date, this.minutes = 0, this.spots = const []});

  factory TripContextDay.fromJson(Map<String, dynamic> json) => TripContextDay(
        day: (json['day'] as num?)?.toInt() ?? 0,
        date: tripDate(json['date']),
        minutes: (json['minutes'] as num?)?.toInt() ?? 0,
        spots: ((json['spots'] as List?) ?? const []).whereType<String>().toList(),
      );
}

class TripEnquiryContext {
  final String city;
  final int? adults;
  final int? kids;
  final int? rooms;
  final List<String> needs;
  final String? travellerName;
  final List<TripContextDay> days;
  final String? pickupTime;
  final String? pickupPlace;
  final String text;

  const TripEnquiryContext({
    this.city = '',
    this.adults,
    this.kids,
    this.rooms,
    this.needs = const [],
    this.travellerName,
    this.days = const [],
    this.pickupTime,
    this.pickupPlace,
    this.text = '',
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
      needs: ((json['needs'] as List?) ?? const []).whereType<String>().toList(),
      travellerName: json['travellerName'] as String?,
      days: ((json['days'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TripContextDay.fromJson)
          .toList(),
      pickupTime: json['pickupTime'] as String?,
      pickupPlace: json['pickupPlace'] as String?,
      text: json['text'] as String? ?? '',
    );
  }
}

class TripPhoneBookingModel {
  final String hostName;
  final String? hostPhone;
  final String roomName;
  final int nights;
  final int agreedTotal;
  final bool advancePaid;
  final int? advanceAmount;
  final String? note;
  final DateTime? recordedAt;
  final DateTime? updatedAt;

  const TripPhoneBookingModel({
    this.hostName = '',
    this.hostPhone,
    this.roomName = '',
    this.nights = 1,
    this.agreedTotal = 0,
    this.advancePaid = false,
    this.advanceAmount,
    this.note,
    this.recordedAt,
    this.updatedAt,
  });

  factory TripPhoneBookingModel.fromJson(Map<String, dynamic> json) => TripPhoneBookingModel(
        hostName: json['hostName'] as String? ?? '',
        hostPhone: json['hostPhone'] as String?,
        roomName: json['roomName'] as String? ?? '',
        nights: (json['nights'] as num?)?.toInt() ?? 1,
        agreedTotal: (json['agreedTotal'] as num?)?.toInt() ?? 0,
        advancePaid: json['advancePaid'] == true,
        advanceAmount: (json['advanceAmount'] as num?)?.toInt(),
        note: json['note'] as String?,
        recordedAt: tripInstant(json['recordedAt']),
        updatedAt: tripInstant(json['updatedAt']),
      );
}

class TripHostConfirmModel {
  final bool linkSent;
  final int linkCount;
  final DateTime? canResendAt;
  final DateTime? answeredAt;
  final String? answer;
  final String? answeredVia;
  final DateTime? canOverrideUntil;

  const TripHostConfirmModel({
    this.linkSent = false,
    this.linkCount = 0,
    this.canResendAt,
    this.answeredAt,
    this.answer,
    this.answeredVia,
    this.canOverrideUntil,
  });

  bool get answeredByLink => answeredVia == 'Link';

  bool canResend(DateTime now) {
    if (!linkSent || answeredAt != null) return false;
    final at = canResendAt;
    return linkCount < 2 && (at == null || !at.isAfter(now));
  }

  bool canOverride(DateTime now) {
    final until = canOverrideUntil;
    return answeredByLink && until != null && until.isAfter(now);
  }

  factory TripHostConfirmModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TripHostConfirmModel();
    return TripHostConfirmModel(
      linkSent: json['linkSent'] == true,
      linkCount: (json['linkCount'] as num?)?.toInt() ?? 0,
      canResendAt: tripInstant(json['canResendAt']),
      answeredAt: tripInstant(json['answeredAt']),
      answer: json['answer'] as String?,
      answeredVia: json['answeredVia'] as String?,
      canOverrideUntil: tripInstant(json['canOverrideUntil']),
    );
  }
}

class TripAdvanceModel {
  final String status;
  final int? amount;
  final DateTime? holdUntil;
  final DateTime? askedAt;
  final DateTime? proofSentAt;
  final DateTime? receivedAt;
  final DateTime? notYetAt;
  final DateTime? lastHostReminderAt;
  final DateTime? nextHostReminderAt;
  final int reminderCount;

  const TripAdvanceModel({
    this.status = TripAdvanceStatuses.none,
    this.amount,
    this.holdUntil,
    this.askedAt,
    this.proofSentAt,
    this.receivedAt,
    this.notYetAt,
    this.lastHostReminderAt,
    this.nextHostReminderAt,
    this.reminderCount = 0,
  });

  bool get isPending => status == TripAdvanceStatuses.pending;
  bool get isProofSent => status == TripAdvanceStatuses.proofSent;
  bool get isReceived => status == TripAdvanceStatuses.received;
  bool get isHoldExpired => status == TripAdvanceStatuses.holdExpired;
  bool get hasRequest => status != TripAdvanceStatuses.none;
  bool get isOpenRequest => isPending || isProofSent;

  bool holdPassed(DateTime now) {
    final h = holdUntil;
    return h != null && !h.isAfter(now);
  }

  factory TripAdvanceModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TripAdvanceModel();
    return TripAdvanceModel(
      status: json['status'] as String? ?? TripAdvanceStatuses.none,
      amount: (json['amount'] as num?)?.toInt(),
      holdUntil: tripInstant(json['holdUntil']),
      askedAt: tripInstant(json['askedAt']),
      proofSentAt: tripInstant(json['proofSentAt']),
      receivedAt: tripInstant(json['receivedAt']),
      notYetAt: tripInstant(json['notYetAt']),
      lastHostReminderAt: tripInstant(json['lastHostReminderAt']),
      nextHostReminderAt: tripInstant(json['nextHostReminderAt']),
      reminderCount: (json['reminderCount'] as num?)?.toInt() ?? 0,
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
  final int? serverNights;
  final String? conversationId;
  final String status;
  final String? failReason;
  final String displayStatusWire;
  final DateTime? expiresAt;
  final bool isUrgent;
  final int? agreedTotal;
  final TripOfferModel? acceptedOffer;
  final TripOfferModel? openOffer;
  final int offerCount;
  final TripEnquiryContext context;
  final TripPhoneBookingModel? phoneBooking;
  final TripHostConfirmModel hostConfirm;
  final TripAdvanceModel advance;
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
    this.serverNights,
    this.conversationId,
    this.status = TripEnquiryStatuses.asked,
    this.failReason,
    this.displayStatusWire = 'asked',
    this.expiresAt,
    this.isUrgent = false,
    this.agreedTotal,
    this.acceptedOffer,
    this.openOffer,
    this.offerCount = 0,
    this.context = const TripEnquiryContext(),
    this.phoneBooking,
    this.hostConfirm = const TripHostConfirmModel(),
    this.advance = const TripAdvanceModel(),
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
  });

  TripDisplayStatus get display => TripDisplayStatus.parse(displayStatusWire);

  bool get canCounter =>
      !isTaxi &&
      (display == TripDisplayStatus.asked || display == TripDisplayStatus.offered) &&
      counterCount < TripConstants.maxCounters &&
      conversationId != null;

  bool get canChangeRequest => !isTaxi && isConfirmedByBoth && pendingChange == null && acceptedOffer != null;

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

  String? get advanceLabel {
    if (isTaxi || !isConfirmedByBoth || !advance.hasRequest) return null;
    final label = TripStatusVisuals.advanceLabel(advance);
    return label.isEmpty ? null : label;
  }

  bool get isOpen => TripEnquiryStatuses.open.contains(status);

  bool get isConfirmed => TripEnquiryStatuses.confirmed.contains(status);

  bool get isUnconfirmed =>
      status == TripEnquiryStatuses.asked ||
      status == TripEnquiryStatuses.offered ||
      status == TripEnquiryStatuses.countered;

  bool get isRed => display.isRed;

  bool get isPhoneBooking => phoneBooking != null;

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
    return TripFormat.dateRange(a, b ?? a);
  }

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

    final pb = json['phoneBooking'];
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
      serverNights: (json['nights'] as num?)?.toInt(),
      conversationId: json['conversationId'] as String?,
      status: json['status'] as String? ?? TripEnquiryStatuses.asked,
      failReason: json['failReason'] as String?,
      displayStatusWire: json['displayStatus'] as String? ?? 'none',
      expiresAt: tripInstant(json['expiresAt']),
      isUrgent: json['isUrgent'] == true,
      agreedTotal: (json['agreedTotal'] as num?)?.toInt(),
      acceptedOffer: offer('acceptedOffer'),
      openOffer: offer('openOffer'),
      offerCount: (json['offerCount'] as num?)?.toInt() ?? 0,
      context: TripEnquiryContext.fromJson(json['context'] as Map<String, dynamic>?),
      phoneBooking: pb is Map<String, dynamic> ? TripPhoneBookingModel.fromJson(pb) : null,
      hostConfirm: TripHostConfirmModel.fromJson(json['hostConfirm'] as Map<String, dynamic>?),
      advance: TripAdvanceModel.fromJson(json['advance'] as Map<String, dynamic>?),
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

class TripEnquiryBatch {
  final List<TripEnquiryModel> items;
  final List<TripSkipped> skipped;
  final bool veryShortNotice;
  final List<String> updated;
  final int? asksLeft;

  const TripEnquiryBatch({
    required this.items,
    required this.skipped,
    required this.veryShortNotice,
    this.updated = const [],
    this.asksLeft,
  });

  factory TripEnquiryBatch.fromJson(Map<String, dynamic> json, {int? asksLeft}) => TripEnquiryBatch(
        items: _enquiryList(json['items']),
        skipped: ((json['skipped'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TripSkipped.fromJson)
            .toList(),
        veryShortNotice: json['veryShortNotice'] == true,
        updated: ((json['updated'] as List?) ?? const []).whereType<String>().toList(),
        asksLeft: asksLeft,
      );

  bool isUpdated(String enquiryId) => updated.contains(enquiryId);
}

class TripPhoneBookingResult {
  final TripEnquiryModel enquiry;
  final String confirmLink;
  final String whatsAppText;

  const TripPhoneBookingResult({required this.enquiry, required this.confirmLink, required this.whatsAppText});

  factory TripPhoneBookingResult.fromJson(Map<String, dynamic> json) => TripPhoneBookingResult(
        enquiry: TripEnquiryModel.fromJson((json['enquiry'] as Map<String, dynamic>?) ?? const {}),
        confirmLink: json['confirmLink'] as String? ?? '',
        whatsAppText: json['whatsAppText'] as String? ?? '',
      );
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
