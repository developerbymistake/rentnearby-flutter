import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../../config/app_tabs.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../models/place_result_model.dart';
import '../../../nearby/controllers/nearby_centre_controller.dart';
import '../../../nearby/models/nearby_models.dart';
import '../../../owner_core/data/single_flight.dart';
import '../../taxi_option_sets.dart';
import 'taxi_feed_repository.dart';
import 'taxi_journey_date.dart';
import 'taxi_popular_routes.dart';
import 'taxi_results_routes.dart';
import 'taxi_search_strings.dart';
import 'taxi_seeker_cache.dart';

class TaxiListControllerV2 extends GetxController {
  static const tag = 'taxi-v2';
  static const _staleAfter = Duration(minutes: 2);

  final bool root;
  final TaxiFeedRepository _repo;
  final LatLng Function()? _centreOf;
  final String? Function()? _pinLabelOf;
  final RxInt? _centreVersion;
  final RxInt? _tabIndex;
  final DateTime Function() _clock;
  final String? Function()? _userIdOf;
  final TaxiResultsOpener _openResults;

  TaxiListControllerV2({
    this.root = true,
    TaxiFeedRepository repo = const TaxiFeedRepository(),
    LatLng Function()? centre,
    String? Function()? pinLabel,
    RxInt? centreVersion,
    RxInt? tabIndex,
    DateTime Function()? clock,
    String? Function()? userIdOf,
    TaxiResultsOpener? openResults,
  })  : _repo = repo,
        _centreOf = centre,
        _pinLabelOf = pinLabel,
        _centreVersion = centreVersion,
        _tabIndex = tabIndex,
        _clock = clock ?? DateTime.now,
        _userIdOf = userIdOf,
        _openResults = openResults ?? TaxiResultsNav.open,
        currentDay = Rx<DateTime>(TaxiJourneyDate.today((clock ?? DateTime.now)()));

  final Rx<DateTime> currentDay;

  final items = <TaxiFeedItem>[].obs;
  final featured = <TaxiFeedItem>[].obs;
  final header = Rxn<NearbyHeader>();
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = false.obs;
  final loadFailed = false.obs;
  final loadMoreFailed = false.obs;
  final from = Rxn<PlaceResult>();
  final to = Rxn<PlaceResult>();
  late final date = Rx<DateTime>(today);
  final popular = <TaxiPopularRoute>[].obs;
  final refreshTrigger = 0.obs;

  final _workers = <Worker>[];
  final _popularFlight = SingleFlight<void>();
  String? _nextToken;
  int _gen = 0;
  bool _coalescing = false;
  bool _opening = false;
  DateTime? _loadedAt;
  String? _listDay;
  String? _pageDate;
  String? _noDateDay;
  DateTime? _popularAt;
  String? _popularDay;
  String? _popularJson;
  ({PlaceResult from, PlaceResult to, TaxiCityPair cities})? _popularPick;

  bool get _tabActive => !root || (_tabIndex ?? Get.find<AuthController>().tabIndex).value == AppTabs.taxi;

  DateTime get today => TaxiJourneyDate.today(_clock());

  bool get isToday => TaxiJourneyDate.same(date.value, currentDay.value);

  Duration get untilNextDay => TaxiJourneyDate.untilNextDay(_clock());

  String? get _userId {
    final f = _userIdOf;
    if (f != null) return f();
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>().user.value?.id;
  }

  LatLng get centre => _centreOf != null ? _centreOf() : NearbyCentreController.to.centre;

  bool get _hasPin {
    final f = _pinLabelOf;
    if (f != null) return f() != null;
    return _centreOf == null && NearbyCentreController.to.hasPin;
  }

  String? get pinLabel {
    final f = _pinLabelOf;
    if (f != null) {
      final l = f();
      return l != null && l.trim().isNotEmpty ? l : null;
    }
    if (_centreOf != null) return null;
    final c = NearbyCentreController.to;
    final l = c.pinLabel;
    return c.hasPin && l != null && l.trim().isNotEmpty ? l : null;
  }

  LatLng get origin => from.value?.latLng ?? centre;

  bool get fromMyLocation => from.value == null && !_hasPin;

  bool get fromNamed => from.value != null || pinLabel != null;

  PlaceResult get routeFrom => from.value ?? PlaceResult(name: pinLabel ?? TaxiSearchStrings.nearYou, subtitle: '', latLng: origin);

  bool get samePlace {
    final t = to.value;
    return t != null && isTooClose(t, routeFrom);
  }

  bool get canSearch => to.value != null && !samePlace;

  bool get canSwap => to.value != null && fromNamed;

