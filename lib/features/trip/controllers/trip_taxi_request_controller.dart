import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../services/notification_hub_service.dart';
import '../data/taxi_request_repository.dart';
import '../data/trip_enquiry_repository.dart';
import '../models/taxi_request_models.dart';
import '../trip_strings_steps_k3.dart';
import '../utils/taxi_request_form.dart';
import '../utils/taxi_result.dart';
import 'trip_plan_controller.dart';

enum TaxiAction { places, send, cancelLegacy, load, loadTrip, cancel, changePickup, askMore, select, notAgreed, endTrip, rate }

class TaxiLapse {
  const TaxiLapse({required this.requestId, required this.unavailable});

  final String requestId;
  final bool unavailable;
}

class TripTaxiRequestController extends GetxController with WidgetsBindingObserver {
  TripTaxiRequestController({
    this._repo = const TaxiRequestRepository(),
    this._enquiries = const TripEnquiryRepository(),
    TaxiRequestRealtime? realtime,
    Future<bool> Function(String tripId)? refreshPlan,
    void Function()? onLegacyClosed,
    String Function()? newClientId,
    Future<bool> Function()? flushPlan,
    DateTime Function()? now,
  })  : _realtimeOverride = realtime,
        _flushPlan = flushPlan ?? _flushPlanController,
        _refreshPlan = refreshPlan ?? _refreshPlanController,
        _onLegacyClosed = onLegacyClosed ?? _refreshPlanEnquiries,
        _newClientId = newClientId ?? (() => const Uuid().v4()),
        _now = now ?? DateTime.now;

  static TripTaxiRequestController get to => Get.isRegistered<TripTaxiRequestController>()
      ? Get.find<TripTaxiRequestController>()
      : Get.put(TripTaxiRequestController());

  static void onTaxiPushIfRegistered() {
    if (Get.isRegistered<TripTaxiRequestController>()) Get.find<TripTaxiRequestController>().onTaxiPush();
  }

  static Future<bool> _refreshPlanController(String tripId) => Get.isRegistered<TripPlanController>()
      ? Get.find<TripPlanController>().refreshTaxiState(tripId: tripId)
      : Future.value(false);

  static Future<bool> _flushPlanController() =>
      Get.isRegistered<TripPlanController>() ? Get.find<TripPlanController>().flushPendingSave() : Future.value(true);

  static void _refreshPlanEnquiries() {
    if (Get.isRegistered<TripPlanController>()) unawaited(Get.find<TripPlanController>().refreshEnquiries());
  }

  final TaxiRequestRepository _repo;
  final TripEnquiryRepository _enquiries;
  final TaxiRequestRealtime? _realtimeOverride;
  final Future<bool> Function(String tripId) _refreshPlan;
  final void Function() _onLegacyClosed;
  final String Function() _newClientId;
  final Future<bool> Function() _flushPlan;
  final DateTime Function() _now;

  final places = Rxn<TaxiPickupPlaces>();
  final form = Rxn<TaxiRequestForm>();
  final paused = false.obs;
  final legacyRows = <TaxiLegacyRow>[].obs;
  final request = Rxn<TaxiRequest>();
  final busy = <TaxiAction>{}.obs;
  final failed = <TaxiAction>{}.obs;
  final lapse = Rxn<TaxiLapse>();

  String? _tripId;
  List<int> _planDays = const [];
  Set<int> _pastDays = const {};
  List<TaxiDayStat> _dayStats = const [];
  String? _clientRequestId;
  String? _attachedId;
  String? _subscribedId;
  bool _observing = false;
  DateTime? _backoffUntil;
  Timer? _backoffTimer;
  Future<void>? _getting;
  bool _getAgain = false;
  final Map<TaxiAction, Future<Object>> _inFlight = {};

  TaxiRequestRealtime? get _realtime =>
      _realtimeOverride ?? (Get.isRegistered<NotificationHubService>() ? Get.find<NotificationHubService>() : null);

  bool isBusy(TaxiAction a) => busy.contains(a);

  bool hasFailed(TaxiAction a) => failed.contains(a);

  bool get isAttached => _attachedId != null;

