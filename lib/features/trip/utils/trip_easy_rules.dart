import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';
import 'trip_enquiry_rules.dart';
import '../trip_strings_dayplan.dart';
import '../trip_strings_v2_easy.dart';

class TripEasyRowInfo {
  final TripEasyRowKey key;
  final TripRowState state;
  final String title;
  final String subtitle;
  final bool needsYou;
  final List<TripEnquiryModel> enquiries;
  final String? journeyId;
  final int nightsTotal;
  final int nightsCovered;
  final List<int> uncoveredDays;
  final TripTaxiRequestRef? taxiRequest;
  final String? pill;

  const TripEasyRowInfo({
    required this.key,
    required this.state,
    required this.title,
    this.subtitle = '',
    this.needsYou = false,
    this.enquiries = const [],
    this.journeyId,
    this.nightsTotal = 0,
    this.nightsCovered = 0,
    this.uncoveredDays = const [],
    this.taxiRequest,
    this.pill,
  });

  TripEasyRowKind get kind => key.kind;

  int? get legIndex => key.legIndex;

  int get askedCount => enquiries
      .where((e) =>
          e.status == TripEnquiryStatuses.asked ||
          e.status == TripEnquiryStatuses.countered ||
          e.status == TripEnquiryStatuses.offered ||
          e.status == TripEnquiryStatuses.fareSent)
      .length;

  bool get canMark =>
      state == TripRowState.todo ||
      state == TripRowState.attention ||
      state == TripRowState.asked ||
      state == TripRowState.offer;

  bool get partial => nightsTotal > 0 && nightsCovered < nightsTotal;

  bool get isDone => state.isDone && !partial;

  TripEasyRowInfo withState(TripRowState s) => TripEasyRowInfo(
        key: key,
        state: s,
        title: title,
        subtitle: subtitle,
        needsYou: needsYou,
        enquiries: enquiries,
        journeyId: journeyId,
        nightsTotal: nightsTotal,
        nightsCovered: nightsCovered,
        uncoveredDays: uncoveredDays,
        taxiRequest: taxiRequest,
        pill: s == state ? pill : null,
      );

  bool get fromTaxiRequest => taxiRequest != null;
}

class TripEasyRules {
  const TripEasyRules._();

  static int _newest(TripEnquiryModel a, TripEnquiryModel b) {
    final x = a.updatedAt ?? a.createdAt;
    final y = b.updatedAt ?? b.createdAt;
    if (x == null || y == null) return 0;
    return y.compareTo(x);
  }

