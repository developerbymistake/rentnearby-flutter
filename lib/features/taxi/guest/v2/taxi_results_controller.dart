import 'dart:async';

import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../../models/place_result_model.dart';
import '../../../owner_core/data/single_flight.dart';
import '../../ways/taxi_ways_availability.dart';
import '../../ways/taxi_ways_repository.dart';
import 'taxi_feed_repository.dart';
import 'taxi_journey_date.dart';
import 'taxi_popular_routes.dart';
import 'taxi_search_strings.dart';
import 'taxi_seeker_cache.dart';

class TaxiResultsArgs {
  final PlaceResult from;
  final bool fromNearYou;
  final PlaceResult to;
  final DateTime date;
  final TaxiCityPair? cities;

  const TaxiResultsArgs({required this.from, required this.fromNearYou, required this.to, required this.date, this.cities});

  Map<String, dynamic> toMap() => {
        'fromName': from.name,
        'fromLat': from.latLng.latitude,
        'fromLng': from.latLng.longitude,
        'fromNearYou': fromNearYou,
        'toName': to.name,
        'toLat': to.latLng.latitude,
        'toLng': to.latLng.longitude,
        'date': TaxiJourneyDate.apiText(date),
        ...?cities?.toParams(),
      };

  static double? _coord(Object? v, double max) => v is num && v.isFinite && v.abs() <= max ? v.toDouble() : null;

  static TaxiResultsArgs? fromMap(Object? raw, DateTime today) {
    if (raw is! Map) return null;
    final fLat = _coord(raw['fromLat'], 90);
    final fLng = _coord(raw['fromLng'], 180);
    final tLat = _coord(raw['toLat'], 90);
    final tLng = _coord(raw['toLng'], 180);
    if (fLat == null || fLng == null || tLat == null || tLng == null) return null;
    final nearYou = raw['fromNearYou'] == true;
    final fName = raw['fromName'];
    final tName = raw['toName'];
    final day = TaxiJourneyDate.parse(raw['date']);
    return TaxiResultsArgs(
      from: PlaceResult(name: fName is String && fName.trim().isNotEmpty ? fName.trim() : TaxiSearchStrings.nearYou, subtitle: '', latLng: LatLng(fLat, fLng)),
      fromNearYou: nearYou,
      to: PlaceResult(name: tName is String ? tName.trim() : '', subtitle: '', latLng: LatLng(tLat, tLng)),
      date: day == null ? today : TaxiJourneyDate.clamp(day, today),
      cities: nearYou ? null : TaxiCityPair.tryParse(raw['fromCityKey'], raw['toCityKey']),
    );
  }
}

class TaxiResultsController extends GetxController {
  static const tag = 'taxi-results';
  static const debounce = Duration(milliseconds: 250);

  final TaxiResultsArgs args;
  final TaxiFeedRepository _repo;
  final DateTime Function() _clock;
  final Duration _debounce;
  final TaxiWaysAvailabilityCheck waysCheck;

  TaxiResultsController({
    required this.args,
    TaxiFeedRepository repo = const TaxiFeedRepository(),
    TaxiWaysRepository waysRepo = const TaxiWaysRepository(),
    DateTime Function()? clock,
    Duration debounceTime = debounce,
  })  : _repo = repo,
        _clock = clock ?? DateTime.now,
        _debounce = debounceTime,
        waysCheck = TaxiWaysAvailabilityCheck(repo: waysRepo),
        currentDay = Rx<DateTime>(TaxiJourneyDate.today((clock ?? DateTime.now)()));

  final Rx<DateTime> currentDay;
  late final date = Rx<DateTime>(TaxiJourneyDate.clamp(args.date, today));
  final sort = TaxiRouteSort.nearest.obs;
  final route = Rxn<TaxiRouteFeed>();
  final isLoading = true.obs;
  final loadFailed = false.obs;
  final expanded = <String>{}.obs;
  final loadingTiers = <String>{}.obs;

  final _latest = LatestOnly();
  Timer? _timer;
  int _epoch = 0;

  DateTime get today => TaxiJourneyDate.today(_clock());

  Duration get untilNextDay => TaxiJourneyDate.untilNextDay(_clock());

  PlaceResult get from => args.from;
  PlaceResult get to => args.to;
  bool get fromNearYou => args.fromNearYou;
  TaxiCityPair? get cities => args.cities;

  bool get canPrev => TaxiJourneyDate.canPrev(date.value, currentDay.value);
  bool get canNext => TaxiJourneyDate.canNext(date.value, currentDay.value);
  bool get isToday => TaxiJourneyDate.same(date.value, currentDay.value);

  int? get freeCount {
    final n = route.value?.freeCount;
    return n != null && n > 0 ? n : null;
  }

  bool get isEmpty {
    final r = route.value;
    return r != null && r.isEmpty;
  }

  String get _requestKey => '${TaxiJourneyDate.apiText(date.value)}|${sort.value}';

  String _cacheKey(String day, String s) => TaxiSeekerCache.routeKey(
        fromLat: from.latLng.latitude,
        fromLng: from.latLng.longitude,
        toLat: to.latLng.latitude,
        toLng: to.latLng.longitude,
        date: day,
        sort: s,
        cities: cities,
      );

  @override
  void onInit() {
    super.onInit();
    unawaited(waysCheck.check(from: from, to: to, fromMyLocation: fromNearYou));
    _show(immediate: true);
  }

  @override
  void onClose() {
    _timer?.cancel();
    _latest.cancel();
    waysCheck.reset();
    super.onClose();
  }