  bool get backingOff => _backoffUntil != null && _now().isBefore(_backoffUntil!);

  TaxiResult<T> _waiting<T>() => TaxiRefused<T>(
        type: null,
        statusCode: 429,
        retryAfterSeconds: _backoffUntil == null ? 1 : _backoffUntil!.difference(_now()).inSeconds.clamp(1, 120).toInt(),
      );

  void _noteRateLimit(TaxiResult<Object?> r) {
    if (r is! TaxiRefused || !r.rateLimited) return;
    final wait = Duration(seconds: r.retryAfterSeconds ?? 1);
    final until = _now().add(wait);
    if (_backoffUntil == null || until.isAfter(_backoffUntil!)) _backoffUntil = until;
    _armBackoffTimer();
  }

  void _armBackoffTimer() {
    final until = _backoffUntil;
    if (until == null) return;
    _backoffTimer?.cancel();
    _backoffTimer = Timer(until.difference(_now()), () {
      _backoffTimer = null;
      if (_attachedId != null) unawaited(refreshRequest());
    });
  }

  @visibleForTesting
  String? get pendingClientRequestId => _clientRequestId;

  Future<TaxiResult<T>> _run<T>(TaxiAction a, Future<TaxiResult<T>> Function() body) {
    final running = _inFlight[a];
    if (running != null) return running as Future<TaxiResult<T>>;
    final future = _guarded(a, body);
    _inFlight[a] = future;
    return future.whenComplete(() => _inFlight.remove(a));
  }

  Future<TaxiResult<T>> _guarded<T>(TaxiAction a, Future<TaxiResult<T>> Function() body) async {
    busy.add(a);
    failed.remove(a);
    try {
      final r = await body();
      if (r is TaxiPaused<T>) paused.value = true;
      final quiet = r is TaxiRefused<T> && r.rateLimited && (a == TaxiAction.load || a == TaxiAction.loadTrip);
      if (r is! TaxiOk<T> && r is! TaxiAlreadyActive<T> && !quiet) failed.add(a);
      return r;
    } finally {
      busy.remove(a);
    }
  }

  Future<TaxiResult<TaxiPickupPlaces>> loadPlaces(String tripId,
          {required List<int> planDays, List<TaxiDayStat> dayStats = const [], Set<int> pastDays = const {}}) =>
      _run(TaxiAction.places, () async {
        if (_tripId != tripId) {
          places.value = null;
          form.value = null;
          legacyRows.clear();
          _clientRequestId = null;
        }
        _tripId = tripId;
        _planDays = List.unmodifiable(planDays);
        _pastDays = Set.unmodifiable(pastDays);
        _dayStats = List.unmodifiable(dayStats);
        final r = await _repo.pickupPlaces(tripId);
        if (r case TaxiOk<TaxiPickupPlaces>(:final value)) {
          places.value = value;
          paused.value = value.paused;
          form.value = _formFor(value, form.value);
        }
        return r;
      });

  TaxiRequestForm _formFor(TaxiPickupPlaces value, TaxiRequestForm? old) {
    final fresh = TaxiRequestForm.initial(places: value, planDays: _planDays, pastDays: _pastDays);
    if (old == null) return fresh;
    final days = old.days.where((d) => _planDays.contains(d) && !fresh.isPast(d)).toSet();
    return TaxiRequestForm(
      places: value,
      planDays: _planDays,
      pickupOn: old.pickupOn && !fresh.pickupPast,
      sightseeingOn: old.sightseeingOn,
      dropOn: old.dropOn && !fresh.dropPast,
      pickupCityKey: value.pickupByKey(old.pickupCityKey)?.cityKey,
      dropSame: old.dropSame,
      dropCityKey: value.dropByKey(old.dropCityKey)?.cityKey,
      days: days,
      seats: TaxiSeats.atLeast(old.seats, value.travellers),
      pastDays: fresh.pastDays,
    );
  }

  void editForm(TaxiRequestForm Function(TaxiRequestForm current) change) {
    final f = form.value;
    if (f == null) return;
    form.value = change(f);
    _clientRequestId = null;
  }

  Future<TaxiResult<TaxiRequest>> send() => _run(TaxiAction.send, _send);

