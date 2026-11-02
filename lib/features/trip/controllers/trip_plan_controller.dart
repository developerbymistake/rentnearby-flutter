import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../../taxi/guest/taxi_browse_repository.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../data/trip_repository.dart';
import '../models/trip_city_model.dart';
import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_plan_result_model.dart';
import '../models/trip_spot_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../utils/trip_whatsapp_text.dart';
import 'my_trips_controller.dart';
import 'trip_supply_controller.dart';

class TripPlanController extends GetxController {
  static TripPlanController get to =>
      Get.isRegistered<TripPlanController>()
          ? Get.find<TripPlanController>()
          : Get.put(TripPlanController(), permanent: true);

  final _repo = const TripRepository();

  final trip = Rxn<TripModel>();
  final plan = Rxn<TripPlan>();
  final result = Rxn<TripPlanResult>();
  final isOpening = false.obs;
  final openFailed = false.obs;
  final isPlanning = false.obs;
  final planFailed = false.obs;
  final planError = RxnString();
  final planRetryable = true.obs;
  final plannerOff = false.obs;
  final isSaving = false.obs;
  final saveFailed = false.obs;
  final lastSavedAt = Rxn<DateTime>();
  final taxiTabOff = false.obs;
  final stayTabOff = false.obs;
  final cityHasTaxis = Rxn<bool>();
  final selectedMapDay = 1.obs;
  TripCityModel? picked;
  int openPages = 0;

  String? _title;
  String? _openingId;
  Future<TripModel?>? _creating;
  Future<bool>? _saving;
  bool _dirtyDuringCreate = false;
  bool _lastPlanWasAuto = false;
  int _flow = 0;
  int _planSeq = 0;
  int _editSeq = 0;
  int _supplySeq = 0;
  DateTime? _planBlockedUntil;
  TripPlan? _rejectedPlan;
  String? _rejectedTitle;
  Timer? _saveTimer;
  Timer? _recalcTimer;
  Completer<void>? _recalcWaiter;
  Worker? _tabWorker;

  @override
  void onInit() {
    super.onInit();
    _tabWorker = ever(TabConfigController.to.version, (_) => checkSupply());
  }

  @override
  void onClose() {
    _saveTimer?.cancel();
    _recalcTimer?.cancel();
    _recalcWaiter?.complete();
    _tabWorker?.dispose();
    if (Get.isRegistered<TripSupplyController>()) Get.delete<TripSupplyController>(force: true);
    super.onClose();
  }

  String get title {
    final t = _title ?? trip.value?.title;
    if (t != null && t.isNotEmpty) return t;
    return '${plan.value?.cityName ?? ''} trip';
  }

  String get cityName => plan.value?.cityName ?? picked?.name ?? '';

  int get dayCount => plan.value?.days.length ?? 0;

  int get spotCount => plan.value?.spotCount ?? 0;

  int get priceSoFar {
    var sum = 0;
    for (final d in plan.value?.days ?? const <TripDay>[]) {
      sum += d.taxi?.fare ?? 0;
      final stay = d.stay;
      if (stay != null && stay.sameAsDay == null) sum += stay.pricePerNight ?? 0;
    }
    return sum;
  }

  int get taxisChosen => (plan.value?.days ?? const <TripDay>[]).where((d) => d.taxi != null).length;

  bool get hasChoice => (plan.value?.days ?? const <TripDay>[]).any((d) => d.taxi != null || d.stay != null);

  bool get showTaxiOption => !taxiTabOff.value && cityHasTaxis.value != false;

  bool get showStayOption => !stayTabOff.value;

  bool get supplyAvailable => plan.value?.districtId != null;

  bool get supplyPending => !supplyAvailable && trip.value == null;

  int get dayLimitMinutes => plan.value?.settings.dayLimitMinutes ?? TripConstants.dayLimitMinutes;

