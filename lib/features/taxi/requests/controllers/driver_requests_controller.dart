import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../trip/utils/taxi_result.dart';
import '../data/driver_request_repository.dart';
import '../models/driver_request_models.dart';
import '../utils/taxi_countdown.dart';

enum DriverRequestAction { list, more, detail, accept, decline, confirm, withdraw }

class DriverRequestsController extends GetxController with WidgetsBindingObserver {
  DriverRequestsController({this._repo = const DriverRequestRepository(), DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static DriverRequestsController get to => Get.isRegistered<DriverRequestsController>()
      ? Get.find<DriverRequestsController>()
      : Get.put(DriverRequestsController());

  static void onPushIfRegistered() {
    if (Get.isRegistered<DriverRequestsController>()) Get.find<DriverRequestsController>().onPush();
  }

  final DriverRequestRepository _repo;
  final DateTime Function() _now;

  final items = <DriverOffer>[].obs;
  final details = <String, DriverOffer>{}.obs;
  final conflicts = <String, DriverDatesConflict>{}.obs;
  final counts = Rxn<DriverOfferCounts>();
  final clockOffset = Duration.zero.obs;
  final nextCursor = Rxn<String>();
  final loaded = false.obs;
  final paused = false.obs;
  final busy = <String>{}.obs;
  final failed = <String>{}.obs;

  final Map<String, Future<Object>> _inFlight = {};
  Future<void>? _refreshing;
  bool _refreshAgain = false;
  bool _refreshQueued = false;
  bool _observing = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  static String _key(DriverRequestAction a, [String? offerId]) => offerId == null ? a.name : '${a.name}:$offerId';

  bool isBusy(DriverRequestAction a, [String? offerId]) => busy.contains(_key(a, offerId));

  bool hasFailed(DriverRequestAction a, [String? offerId]) => failed.contains(_key(a, offerId));

  int get badge => counts.value?.newCount ?? 0;

  bool get hasMore => nextCursor.value != null;

  List<DriverOffer> inBucket(OfferBucket b) => [for (final o in items) if (o.bucket == b) o];

  DriverOffer? offer(String offerId) => details[offerId] ?? items.firstWhereOrNull((o) => o.offerId == offerId);

  DriverDatesConflict? conflictFor(String offerId) => conflicts[offerId] ?? offer(offerId)?.datesConflict;

  DateTime? deadlineOf(DriverOffer o) => switch (o.state) {
        OfferState.ringing => o.expiresAtInstant,
        OfferState.selected => o.confirmByInstant,
        _ => null,
      };

  Duration remaining(DriverOffer o) => TaxiCountdown.remaining(deadlineOf(o), offset: clockOffset.value, now: _now());

  String countdownText(DriverOffer o) => TaxiCountdown.text(remaining(o));

  Future<TaxiResult<T>> _run<T>(DriverRequestAction a, String? offerId, Future<TaxiResult<T>> Function() body) {
    final key = _key(a, offerId);
    final running = _inFlight[key];
    if (running != null) return running as Future<TaxiResult<T>>;
    final future = _guarded(key, body);
    _inFlight[key] = future;
    return future.whenComplete(() => _inFlight.remove(key));
  }

  Future<TaxiResult<T>> _guarded<T>(String key, Future<TaxiResult<T>> Function() body) async {
    busy.add(key);
    failed.remove(key);
    try {
      final r = await body();
      if (r is TaxiPaused<T>) paused.value = true;
      if (r is! TaxiOk<T>) failed.add(key);
      return r;
    } finally {
      busy.remove(key);
    }
  }

  Future<TaxiResult<DriverOfferList>> load() => _run(DriverRequestAction.list, null, () async {
        final r = await _repo.offers();
        if (r case TaxiOk<DriverOfferList>(:final value)) {
          _applyList(value, replace: true);
          paused.value = false;
        }
        return r;
      });

  Future<TaxiResult<DriverOfferList>> loadMore() {
    final cursor = nextCursor.value;
    if (cursor == null) return Future.value(const TaxiNotFound<DriverOfferList>());
    return _run(DriverRequestAction.more, null, () async {
      final r = await _repo.offers(cursor: cursor);
      if (r case TaxiOk<DriverOfferList>(:final value)) _applyList(value, replace: false);
      return r;
    });
  }

  void _applyList(DriverOfferList list, {required bool replace}) {
    clockOffset.value = list.clockOffset(_now()) ?? clockOffset.value;
    counts.value = list.counts;
    nextCursor.value = list.nextCursor;
    if (replace) {
      items.assignAll(list.items);
    } else {
      final known = {for (final o in items) o.offerId};
      items.addAll([for (final o in list.items) if (!known.contains(o.offerId)) o]);
    }
    loaded.value = true;
  }

  Future<TaxiResult<DriverOffer>> loadOffer(String offerId) => _run(DriverRequestAction.detail, offerId, () async {
        final r = await _repo.offer(offerId);
        if (r case TaxiOk<DriverOffer>(:final value)) _upsert(value);
        return r;
      });

  void _upsert(DriverOffer o) {
    final i = items.indexWhere((e) => e.offerId == o.offerId);
    if (i >= 0) items[i] = o;
    if (o.trip != null || details.containsKey(o.offerId)) details[o.offerId] = o;
    final conflict = o.datesConflict;
    if (conflict != null) {
      conflicts[o.offerId] = conflict;
    } else {
      conflicts.remove(o.offerId);
    }
  }

  void _mark(String offerId, OfferState state) {
    final i = items.indexWhere((e) => e.offerId == offerId);
    if (i >= 0) items[i] = items[i].copyWith(state: state);
    final d = details[offerId];
    if (d != null) details[offerId] = d.copyWith(state: state);
  }

  Future<TaxiResult<DriverOffer>> _act(
    DriverRequestAction a,
    String offerId,
    Future<TaxiResult<DriverOffer>> Function() call,
  ) =>
      _run(a, offerId, () async {
        final r = await call();
        switch (r) {
          case TaxiOk<DriverOffer>(:final value):
            _upsert(value);
            unawaited(reloadList());
          case TaxiOfferMissed<DriverOffer>():
            _mark(offerId, OfferState.missed);
            unawaited(reloadList());
          case TaxiDatesAlreadyBooked<DriverOffer>(:final conflict):
            if (conflict != null) conflicts[offerId] = conflict;
          case TaxiConfirmWindowPassed<DriverOffer>() || TaxiStateInvalid<DriverOffer>() || TaxiNotFound<DriverOffer>():
            unawaited(reloadList());
            unawaited(loadOffer(offerId));
          default:
            break;
        }
        return r;
      });

  Future<TaxiResult<DriverOffer>> accept(String offerId) =>
      _act(DriverRequestAction.accept, offerId, () => _repo.accept(offerId));

  Future<TaxiResult<DriverOffer>> decline(String offerId, {ReasonChip? chip}) =>
      _act(DriverRequestAction.decline, offerId, () => _repo.decline(offerId, chip: chip));

  Future<TaxiResult<DriverOffer>> confirm(String offerId) =>
      _act(DriverRequestAction.confirm, offerId, () => _repo.confirm(offerId));

  Future<TaxiResult<DriverOffer>> withdraw(String offerId, ReasonChip chip) =>
      _act(DriverRequestAction.withdraw, offerId, () => _repo.withdraw(offerId, chip));

  void onPush() => _queueReload();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _queueReload();
  }

  void _queueReload() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    scheduleMicrotask(() {
      _refreshQueued = false;
      unawaited(reloadList());
    });
  }

  Future<void> reloadList() {
    final running = _refreshing;
    if (running != null) {
      _refreshAgain = true;
      return running;
    }
    final f = _refreshLoop().whenComplete(() => _refreshing = null);
    _refreshing = f;
    return f;
  }

  Future<void> _refreshLoop() async {
    do {
      _refreshAgain = false;
      await load();
    } while (_refreshAgain);
  }

  @override
  void onClose() {
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    super.onClose();
  }
}
