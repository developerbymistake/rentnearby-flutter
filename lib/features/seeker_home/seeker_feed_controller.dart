import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../config/app_tabs.dart';
import '../../controllers/auth_controller.dart';
import '../owner_core/data/owner_cache.dart';
import '../owner_core/data/owner_result.dart';
import '../owner_core/data/single_flight.dart';
import '../trip/models/trip_model.dart';
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
  // The last load failed and nothing was shown yet: Home shows the neutral card with Retry.
  final failed = false.obs;
  final seenKey = RxnString();

  final _flight = SingleFlight<void>();
  final _latest = LatestOnly();
  final _workers = <Worker>[];
  DateTime? _lastLoad;
  String? _loadedFor;
  String? _tripsSig;
  // An equal answer is not assigned again, so Home does not rebuild on every refresh (FX-29).
  String? _shownJson;
  bool _firstDone = false;

  static const Duration tripsDebounce = Duration(milliseconds: 300);

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

  static String tripsSignature(Iterable<TripSummaryModel> trips) => [
        for (final t in trips) '${t.id}|${t.startDate?.toIso8601String()}|${t.endDate?.toIso8601String()}|${t.completedAt != null}',
      ].join(',');

  // Only a real change of the trips list (dates, completion, add or remove) refreshes the feed (FX-12).
  void attachTripsList(RxList<TripSummaryModel> list, {Rxn<DateTime>? offlineCopyAt}) {
    _tripsSig = tripsSignature(list);
    _workers.add(debounce<List<TripSummaryModel>>(list, (items) {
      final sig = tripsSignature(items);
      if (sig == _tripsSig) return;
      if (!_firstDone || offlineCopyAt?.value != null) return;
      _tripsSig = sig;
      refreshIfStale(force: true);
    }, time: tripsDebounce));
  }

  void _onUser() {
    final id = _userId;
    if (id == _loadedFor) return;
    feed.value = null;
    _paintCopy();
    _latest.cancel();
    if (id != null) _load();
  }

  void _paintCopy() {
    final id = _userId;
    _loadedFor = id;
    seenKey.value = OwnerCache.statusSeen(id);
    final saved = OwnerCache.read(id, OwnerCacheKeys.seekerFeed);
    _shownJson = saved == null ? null : jsonEncode(saved);
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
      if (res case OwnerOk<SeekerFeed>(:final value)) {
        _lastLoad = _clock();
        failed.value = false;
        final json = value.toJson();
        final encoded = jsonEncode(json);
        if (encoded != _shownJson || feed.value == null) {
          _shownJson = encoded;
          feed.value = value;
          OwnerCache.write(id, OwnerCacheKeys.seekerFeed, json);
        }
      } else {
        failed.value = true;
      }
    } catch (_) {
      if (!isClosed && _latest.isLatest(ticket)) failed.value = true;
    } finally {
      if (!isClosed && _latest.isLatest(ticket)) {
        loading.value = false;
        _firstDone = true;
      }
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
    _shownJson = null;
    seenKey.value = null;
    loading.value = false;
    failed.value = false;
    _lastLoad = null;
    _firstDone = false;
  }
}