  @override
  void onInit() {
    super.onInit();
    final version = _centreVersion ?? NearbyCentreController.to.centreVersion;
    _workers.add(ever(version, (_) => _centreMoved()));
    _workers.add(ever(refreshTrigger, (_) => _invalidate()));
    if (root) {
      _workers.add(ever(_tabIndex ?? Get.find<AuthController>().tabIndex, (i) {
        if (i == AppTabs.taxi) {
          refreshIfStale();
        } else {
          _resetSearch();
        }
      }));
    }
    _paintCopies();
    if (_tabActive) {
      _load(silent: items.isNotEmpty || featured.isNotEmpty);
      unawaited(loadPopular());
    }
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void _paintCopies() {
    final id = _userId;
    if (id == null) return;
    final day = TaxiJourneyDate.apiText(today);
    final pop = TaxiSeekerCache.readPopular(id);
    if (pop != null && pop.date == day) {
      popular.assignAll(pop.routes);
      _popularJson = jsonEncode([for (final r in pop.routes) r.toJson()]);
      _popularDay = day;
      _popularAt = pop.savedAt;
    }
    if (from.value != null) return;
    final local = TaxiSeekerCache.readLocal(id);
    final o = origin;
    if (local == null || local.date != day) return;
    if (local.lat != TaxiSeekerCache.round2(o.latitude) || local.lng != TaxiSeekerCache.round2(o.longitude)) return;
    final page = TaxiLocalPage.fromData(local.data);
    _apply(page, day);
    _nextToken = null;
    hasMore.value = false;
    isLoading.value = false;
  }

  bool isTooClose(PlaceResult a, PlaceResult? b) =>
      b != null &&
      TaxiOptionSets.distanceMeters(a.latLng.latitude, a.latLng.longitude, b.latLng.latitude, b.latLng.longitude) <
          TaxiOptionSets.minEndpointDistanceMeters;

  void setFrom(PlaceResult p) {
    from.value = p;
    _reloadFresh();
  }

  void useCentreAsFrom() {
    if (from.value == null) return;
    from.value = null;
    _reloadFresh();
  }

  void setTo(PlaceResult p) => to.value = p;

  void clearTo() {
    if (to.value == null) return;
    to.value = null;
  }

  void setDate(DateTime d) => date.value = TaxiJourneyDate.clamp(d, today);

  void swap() {
    final t = to.value;
    if (t == null || !canSwap) return;
    final f = routeFrom;
    from.value = t;
    to.value = f;
    _reloadFresh();
  }

  void applyPopular(TaxiPopularRoute r) {
    if (_opening) return;
    final f = r.from;
    final t = r.to;
    from.value = f;
    to.value = t;
    final c = r.cities;
    _popularPick = c == null ? null : (from: f, to: t, cities: c);
    _reloadFresh();
    unawaited(search());
  }

  // Keys are sent only while From and To are still the picked popular places.
  TaxiCityPair? get cityPair {
    final p = _popularPick;
    if (p == null) return null;
    final f = from.value;
    final t = to.value;
    if (identical(f, p.from) && identical(t, p.to)) return p.cities;
    if (identical(f, p.to) && identical(t, p.from)) return p.cities.reversed;
    return null;
  }

  Future<void> search() async {
    final t = to.value;
    if (t == null || !canSearch || _opening) return;
    _opening = true;
    try {
      final d = TaxiJourneyDate.clamp(date.value, today);
      await _openResults(from: routeFrom, fromNearYou: fromMyLocation, to: t, date: d, cities: cityPair);
    } catch (_) {
    } finally {
      _opening = false;
    }
  }

  void _centreMoved() {
    if (isClosed || from.value != null || _coalescing) return;
    _coalescing = true;
    scheduleMicrotask(() {
      _coalescing = false;
      if (!isClosed) _reloadFresh();
    });
  }

  void _resetSearch() {
    final day = today;
    if (!TaxiJourneyDate.same(currentDay.value, day)) currentDay.value = day;
    if (!TaxiJourneyDate.same(date.value, day)) date.value = day;
    _popularPick = null;
    if (to.value == null && from.value == null) return;
    to.value = null;
    from.value = null;
    _gen++;
    _loadedAt = null;
  }

  void _rollDay() {
    final t = today;
    if (!TaxiJourneyDate.same(currentDay.value, t)) currentDay.value = t;
    if (date.value.isBefore(t)) date.value = t;
  }

  // Called at IST midnight and on app resume by the screen.
  void checkDay() {
    if (TaxiJourneyDate.same(currentDay.value, today)) return;
    _rollDay();
    refreshIfStale();
  }

  void refreshIfStale() {
    if (!_tabActive) return;
    _rollDay();
    final day = TaxiJourneyDate.apiText(today);
    unawaited(loadPopular());
    if (_listDay != null && _listDay != day) {
      _reloadFresh();
      return;
    }
    final at = _loadedAt;
    if (at != null && _clock().difference(at) <= _staleAfter) return;
    _load(silent: items.isNotEmpty || featured.isNotEmpty);
  }

  Future<void> pullRefresh() {
    _rollDay();
    unawaited(loadPopular(force: true));
    return _load(silent: true);
  }

  void retry() => _load(silent: false);

  void _invalidate() {
    _loadedAt = null;
    TaxiSeekerCache.dropLocal(_userId);
    if (_tabActive) _load(silent: true);
  }

  void _reloadFresh() {
    _gen++;
    _loadedAt = null;
    items.clear();
    featured.clear();
    hasMore.value = false;
    _nextToken = null;
    loadFailed.value = false;
    loadMoreFailed.value = false;
    isLoadingMore.value = false;
    isLoading.value = true;
    if (_tabActive) _load(silent: false);
  }

  void _apply(NearbyPage<TaxiFeedItem> page, String day) {
    header.value = page.header;
    featured.assignAll(page.featured);
    final fid = page.featured.map((e) => e.id).toSet();
    items.assignAll(page.items.where((e) => !fid.contains(e.id)));
    hasMore.value = page.hasMore;
    _nextToken = page.nextToken;
    _listDay = day;
  }

  Future<NearbyPage<TaxiFeedItem>> _fetchLocal(LatLng o, String day, {String? token, String? sentDate}) async {
    if (token != null) return _repo.local(lat: o.latitude, lng: o.longitude, pageToken: token, date: sentDate);
    if (_noDateDay == day) return _repo.local(lat: o.latitude, lng: o.longitude);
    try {
      return await _repo.local(lat: o.latitude, lng: o.longitude, date: day);
    } on TaxiInvalidDateError {
      _noDateDay = day;
      return _repo.local(lat: o.latitude, lng: o.longitude);
    }
  }

  Future<void> _load({required bool silent}) async {
    final myGen = ++_gen;
    loadFailed.value = false;
    loadMoreFailed.value = false;
    isLoadingMore.value = false;
    if (!silent) isLoading.value = true;
    final o = origin;
    final picked = from.value != null;
    final day = TaxiJourneyDate.apiText(today);
    final id = _userId;
    try {
      final page = await _fetchLocal(o, day);
      if (myGen != _gen) return;
      _apply(page, day);
      _pageDate = _noDateDay == day ? null : day;
      _loadedAt = _clock();
      final raw = page is TaxiLocalPage ? page.raw : null;
      if (raw != null && !picked && id != null && id == _userId) {
        TaxiSeekerCache.writeLocal(id, date: day, lat: o.latitude, lng: o.longitude, data: raw, now: _clock());
      }
    } catch (_) {
      if (myGen != _gen) return;
      if (items.isEmpty && featured.isEmpty) loadFailed.value = true;
    } finally {
      if (myGen == _gen) isLoading.value = false;
    }
  }

  Future<void> loadPopular({bool force = false}) {
    final day = TaxiJourneyDate.apiText(today);
    final at = _popularAt;
    if (!force && _popularDay == day && at != null && _clock().difference(at) < TaxiSeekerCache.popularFresh) {
      return Future.value();
    }
    return _popularFlight.run(() => _fetchPopular(day));
  }

  Future<void> _fetchPopular(String day) async {
    final id = _userId;
    try {
      final list = await _repo.popularRoutes();
      if (isClosed || id != _userId) return;
      final now = _clock();
      _popularAt = now;
      _popularDay = day;
      final encoded = jsonEncode([for (final r in list) r.toJson()]);
      if (encoded != _popularJson) {
        _popularJson = encoded;
        popular.assignAll(list);
      }
      if (id != null) TaxiSeekerCache.writePopular(id, date: day, routes: list, now: now);
    } catch (_) {
      if (isClosed) return;
      if (_popularDay != day) {
        _popularJson = null;
        popular.clear();
      }
    }
  }

  void loadNextPage() {
    if (!hasMore.value || isLoading.value || isLoadingMore.value || loadMoreFailed.value) return;
    unawaited(_loadMore());
  }

  void retryLoadMore() {
    loadMoreFailed.value = false;
    unawaited(_loadMore());
  }

  Future<void> _loadMore() async {
    final token = _nextToken;
    if (token == null) return;
    final myGen = _gen;
    isLoadingMore.value = true;
    loadMoreFailed.value = false;
    final o = origin;
    try {
      final page = await _fetchLocal(o, _listDay ?? TaxiJourneyDate.apiText(today), token: token, sentDate: _pageDate);
      if (myGen != _gen) return;
      final seen = {...items.map((e) => e.id), ...featured.map((e) => e.id)};
      items.addAll(page.items.where((e) => seen.add(e.id)));
      hasMore.value = page.hasMore;
      _nextToken = page.nextToken;
    } catch (_) {
      if (myGen == _gen) loadMoreFailed.value = true;
    } finally {
      if (myGen == _gen) isLoadingMore.value = false;
    }
  }
}