  TripPlanDay? resultDay(int day) {
    final r = result.value?.dayAt(day);
    final d = plan.value?.dayAt(day);
    if (r == null || d == null) return null;
    final ids = d.spots.map((s) => s.id).toList();
    if (ids.length != r.spotIds.length) return null;
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] != r.spotIds[i]) return null;
    }
    return r;
  }

  int dayTotalMinutes(int day) => resultDay(day)?.totalMinutes ?? plan.value?.dayAt(day)?.visitMinutes ?? 0;

  bool isOverLimit(int day) => dayTotalMinutes(day) > dayLimitMinutes;

  bool isEstimate(int day) => resultDay(day)?.isEstimate ?? false;

  double dayKm(int day) => resultDay(day)?.km ?? 0;

  Map<String, dynamic>? routeFor(int day) => resultDay(day)?.routeGeoJson;

  TripLeg? legFrom(int day, String spotId) => resultDay(day)?.legFrom(spotId);

  List<TripWarning> warningsFor(int day) => result.value?.warningsFor(day) ?? const [];

  bool hasWarning(int day, String code) => result.value?.hasWarning(day, code) ?? false;

  String whatsAppMessage(int day, String driverName) {
    final d = plan.value?.dayAt(day);
    return TripWhatsAppText.build(
      driverName: driverName,
      cityName: cityName,
      day: day,
      stops: d?.spots.map((s) => s.name).toList() ?? const [],
      km: dayKm(day),
      minutes: dayTotalMinutes(day),
    );
  }

  void _reset() {
    _saveTimer?.cancel();
    _recalcTimer?.cancel();
    _recalcWaiter?.complete();
    _recalcWaiter = null;
    _flow++;
    _planSeq++;
    _editSeq++;
    _creating = null;
    _saving = null;
    _title = null;
    _openingId = null;
    _dirtyDuringCreate = false;
    _lastPlanWasAuto = false;
    trip.value = null;
    plan.value = null;
    result.value = null;
    isOpening.value = false;
    openFailed.value = false;
    isPlanning.value = false;
    _clearPlanError();
    plannerOff.value = false;
    _rejectedPlan = null;
    _rejectedTitle = null;
    saveFailed.value = false;
    lastSavedAt.value = null;
    cityHasTaxis.value = null;
    selectedMapDay.value = 1;
    picked = null;
    if (Get.isRegistered<TripSupplyController>()) Get.delete<TripSupplyController>(force: true);
  }

  Future<void> _flushPendingSave() async {
    if (_saveTimer?.isActive ?? false) {
      await saveNow();
      return;
    }
    final creating = _creating;
    if (creating != null) await creating;
    final saving = _saving;
    if (saving != null) await saving;
  }

  bool _isPlannerOff(Object e) => DioErrorMapper.errorType(e) == TripErrorTypes.plannerDisabled;

  bool _isUnauthorized(Object e) => e is DioException && e.response?.statusCode == 401;

  int? _status(Object e) => e is DioException ? e.response?.statusCode : null;

  void _clearPlanError() {
    planFailed.value = false;
    planError.value = null;
    planRetryable.value = true;
  }

  void _onPlanError(Object e) {
    final status = _status(e);
    if (status == 429) {
      final raw = (e as DioException).response?.headers.value('retry-after');
      final seconds = int.tryParse(raw ?? '') ?? 60;
      _planBlockedUntil = DateTime.now().add(Duration(seconds: seconds <= 0 ? 60 : seconds));
    }
    final type = DioErrorMapper.errorType(e);
    if (type == TripErrorTypes.cityNotFound) {
      planError.value = TripStrings.cityUnavailable;
      planRetryable.value = false;
    } else if (type == TripErrorTypes.citiesUnavailable) {
      planError.value = TripStrings.citiesFailed;
      planRetryable.value = true;
    } else {
      planError.value = DioErrorMapper.toMessage(e, TripStrings.checkConnection);
      planRetryable.value = status != 400;
    }
    planFailed.value = true;
  }

  Duration? get _planWait {
    final until = _planBlockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  void _onSaveError(Object e, TripPlan p) {
    final type = DioErrorMapper.errorType(e);
    if (type == TripErrorTypes.cityNotFound) {
      AppToast.error(TripStrings.cityUnavailable);
    } else if (type == TripErrorTypes.citiesUnavailable) {
      AppToast.error(TripStrings.citiesFailed);
    } else if (_status(e) == 400) {
      _rejectedPlan = p;
      _rejectedTitle = _title;
      AppToast.error(DioErrorMapper.toMessage(e, TripStrings.saveFailed));
    } else {
      AppToast.error(TripStrings.saveFailed);
    }
    saveFailed.value = true;
  }

  Future<void> Function()? _detachPendingSave() {
    final p = plan.value;
    final creating = _creating;
    final dirty = (_saveTimer?.isActive ?? false) || (creating != null && _dirtyDuringCreate);
    if (!dirty || plannerOff.value || p == null) return null;
    final saving = _saving;
    final existing = trip.value;
    final title = _title;
    final status = _statusFor(false, p);
    return () async {
      try {
        final id = creating != null ? (await creating)?.id : existing?.id;
        if (saving != null) await saving;
        if (id == null) {
          if (creating != null || saving != null) return;
          await _repo.create(title: title, status: status, plan: p);
        } else {
          await _update(id, title, status, p);
        }
        if (Get.isRegistered<MyTripsController>()) Get.find<MyTripsController>().load();
      } catch (_) {
        return;
      }
    };
  }

  Future<void> startFromSelection(TripCityModel city, List<TripSpotModel> chosen) async {
    final pendingSave = _detachPendingSave();
    _reset();
    if (pendingSave != null) unawaited(pendingSave());
    picked = city;
    plan.value = TripPlan(
      cityKey: city.cityKey,
      cityName: city.name,
      centreLatitude: city.latitude,
      centreLongitude: city.longitude,
      days: [TripDay(day: 1, spots: chosen.take(TripConstants.maxSpots).map(TripSpotRef.fromSpot).toList())],
    );
    checkSupply();
    await Future.wait([autoPlan(), _createDraft()]);
  }

  Future<void> _createDraft() {
    final pending = _creating;
    if (pending != null) return pending;
    final f = _runCreate();
    _creating = f;
    return f.whenComplete(() {
      if (identical(_creating, f)) _creating = null;
      if (_dirtyDuringCreate && trip.value != null) {
        _dirtyDuringCreate = false;
        saveNow();
      }
    });
  }

  Future<TripModel?> _runCreate() async {
    final p = plan.value;
    if (p == null) return null;
    final flow = _flow;
    isSaving.value = true;
    try {
      final created = await _repo.create(title: _title, status: TripStatuses.draft, plan: p);
      if (flow != _flow) return created;
      trip.value = created;
      _adoptDistrict(created);
      saveFailed.value = false;
      lastSavedAt.value = DateTime.now();
      return created;
    } catch (e) {
      if (flow != _flow) return null;
      _dirtyDuringCreate = false;
      if (_isPlannerOff(e)) {
        plannerOff.value = true;
      } else if (!_isUnauthorized(e)) {
        _onSaveError(e, p);
      }
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  void _adoptDistrict(TripModel saved) {
    final p = plan.value;
    if (p == null || p.districtId != null || saved.districtId == null) return;
    plan.value = p.copyWith(districtId: saved.districtId);
    checkSupply();
  }

  Future<void> open(String tripId) async {
    if (trip.value?.id == tripId && plan.value != null) return;
    if (_openingId == tripId && isOpening.value) return;
    final pendingSave = _detachPendingSave();
    _reset();
    if (pendingSave != null) unawaited(pendingSave());
    _openingId = tripId;
    isOpening.value = true;
    try {
      final t = await _repo.get(tripId);
      if (_openingId != tripId) return;
      trip.value = t;
      plan.value = t.plan;
      picked = TripCityModel(
        cityKey: t.cityKey,
        name: t.cityName,
        latitude: t.cityLatitude,
        longitude: t.cityLongitude,
      );
      checkSupply();
      await _runRecalculate();
    } catch (e) {
      if (_openingId != tripId) return;
      if (_isPlannerOff(e)) {
        plannerOff.value = true;
      } else if (!_isUnauthorized(e)) {
        openFailed.value = true;
      }
    } finally {
      if (_openingId == tripId) isOpening.value = false;
    }
  }

  Future<void> retryOpen() async {
    final id = _openingId;
    if (id != null) await open(id);
  }

  Future<void> retryPlan() async {
    if (_planWait != null) {
      AppToast.warning(planError.value ?? TripStrings.checkConnection);
      return;
    }
    await (_lastPlanWasAuto ? autoPlan() : _runRecalculate());
  }

  Map<String, dynamic> _planBody(TripPlan p, String mode) => {
        'cityKey': p.cityKey,
        'mode': mode,
        if (mode == 'auto') 'spots': p.allSpots.map((s) => s.toPlanInput()).toList(),
        if (mode != 'auto')
          'days': p.days
              .where((d) => d.spots.isNotEmpty)
              .map((d) => {'day': d.day, 'spots': d.spots.map((s) => s.toPlanInput()).toList()})
              .toList(),
        'dayLimitMinutes': p.settings.dayLimitMinutes,
        'startDate': ?p.settings.startDateIso,
      };

  Future<void> autoPlan() async {
    final p = plan.value;
    if (p == null || p.spotCount == 0) return;
    _lastPlanWasAuto = true;
    final seq = ++_planSeq;
    final edit = _editSeq;
    isPlanning.value = true;
    _clearPlanError();
    try {
      final r = await _repo.plan(_planBody(p, 'auto'));
      if (seq != _planSeq) return;
      _lastPlanWasAuto = false;
      if (edit != _editSeq || plan.value == null) {
        unawaited(_runRecalculate());
        return;
      }
      plan.value = _applyAuto(plan.value!, r);
      result.value = r;
      scheduleSave();
    } catch (e) {
      if (seq != _planSeq) return;
      if (_isPlannerOff(e)) {
        plannerOff.value = true;
      } else if (!_isUnauthorized(e)) {
        _onPlanError(e);
      }
    } finally {
      if (seq == _planSeq) isPlanning.value = false;
    }
  }

  TripPlan _applyAuto(TripPlan p, TripPlanResult r) {
    final byId = {for (final s in p.allSpots) s.id: s};
    final used = <String>{};
    final days = <TripDay>[];
    for (final rd in r.days) {
      final spots = <TripSpotRef>[];
      for (final id in rd.spotIds) {
        final s = byId[id];
        if (s != null && used.add(id)) spots.add(s);
      }
      final old = p.dayAt(days.length + 1);
      days.add(TripDay(day: days.length + 1, spots: spots, taxi: old?.taxi, stay: old?.stay));
    }
    while (days.isNotEmpty && days.last.spots.isEmpty) {
      days.removeLast();
    }
    final leftover = byId.values.where((s) => !used.contains(s.id)).toList();
    if (days.isEmpty) {
      final old = p.dayAt(1);
      days.add(TripDay(day: 1, spots: leftover, taxi: old?.taxi, stay: old?.stay));
    } else if (leftover.isNotEmpty) {
      days[days.length - 1] = days.last.copyWith(spots: [...days.last.spots, ...leftover]);
    }
    return p.copyWith(
      days: _fixSameStay(days),
      centreLatitude: r.centreLatitude,
      centreLongitude: r.centreLongitude,
    );
  }

  Future<void> recalculate() {
    _recalcTimer?.cancel();
    final waiter = _recalcWaiter ??= Completer<void>();
    final wait = _planWait;
    final delay = wait != null && wait > TripConstants.recalcDebounce ? wait : TripConstants.recalcDebounce;
    _recalcTimer = Timer(delay, () {
      final w = _recalcWaiter;
      _recalcWaiter = null;
      _runRecalculate().whenComplete(() {
        if (w != null && !w.isCompleted) w.complete();
      });
    });
    return waiter.future;
  }

  Future<void> _runRecalculate() async {
    final p = plan.value;
    if (p == null) return;
    if (p.spotCount == 0) {
      _planSeq++;
      result.value = null;
      isPlanning.value = false;
      _clearPlanError();
      return;
    }
    _lastPlanWasAuto = false;
    final seq = ++_planSeq;
    isPlanning.value = true;
    _clearPlanError();
    try {
      final r = await _repo.plan(_planBody(p, 'recalculate'));
      if (seq != _planSeq) return;
      result.value = r;
      final current = plan.value;
      if (current != null && (r.centreLatitude != current.centreLatitude || r.centreLongitude != current.centreLongitude)) {
        plan.value = current.copyWith(centreLatitude: r.centreLatitude, centreLongitude: r.centreLongitude);
      }
    } catch (e) {
      if (seq != _planSeq) return;
      if (_isPlannerOff(e)) {
        plannerOff.value = true;
      } else if (!_isUnauthorized(e)) {
        _onPlanError(e);
      }
    } finally {
      if (seq == _planSeq) isPlanning.value = false;
    }
  }

  List<TripDay> _renumber(List<TripDay> days) {
    final lastFull = days.lastIndexWhere((d) => d.spots.isNotEmpty);
    final kept = lastFull < 0 ? <TripDay>[] : days.sublist(0, lastFull + 1);
    if (kept.isEmpty) {
      final first = days.isEmpty ? null : days.first;
      return [TripDay(day: 1, taxi: first?.taxi, stay: first?.stay?.copyWith(clearSameAsDay: true))];
    }
    final map = <int, int>{};
    for (var i = 0; i < kept.length; i++) {
      map[kept[i].day] = i + 1;
    }
    final out = <TripDay>[];
    for (var i = 0; i < kept.length; i++) {
      final d = kept[i];
      var stay = d.stay;
      final same = stay?.sameAsDay;
      if (stay != null && same != null) {
        final target = map[same];
        stay = target == null ? stay.copyWith(clearSameAsDay: true) : stay.copyWith(sameAsDay: target);
      }
      out.add(TripDay(day: i + 1, spots: d.spots, taxi: d.taxi, stay: stay));
    }
    return _fixSameStay(out);
  }

  List<TripDay> _fixSameStay(List<TripDay> days) => [
        for (final d in days)
          if (d.stay?.sameAsDay != null && (d.stay!.sameAsDay! >= d.day || d.stay!.sameAsDay! < 1))
            d.copyWith(stay: d.stay!.copyWith(clearSameAsDay: true))
          else
            d,
      ];

  void _applyEdit(List<TripDay> days) {
    final p = plan.value;
    if (p == null) return;
    _editSeq++;
    plan.value = p.copyWith(days: _renumber(days));
    recalculate();
    scheduleSave();
  }

  void moveSpot(String id, int toDay) {
    final p = plan.value;
    if (p == null) return;
    final fromDay = p.dayOfSpot(id);
    final spot = p.spotById(id);
    if (fromDay == null || spot == null || fromDay == toDay || p.dayAt(toDay) == null) return;
    _applyEdit([
      for (final d in p.days)
        if (d.day == fromDay)
          d.copyWith(spots: d.spots.where((s) => s.id != id).toList())
        else if (d.day == toDay)
          d.copyWith(spots: [...d.spots, spot])
        else
          d,
    ]);
  }

  void reorder(int day, int oldIndex, int newIndex) {
    final p = plan.value;
    final d = p?.dayAt(day);
    if (p == null || d == null || oldIndex < 0 || oldIndex >= d.spots.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, d.spots.length - 1);
    if (newIndex == oldIndex) return;
    final spots = [...d.spots];
    final s = spots.removeAt(oldIndex);
    spots.insert(newIndex, s);
    _applyEdit([for (final x in p.days) x.day == day ? x.copyWith(spots: spots) : x]);
  }

  void removeSpot(String id) {
    final p = plan.value;
    if (p == null || p.dayOfSpot(id) == null) return;
    _applyEdit([for (final d in p.days) d.copyWith(spots: d.spots.where((s) => s.id != id).toList())]);
  }

  void addSpots(List<TripSpotModel> spots) {
    final p = plan.value;
    if (p == null || p.days.isEmpty) return;
    final existing = p.spotIds;
    final room = TripConstants.maxSpots - existing.length;
    final fresh = spots.where((s) => !existing.contains(s.id)).toList();
    if (fresh.isEmpty) return;
    if (fresh.length > room) AppToast.warning(TripStrings.maxPlaces);
    final adding = fresh.take(room < 0 ? 0 : room).map(TripSpotRef.fromSpot).toList();
    if (adding.isEmpty) return;
    final last = p.days.last;
    _applyEdit([for (final d in p.days) d.day == last.day ? d.copyWith(spots: [...d.spots, ...adding]) : d]);
  }

  void _applyChoice(List<TripDay> days) {
    final p = plan.value;
    if (p == null) return;
    plan.value = p.copyWith(days: days);
    scheduleSave();
  }

  void selectTaxi(int day, TaxiBrowseItem t) {
    final p = plan.value;
    if (p == null) return;
    final choice = TripTaxiChoice(
      taxiId: t.id,
      name: t.driverName,
      fare: t.minFare,
      vehicleTypeName: t.vehicleTypeName.isEmpty ? null : t.vehicleTypeName,
    );
    _applyChoice([for (final d in p.days) d.day == day ? d.copyWith(taxi: choice) : d]);
  }

  void clearTaxi(int day) {
    final p = plan.value;
    if (p == null) return;
    _applyChoice([for (final d in p.days) d.day == day ? d.copyWith(clearTaxi: true) : d]);
  }

  void selectStay(int day, StayNearbyModel s) {
    final p = plan.value;
    if (p == null) return;
    final choice = TripStayChoice(stayId: s.id, name: s.title, pricePerNight: s.minPricePerNight);
    final copy = TripStayChoice(stayId: s.id, name: s.title, pricePerNight: s.minPricePerNight, sameAsDay: day);
    final laterEmpty = p.days.where((d) => d.day > day).every((d) => d.stay == null);
    final prefill = day == 1 || laterEmpty;
    _applyChoice([
      for (final d in p.days)
        if (d.day == day)
          d.copyWith(stay: choice)
        else if (d.day > day && (d.stay?.sameAsDay == day || (prefill && (d.stay == null || d.stay!.isSameStay))))
          d.copyWith(stay: copy)
        else
          d,
    ]);
  }

  void clearStay(int day) {
    final p = plan.value;
    if (p == null) return;
    _applyChoice([
      for (final d in p.days)
        if (d.day == day)
          d.copyWith(clearStay: true)
        else if (d.stay?.sameAsDay == day)
          d.copyWith(stay: d.stay!.copyWith(clearSameAsDay: true))
        else
          d,
    ]);
  }

  Future<void> checkSupply() async {
    final p = plan.value;
    if (p == null) return;
    final tabs = TabConfigController.to;
    taxiTabOff.value = !tabs.isActiveForIndex(AppTabs.taxi);
    stayTabOff.value = !tabs.isActiveForIndex(AppTabs.stays);
    final seq = ++_supplySeq;
    final districtId = p.districtId;
    if (districtId == null) {
      cityHasTaxis.value = null;
      return;
    }
    if (taxiTabOff.value) return;
    try {
      final page = await const TaxiBrowseRepository().browseLocal(districtId: districtId, pageSize: 1);
      if (seq != _supplySeq) return;
      cityHasTaxis.value = page.items.isNotEmpty;
    } catch (e) {
      if (seq != _supplySeq) return;
      if (DioErrorMapper.errorType(e) == ApiService.tabInactiveType) taxiTabOff.value = true;
    }
  }

  void scheduleSave() {
    if (plannerOff.value || plan.value == null) return;
    if (identical(plan.value, _rejectedPlan) && _title == _rejectedTitle) return;
    if (_creating != null) {
      _dirtyDuringCreate = true;
      return;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(TripConstants.autosaveDebounce, () => saveNow());
  }

  Future<bool> rename(String title) {
    _title = title.trim();
    return saveNow();
  }

  Future<bool> saveNow({bool markPlanned = false}) async {
    _saveTimer?.cancel();
    if (plannerOff.value || plan.value == null) return false;
    final creating = _creating;
    if (creating != null) await creating;
    while (_saving != null) {
      await _saving;
    }
    if (plannerOff.value || plan.value == null) return false;
    final f = _save(markPlanned);
    _saving = f;
    try {
      return await f;
    } finally {
      if (identical(_saving, f)) _saving = null;
    }
  }

  String _statusFor(bool markPlanned, TripPlan p) {
    if (p.spotCount == 0) return TripStatuses.draft;
    if (markPlanned) return TripStatuses.planned;
    return trip.value?.status ?? TripStatuses.draft;
  }

  Future<bool> _save(bool markPlanned) async {
    final p = plan.value!;
    final flow = _flow;
    isSaving.value = true;
    try {
      final current = trip.value;
      final saved = current == null
          ? await _repo.create(title: _title, status: _statusFor(markPlanned, p), plan: p)
          : await _update(current.id, _title, _statusFor(markPlanned, p), p);
      if (flow != _flow) return false;
      trip.value = saved;
      _adoptDistrict(saved);
      saveFailed.value = false;
      lastSavedAt.value = DateTime.now();
      return true;
    } catch (e) {
      if (flow != _flow) return false;
      if (_isPlannerOff(e)) {
        plannerOff.value = true;
        return false;
      }
      if (_isUnauthorized(e)) return false;
      _onSaveError(e, p);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<TripModel> _update(String id, String? title, String status, TripPlan p) async {
    try {
      return await _repo.update(id, title: title, status: status, plan: p);
    } catch (e) {
      final type = DioErrorMapper.errorType(e);
      if (type == TripErrorTypes.concurrentUpdate) {
        await _repo.get(id);
        return _repo.update(id, title: title, status: status, plan: p);
      }
      if (type == TripErrorTypes.tripNotFound) {
        return _repo.create(title: title, status: status, plan: p);
      }
      rethrow;
    }
  }

  Future<bool> deleteTrip() async {
    _saveTimer?.cancel();
    final creating = _creating;
    if (creating != null) await creating;
    final saving = _saving;
    if (saving != null) await saving;
    _saveTimer?.cancel();
    final id = trip.value?.id;
    if (id != null) {
      try {
        await _repo.delete(id);
      } catch (e) {
        if (DioErrorMapper.errorType(e) != TripErrorTypes.tripNotFound) {
          AppToast.error(DioErrorMapper.toMessage(e, "Couldn't delete the trip."));
          return false;
        }
      }
      if (Get.isRegistered<MyTripsController>()) Get.find<MyTripsController>().removeLocal(id);
    }
    _reset();
    return true;
  }

  Future<void> releaseIfIdle() async {
    if (openPages > 0) return;
    await _flushPendingSave();
    if (openPages > 0 || !Get.isRegistered<TripPlanController>()) return;
    if (!identical(Get.find<TripPlanController>(), this)) return;
    if (Get.isRegistered<MyTripsController>()) Get.find<MyTripsController>().load();
    Get.delete<TripPlanController>(force: true);
  }
}
