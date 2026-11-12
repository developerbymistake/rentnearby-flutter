import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../models/nearby_models.dart';
import 'nearby_centre_controller.dart';

abstract class NearbyFeedController<T> extends GetxController {
  static const staleAfter = Duration(minutes: 2);
  static const thinBelow = 3;

  final items = <T>[].obs;
  final featured = <T>[].obs;
  final header = Rxn<NearbyHeader>();
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = false.obs;
  final loadFailed = false.obs;
  final loadMoreFailed = false.obs;

  final _workers = <Worker>[];
  String? _token;
  int _gen = 0;
  DateTime? _loadedAt;
  bool _dirty = true;
  bool _queued = false;

  Future<NearbyPage<T>> fetchPage(String? token);
  String idOf(T item);

  // null = not a tab, always active.
  int? get tabIndex => null;
  RxInt get centreVersion => NearbyCentreController.to.centreVersion;
  RxInt? get tabRx => Get.isRegistered<AuthController>() ? Get.find<AuthController>().tabIndex : null;
  DateTime now() => DateTime.now();

  bool get tabActive {
    final t = tabIndex;
    if (t == null) return true;
    return tabRx?.value == t;
  }

  bool get isEmpty => !isLoading.value && !loadFailed.value && items.isEmpty && featured.isEmpty;
  bool get isThin =>
      !isLoading.value && !loadFailed.value && !hasMore.value && items.length + featured.length > 0 && items.length + featured.length < thinBelow;

  @override
  void onInit() {
    super.onInit();
    _workers.add(ever(centreVersion, (_) => _queueReload()));
    final rx = tabRx;
    if (rx != null && tabIndex != null) {
      _workers.add(ever(rx, (i) {
        if (i == tabIndex) refreshIfNeeded();
      }));
    }
    if (tabActive) refreshIfNeeded();
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void markDirty() {
    _dirty = true;
    if (tabActive) refreshIfNeeded();
  }

  void _queueReload() {
    _dirty = true;
    if (_queued) return;
    _queued = true;
    Future.microtask(() {
      _queued = false;
      if (isClosed) return;
      if (tabActive) refreshIfNeeded();
    });
  }

  Future<void> refreshIfNeeded() async {
    final at = _loadedAt;
    final stale = at == null || now().difference(at) > staleAfter;
    if (_dirty || stale || loadFailed.value) await reload();
  }

  Future<void> reload({bool silent = false}) async {
    final gen = ++_gen;
    _dirty = false;
    if (!silent || items.isEmpty) isLoading.value = true;
    loadFailed.value = false;
    loadMoreFailed.value = false;
    isLoadingMore.value = false;
    try {
      final page = await fetchPage(null);
      if (gen != _gen || isClosed) return;
      final ids = <String>{};
      final f = <T>[];
      for (final x in page.featured) {
        if (ids.add(idOf(x))) f.add(x);
      }
      final list = <T>[];
      for (final x in page.items) {
        if (ids.add(idOf(x))) list.add(x);
      }
      featured.assignAll(f);
      items.assignAll(list);
      header.value = page.header;
      hasMore.value = page.hasMore && page.nextToken != null;
      _token = page.nextToken;
      _loadedAt = now();
    } catch (_) {
      if (gen != _gen || isClosed) return;
      loadFailed.value = true;
    } finally {
      if (gen == _gen) isLoading.value = false;
    }
  }

  Future<void> loadNextPage() async {
    if (isLoading.value || isLoadingMore.value || !hasMore.value || _token == null) return;
    final gen = _gen;
    isLoadingMore.value = true;
    loadMoreFailed.value = false;
    try {
      final page = await fetchPage(_token);
      if (gen != _gen || isClosed) return;
      final ids = <String>{...featured.map(idOf), ...items.map(idOf)};
      final add = <T>[];
      for (final x in page.items) {
        if (ids.add(idOf(x))) add.add(x);
      }
      items.addAll(add);
      hasMore.value = page.hasMore && page.nextToken != null;
      _token = page.nextToken;
    } catch (_) {
      if (gen != _gen || isClosed) return;
      loadMoreFailed.value = true;
    } finally {
      if (gen == _gen) isLoadingMore.value = false;
    }
  }

  void onScrollMetrics(ScrollMetrics m) {
    if (m.maxScrollExtent <= 0) return;
    if (m.pixels >= m.maxScrollExtent * 0.7) loadNextPage();
  }

  Future<void> retry() => reload();
  Future<void> pullRefresh() => reload(silent: true);
}
