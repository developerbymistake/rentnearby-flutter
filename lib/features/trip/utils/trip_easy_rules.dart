import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';
import 'trip_enquiry_rules.dart';
import 'trip_format.dart';
import '../trip_strings_v2_easy.dart';
import 'trip_step_rules.dart';
import 'trip_travel_rules.dart';

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
      );
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
        TripEasyRowKind.between => p.legAt(key.legIndex ?? 0)?.travelMark,
        TripEasyRowKind.taxi => p.taxiMark,
        _ => null,
      };

  static List<TripEasyRowKey> keys(TripPlan p) {
    final n = p.legs.isEmpty ? 1 : p.legs.length;
    return [
      const TripEasyRowKey(TripEasyRowKind.gettingThere),
      for (var k = 1; k <= n; k++) ...[
        if (k >= 2) TripEasyRowKey(TripEasyRowKind.between, k),
        TripEasyRowKey(TripEasyRowKind.stay, k),
      ],
      const TripEasyRowKey(TripEasyRowKind.taxi),
      const TripEasyRowKey(TripEasyRowKind.comingBack),
    ];
  }

  static List<TripEasyRowInfo> rows(
    TripPlan p,
    List<TripEnquiryModel> enquiries,
    List<TripJourney> journeys, {
    Set<String> dismissed = const {},
  }) {
    bool gone(String id) => dismissed.contains(id) || p.dismissedEnquiryIds.contains(id);
    return [
      for (final k in keys(p))
        switch (k.kind) {
          TripEasyRowKind.stay => _stay(p, enquiries, k, gone),
          TripEasyRowKind.taxi => _taxi(p, enquiries, k, gone),
          TripEasyRowKind.between => _between(p, enquiries, journeys, k),
          TripEasyRowKind.gettingThere || TripEasyRowKind.comingBack => _step(p, enquiries, journeys, k),
        },
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

  static String betweenName(TripPlan p, int legIndex) =>
      TripStringsV2Easy.between(p.legAt(legIndex - 1)?.cityName ?? '', p.legAt(legIndex)?.cityName ?? '');

  static String hintOf(TripPlan p, TripEasyRowKey key) => switch (key.kind) {
        TripEasyRowKind.stay => _stayHint(p, key.legIndex ?? 1),
        TripEasyRowKind.taxi => TripStringsV2Easy.taxiDays(p.days.length),
        TripEasyRowKind.between => _betweenHint(p, key.legIndex ?? 2),
        TripEasyRowKind.gettingThere => _route(p.steps.startFrom?.name, _firstCity(p)),
        TripEasyRowKind.comingBack => _route(_lastCity(p), p.steps.homeEnd?.name),
      };

  static String? _firstCity(TripPlan p) => p.legs.isEmpty ? p.cityName : p.legAt(1)?.cityName ?? p.cityName;

  static String? _lastCity(TripPlan p) => p.legs.isEmpty ? p.cityName : p.legs.last.cityName;

  static String _route(String? from, String? to) {
    final a = from?.trim() ?? '';
    final b = to?.trim() ?? '';
    return a.isEmpty || b.isEmpty ? TripStringsV2Easy.travelHint : '$a → $b';
  }

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

  static String _betweenHint(TripPlan p, int legIndex) {
    final name = betweenName(p, legIndex);
    if (p.legAt(legIndex - 1) == null || p.legAt(legIndex) == null) return TripStringsV2Easy.betweenHint;
    final start = p.legStart(legIndex);
    final d = start < 1 ? null : p.settings.dateOf(start);
    final route = name.replaceFirst(' to ', ' → ');
    return d == null ? route : '$route · ${TripFormat.shortDate(d)}';
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

  static TripEasyRowInfo _taxi(TripPlan p, List<TripEnquiryModel> all, TripEasyRowKey k, bool Function(String) gone) {
    final rows = taxiRows(all);
    final mark = markOf(p, k);
    if (mark != null) return _marked(p, k, mark, rows);
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

  static TripJourney? _journey(List<TripJourney> all, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final j in all) {
      if (j.id == id) return j;
    }
    return null;
  }

  static TripEasyRowInfo _travel(
    TripPlan p,
    TripEasyRowKey k,
    TripTravelState s,
    String? journeyId,
    List<TripEnquiryModel> rows, [
    bool carNeedsYou = false,
    TripJourney? journey,
  ]) {
    final TripRowState state;
    var needs = false;
    var line = hintOf(p, k);
    if (s.name == 'own') {
      state = TripRowState.own;
    } else {
      switch (s) {
        case TripTravelState.confirmed:
          state = TripRowState.confirmed;
          line = TripStringsV2Easy.confirmedLine;
        case TripTravelState.booked:
          state = TripRowState.booked;
          line = TripStringsV2Easy.bookedLine;
        case TripTravelState.partlyBooked || TripTravelState.asked:
          state = TripRowState.asked;
          needs = carNeedsYou;
          line = TripStringsV2Easy.waitingForReply;
        case TripTravelState.free:
          state = TripRowState.offer;
          needs = true;
          line = TripStringsV2Easy.offers(1);
        case TripTravelState.saved:
          state = TripRowState.saved;
          line = TripStringsV2Easy.savedDetail(journey?.cars ?? 0, journey?.listedTotal) ?? TripStringsV2Easy.savedLine;
        case TripTravelState.dateChanged:
          state = TripRowState.attention;
          line = TripStringsV2Easy.dateChanged;
        case TripTravelState.carMissing:
          state = TripRowState.attention;
          line = TripStringsV2Easy.carMissing;
        case TripTravelState.driverUnavailable:
          state = TripRowState.attention;
          line = TripStringsV2Easy.driverUnavailable;
        default:
          state = TripRowState.todo;
      }
    }
    return TripEasyRowInfo(
      key: k,
      state: state,
      title: titleOf(p, k),
      subtitle: line,
      needsYou: needs,
      enquiries: rows,
      journeyId: journeyId,
    );
  }

  static TripEasyRowInfo _step(TripPlan p, List<TripEnquiryModel> all, List<TripJourney> journeys, TripEasyRowKey k) {
    final role = k.kind == TripEasyRowKind.gettingThere ? TripStepRole.gettingThere : TripStepRole.comingBack;
    final step = p.steps.of(role);
    if (step.status == TripStepStatus.own || step.status == TripStepStatus.skipped) {
      return TripEasyRowInfo(
        key: k,
        state: step.status == TripStepStatus.own ? TripRowState.own : TripRowState.skipped,
        title: titleOf(p, k),
        subtitle: hintOf(p, k),
      );
    }
    final id = step.hasJourney ? step.journeyId : null;
    final j = _journey(journeys, id);
    final rows = id == null ? const <TripEnquiryModel>[] : TripTravelRules.liveRowsOf(id, all);
    final s = TripTravelRules.stateOf(
      role: TripJourneyRole.of(role),
      step: step,
      journey: j,
      journeyRows: all,
      travelDate: TripStepRules.expectedDate(role, step, p.settings, p.days.length),
    );
    if (j != null && s.name != 'own' && _moved(p, role, j, s == TripTravelState.confirmed)) {
      return TripEasyRowInfo(
        key: k,
        state: TripRowState.attention,
        title: titleOf(p, k),
        subtitle: TripStringsV2Easy.dateChanged,
        enquiries: rows,
        journeyId: id,
      );
    }
    return _travel(p, k, s, id, rows, _carNeedsYou(j, rows, step.ownCars), j);
  }

  static bool _moved(TripPlan p, TripStepRole role, TripJourney j, bool confirmed) {
    final city = role == TripStepRole.gettingThere
        ? p.legs.where((l) => l.index == 1).firstOrNull
        : (p.legs.isEmpty ? null : ([...p.legs]..sort((a, b) => a.index.compareTo(b.index))).last);
    final cityChanged = TripStepRules.cityChanged(role, j, city?.latitude, city?.longitude);
    if (confirmed) return cityChanged;
    return TripStepRules.startChanged(role, p.steps.endOf(role), j, cityLat: city?.latitude, cityLon: city?.longitude);
  }

  static bool _carNeedsYou(TripJourney? j, List<TripEnquiryModel> rows, List<int> ownCars) {
    if (j == null) return false;
    for (final car in j.legs) {
      if (ownCars.contains(car.legIndex)) continue;
      final mine = [for (final e in rows) if (e.context.journeyLegIndex == car.legIndex) e];
      if (mine.any((e) =>
          e.status == TripEnquiryStatuses.bookedByTraveller || e.status == TripEnquiryStatuses.confirmedByBoth)) {
        continue;
      }
      if (car.lastKnownStatus == TripTravelRules.notFreeStatus || !car.driverAvailable) continue;
      if (car.lastKnownStatus == TripTravelRules.freeStatus || mine.any((e) => e.status == TripEnquiryStatuses.fareSent)) {
        return true;
      }
      if (car.lastEnquiryId == null && mine.every((e) => e.status != TripEnquiryStatuses.asked)) return true;
    }
    return false;
  }

  static TripEasyRowInfo _between(TripPlan p, List<TripEnquiryModel> all, List<TripJourney> journeys, TripEasyRowKey k) {
    final leg = p.legAt(k.legIndex ?? 0);
    final mark = leg?.travelMark;
    if (mark != null) return _marked(p, k, mark, const []);
    final a = leg?.arrival;
    if (a == null) return _travel(p, k, TripTravelState.notPlanned, null, const []);
    final j = _journey(journeys, a.journeyId);
    final rows = TripTravelRules.liveRowsOf(a.journeyId, all);
    if (j == null) return _travel(p, k, TripTravelState.asked, a.journeyId, rows);
    final start = p.legStart(k.legIndex ?? 0);
    final s = TripTravelRules.stateOf(
      role: TripJourneyRole.segment,
      arrival: a,
      journey: j,
      journeyRows: all,
      travelDate: start > 0 ? p.settings.dateOf(start) : null,
    );
    return _travel(p, k, s, a.journeyId, rows, _carNeedsYou(j, rows, a.ownCars), j);
  }

  static ({int done, int total, int percent}) progress(List<TripEasyRowInfo> rows) {
    final counted = [for (final r in rows) if (r.state != TripRowState.skipped) r];
    final done = counted.where((r) => r.isDone).length;
    return (done: done, total: counted.length, percent: counted.isEmpty ? 100 : done * 100 ~/ counted.length);
  }

  static ({int done, int total, int percent}) progressOf(List<TripEasyRowInfo> rows, TripProgress? server) {
    if (server != null && server.total > 0) return (done: server.done, total: server.total, percent: server.percent);
    return progress(rows);
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
