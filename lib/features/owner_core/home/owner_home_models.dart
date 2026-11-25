import '../../../utils/photo_url.dart';
import '../calendar/models/calendar_models.dart';
import '../json/owner_dates.dart';
import '../json/owner_json.dart';
import '../plan/plan_card_state.dart';

class OwnerStatusLine {
  const OwnerStatusLine({required this.code, this.args = const {}});

  final String code;
  final Map<String, dynamic> args;

  static OwnerStatusLine? maybe(Object? raw) {
    final m = OwnerJson.mapOrNull(raw);
    final code = OwnerJson.strOrNull(m?['code']);
    if (m == null || code == null) return null;
    return OwnerStatusLine(code: code, args: OwnerJson.map(m['args']));
  }
}

class OwnerHomeListing {
  const OwnerHomeListing({
    this.id,
    this.kind,
    this.status,
    this.everApproved = false,
    this.name = '',
    this.sub,
    this.cityName,
    this.plate,
    this.vehicleName,
    this.seats,
    this.displayPhotoUrl,
    this.switchOn = false,
    this.isFeatured = false,
    this.takenDown = false,
    this.rejectedReason,
    this.areaPaused = false,
    this.tabOff = false,
    this.plannerOff = false,
    this.pendingEdit = false,
    this.ringReady,
    this.onTripUntil,
    this.routesMeter,
    this.localDayRate,
    this.statusLine,
  });

  final String? id;
  final String? kind;
  final String? status;
  final bool everApproved;
  final String name;
  final String? sub;
  final String? cityName;
  final String? plate;
  final String? vehicleName;
  final int? seats;
  final String? displayPhotoUrl;
  final bool switchOn;
  final bool isFeatured;
  final bool takenDown;
  final String? rejectedReason;
  final bool areaPaused;
  final bool tabOff;
  final bool plannerOff;
  final bool pendingEdit;
  final bool? ringReady;
  final DateTime? onTripUntil;
  final Meter? routesMeter;
  final int? localDayRate;
  final OwnerStatusLine? statusLine;

  bool get approved => status == 'Approved';
  bool get underReview => status == 'PendingReview';
  bool get rejected => status == 'Rejected';

  factory OwnerHomeListing.fromJson(Map<String, dynamic> j) => OwnerHomeListing(
        id: OwnerJson.strOrNull(j['id']),
        kind: OwnerJson.strOrNull(j['kind']),
        status: OwnerJson.strOrNull(j['status']),
        everApproved: OwnerJson.boolean(j['everApproved']),
        name: OwnerJson.strOrNull(j['name']) ?? '',
        sub: OwnerJson.strOrNull(j['sub']),
        cityName: OwnerJson.strOrNull(j['cityName']),
        plate: OwnerJson.strOrNull(j['plate']),
        vehicleName: OwnerJson.strOrNull(j['vehicleName']),
        seats: OwnerJson.intOrNull(j['seats']),
        displayPhotoUrl: PhotoUrl.parse(j['displayPhotoUrl']),
        switchOn: OwnerJson.boolean(j['switchOn']),
        isFeatured: OwnerJson.boolean(j['isFeatured']),
        takenDown: OwnerJson.boolean(j['takenDown']),
        rejectedReason: OwnerJson.strOrNull(j['rejectedReason']),
        areaPaused: OwnerJson.boolean(j['areaPaused']),
        tabOff: OwnerJson.boolean(j['tabOff']),
        plannerOff: OwnerJson.boolean(j['plannerOff']),
        pendingEdit: OwnerJson.boolean(j['pendingEdit']),
        ringReady: OwnerJson.boolOrNull(j['ringReady']),
        onTripUntil: OwnerDates.day(j['onTripUntil']),
        routesMeter: Meter.maybe(j['routesMeter']),
        localDayRate: OwnerJson.intOrNull(j['localDayRate']),
        statusLine: OwnerStatusLine.maybe(j['statusLine']),
      );
}

class OwnerAttention {
  const OwnerAttention({required this.code, this.priority = 99, this.args = const {}});