  Future<TaxiResult<TaxiRequest>> _send() async {
    final f = form.value;
    final tripId = _tripId;
    if (f == null || tripId == null || !f.canSend) return TaxiFailed(message: f?.summary ?? '');
    if (!await _flushPlan()) return const TaxiFailed(message: TripStringsStepsK3.notSavedToTrip);
    final cid = _clientRequestId ??= _newClientId();
    final r = await _repo.create(tripId, f.toBody(cid, _dayStats));
    switch (r) {
      case TaxiOk<TaxiRequest>(:final value):
        _clientRequestId = null;
        paused.value = false;
        legacyRows.clear();
        apply(value);
      case TaxiAlreadyActive<TaxiRequest>(:final requestId):
        _clientRequestId = null;
        if (requestId != null) await _fetch(requestId);
      case TaxiLegacyActive<TaxiRequest>(:final rows):
        legacyRows.assignAll(rows);
      case TaxiOffline<TaxiRequest>() || TaxiFailed<TaxiRequest>():
        break;
      case TaxiRefused<TaxiRequest>(:final statusCode) when statusCode >= 500:
        break;
      default:
        _clientRequestId = null;
    }
    return r;
  }

  Future<TaxiResult<TaxiRequest>> cancelLegacyTaxi([List<TaxiLegacyRow>? rows]) =>
      _run(TaxiAction.cancelLegacy, () async {
        final list = rows ?? legacyRows.toList();
        for (final row in list) {
          final refused = await _closeLegacy(row);
          if (refused != null) return refused;
        }
        legacyRows.clear();
        if (list.isNotEmpty) _onLegacyClosed();
        return send();
      });

  Future<TaxiResult<TaxiRequest>?> _closeLegacy(TaxiLegacyRow row) async {
    try {
      if (row.booked) {
        await _enquiries.cancel(row.id);
      } else {
        await _enquiries.withdraw(row.id);
      }
      return null;
    } catch (e) {
      return TaxiResult.fromError<TaxiRequest>(e);
    }
  }

  static int _lockKey(TaxiRequest? r) => switch (r?.state) {
        RequestState.open || RequestState.collecting || RequestState.selected => 1,
        RequestState.booked || RequestState.inProgress => 2,
        _ => 0,
      };

  bool apply(TaxiRequest next) {
    final cur = request.value;
    if (cur != null && cur.id == next.id && next.version <= cur.version) return false;
    _noteLapse(cur, next);
    request.value = next;
    if (_lockKey(cur) != _lockKey(next)) unawaited(_refreshPlan(next.tripId));
    final ended = !next.state.active && next.state != RequestState.unknown;
    if (ended && _subscribedId == next.id) _unsubscribe();
    return true;
  }

  void _noteLapse(TaxiRequest? cur, TaxiRequest next) {
    if (cur == null || cur.id != next.id) {
      lapse.value = null;
      return;
    }
    final back = cur.state == RequestState.selected &&
        (next.state == RequestState.collecting || next.state == RequestState.open) &&
        !isBusy(TaxiAction.notAgreed) &&
        !isBusy(TaxiAction.cancel);
    if (back) {
      final by = cur.selectedDriver?.confirmByAt;
      final at = next.updatedAtAt;
      lapse.value = TaxiLapse(requestId: next.id, unavailable: by == null || at == null || at.isBefore(by));
    } else if (next.state != RequestState.collecting && next.state != RequestState.open) {
      lapse.value = null;
    }
  }

  Future<TaxiResult<TaxiRequest>> _fetch(String requestId) async {
    if (backingOff) return _waiting();
    final r = await _repo.get(requestId);
    _noteRateLimit(r);
    if (r case TaxiOk<TaxiRequest>(:final value)) apply(value);
    return r;
  }

  Future<TaxiResult<TaxiRequest>> load(String requestId) => _run(TaxiAction.load, () => _fetch(requestId));

  Future<TaxiResult<TaxiRequest?>> loadForTrip(String tripId) => _run(TaxiAction.loadTrip, () async {
        if (backingOff) return _waiting();
        final r = await _repo.forTrip(tripId);
        _noteRateLimit(r);
        if (r case TaxiOk<TaxiRequest?>(:final value?)) apply(value);
        return r;
      });