  static Set<int> nightsOf(TripEnquiryModel e, TripPlan p) {
    var first = e.day;
    final start = p.settings.startDate;
    final ci = e.checkIn;
    if (start != null && ci != null) {
      first = DateTime.utc(ci.year, ci.month, ci.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays + 1;
    }
    if (first == null) return const {};
    final n = e.nights < 1 ? 1 : e.nights;
    return {for (var i = 0; i < n; i++) first + i};
  }

  static Set<int> _legDays(TripPlan p, int legIndex) => {
        for (final d in p.days)
          if (d.leg == legIndex) d.day,
      };

  static List<TripEnquiryModel> stayRows(TripPlan p, List<TripEnquiryModel> all, int legIndex) {
    final days = _legDays(p, legIndex);
    return [
      for (final e in all)
        if (!e.isTaxi && e.status != TripEnquiryStatuses.closed && nightsOf(e, p).any(days.contains)) e,
    ]..sort(_newest);
  }

  static List<TripEnquiryModel> taxiRows(List<TripEnquiryModel> all) => [
        for (final e in all)
          if (e.isTaxi && !e.isSegment && e.context.journeyId == null && e.status != TripEnquiryStatuses.closed) e,
      ]..sort(_newest);

  static TripRowMark? markOf(TripPlan p, TripEasyRowKey key) => switch (key.kind) {
        TripEasyRowKind.stay => p.legAt(key.legIndex ?? 0)?.stayMark,
        TripEasyRowKind.taxi => p.taxiMark,
        _ => null,
      };

  static List<TripEasyRowKey> keys(TripPlan p) {
    final n = p.legs.isEmpty ? 1 : p.legs.length;
    return [
      for (var k = 1; k <= n; k++) TripEasyRowKey(TripEasyRowKind.stay, k),
      const TripEasyRowKey(TripEasyRowKind.taxi),
    ];
  }

  static List<TripEasyRowInfo> rows(
    TripPlan p,
    List<TripEnquiryModel> enquiries,
    List<TripJourney> journeys, {
    Set<String> dismissed = const {},
    TripTaxiRequestRef? taxiRequest,
    bool taxiCanRate = false,
  }) {
    bool gone(String id) => dismissed.contains(id) || p.dismissedEnquiryIds.contains(id);
    return [
      for (final k in keys(p))
        k.kind == TripEasyRowKind.stay
            ? _stay(p, enquiries, k, gone)
            : _taxi(p, enquiries, k, gone, taxiRequest, taxiCanRate),
    ];
  }

  static TripEasyRowInfo? rowOf(List<TripEasyRowInfo> rows, TripEasyRowKey key) {
    for (final r in rows) {
      if (r.key == key) return r;
    }
    return null;
  }

  static String titleOf(TripPlan p, TripEasyRowKey key) => switch (key.kind) {
        TripEasyRowKind.gettingThere => TripStringsV2Easy.gettingThere,
        TripEasyRowKind.comingBack => TripStringsV2Easy.comingBack,
        TripEasyRowKind.taxi => TripStringsV2Easy.localTaxi,
        TripEasyRowKind.stay => TripStringsV2Easy.stayIn(p.legAt(key.legIndex ?? 1)?.cityName ?? p.cityName),
        TripEasyRowKind.between => TripStringsV2Easy.betweenTitle,
      };

  static String hintOf(TripPlan p, TripEasyRowKey key) => switch (key.kind) {
        TripEasyRowKind.stay => _stayHint(p, key.legIndex ?? 1),
        TripEasyRowKind.taxi => TripStringsV2Easy.taxiDays(p.days.length),
        _ => TripStringsV2Easy.travelHint,
      };

  static String _stayHint(TripPlan p, int legIndex) {
    final nights = p.legDayCount(legIndex);
    final text = _nightsText(nights);
    if (text == null) return TripStringsV2Easy.stayHint;
    final inDate = p.settings.dateOf(p.legStart(legIndex));
    if (inDate == null) return text;
    final out = DateTime(inDate.year, inDate.month, inDate.day + nights);
    final dates = TripStringsV2Easy.stayDates(inDate, out);
    return '$text · $dates';
  }

  static String? _nightsText(int days) => days < 1 ? null : TripStringsV2Easy.nightsOf(days);

  static TripEasyRowInfo _marked(TripPlan p, TripEasyRowKey k, TripRowMark m, List<TripEnquiryModel> rows) => TripEasyRowInfo(
        key: k,
        state: m.isOwn ? TripRowState.own : TripRowState.skipped,
        title: titleOf(p, k),
        subtitle: hintOf(p, k),
        enquiries: rows,
      );

  static TripEnquiryModel? _lastClosedProblem(List<TripEnquiryModel> newestFirst, bool Function(String) gone) {
    for (final e in newestFirst) {
      if (e.isOpen || e.status == TripEnquiryStatuses.closed || gone(e.id)) continue;
      return TripEnquiryStatuses.problem.contains(e.status) ? e : null;
    }
    return null;
  }

  static TripEasyRowInfo _stay(TripPlan p, List<TripEnquiryModel> all, TripEasyRowKey k, bool Function(String) gone) {
    final byDays = stayRows(p, all, k.legIndex ?? 1);
    final mark = markOf(p, k);
    if (mark != null) return _marked(p, k, mark, byDays);
    final moved = <TripEnquiryModel>[];
    final rows = <TripEnquiryModel>[];
    for (final e in byDays) {
      final home = TripEnquiryRules.homeLegIndex(e, p);
      (home != null && home != k.legIndex ? moved : rows).add(e);
    }
    final live = [for (final e in rows) if (e.isOpen) e];
    final legDays = _legDays(p, k.legIndex ?? 1);
    final covered = <int>{for (final e in live) ...nightsOf(e, p).where(legDays.contains)};
    final uncovered = ([...legDays]..sort()).where((d) => !covered.contains(d)).toList();
    final partial = legDays.isNotEmpty && covered.length < legDays.length;
    TripEasyRowInfo info(TripRowState s, String line, {bool needsYou = false}) {
      final counts = s == TripRowState.asked ||
          s == TripRowState.offer ||
          s == TripRowState.booked ||
          s == TripRowState.confirmed;
      return TripEasyRowInfo(
        key: k,
        state: s,
        title: titleOf(p, k),
        subtitle: counts && partial ? TripStringsV2Easy.coverLine(_pillWord(s), covered.length, legDays.length) : line,
        needsYou: needsYou,
        enquiries: rows,
        nightsTotal: counts ? legDays.length : 0,
        nightsCovered: counts ? covered.length : 0,
        uncoveredDays: counts ? uncovered : const [],
      );
    }

    final both = live.where((e) => e.status == TripEnquiryStatuses.confirmedByBoth).firstOrNull;
    if (both == null && moved.any((e) => e.status == TripEnquiryStatuses.confirmedByBoth)) {
      return TripEasyRowInfo(
        key: k,
        state: TripRowState.attention,
        title: titleOf(p, k),
        subtitle: TripStringsV2Easy.dateChanged,
        needsYou: true,
        enquiries: moved,
      );
    }
    final offered = [
      for (final e in live)
        if (e.status == TripEnquiryStatuses.offered) e,
    ];
    if (both != null) {
      final others = [for (final e in live) if (e.id != both.id && e.status == TripEnquiryStatuses.offered) e];
      final needs = both.advance.isPending || both.hasPendingRevised || others.isNotEmpty;
      return info(TripRowState.confirmed, both.listingName, needsYou: needs);
    }
    final byYou = live.where((e) => e.status == TripEnquiryStatuses.confirmedByTraveller).firstOrNull;
    if (byYou != null) return info(TripRowState.booked, byYou.listingName, needsYou: offered.isNotEmpty);
    if (offered.isNotEmpty) return info(TripRowState.offer, _offerLine(offered), needsYou: true);
    final asked = [
      for (final e in live)
        if (e.status == TripEnquiryStatuses.asked || e.status == TripEnquiryStatuses.countered) e,
    ];
    if (asked.isNotEmpty) return info(TripRowState.asked, TripStringsV2Easy.asked(asked.length));
    final red = _lastClosedProblem(rows, gone);
    if (red != null) return info(TripRowState.attention, TripStringsV2Easy.stayProblem(red.status));
    return info(TripRowState.todo, hintOf(p, k));
  }

  static String _pillWord(TripRowState s) => switch (s) {
        TripRowState.offer => TripStringsV2Easy.pillOffer,
        TripRowState.booked => TripStringsV2Easy.pillBooked,
        TripRowState.confirmed => TripStringsV2Easy.pillConfirmed,
        _ => TripStringsV2Easy.pillAsked,
      };

  static String _offerLine(List<TripEnquiryModel> offers) {
    final name = offers.length == 1 ? offers.first.listingName.trim() : '';
    return name.isEmpty ? TripStringsV2Easy.offers(offers.length) : TripStringsV2Easy.offerFrom(name);
  }

  static const Set<String> _activeRequestStates = {'Open', 'Collecting', 'Selected', 'Booked', 'InProgress'};

  static const Set<String> _endedRequestStates = {'Cancelled', 'Expired'};

  static bool taxiRequestActive(TripTaxiRequestRef? r) => r != null && _activeRequestStates.contains(r.state);

  // Contract section 4: the new request feeds the taxi row; legacy enquiries only when the trip never had one.
  static TripEasyRowInfo? _fromRequest(TripPlan p, TripEasyRowKey k, TripTaxiRequestRef r, List<TripEnquiryModel> rows,
      {bool canRate = false}) {
    TripEasyRowInfo info(TripRowState s, String line, {bool needsYou = false, String? pill}) => TripEasyRowInfo(
          key: k,
          state: s,
          title: titleOf(p, k),
          subtitle: line,
          needsYou: needsYou,
          enquiries: rows,
          taxiRequest: r,
          pill: pill,
        );
    return switch (r.state) {
      'Open' => info(TripRowState.asked, TripStringsDayplan.taxiFinding),
      'Collecting' => info(TripRowState.offer, TripStringsDayplan.taxiChoose, needsYou: true),
      // Driver has not confirmed yet: not done, unlike the legacy "Booked by you".
      'Selected' => info(TripRowState.asked, TripStringsDayplan.taxiWaitingConfirm, pill: TripStringsDayplan.pillWaiting),
      'Booked' => info(TripRowState.confirmed, TripStringsDayplan.taxiBooked),
      'InProgress' => info(TripRowState.confirmed, TripStringsDayplan.taxiInProgress),
      'Completed' => info(TripRowState.confirmed, r.view == 'Rate' ? TripStringsDayplan.taxiRate : TripStringsDayplan.taxiDone),
      // O13: the driver left or an admin cancelled during the trip; the traveller can still rate.
      'Cancelled' when canRate => info(TripRowState.confirmed, TripStringsDayplan.taxiRate),
      _ => null,
    };
  }

  static TripEasyRowInfo _taxi(
    TripPlan p,
    List<TripEnquiryModel> all,
    TripEasyRowKey k,
    bool Function(String) gone, [
    TripTaxiRequestRef? request,
    bool canRate = false,
  ]) {
    final rows = taxiRows(all);
    final mark = markOf(p, k);
    if (request != null && taxiRequestActive(request)) return _fromRequest(p, k, request, rows)!;
    if (mark != null) return _marked(p, k, mark, rows);
    if (request != null) {
      final done = _fromRequest(p, k, request, rows, canRate: canRate);
      if (done != null) return done;
      if (_endedRequestStates.contains(request.state)) {
        return TripEasyRowInfo(key: k, state: TripRowState.todo, title: titleOf(p, k), subtitle: hintOf(p, k), enquiries: rows);
      }
    }
    final live = [for (final e in rows) if (e.isOpen) e];
    TripEasyRowInfo info(TripRowState s, String line, {bool needsYou = false}) => TripEasyRowInfo(
          key: k,
          state: s,
          title: titleOf(p, k),
          subtitle: line,
          needsYou: needsYou,
          enquiries: rows,
        );
    final both = live.where((e) => e.status == TripEnquiryStatuses.confirmedByBoth).firstOrNull;
    if (both != null) {
      final replace = live.any((e) => e.id != both.id && e.status == TripEnquiryStatuses.fareSent);
      return info(TripRowState.confirmed, both.listingName, needsYou: replace);
    }
    final fare = live.where((e) => e.status == TripEnquiryStatuses.fareSent).toList();
    final byYou = live.where((e) => e.status == TripEnquiryStatuses.bookedByTraveller).firstOrNull;
    if (byYou != null) return info(TripRowState.booked, byYou.listingName, needsYou: fare.isNotEmpty);
    if (fare.isNotEmpty) return info(TripRowState.offer, _offerLine(fare), needsYou: true);
    final asked = [
      for (final e in live)
        if (e.status == TripEnquiryStatuses.asked) e,
    ];
    if (asked.isNotEmpty) return info(TripRowState.asked, TripStringsV2Easy.asked(asked.length));
    final red = _lastClosedProblem(rows, gone);
    if (red != null) return info(TripRowState.attention, TripStringsV2Easy.taxiProblem(red.status));
    return info(TripRowState.todo, hintOf(p, k));
  }

  static TripEasyRowInfo? firstInProgress(List<TripEasyRowInfo> rows) {
    for (final r in rows) {
      if (r.needsYou && r.state.inProgress) return r;
    }
    for (final r in rows) {
      if (r.state.inProgress) return r;
    }
    return null;
  }

  static bool hasOwnMark(TripPlan p) =>
      p.taxiMark?.isOwn == true ||
      p.steps.gettingThere.status == TripStepStatus.own ||
      p.steps.comingBack.status == TripStepStatus.own ||
      p.legs.any((l) => l.stayMark?.isOwn == true || l.travelMark?.isOwn == true);

  static bool allResolved(List<TripEasyRowInfo> rows) => rows.every((r) => r.isDone || r.state == TripRowState.skipped);
}