  final String code;
  final int priority;
  final Map<String, dynamic> args;

  factory OwnerAttention.fromJson(Map<String, dynamic> j) => OwnerAttention(
        code: OwnerJson.str(j['code']),
        priority: OwnerJson.integer(j['priority'], 99),
        args: OwnerJson.map(j['args']),
      );

  static List<OwnerAttention> listOf(Object? raw) {
    final out = OwnerJson.list(raw, OwnerAttention.fromJson).where((a) => a.code.isNotEmpty).toList();
    out.sort((a, b) => a.priority.compareTo(b.priority));
    return out;
  }
}

class OwnerNumbers {
  const OwnerNumbers({
    this.newEnquiries,
    this.offersWaiting,
    this.confirmed,
    this.newRequests,
    this.missedRequests,
    this.nextBookingDate,
    this.ratingAvg,
    this.ratingCount,
    this.centreBadge = 0,
  });

  final int? newEnquiries;
  final int? offersWaiting;
  final int? confirmed;
  final int? newRequests;
  final int? missedRequests;
  final DateTime? nextBookingDate;
  final double? ratingAvg;
  final int? ratingCount;
  final int centreBadge;

  factory OwnerNumbers.fromJson(Map<String, dynamic> j) {
    final stay = OwnerJson.map(j['stay']);
    final taxi = OwnerJson.map(j['taxi']);
    int? pick(String key, Map<String, dynamic> nested) => OwnerJson.intOrNull(nested[key]) ?? OwnerJson.intOrNull(j[key]);
    return OwnerNumbers(
      newEnquiries: pick('newEnquiries', stay),
      offersWaiting: pick('offersWaiting', stay),
      confirmed: pick('confirmed', stay),
      newRequests: pick('newRequests', taxi),
      missedRequests: pick('missedRequests', taxi),
      nextBookingDate: OwnerDates.day(taxi['nextBookingDate'] ?? j['nextBookingDate']),
      ratingAvg: OwnerJson.doubleOrNull(taxi['ratingAvg'] ?? j['ratingAvg']),
      ratingCount: pick('ratingCount', taxi),
      centreBadge: OwnerJson.integer(j['centreBadge']),
    );
  }
}

class OwnerUpcoming {
  const OwnerUpcoming({
    this.rows = const [],
    this.moreInWindowCount = 0,
    this.windowLabelDays,
    this.beyondWindowAppCount = 0,
    this.beyondWindowFirstDate,
    this.window = const CalendarWindow(),
  });

  final List<CalendarEntry> rows;
  final int moreInWindowCount;
  final int? windowLabelDays;
  final int beyondWindowAppCount;
  final DateTime? beyondWindowFirstDate;
  final CalendarWindow window;

  factory OwnerUpcoming.fromJson(Map<String, dynamic> j) => OwnerUpcoming(
        rows: CalendarEntry.listOf(j['rows']).take(3).toList(),
        moreInWindowCount: OwnerJson.integer(j['moreInWindowCount']),
        windowLabelDays: OwnerJson.intOrNull(j['windowLabelDays']),
        beyondWindowAppCount: OwnerJson.integer(j['beyondWindowAppCount']),
        beyondWindowFirstDate: OwnerDates.day(j['beyondWindowFirstDate']),
        window: CalendarWindow.fromJson(OwnerJson.map(j['window'])),
      );
}

class OwnerWeekly {
  const OwnerWeekly({this.shown, this.enquiries, this.requestsNoRoute, this.requestsOnRoutes, this.accepted});

  final int? shown;
  final int? enquiries;
  final int? requestsNoRoute;
  final int? requestsOnRoutes;
  final int? accepted;

  factory OwnerWeekly.fromJson(Map<String, dynamic> j) => OwnerWeekly(
        shown: OwnerJson.intOrNull(j['shown']),
        enquiries: OwnerJson.intOrNull(j['enquiries']),
        requestsNoRoute: OwnerJson.intOrNull(j['requestsNoRoute']),
        requestsOnRoutes: OwnerJson.intOrNull(j['requestsOnRoutes']),
        accepted: OwnerJson.intOrNull(j['accepted']),
      );
}