  void attach(String requestId) {
    _attachedId = requestId;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _subscribe(requestId);
    unawaited(refreshRequest());
  }

  void detach() {
    _unsubscribe();
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _attachedId = null;
    _backoffTimer?.cancel();
    _backoffTimer = null;
  }

  void _subscribe(String requestId) {
    if (_subscribedId == requestId) return;
    _unsubscribe();
    final cur = request.value;
    if (cur != null && cur.id == requestId && !cur.state.active && cur.state != RequestState.unknown) return;
    final rt = _realtime;
    if (rt == null) return;
    rt.subscribeTaxiRequest(requestId, _onSignal);
    _subscribedId = requestId;
  }

  void _unsubscribe() {
    final id = _subscribedId;
    if (id == null) return;
    _subscribedId = null;
    _realtime?.unsubscribeTaxiRequest(id);
  }

  void _onSignal(TaxiRequestSignal s) {
    if (s.requestId != _attachedId) return;
    if (s.reconnected) {
      unawaited(refreshRequest());
      return;
    }
    final cur = request.value;
    final local = cur != null && cur.id == s.requestId ? cur.version : -1;
    final v = s.version;
    if (v != null && v > local) unawaited(refreshRequest());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _attachedId != null) unawaited(refreshRequest());
  }

  void onTaxiPush() {
    if (_attachedId != null || request.value != null) unawaited(refreshRequest());
  }

  Future<void> refreshRequest() {
    final running = _getting;
    if (running != null) {
      _getAgain = true;
      return running;
    }
    final f = _getLoop().whenComplete(() => _getting = null);
    _getting = f;
    return f;
  }

  Future<void> _getLoop() async {
    do {
      _getAgain = false;
      final id = _attachedId ?? request.value?.id;
      if (id == null) return;
      if (backingOff) {
        if (_backoffTimer == null) _armBackoffTimer();
        return;
      }
      await _run(TaxiAction.load, () => _fetch(id));
    } while (_getAgain && !backingOff);
  }

  Future<TaxiResult<TaxiRequest>> _act(TaxiAction a, Future<TaxiResult<TaxiRequest>> Function(String id) call) =>
      _run(a, () async {
        final id = request.value?.id;
        if (id == null) return const TaxiNotFound<TaxiRequest>();
        if (backingOff) return _waiting();
        if (a != TaxiAction.rate && a != TaxiAction.endTrip) lapse.value = null;
        final r = await call(id);
        _noteRateLimit(r);
        switch (r) {
          case TaxiOk<TaxiRequest>(:final value):
            apply(value);
          case TaxiStateInvalid<TaxiRequest>() || TaxiNotFound<TaxiRequest>():
            unawaited(refreshRequest());
          default:
            break;
        }
        return r;
      });

  Future<TaxiResult<TaxiRequest>> cancel({ReasonChip? chip}) =>
      _act(TaxiAction.cancel, (id) => _repo.cancel(id, chip: chip));

  Future<TaxiResult<TaxiRequest>> changePickup() =>
      _act(TaxiAction.changePickup, (id) => _repo.cancel(id, reason: RequestEndReason.pickupChanged.wire));

  Future<TaxiResult<TaxiRequest>> askMore() => _act(TaxiAction.askMore, _repo.askMore);

  Future<TaxiResult<TaxiRequest>> select(String offerId) =>
      _act(TaxiAction.select, (id) => _repo.select(id, offerId));

  Future<TaxiResult<TaxiRequest>> notAgreed(String offerId) =>
      _act(TaxiAction.notAgreed, (id) => _repo.notAgreed(id, offerId));

  Future<TaxiResult<TaxiRequest>> endTrip() => _act(TaxiAction.endTrip, _repo.end);

  Future<TaxiResult<TaxiRequest>> rate(int stars) => _act(TaxiAction.rate, (id) => _repo.rate(id, stars));

  @override
  void onClose() {
    _backoffTimer?.cancel();
    detach();
    super.onClose();
  }
}