  void setDate(DateTime d) {
    final next = TaxiJourneyDate.clamp(d, today);
    if (TaxiJourneyDate.same(next, date.value)) return;
    date.value = next;
    _show();
  }

  void prevDay() {
    if (canPrev) setDate(TaxiJourneyDate.addDays(date.value, -1));
  }

  void nextDay() {
    if (canNext) setDate(TaxiJourneyDate.addDays(date.value, 1));
  }

  void setSort(String s) {
    if (!TaxiRouteSort.all.contains(s) || s == sort.value) return;
    sort.value = s;
    _show();
  }

  // Called at IST midnight and on app resume by the screen.
  void checkDay() {
    final t = today;
    if (TaxiJourneyDate.same(currentDay.value, t)) return;
    currentDay.value = t;
    if (date.value.isBefore(t)) setDate(t);
  }

  void retry() {
    _timer?.cancel();
    unawaited(_load());
  }

  Future<void> pullRefresh() {
    checkDay();
    _timer?.cancel();
    return _load();
  }

  void _show({bool immediate = false}) {
    _epoch++;
    _timer?.cancel();
    _latest.cancel();
    expanded.clear();
    loadingTiers.clear();
    loadFailed.value = false;
    final hit = TaxiSeekerCache.route(_cacheKey(TaxiJourneyDate.apiText(date.value), sort.value), _clock());
    if (hit != null) {
      route.value = hit.feed;
      isLoading.value = false;
      if (hit.fresh) return;
    } else {
      route.value = null;
      isLoading.value = true;
    }
    if (immediate) {
      unawaited(_load());
    } else {
      _timer = Timer(_debounce, () => unawaited(_load()));
    }
  }

  // A day the server rejects is retried once without a date, for this request only.
  Future<({TaxiRouteFeed feed, bool dated})> _fetch(String day, String s) async {
    final o = from.latLng;
    final t = to.latLng;
    Future<TaxiRouteFeed> call(String? d) => _repo.route(
          fromLat: o.latitude,
          fromLng: o.longitude,
          toLat: t.latitude,
          toLng: t.longitude,
          date: d,
          sort: s,
          cities: cities,
        );
    try {
      return (feed: await call(day), dated: true);
    } on TaxiInvalidDateError {
      return (feed: await call(null), dated: false);
    }
  }

  Future<void> _load() async {
    final ticket = _latest.next();
    _epoch++;
    loadingTiers.clear();
    final key = _requestKey;
    final requested = date.value;
    final day = TaxiJourneyDate.apiText(requested);
    final s = sort.value;
    loadFailed.value = false;
    if (route.value == null) isLoading.value = true;
    try {
      final res = await _fetch(day, s);
      if (isClosed || !_latest.isLatest(ticket) || key != _requestKey) return;
      final feed = res.feed;
      // Without a date the server answers for IST today.
      final answered = TaxiJourneyDate.parse(feed.date) ?? (res.dated ? requested : today);
      final shown = TaxiJourneyDate.clamp(answered, today);
      if (TaxiJourneyDate.same(answered, shown)) {
        TaxiSeekerCache.putRoute(_cacheKey(TaxiJourneyDate.apiText(shown), s), feed, _clock());
      }
      route.value = feed;
      expanded.clear();
      if (!TaxiJourneyDate.same(shown, date.value)) date.value = shown;
    } catch (_) {
      if (isClosed || !_latest.isLatest(ticket)) return;
      if (route.value == null) loadFailed.value = true;
    } finally {
      if (!isClosed && _latest.isLatest(ticket)) isLoading.value = false;
    }
  }

  bool isExpanded(String key) => expanded.contains(key);

  // Show more on a collapsed tier opens it; on an open tier it loads the next page.
  Future<void> showMoreOf(String key) async {
    final r = route.value;
    final tier = r?.tier(key);
    if (r == null || tier == null || loadingTiers.contains(key)) return;
    if (tier.collapsed && !expanded.contains(key)) {
      expanded.add(key);
      return;
    }
    final token = tier.nextToken;
    if (!tier.hasMore || token == null) return;
    final epoch = _epoch;
    final o = from.latLng;
    final t = to.latLng;
    final day = TaxiJourneyDate.apiText(date.value);
    final s = sort.value;
    Future<TaxiTier?> call(String? d) => _repo.routeTier(
          tier: key,
          pageToken: token,
          fromLat: o.latitude,
          fromLng: o.longitude,
          toLat: t.latitude,
          toLng: t.longitude,
          date: d,
          sort: s,
          cities: cities,
        );
    loadingTiers.add(key);
    try {
      TaxiTier? next;
      try {
        next = await call(day);
      } on TaxiInvalidDateError {
        next = await call(null);
      }
      if (isClosed || epoch != _epoch || next == null) return;
      final cur = route.value;
      final curTier = cur?.tier(key);
      if (cur == null || curTier == null) return;
      final seen = {for (final x in cur.tiers) ...x.items.map((e) => e.id)};
      final merged = [...curTier.items, ...next.items.where((e) => seen.add(e.id))];
      final updated = curTier.copyWith(items: merged, hasMore: next.hasMore, nextToken: next.nextToken);
      route.value = cur.withTiers([for (final x in cur.tiers) x.key == key ? updated : x]);
    } catch (_) {
      // The Show more row stays, so the user can tap again.
    } finally {
      if (!isClosed && epoch == _epoch) loadingTiers.remove(key);
    }
  }
}
