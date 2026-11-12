import 'dart:async';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../../config/app_tabs.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../models/place_result_model.dart';
import '../../../nearby/controllers/nearby_centre_controller.dart';
import '../../../nearby/models/nearby_models.dart';
import '../../taxi_option_sets.dart';
import 'taxi_feed_repository.dart';

class TaxiListControllerV2 extends GetxController {
  static const tag = 'taxi-v2';
  static const _staleAfter = Duration(minutes: 2);

  final bool root;
  final TaxiFeedRepository _repo;
  final LatLng Function()? _centreOf;
  final RxInt? _centreVersion;
  final RxInt? _tabIndex;

  TaxiListControllerV2({
    this.root = true,
    TaxiFeedRepository repo = const TaxiFeedRepository(),
    LatLng Function()? centre,
    RxInt? centreVersion,
    RxInt? tabIndex,
  })  : _repo = repo,
        _centreOf = centre,
        _centreVersion = centreVersion,
        _tabIndex = tabIndex;

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
  final route = Rxn<TaxiRouteFeed>();
  final expanded = <String>{}.obs;
  final loadingTiers = <String>{}.obs;
  final refreshTrigger = 0.obs;

  final _workers = <Worker>[];
  String? _nextToken;
  int _gen = 0;
  bool _coalescing = false;
  DateTime? _loadedAt;

  bool get isRoute => to.value != null;
  bool get _tabActive => !root || (_tabIndex ?? Get.find<AuthController>().tabIndex).value == AppTabs.taxi;

  LatLng get centre => _centreOf != null ? _centreOf() : NearbyCentreController.to.centre;

  LatLng get origin => from.value?.latLng ?? centre;

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
    if (_tabActive) _load(silent: false);
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
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

  void setTo(PlaceResult p) {
    to.value = p;
    _reloadFresh();
  }

  void clearTo() {
    if (to.value == null) return;
    to.value = null;
    _reloadFresh();
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
    if (to.value == null && from.value == null) return;
    to.value = null;
    from.value = null;
    _gen++;
    _loadedAt = null;
  }

  void refreshIfStale() {
    if (!_tabActive) return;
    final at = _loadedAt;
    if (at != null && DateTime.now().difference(at) <= _staleAfter) return;
    _load(silent: items.isNotEmpty || route.value != null);
  }

  Future<void> pullRefresh() => _load(silent: true);

  void retry() => _load(silent: false);

  void _invalidate() {
    _loadedAt = null;
    if (_tabActive) _load(silent: true);
  }

  void _reloadFresh() {
    _gen++;
    _loadedAt = null;
    items.clear();
    featured.clear();
    route.value = null;
    expanded.clear();
    loadingTiers.clear();
    hasMore.value = false;
    _nextToken = null;
    loadFailed.value = false;
    loadMoreFailed.value = false;
    isLoadingMore.value = false;
    isLoading.value = true;
    if (_tabActive) _load(silent: false);
  }

  Future<void> _load({required bool silent}) async {
    final myGen = ++_gen;
    loadFailed.value = false;
    loadMoreFailed.value = false;
    isLoadingMore.value = false;
    if (!silent) isLoading.value = true;
    final o = origin;
    final t = to.value;
    try {
      if (t != null) {
        final res = await _repo.route(
          fromLat: o.latitude,
          fromLng: o.longitude,
          toLat: t.latLng.latitude,
          toLng: t.latLng.longitude,
        );
        if (myGen != _gen) return;
        route.value = res;
        header.value = res.header;
        items.clear();
        featured.clear();
        hasMore.value = false;
        expanded.clear();
      } else {
        final page = await _repo.local(lat: o.latitude, lng: o.longitude);
        if (myGen != _gen) return;
        route.value = null;
        header.value = page.header;
        featured.assignAll(page.featured);
        final fid = page.featured.map((e) => e.id).toSet();
        items.assignAll(page.items.where((e) => !fid.contains(e.id)));
        hasMore.value = page.hasMore;
        _nextToken = page.nextToken;
      }
      _loadedAt = DateTime.now();
    } catch (_) {
      if (myGen != _gen) return;
      if (items.isEmpty && route.value == null) loadFailed.value = true;
    } finally {
      if (myGen == _gen) isLoading.value = false;
    }
  }

  void loadNextPage() {
    if (isRoute || !hasMore.value || isLoading.value || isLoadingMore.value || loadMoreFailed.value) return;
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
      final page = await _repo.local(lat: o.latitude, lng: o.longitude, pageToken: token);
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
    final t = to.value;
    if (!tier.hasMore || token == null || t == null) return;
    final myGen = _gen;
    final o = origin;
    loadingTiers.add(key);
    try {
      final next = await _repo.routeTier(
        tier: key,
        pageToken: token,
        fromLat: o.latitude,
        fromLng: o.longitude,
        toLat: t.latLng.latitude,
        toLng: t.latLng.longitude,
      );
      if (myGen != _gen || next == null) return;
      final cur = route.value;
      final curTier = cur?.tier(key);
      if (cur == null || curTier == null) return;
      final seen = {for (final x in cur.tiers) ...x.items.map((e) => e.id)};
      final merged = [...curTier.items, ...next.items.where((e) => seen.add(e.id))];
      final updated = curTier.copyWith(items: merged, hasMore: next.hasMore, nextToken: next.nextToken);
      route.value = TaxiRouteFeed(
        header: cur.header,
        tiers: [for (final x in cur.tiers) x.key == key ? updated : x],
      );
    } catch (_) {
      // The Show more row stays, so the user can tap again.
    } finally {
      loadingTiers.remove(key);
    }
  }
}
