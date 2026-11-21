import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../config/app_tabs.dart';
import '../../controllers/auth_controller.dart';
import '../owner_core/data/owner_cache.dart';
import '../owner_core/data/owner_result.dart';
import '../owner_core/data/single_flight.dart';
import 'seeker_feed_api.dart';
import 'seeker_feed_model.dart';
import 'seeker_status_rule.dart';

class SeekerFeedController extends GetxController with WidgetsBindingObserver {
  SeekerFeedController({this.api = const SeekerFeedApi(), DateTime Function()? clock, this.userIdOf}) : _clock = clock ?? DateTime.now;

  static SeekerFeedController? get maybe => Get.isRegistered<SeekerFeedController>() ? Get.find<SeekerFeedController>() : null;

  static const Duration minGap = Duration(seconds: 30);

  final SeekerFeedApi api;
  final DateTime Function() _clock;
  final String? Function()? userIdOf;

  final feed = Rxn<SeekerFeed>();
  final loading = false.obs;
  final seenKey = RxnString();

  final _flight = SingleFlight<void>();
  final _latest = LatestOnly();
  final _workers = <Worker>[];
  DateTime? _lastLoad;
  String? _loadedFor;

  String? get _userId {
    final f = userIdOf;
    if (f != null) return f();
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>().user.value?.id;
  }

  bool get showSkeleton => feed.value == null && loading.value;

  SeekerStatus? get visibleStatus {
    final s = feed.value?.status;
    return SeekerStatusRule.visible(s, seenKey.value) ? s : null;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _paintCopy();
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      _workers.add(ever<int>(auth.tabIndex, (i) {
        if (i == AppTabs.home) refreshIfStale();
      }));
      _workers.add(ever(auth.user, (_) => _onUser()));
    }
    reload();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final w in _workers) {
      w.dispose();
    }
    _latest.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !isClosed) refreshIfStale();
  }

  void attachTripsList(RxList<Object?> list) {
    _workers.add(ever(list, (_) => refreshIfStale(force: true)));
  }

  void _onUser() {
    final id = _userId;
    if (id == _loadedFor) return;
    feed.value = null;
    _paintCopy();
    reload();
  }

  void _paintCopy() {
    final id = _userId;
    _loadedFor = id;
    seenKey.value = OwnerCache.statusSeen(id);
    final saved = OwnerCache.read(id, OwnerCacheKeys.seekerFeed);
    if (saved != null) feed.value = SeekerFeed.fromJson(saved);
  }

  Future<void> refreshIfStale({bool force = false}) {
    final last = _lastLoad;
    if (!force && last != null && _clock().difference(last) < minGap) return Future.value();
    return reload();
  }

  Future<void> reload() => _flight.run(_load);

  Future<void> _load() async {
    final id = _userId;
    final ticket = _latest.next();
    loading.value = true;
    try {
      final res = await api.load();
      if (isClosed || !_latest.isLatest(ticket) || id != _userId) return;
      _lastLoad = _clock();
      if (res case OwnerOk<SeekerFeed>(:final value)) {
        feed.value = value;
        OwnerCache.write(id, OwnerCacheKeys.seekerFeed, value.toJson());
      } else if (feed.value == null) {
        feed.value = SeekerFeed.empty;
      }
    } catch (_) {
      if (!isClosed && _latest.isLatest(ticket) && feed.value == null) feed.value = SeekerFeed.empty;
    } finally {
      if (!isClosed && _latest.isLatest(ticket)) loading.value = false;
    }
  }

  void markStatusOpened() {
    final s = feed.value?.status;
    if (s == null || s.key.isEmpty) return;
    seenKey.value = s.key;
    OwnerCache.setStatusSeen(_userId, s.key);
  }

  void reset() {
    _latest.cancel();
    feed.value = null;
    seenKey.value = null;
    loading.value = false;
    _lastLoad = null;
  }
}