class OwnerPlanCard {
  const OwnerPlanCard({
    this.state = PlanCardState.unknown,
    this.paymentEnabled = false,
    this.isPaid = false,
    this.source,
    this.endsAt,
    this.renewsOn,
    this.trialAvailable = false,
    this.limits = const {},
    this.hidden = const {},
    this.ringWeight,
    this.paymentStartsOn,
    this.plansStartedToday = false,
    this.weekly,
  });

  final PlanCardState state;
  final bool paymentEnabled;
  final bool isPaid;
  final String? source;
  final DateTime? endsAt;
  final DateTime? renewsOn;
  final bool trialAvailable;
  final Map<String, dynamic> limits;
  final Map<String, dynamic> hidden;
  final int? ringWeight;
  final DateTime? paymentStartsOn;
  final bool plansStartedToday;
  final OwnerWeekly? weekly;

  static OwnerPlanCard? maybe(Object? raw) {
    final j = OwnerJson.mapOrNull(raw);
    if (j == null) return null;
    final weekly = OwnerJson.mapOrNull(j['weekly']);
    return OwnerPlanCard(
      state: PlanCardStates.parse(j['state']),
      paymentEnabled: OwnerJson.boolean(j['paymentEnabled']),
      isPaid: OwnerJson.boolean(j['isPaid']),
      source: OwnerJson.strOrNull(j['source']),
      endsAt: OwnerJson.time(j['endsAt']) ?? OwnerDates.day(j['endsAt']),
      renewsOn: OwnerDates.day(j['renewsOn']) ?? OwnerJson.time(j['renewsOn']),
      trialAvailable: OwnerJson.boolean(j['trialAvailable']),
      limits: OwnerJson.map(j['limits']),
      hidden: OwnerJson.map(j['hidden']),
      ringWeight: OwnerJson.intOrNull(j['ringWeight']),
      paymentStartsOn: OwnerDates.day(j['paymentStartsOn']),
      plansStartedToday: OwnerJson.boolean(j['plansStartedToday']),
      weekly: weekly == null ? null : OwnerWeekly.fromJson(weekly),
    );
  }
}

class OwnerHomeDto {
  const OwnerHomeDto({
    this.role,
    this.today,
    this.paymentEnabled = false,
    this.listing = const OwnerHomeListing(),
    this.attention = const [],
    this.attentionCount = 0,
    this.numbers = const OwnerNumbers(),
    this.upcoming = const OwnerUpcoming(),
    this.planCard,
    this.festival,
    this.raw = const {},
  });

  final String? role;
  final DateTime? today;
  final bool paymentEnabled;
  final OwnerHomeListing listing;
  final List<OwnerAttention> attention;
  final int attentionCount;
  final OwnerNumbers numbers;
  final OwnerUpcoming upcoming;
  final OwnerPlanCard? planCard;
  final FestivalRow? festival;
  final Map<String, dynamic> raw;

  factory OwnerHomeDto.fromJson(Map<String, dynamic> j) {
    final attention = OwnerAttention.listOf(j['attention']);
    return OwnerHomeDto(
      role: OwnerJson.strOrNull(j['role']),
      today: OwnerDates.day(j['today']),
      paymentEnabled: OwnerJson.boolean(j['paymentEnabled']),
      listing: OwnerHomeListing.fromJson(OwnerJson.map(j['listing'])),
      attention: attention,
      attentionCount: OwnerJson.intOrNull(j['attentionCount']) ?? attention.length,
      numbers: OwnerNumbers.fromJson(OwnerJson.map(j['numbers'])),
      upcoming: OwnerUpcoming.fromJson(OwnerJson.map(j['upcoming'])),
      planCard: OwnerPlanCard.maybe(j['planCard']),
      festival: FestivalRow.maybe(j['festival']),
      raw: j,
    );
  }
}
