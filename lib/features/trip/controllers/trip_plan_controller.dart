import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../../taxi/guest/taxi_browse_repository.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../../taxi/taxi_option_sets.dart';
import '../data/trip_repository.dart';
import '../data/trip_today_cache.dart';
import '../models/trip_city_model.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_plan_result_model.dart';
import '../models/trip_spot_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../utils/trip_whatsapp_text.dart';
import '../widgets/trip_status.dart';
import 'my_trips_controller.dart';
import 'trip_enquiry_controller.dart';
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
  final taxiSupply = Rxn<bool>();
  final tripGone = false.obs;
  final needsUpdate = false.obs;
  final selectedMapDay = 1.obs;
  final enquiryList = <TripEnquiryModel>[].obs;
  final enquiriesLoading = false.obs;
  final enquiriesFailed = false.obs;
  final dismissedRed = <String>{}.obs;
  final bannerDismissed = false.obs;
  final confirmLinks = <String, TripPhoneBookingResult>{};
  final offline = false.obs;
  final problemBusy = false.obs;
  final askBusy = false.obs;
  bool lastProblemQueued = false;
  TripCityModel? picked;
  int openPages = 0;
  int _enquirySeq = 0;
  final _legacySynced = <String>{};

  String? _title;
  String? _clientTripId;
  bool _settingsChangedWhilePlanning = false;
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
      if (stay != null && !stay.isSkipped) sum += stay.pricePerNight ?? 0;
    }
    return sum;
  }

  int get taxisChosen => (plan.value?.days ?? const <TripDay>[]).where((d) => d.taxi != null).length;

  bool get hasChoice => (plan.value?.days ?? const <TripDay>[]).any((d) => d.taxi != null || d.stay != null);

  bool get showTaxiOption =>
      (!taxiTabOff.value && cityHasTaxis.value != false) ||
      (plan.value?.days ?? const <TripDay>[]).any((d) => hasTaxiActivity(d.day));

  bool get showStayOption =>
      !stayTabOff.value || (plan.value?.days ?? const <TripDay>[]).any((d) => hasStayActivity(d.day));

  bool hasStayActivity(int day) {
    final d = plan.value?.dayAt(day);
    if (d == null) return false;
    return d.stay != null || d.stayShortlist.isNotEmpty || enquiriesForNight(day).isNotEmpty;
  }

  bool hasTaxiActivity(int day) {
    final d = plan.value?.dayAt(day);
    if (d == null) return false;
    return d.taxi != null || d.taxiShortlist.isNotEmpty || taxiEnquiriesForDay(day).isNotEmpty;
  }

  bool get canFindStay => supplyAvailable && !stayTabOff.value && !isReadOnly;

  bool get canFindTaxi => taxiSupply.value == true && !taxiTabOff.value && !isReadOnly;

  bool get supplyAvailable => plan.value?.districtId != null;

  bool get supplyPending => !supplyAvailable && trip.value == null;

  int get dayLimitMinutes => plan.value?.settings.dayLimitMinutes ?? TripConstants.dayLimitMinutes;

  TripSettings get settings => plan.value?.settings ?? const TripSettings();

  bool get hasDates => settings.hasDates;

  DateTime? dateOf(int day) => settings.dateOf(day);

  int get defaultMapDay {
    final start = settings.startDate;
    final n = dayCount;
    if (start == null || n < 1) return 1;
    final now = DateTime.now();
    final offset = DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    return offset >= 0 && offset < n ? offset + 1 : 1;
  }

  bool get isPlanned => trip.value?.status == TripStatuses.planned;

  bool get isCompleted => trip.value?.status == TripStatuses.completed;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  int? get todayDay {
    final start = settings.startDate;
    final n = dayCount;
    if (start == null || n < 1) return null;
    final offset = DateTime.utc(_today.year, _today.month, _today.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
    return offset >= 0 && offset < n ? offset + 1 : null;
  }

  bool get isRunning => todayDay != null;

  bool get isLastDayOrAfter {
    final end = settings.endDate(dayCount);
    return end != null && !_today.isBefore(end);
  }

  DateTime? get checkOutDate => settings.checkOutDate(dayCount);

  bool get isPastTrip {
    final last = hasDates && dayCount > 0 ? dateOf(dayCount) : null;
    return last != null && _today.isAfter(last);
  }

  bool get isReadOnly => isCompleted || isPastTrip;

  bool isDayPast(int day) {
    final d = dateOf(day);
    return d != null && d.isBefore(_today);
  }

  bool canEditDay(int day) => !isReadOnly && !isDayPast(day);

  bool get canComplete => trip.value != null && !isCompleted && (!hasDates || isRunning || isLastDayOrAfter);

  TripEnquiryModel? todayStay(int day) {
    final e = primaryEnquiry(day);
    return e != null && e.isBooked ? e : null;
  }

  TripEnquiryModel? todayTaxi(int day) {
    final e = primaryTaxiEnquiry(day);
    return e != null && e.isBooked ? e : null;
  }

  TripStayChoice? ownStayOf(int day) {
    var s = plan.value?.dayAt(day)?.stay;
    final same = s?.sameAsDay;
    if (same != null) s = plan.value?.dayAt(same)?.stay;
    return s != null && s.isOwn ? s : null;
  }

  TripTaxiChoice? ownTaxiOf(int day) {
    final t = plan.value?.dayAt(day)?.taxi;
    return t != null && t.isOwn ? t : null;
  }

  List<String> todaySpotNames(int day) =>
      plan.value?.dayAt(day)?.spots.map((s) => s.name).where((n) => n.isNotEmpty).toList() ?? const [];

  static bool _outsideWindow(TripEnquiryModel e, DateTime start, DateTime checkOut) {
    if (e.isTaxi) {
      final dates = e.taxiDates;
      return dates.any((d) => d.isBefore(start) || !d.isBefore(checkOut));
    }
    final ci = e.checkIn;
    if (ci == null) return false;
    final co = e.checkOut ?? DateTime(ci.year, ci.month, ci.day + 1);
    return ci.isBefore(start) || co.isAfter(checkOut);
  }

  int daysAfterLimit(int? maxDays) => maxDays != null && maxDays < dayCount ? maxDays : dayCount;

  DateChangeImpact dateChangeImpact(DateTime newStart, {int? days}) {
    final start = DateTime(newStart.year, newStart.month, newStart.day);
    final n = days ?? dayCount;
    final checkOut = DateTime(start.year, start.month, start.day + (n < 1 ? 1 : n));
    final booked = <TripEnquiryModel>[];
    final open = <TripEnquiryModel>[];
    for (final e in enquiryList) {
      if (!e.isOpen || !_outsideWindow(e, start, checkOut)) continue;
      (e.isBooked ? booked : open).add(e);
    }
    booked.sort(_newestFirst);
    open.sort(_newestFirst);
    return DateChangeImpact(booked: booked, open: open);
  }

  List<TripEnquiryModel> bookingsOutsideDates(DateTime newStart) => dateChangeImpact(newStart).all;

  List<TripStayShortlistItem> askAgainStays(int day) {
    final date = dateOf(day);
    if (date == null || date.isBefore(_today)) return const [];
    final off = unavailableStayIds;
    final all = enquiriesForNight(day);
    return (plan.value?.dayAt(day)?.stayShortlist ?? const <TripStayShortlistItem>[]).where((s) {
      if (off.contains(s.stayId)) return false;
      final mine = all.where((e) => e.listingId == s.stayId);
      return mine.isNotEmpty && !mine.any((e) => e.isOpen);
    }).toList();
  }

  List<TripTaxiShortlistItem> askAgainTaxis(int day) {
    final date = dateOf(day);
    if (date == null || date.isBefore(_today)) return const [];
    final all = taxiEnquiriesForDay(day);
    return (plan.value?.dayAt(day)?.taxiShortlist ?? const <TripTaxiShortlistItem>[]).where((s) {
      final mine = all.where((e) => e.listingId == s.taxiId);
      return mine.isNotEmpty && !mine.any((e) => e.isOpen);
    }).toList();
  }

  bool canAskAgain(String kind, int day) =>
      kind == TripEnquiryKinds.taxi ? askAgainTaxis(day).isNotEmpty : askAgainStays(day).isNotEmpty;

  Future<TripEnquiryBatch?> askAgain({required String kind, required int day}) async {
    if (askBusy.value) return null;
    askBusy.value = true;
    try {
      final batch = await TripEnquiryController.to.askAgain(kind: kind, day: day);
      if (batch == null) return null;
      if (batch.items.isEmpty) {
        AppToast.warning(TripStrings.askAgainNothing);
        return null;
      }
      kind == TripEnquiryKinds.taxi ? dismissRedTaxi(day) : dismissRed(day);
      AppToast.success(kind == TripEnquiryKinds.taxi
          ? TripStrings.askAgainSentTaxi(batch.items.length)
          : TripStrings.askAgainSent(batch.items.length));
      return batch;
    } finally {
      askBusy.value = false;
    }
  }

  Future<bool> reportProblem({
    required int day,
    required String kind,
    String? enquiryId,
    String? note,
    double? latitude,
    double? longitude,
  }) async {
    final tripId = trip.value?.id;
    if (tripId == null || problemBusy.value) return false;
    problemBusy.value = true;
    lastProblemQueued = false;
    try {
      final res = await _repo.reportProblem(
        tripId,
        day: day,
        kind: kind,
        enquiryId: enquiryId,
        note: note,
        latitude: latitude,
        longitude: longitude,
      );
      final rows = res.rows;
      if (rows.isNotEmpty) applyEnquiries(rows);
      return true;
    } catch (e) {
      if (DioErrorMapper.isNetworkError(e)) {
        TripTodayCache.queueProblem({
          'tripId': tripId,
          'day': day,
          'kind': kind,
          'enquiryId': ?enquiryId,
          'note': ?note,
          'latitude': ?latitude,
          'longitude': ?longitude,
          'queuedAt': DateTime.now().toUtc().toIso8601String(),
        });
        lastProblemQueued = true;
        AppToast.warning(TripStrings.problemQueued);
        return true;
      }
      AppToast.error(DioErrorMapper.toMessage(e, TripStrings.checkConnection));
      return false;
    } finally {
      problemBusy.value = false;
    }
  }

  Future<void> flushProblemQueue() async {
    for (final it in TripTodayCache.drainProblems()) {
      final tripId = it['tripId'] as String?;
      final day = (it['day'] as num?)?.toInt();
      final kind = it['kind'] as String?;
      if (tripId == null || day == null || kind == null) continue;
      try {
        final res = await _repo.reportProblem(
          tripId,
          day: day,
          kind: kind,
          enquiryId: it['enquiryId'] as String?,
          note: it['note'] as String?,
          latitude: (it['latitude'] as num?)?.toDouble(),
          longitude: (it['longitude'] as num?)?.toDouble(),
        );
        final rows = res.rows;
        if (rows.isNotEmpty && trip.value?.id == tripId) applyEnquiries(rows);
      } catch (_) {
        continue;
      }
    }
  }

  void _cacheResult(TripPlanResult r) {
    final id = trip.value?.id;
    if (id != null) TripTodayCache.saveResult(id, r);
  }

  bool _openFromCache(String tripId, Object e) {
    if (!DioErrorMapper.isNetworkError(e)) return false;
    final cached = TripTodayCache.trip(tripId);
    if (cached == null) return false;
    trip.value = cached;
    plan.value = cached.plan;
    enquiryList.assignAll(cached.enquiries);
    result.value = TripTodayCache.result(tripId);
    picked = TripCityModel(
      cityKey: cached.cityKey,
      name: cached.cityName,
      latitude: cached.cityLatitude,
      longitude: cached.cityLongitude,
    );
    offline.value = true;
    openFailed.value = false;
    return true;
  }

  TripTaxiChoice? get bookedTaxi {
    for (final d in plan.value?.days ?? const <TripDay>[]) {
      if (d.taxi?.isBooked ?? false) return d.taxi;
    }
    return null;
  }

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
    _clientTripId = null;
    _settingsChangedWhilePlanning = false;
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
    taxiSupply.value = null;
    tripGone.value = false;
    needsUpdate.value = false;
    selectedMapDay.value = 1;
    _enquirySeq++;
    enquiryList.clear();
    enquiriesLoading.value = false;
    enquiriesFailed.value = false;
    dismissedRed.clear();
    bannerDismissed.value = false;
    confirmLinks.clear();
    offline.value = false;
    picked = null;
    if (Get.isRegistered<TripSupplyController>()) Get.delete<TripSupplyController>(force: true);
  }

  Future<bool> flushPendingSave() async {
    if (tripGone.value || needsUpdate.value || plannerOff.value) return false;
    if (_saveTimer?.isActive ?? false) return saveNow();
    final creating = _creating;
    if (creating != null && await creating == null) return false;
    if (_dirtyDuringCreate || (_saveTimer?.isActive ?? false)) return saveNow();
    final saving = _saving;
    if (saving != null && !await saving) return false;
    if (trip.value == null || saveFailed.value) return saveNow();
    return true;
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
    final clientId = _clientTripId;
    final status = _statusFor(false, p);
    return () async {
      try {
        final id = creating != null ? (await creating)?.id : existing?.id;
        if (saving != null) await saving;
        if (id == null) {
          if (creating != null || saving != null) return;
          await _repo.create(title: title, status: status, plan: p, clientTripId: clientId);
        } else {
          await _update(id, title, status, p);
        }
        if (Get.isRegistered<MyTripsController>()) Get.find<MyTripsController>().load();
      } catch (_) {
        return;
      }
    };
  }

  Future<void> startFromSelection(TripCityModel city, List<TripSpotModel> chosen, {TripSettings? settings}) async {
    final pendingSave = _detachPendingSave();
    _reset();
    if (pendingSave != null) unawaited(pendingSave());
    picked = city;
    _clientTripId = const Uuid().v4();
    plan.value = TripPlan(
      cityKey: city.cityKey,
      cityName: city.name,
      centreLatitude: city.latitude,
      centreLongitude: city.longitude,
      days: [TripDay(day: 1, spots: chosen.take(TripConstants.maxSpots).map(TripSpotRef.fromSpot).toList())],
      settings: settings ?? const TripSettings(),
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
      final created = await _repo.create(title: _title, status: TripStatuses.draft, plan: p, clientTripId: _clientTripId);
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

  Future<void> open(String tripId, {bool fresh = false}) async {
    if (!fresh && trip.value?.id == tripId && plan.value != null && !tripGone.value) return;
    if (_openingId == tripId && isOpening.value) return;
    final pendingSave = _detachPendingSave();
    _reset();
    if (pendingSave != null) unawaited(pendingSave());
    _openingId = tripId;
    isOpening.value = true;
    try {
      final t = await _repo.get(tripId);
      if (_openingId != tripId) return;
      TripTodayCache.saveTrip(t);
      trip.value = t;
      enquiryList.assignAll(t.enquiries);
      plan.value = t.plan;
      picked = TripCityModel(
        cityKey: t.cityKey,
        name: t.cityName,
        latitude: t.cityLatitude,
        longitude: t.cityLongitude,
      );
      checkSupply();
      _adoptDistrict(t);
      reconcilePlan();
      unawaited(syncLegacyTaxiBookings());
      unawaited(flushProblemQueue());
      await _runRecalculate();
    } catch (e) {
      if (_openingId != tripId) return;
      if (_isPlannerOff(e)) {
        plannerOff.value = true;
      } else if (_isGone(e)) {
        _markGone(tripId);
      } else if (!_isUnauthorized(e)) {
        if (!_openFromCache(tripId, e)) openFailed.value = true;
      }
    } finally {
      if (_openingId == tripId) isOpening.value = false;
    }
  }

  bool _isGone(Object e) {
    final type = DioErrorMapper.errorType(e);
    if (type == TripErrorTypes.tripNotFound) return true;
    final status = _status(e);
    return status == 404 || (status == 403 && type != TripErrorTypes.plannerDisabled && type != ApiService.tabInactiveType);
  }

  void _markGone(String tripId) {
    _saveTimer?.cancel();
    _recalcTimer?.cancel();
    _dirtyDuringCreate = false;
    tripGone.value = true;
    openFailed.value = false;
    StorageService.clearTripCache(tripId);
    if (Get.isRegistered<MyTripsController>()) Get.find<MyTripsController>().removeLocal(tripId);
  }

  Future<void> retryOpen() async {
    final id = _openingId;
    if (id != null) await open(id, fresh: true);
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
        if (mode == 'auto') 'maxDays': ?p.settings.maxDays,
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
      _cacheResult(r);
      scheduleSave();
      if (_settingsChangedWhilePlanning) {
        _settingsChangedWhilePlanning = false;
        unawaited(recalculate());
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
      days.add(TripDay(
        day: days.length + 1,
        spots: spots,
        taxi: old?.taxi,
        stay: old?.stay,
        stayShortlist: old?.stayShortlist ?? const [],
        taxiShortlist: old?.taxiShortlist ?? const [],
      ));
    }
    while (days.isNotEmpty && days.last.spots.isEmpty) {
      days.removeLast();
    }
    final leftover = byId.values.where((s) => !used.contains(s.id)).toList();
    if (days.isEmpty) {
      final old = p.dayAt(1);
      days.add(TripDay(
        day: 1,
        spots: leftover,
        taxi: old?.taxi,
        stay: old?.stay,
        stayShortlist: old?.stayShortlist ?? const [],
        taxiShortlist: old?.taxiShortlist ?? const [],
      ));
    } else if (leftover.isNotEmpty) {
      days[days.length - 1] = days.last.copyWith(spots: [...days.last.spots, ...leftover]);
    }
    return p.copyWith(
      days: _fixSameStay(days),
      centreLatitude: r.centreLatitude,
      centreLongitude: r.centreLongitude,
    );
  }

  @visibleForTesting
  TripPlan applyAutoForTest(TripPlan p, TripPlanResult r) => _applyAuto(p, r);

  @visibleForTesting
  List<TripDay> renumberForTest(List<TripDay> days, {bool keepEmptyDays = false}) =>
      _renumber(days, keepEmptyDays: keepEmptyDays);

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
      _cacheResult(r);
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

  List<TripDay> _renumber(List<TripDay> days, {bool keepEmptyDays = false}) {
    final lastFull = keepEmptyDays ? days.length - 1 : days.lastIndexWhere((d) => d.spots.isNotEmpty);
    final kept = lastFull < 0 ? <TripDay>[] : days.sublist(0, lastFull + 1);
    if (kept.isEmpty) {
      final first = days.isEmpty ? null : days.first;
      return [TripDay(day: 1, taxi: _remapBooking(first?.taxi, map: const {1: 1}), stay: first?.stay?.copyWith(clearSameAsDay: true))];
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
      out.add(TripDay(
        day: i + 1,
        spots: d.spots,
        taxi: _remapBooking(d.taxi, map: map),
        stay: stay,
        stayShortlist: [
          for (final s in d.stayShortlist)
            if (s.sameAsDay == null)
              s
            else if (map[s.sameAsDay] == null)
              s.copyWith(clearSameAsDay: true)
            else
              s.copyWith(sameAsDay: map[s.sameAsDay]),
        ],
        taxiShortlist: d.taxiShortlist,
      ));
    }
    return _fixSameStay(out);
  }

  TripTaxiChoice? _remapBooking(TripTaxiChoice? taxi, {required Map<int, int> map}) {
    final b = taxi?.booking;
    if (taxi == null || b == null) return taxi;
    final days = {for (final d in b.days) ?map[d]}.toList()..sort();
    if (days.isEmpty) return taxi.copyWith(clearBooking: true);
    return taxi.copyWith(
      booking: b.copyWith(days: days),
      fare: (b.agreedFare / days.length).round(),
    );
  }

  static bool _badRef(int? same, int day) => same != null && (same >= day || same < 1);

  List<TripDay> _fixSameStay(List<TripDay> days) => [
        for (final d in days)
          if (_badRef(d.stay?.sameAsDay, d.day) || d.stayShortlist.any((s) => _badRef(s.sameAsDay, d.day)))
            d.copyWith(
              stay: _badRef(d.stay?.sameAsDay, d.day) ? d.stay!.copyWith(clearSameAsDay: true) : null,
              stayShortlist: [
                for (final s in d.stayShortlist) _badRef(s.sameAsDay, d.day) ? s.copyWith(clearSameAsDay: true) : s,
              ],
            )
          else
            d,
      ];

  void _applyEdit(List<TripDay> days, {bool keepEmptyDays = false}) {
    final p = plan.value;
    if (p == null) return;
    _editSeq++;
    plan.value = p.copyWith(days: _renumber(days, keepEmptyDays: keepEmptyDays));
    recalculate();
    scheduleSave();
  }

  bool _dayHasBookings(TripDay d) =>
      d.stay != null ||
      d.taxi != null ||
      d.stayShortlist.isNotEmpty ||
      d.taxiShortlist.isNotEmpty ||
      enquiriesForNight(d.day).any((e) => e.isOpen) ||
      taxiEnquiriesForDay(d.day).any((e) => e.isOpen);

  EditImpact editImpact(List<TripDay> next) {
    final lastFull = next.lastIndexWhere((d) => d.spots.isNotEmpty);
    final keep = lastFull < 0 ? 1 : lastFull + 1;
    final dropped = <int>[
      for (var i = keep; i < next.length; i++)
        if (_dayHasBookings(plan.value?.dayAt(next[i].day) ?? next[i])) next[i].day,
    ];
    return EditImpact(droppedDaysWithBookings: dropped);
  }

  List<TripDay>? _movedDays(String id, int toDay) {
    final p = plan.value;
    if (p == null) return null;
    final fromDay = p.dayOfSpot(id);
    final spot = p.spotById(id);
    if (fromDay == null || spot == null || fromDay == toDay || p.dayAt(toDay) == null) return null;
    return [
      for (final d in p.days)
        if (d.day == fromDay)
          d.copyWith(spots: d.spots.where((s) => s.id != id).toList())
        else if (d.day == toDay)
          d.copyWith(spots: [...d.spots, spot])
        else
          d,
    ];
  }

  List<TripDay>? _removedDays(String id) {
    final p = plan.value;
    if (p == null || p.dayOfSpot(id) == null) return null;
    return [for (final d in p.days) d.copyWith(spots: d.spots.where((s) => s.id != id).toList())];
  }

  EditImpact moveImpact(String id, int toDay) {
    final next = _movedDays(id, toDay);
    return next == null ? const EditImpact() : editImpact(next);
  }

  EditImpact removeImpact(String id) {
    final next = _removedDays(id);
    return next == null ? const EditImpact() : editImpact(next);
  }

  void moveSpot(String id, int toDay, {bool keepEmptyDays = false}) {
    if (isReadOnly) return;
    final next = _movedDays(id, toDay);
    if (next != null) _applyEdit(next, keepEmptyDays: keepEmptyDays);
  }

  void reorder(int day, int oldIndex, int newIndex) {
    if (isReadOnly) return;
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

  void removeSpot(String id, {bool keepEmptyDays = false}) {
    if (isReadOnly) return;
    final next = _removedDays(id);
    if (next != null) _applyEdit(next, keepEmptyDays: keepEmptyDays);
  }

  void addSpots(List<TripSpotModel> spots) {
    final p = plan.value;
    if (p == null || p.days.isEmpty || isReadOnly) return;
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
    if (p == null || !canEditDay(day) || bookedTaxiEnquiryFor(day) != null) return;
    final choice = TripTaxiChoice(
      taxiId: t.id,
      name: t.driverName,
      fare: t.localDayRate,
      vehicleTypeName: t.vehicleTypeName.isEmpty ? null : t.vehicleTypeName,
    );
    _applyChoice([for (final d in p.days) d.day == day ? d.copyWith(taxi: choice) : d]);
  }

  void clearTaxi(int day) {
    final p = plan.value;
    if (p == null || !canEditDay(day)) return;
    _applyChoice([for (final d in p.days) d.day == day ? d.copyWith(clearTaxi: true) : d]);
  }

  TripEnquiryModel? bookedTaxiEnquiryFor(int day) {
    for (final e in taxiEnquiriesForDay(day)) {
      if (e.isBooked) return e;
    }
    return null;
  }

  TripDisplayStatus? taxiStatusFor(int day, String taxiId) {
    TripDisplayStatus? best;
    var bestRank = 99;
    for (final e in taxiEnquiriesForDay(day)) {
      if (e.listingId != taxiId) continue;
      final r = _taxiRank(e.display);
      if (r < bestRank) {
        best = e.display;
        bestRank = r;
      }
    }
    return best;
  }

  bool isTaxiShortlisted(int day, String taxiId) =>
      plan.value?.dayAt(day)?.taxiShortlist.any((s) => s.taxiId == taxiId) ?? false;

  int taxiShortlistCount(int day) => plan.value?.dayAt(day)?.taxiShortlist.length ?? 0;

  bool toggleTaxiShortlist(int day, TaxiBrowseItem t, {bool wholeTrip = true}) {
    final p = plan.value;
    final d = p?.dayAt(day);
    if (p == null || d == null || !canEditDay(day)) return true;
    if (isTaxiShortlisted(day, t.id)) {
      removeTaxiShortlist(day, t.id);
      return true;
    }
    if (d.taxiShortlist.length >= TripConstants.maxShortlist) return false;
    final item = TripTaxiShortlistItem(
      taxiId: t.id,
      name: t.driverName,
      vehicleTypeName: t.vehicleTypeName.isEmpty ? null : t.vehicleTypeName,
      seats: t.seats,
      localDayRate: t.localDayRate,
      wholeTrip: wholeTrip,
    );
    _applyChoice([for (final x in p.days) x.day == day ? x.copyWith(taxiShortlist: [...x.taxiShortlist, item]) : x]);
    return true;
  }

  List<TripTaxiShortlistItem> sendableTaxiShortlist(int day) {
    final items = plan.value?.dayAt(day)?.taxiShortlist ?? const <TripTaxiShortlistItem>[];
    if (items.isEmpty) return const [];
    final asked = {
      for (final e in taxiEnquiriesForDay(day))
        if (e.isOpen) e.listingId,
    };
    return items.where((s) => !asked.contains(s.taxiId)).toList();
  }

  void removeTaxiShortlist(int day, String taxiId) {
    final p = plan.value;
    if (p == null) return;
    _applyChoice([
      for (final x in p.days)
        x.day == day ? x.copyWith(taxiShortlist: x.taxiShortlist.where((i) => i.taxiId != taxiId).toList()) : x,
    ]);
  }

  void clearTaxiShortlist(int day) {
    final p = plan.value;
    if (p == null || (p.dayAt(day)?.taxiShortlist.isEmpty ?? true)) return;
    _applyChoice([for (final x in p.days) x.day == day ? x.copyWith(taxiShortlist: const []) : x]);
  }

  void setOwnTaxi({required List<int> days, required String name, String? phone, String? note, int? farePerDay}) {
    final p = plan.value;
    if (p == null) return;
    final ph = phone?.trim();
    final nt = note?.trim();
    final own = TripTaxiChoice.own(
      name: name.trim(),
      phone: ph == null || ph.isEmpty ? null : ph,
      note: nt == null || nt.isEmpty ? null : nt,
      fare: farePerDay == null || farePerDay <= 0 ? null : farePerDay,
    );
    final chosen = {
      for (final d in days)
        if (p.dayAt(d) != null && canEditDay(d) && bookedTaxiEnquiryFor(d) == null) d,
    };
    if (chosen.isEmpty) return;
    _applyChoice([
      for (final x in p.days) chosen.contains(x.day) ? x.copyWith(taxi: own, taxiShortlist: const []) : x,
    ]);
  }

  void clearOwnTaxi(int day) {
    final p = plan.value;
    if (p == null || !(p.dayAt(day)?.taxi?.isOwn ?? false) || !canEditDay(day)) return;
    _applyChoice([for (final x in p.days) x.day == day ? x.copyWith(clearTaxi: true) : x]);
  }

  void selectStay(int day, StayNearbyModel s) {
    final p = plan.value;
    if (p == null || !canEditDay(day)) return;
    final choice = TripStayChoice(
      stayId: s.id,
      name: s.title,
      pricePerNight: s.minPricePerNight,
      latitude: s.latitude,
      longitude: s.longitude,
    );
    final copy = TripStayChoice(
      stayId: s.id,
      name: s.title,
      pricePerNight: s.minPricePerNight,
      sameAsDay: day,
      latitude: s.latitude,
      longitude: s.longitude,
    );
    final laterEmpty = p.days.where((d) => d.day > day).every((d) => d.stay == null);
    final prefill = day == 1 || laterEmpty;
    _applyChoice([
      for (final d in p.days)
        if (d.day == day)
          d.copyWith(stay: choice)
        else if (d.day > day &&
            (d.stay?.sameAsDay == day || (prefill && (d.stay == null || d.stay!.isSameStay))))
          d.copyWith(stay: copy)
        else
          d,
    ]);
  }

  void fillStayCoordinates(Iterable<StayNearbyModel> items) {
    final p = plan.value;
    if (p == null) return;
    final byId = {for (final s in items) s.id: s};
    var changed = false;
    final days = <TripDay>[];
    for (final d in p.days) {
      final stay = d.stay;
      final s = stay == null || stay.hasCoordinates ? null : byId[stay.stayId];
      if (stay != null && s != null) {
        changed = true;
        days.add(d.copyWith(stay: stay.copyWith(latitude: s.latitude, longitude: s.longitude)));
      } else {
        days.add(d);
      }
    }
    if (changed) _applyChoice(days);
  }

  void bookTaxi({required TaxiBrowseItem taxi, required TripTaxiBooking booking}) {
    final p = plan.value;
    if (p == null) return;
    final valid = booking.days.where((d) => p.dayAt(d) != null).toSet().toList()..sort();
    if (valid.isEmpty) return;
    final b = booking.copyWith(days: valid);
    final choice = TripTaxiChoice(
      taxiId: taxi.id,
      name: taxi.driverName,
      fare: (b.agreedFare / valid.length).round(),
      vehicleTypeName: taxi.vehicleTypeName.isEmpty ? null : taxi.vehicleTypeName,
      booking: b,
    );
    final days = [
      for (final d in p.days)
        if (valid.contains(d.day))
          d.copyWith(taxi: choice)
        else if (_booking(d, replacedBy: taxi.id, days: valid))
          d.copyWith(clearTaxi: true)
        else
          d,
    ];
    plan.value = p.copyWith(
      days: days,
      settings: p.settings.copyWith(pickupTime: b.pickupTime, pickupPlace: b.pickupPlace),
    );
    scheduleSave();
  }

  bool _booking(TripDay d, {required String replacedBy, required List<int> days}) {
    final t = d.taxi;
    final b = t?.booking;
    if (t == null || b == null) return false;
    return t.taxiId == replacedBy || b.days.any(days.contains);
  }

  void clearTaxiBooking(String taxiId) {
    final p = plan.value;
    if (p == null) return;
    _applyChoice([
      for (final d in p.days)
        if (d.taxi?.taxiId == taxiId && d.taxi!.isBooked && bookedTaxiEnquiryFor(d.day) == null)
          d.copyWith(clearTaxi: true)
        else
          d,
    ]);
  }

  Future<SettingsSaveResult> saveSettings(TripSettings next) async {
    final p = plan.value;
    if (p == null || isReadOnly) return const SettingsSaveResult(saved: false);
    final old = p.settings;
    final replan = next.dayLimitMinutes != old.dayLimitMinutes || next.startDateIso != old.startDateIso;
    final redo = next.maxDays != old.maxDays;
    final peopleChanged = next.adults != old.adults || next.kids != old.kids || next.rooms != old.rooms;
    final confirmed = <TripEnquiryModel>[];
    final open = <TripEnquiryModel>[];
    if (peopleChanged) {
      for (final e in enquiryList) {
        if (!e.isOpen) continue;
        if (!e.isTaxi && e.isConfirmed) {
          confirmed.add(e);
        } else if (!e.isBooked) {
          open.add(e);
        }
      }
      confirmed.sort(_newestFirst);
      open.sort(_newestFirst);
    }
    plan.value = p.copyWith(settings: next);
    if (redo) {
      unawaited(autoPlan());
    } else if (replan) {
      if (isPlanning.value && _lastPlanWasAuto) {
        _settingsChangedWhilePlanning = true;
      } else {
        recalculate();
      }
    }
    scheduleSave();
    return SettingsSaveResult(saved: true, confirmedAffected: confirmed, openAffected: open);
  }

  void clearStay(int day) {
    final p = plan.value;
    if (p == null || !canEditDay(day)) return;
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

  List<TripEnquiryModel> get enquiries => enquiryList;

  static int _newestFirst(TripEnquiryModel a, TripEnquiryModel b) {
    final x = a.createdAt;
    final y = b.createdAt;
    if (x == null || y == null) return 0;
    return y.compareTo(x);
  }

  static bool _sameDate(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  List<TripEnquiryModel> enquiriesForNight(int day) {
    final date = dateOf(day);
    return enquiryList
        .where((e) => e.kind == TripEnquiryKinds.stay && (date != null ? e.coversDate(date) : e.day == day))
        .toList()
      ..sort(_newestFirst);
  }

  List<TripEnquiryModel> get enquiriesOutsideDates {
    final start = settings.startDate;
    final end = checkOutDate;
    if (start == null || end == null) return const [];
    return enquiryList.where((e) => e.isOpen && _outsideWindow(e, start, end)).toList()..sort(_newestFirst);
  }

  static int _rank(TripDisplayStatus s) => switch (s) {
        TripDisplayStatus.confirmedByBoth => 0,
        TripDisplayStatus.confirmedByYou => 1,
        TripDisplayStatus.offered => 2,
        TripDisplayStatus.asked => 3,
        _ when s.isRed => 4,
        TripDisplayStatus.closed => 5,
        _ => 6,
      };

  TripEnquiryModel? primaryEnquiry(int day) {
    TripEnquiryModel? best;
    var bestRank = 99;
    for (final e in enquiriesForNight(day)) {
      if (e.isRed && dismissedRed.contains(e.id)) continue;
      final r = _rank(e.display);
      if (r < bestRank) {
        best = e;
        bestRank = r;
      }
    }
    return best;
  }

  int? get firstRedDay {
    for (final d in plan.value?.days ?? const <TripDay>[]) {
      if (primaryEnquiry(d.day)?.isRed ?? false) return d.day;
    }
    return null;
  }

  List<TripEnquiryModel> taxiEnquiriesForDay(int day) {
    final date = dateOf(day);
    return enquiryList
        .where((e) => e.isTaxi && (date != null && e.checkIn != null ? e.coversTaxiDate(date) : e.days.contains(day)))
        .toList()
      ..sort(_newestFirst);
  }

  List<int> _planDaysOf(TripEnquiryModel e, List<TripDay> days) {
    if (settings.hasDates && e.checkIn != null) {
      return [
        for (final d in days)
          if (e.coversTaxiDate(dateOf(d.day)!)) d.day,
      ];
    }
    return [
      for (final d in days)
        if (e.days.contains(d.day)) d.day,
    ];
  }

  static int _taxiRank(TripDisplayStatus s) => switch (s) {
        TripDisplayStatus.confirmedByBoth => 0,
        TripDisplayStatus.bookedByYou => 1,
        TripDisplayStatus.fareSent => 2,
        TripDisplayStatus.asked => 3,
        _ when s.isRed => 4,
        TripDisplayStatus.closed => 5,
        _ => 6,
      };

  TripEnquiryModel? primaryTaxiEnquiry(int day) {
    TripEnquiryModel? best;
    var bestRank = 99;
    for (final e in taxiEnquiriesForDay(day)) {
      if (e.isRed && dismissedRed.contains(e.id)) continue;
      final r = _taxiRank(e.display);
      if (r < bestRank) {
        best = e;
        bestRank = r;
      }
    }
    return best;
  }

  int? get firstRedTaxiDay {
    for (final d in plan.value?.days ?? const <TripDay>[]) {
      if (primaryTaxiEnquiry(d.day)?.isRed ?? false) return d.day;
    }
    return null;
  }

  void dismissRedTaxi(int day) {
    final e = primaryTaxiEnquiry(day);
    if (e != null && e.isRed) dismissedRed.add(e.id);
  }

  bool get hasOpenAdvance => enquiryList.any((e) => !e.isTaxi && e.isConfirmedByBoth && e.advance.isOpenRequest);

  Future<void> syncLegacyTaxiBookings() async {
    final tripId = trip.value?.id;
    final p = plan.value;
    if (tripId == null || p == null || !p.settings.hasDates || _legacySynced.contains(tripId)) return;
    _legacySynced.add(tripId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final seen = <String>{};
    for (final d in p.days) {
      final t = d.taxi;
      final b = t?.booking;
      if (t == null || b == null || t.isOwn || t.taxiId.isEmpty || !seen.add(t.taxiId)) continue;
      if (enquiryList.any((e) => e.isTaxi && e.listingId == t.taxiId)) continue;
      final bookedDays = b.days.where((x) => p.dayAt(x) != null).toList()..sort();
      if (bookedDays.isEmpty || b.agreedFare < TaxiOptionSets.minFare) continue;
      final allFuture = bookedDays.every((x) {
        final date = dateOf(x);
        return date != null && !date.isBefore(today);
      });
      if (!allFuture) continue;
      final place = (b.pickupPlace ?? p.settings.pickupPlace ?? '').trim();
      if (place.isEmpty) continue;
      await TripEnquiryController.to.syncTaxiBooking(
        tripId,
        taxiId: t.taxiId,
        days: bookedDays,
        agreedFare: b.agreedFare,
        tollExtra: b.tollExtra,
        pickupTime: b.pickupTime ?? p.settings.pickupTime ?? TripConstants.defaultPickupTime,
        pickupPlace: place,
      );
      if (trip.value?.id != tripId) return;
    }
  }

  void dismissRed(int day) {
    final e = primaryEnquiry(day);
    if (e == null || !e.isRed) return;
    dismissedRed.add(e.id);
    final stay = plan.value?.dayAt(day)?.stay;
    if (stay != null && !stay.isOwn && stay.stayId == e.listingId) clearStay(day);
  }

  void rememberLink(TripPhoneBookingResult r) {
    if (r.enquiry.id.isNotEmpty && r.confirmLink.isNotEmpty) confirmLinks[r.enquiry.id] = r;
  }

  void applyEnquiries(Iterable<TripEnquiryModel> items) {
    final tripId = trip.value?.id;
    var changed = false;
    for (final e in items) {
      if (e.id.isEmpty || (tripId != null && e.tripId != null && e.tripId != tripId)) continue;
      final i = enquiryList.indexWhere((x) => x.id == e.id);
      if (i >= 0) {
        enquiryList[i] = e;
      } else {
        enquiryList.insert(0, e);
      }
      changed = true;
    }
    if (!changed) return;
    final t = trip.value;
    if (t != null) trip.value = t.copyWith(enquiries: enquiryList.toList());
    reconcilePlan();
  }

  void reconcilePlan() {
    final p = plan.value;
    if (p == null || p.days.isEmpty) return;
    final days = [...p.days];
    final taxiChanged = _reconcileTaxis(days);
    final stayChanged = p.settings.hasDates && _reconcileStays(days);
    if (!taxiChanged && !stayChanged) return;
    plan.value = p.copyWith(days: days);
    scheduleSave();
  }

  bool _reconcileTaxis(List<TripDay> days) {
    var changed = false;
    int? indexOf(int day) {
      for (var i = 0; i < days.length; i++) {
        if (days[i].day == day) return i;
      }
      return null;
    }

    final claimed = <int>{};
    final booked = enquiryList
        .where((e) => e.isTaxi && (e.isBookedByYou || e.display == TripDisplayStatus.confirmedByBoth))
        .toList()
      ..sort(_newestFirst);
    for (final e in booked) {
      final fare = e.taxi?.agreedFare;
      if (fare == null || e.days.isEmpty) continue;
      final covered = _planDaysOf(e, days);
      for (final day in covered) {
        final i = indexOf(day);
        if (i == null || claimed.contains(i)) continue;
        claimed.add(i);
        final cur = days[i].taxi;
        final same = cur != null && !cur.isOwn && cur.taxiId == e.listingId;
        final b = cur?.booking;
        final t = e.taxi!;
        final upToDate = same &&
            b != null &&
            b.agreedFare == fare &&
            b.tollExtra == t.tollExtra &&
            b.pickupTime == t.pickupTime &&
            b.pickupPlace == t.pickupPlace &&
            listEquals(b.days, covered);
        if (upToDate) continue;
        days[i] = days[i].copyWith(
          taxi: TripTaxiChoice(
            taxiId: e.listingId,
            name: e.listingName,
            fare: (fare / e.days.length).ceil(),
            vehicleTypeName: same ? cur.vehicleTypeName : null,
            booking: TripTaxiBooking(
              agreedFare: fare,
              tollExtra: t.tollExtra,
              pickupTime: t.pickupTime,
              pickupPlace: t.pickupPlace,
              days: covered,
              note: same ? b?.note : null,
              bookedAt: t.bookedAt,
            ),
          ),
        );
        changed = true;
      }
    }
    for (final e in enquiryList) {
      if (!e.isTaxi || !_taxiTerminal(e.display)) continue;
      for (final day in _planDaysOf(e, days)) {
        final i = indexOf(day);
        if (i == null || claimed.contains(i)) continue;
        final cur = days[i].taxi;
        if (cur != null && !cur.isOwn && cur.isBooked && cur.taxiId == e.listingId) {
          days[i] = days[i].copyWith(clearTaxi: true);
          changed = true;
        }
      }
    }
    final serverIds = {
      for (final e in enquiryList)
        if (e.isTaxi && e.isBooked) e.listingId,
    };
    for (var i = 0; i < days.length; i++) {
      if (claimed.contains(i)) continue;
      final cur = days[i].taxi;
      if (cur != null && !cur.isOwn && cur.isBooked && serverIds.contains(cur.taxiId)) {
        days[i] = days[i].copyWith(clearTaxi: true);
        changed = true;
      }
    }
    return changed;
  }

  static bool _taxiTerminal(TripDisplayStatus s) =>
      s == TripDisplayStatus.cancelled ||
      s == TripDisplayStatus.notMe ||
      s == TripDisplayStatus.notAvailable ||
      s == TripDisplayStatus.expired ||
      s == TripDisplayStatus.closed;

  bool _reconcileStays(List<TripDay> days) {
    var changed = false;
    int? indexFor(DateTime date) {
      for (var i = 0; i < days.length; i++) {
        if (_sameDate(dateOf(days[i].day), date)) return i;
      }
      return null;
    }

    final claimed = <int>{};
    final confirmed = enquiryList
        .where((e) => e.kind == TripEnquiryKinds.stay && e.display.isConfirmed && e.checkIn != null)
        .toList()
      ..sort(_newestFirst);
    for (final e in confirmed) {
      final ci = e.checkIn!;
      final nights = e.nights;
      final total = e.agreedTotal;
      final price = total == null ? null : (total / nights).ceil();
      int? firstDay;
      for (var k = 0; k < nights; k++) {
        final i = indexFor(DateTime(ci.year, ci.month, ci.day + k));
        if (i == null || claimed.contains(i)) continue;
        claimed.add(i);
        final d = days[i];
        final want = TripStayChoice(
          stayId: e.listingId,
          name: e.listingName,
          pricePerNight: price,
          sameAsDay: firstDay,
          latitude: e.listingLatitude != null && e.listingLongitude != null ? e.listingLatitude : null,
          longitude: e.listingLatitude != null && e.listingLongitude != null ? e.listingLongitude : null,
        );
        firstDay ??= d.day;
        final cur = d.stay;
        if (cur == null ||
            cur.isOwn ||
            cur.stayId != want.stayId ||
            cur.pricePerNight != want.pricePerNight ||
            cur.sameAsDay != want.sameAsDay) {
          days[i] = d.copyWith(stay: want);
          changed = true;
        }
      }
    }
    for (final e in enquiryList) {
      final ci = e.checkIn;
      if (e.kind != TripEnquiryKinds.stay || e.isOpen || ci == null) continue;
      for (var k = 0; k < e.nights; k++) {
        final i = indexFor(DateTime(ci.year, ci.month, ci.day + k));
        if (i == null || claimed.contains(i)) continue;
        final cur = days[i].stay;
        if (cur != null && !cur.isOwn && cur.stayId == e.listingId) {
          days[i] = days[i].copyWith(clearStay: true);
          changed = true;
        }
      }
    }
    for (var i = 0; i < days.length; i++) {
      final s = days[i].stay;
      final same = s?.sameAsDay;
      if (s == null || same == null) continue;
      final target = days.where((d) => d.day == same).firstOrNull?.stay;
      if (target == null || target.stayId != s.stayId) {
        days[i] = days[i].copyWith(stay: s.copyWith(clearSameAsDay: true));
        changed = true;
      }
    }
    return changed;
  }

  Future<void> refreshEnquiries() async {
    final id = trip.value?.id;
    if (id == null) return;
    final seq = ++_enquirySeq;
    final flow = _flow;
    enquiriesLoading.value = true;
    try {
      final t = await _repo.get(id);
      if (flow != _flow || seq != _enquirySeq) return;
      TripTodayCache.saveTrip(t);
      enquiryList.assignAll(t.enquiries);
      trip.value = (trip.value ?? t).copyWith(enquiries: t.enquiries);
      enquiriesFailed.value = false;
      offline.value = false;
      reconcilePlan();
      unawaited(flushProblemQueue());
    } catch (e) {
      if (flow != _flow || seq != _enquirySeq) return;
      if (_isPlannerOff(e)) {
        plannerOff.value = true;
      } else if (!_isUnauthorized(e)) {
        if (DioErrorMapper.isNetworkError(e)) offline.value = true;
        enquiriesFailed.value = true;
      }
    } finally {
      if (seq == _enquirySeq) enquiriesLoading.value = false;
    }
  }

  bool isShortlisted(int day, String stayId) =>
      plan.value?.dayAt(day)?.stayShortlist.any((s) => s.stayId == stayId) ?? false;

  int shortlistCount(int day) => plan.value?.dayAt(day)?.stayShortlist.length ?? 0;

  Set<String> get unavailableStayIds {
    if (!Get.isRegistered<TripSupplyController>()) return const {};
    return {for (final s in Get.find<TripSupplyController>().stays) if (!s.isActive) s.id};
  }

  List<TripStayShortlistItem> sendableShortlist(int day) {
    final items = plan.value?.dayAt(day)?.stayShortlist ?? const <TripStayShortlistItem>[];
    if (items.isEmpty) return const [];
    final off = unavailableStayIds;
    final asked = {
      for (final e in enquiriesForNight(day))
        if (e.isOpen) e.listingId,
    };
    return items.where((s) => !off.contains(s.stayId) && !asked.contains(s.stayId)).toList();
  }

  bool toggleShortlist(int day, StayNearbyModel s) {
    final p = plan.value;
    final d = p?.dayAt(day);
    if (p == null || d == null || !canEditDay(day)) return true;
    if (isShortlisted(day, s.id)) {
      removeShortlist(day, s.id);
      return true;
    }
    if (d.stayShortlist.length >= TripConstants.maxShortlist) return false;
    final item = TripStayShortlistItem(
      stayId: s.id,
      name: s.title,
      pricePerNight: s.minPricePerNight,
      latitude: s.latitude,
      longitude: s.longitude,
      distanceKm: s.distanceKm,
    );
    final copy = item.copyWith(sameAsDay: day);
    final laterEmpty = p.days.where((x) => x.day > day).every((x) => x.stayShortlist.isEmpty);
    final prefill = day == 1 || laterEmpty;
    bool follows(TripDay x) =>
        x.stayShortlist.isEmpty ? prefill : x.stayShortlist.every((i) => i.sameAsDay == day);
    _applyChoice([
      for (final x in p.days)
        if (x.day == day)
          x.copyWith(stayShortlist: [...x.stayShortlist, item])
        else if (x.day > day &&
            x.stay == null &&
            follows(x) &&
            x.stayShortlist.length < TripConstants.maxShortlist &&
            !x.stayShortlist.any((i) => i.stayId == s.id))
          x.copyWith(stayShortlist: [...x.stayShortlist, copy])
        else
          x,
    ]);
    return true;
  }

  void removeShortlist(int day, String stayId) {
    final p = plan.value;
    if (p == null) return;
    _applyChoice([
      for (final x in p.days)
        if (x.day == day)
          x.copyWith(stayShortlist: x.stayShortlist.where((i) => i.stayId != stayId).toList())
        else if (x.day > day && x.stayShortlist.any((i) => i.stayId == stayId && i.sameAsDay == day))
          x.copyWith(
              stayShortlist: x.stayShortlist.where((i) => !(i.stayId == stayId && i.sameAsDay == day)).toList())
        else
          x,
    ]);
  }

  void clearShortlist(int day) {
    final ids = plan.value?.dayAt(day)?.stayShortlist.map((s) => s.stayId).toList() ?? const <String>[];
    for (final id in ids) {
      removeShortlist(day, id);
    }
  }

  List<int> enquiryNightsRun(int day) {
    final p = plan.value;
    if (p == null || p.dayAt(day) == null) return const [];
    final run = [day];
    for (var d = day + 1; d <= dayCount; d++) {
      final stay = p.dayAt(d)?.stay;
      if (!canEditDay(d) ||
          ownStayOf(d) != null ||
          (stay != null && stay.isSkipped) ||
          enquiriesForNight(d).any((e) => e.isBooked)) {
        break;
      }
      run.add(d);
    }
    return run;
  }

  List<int> ownStayNights(int day, {bool allNights = false}) {
    final p = plan.value;
    if (p == null || p.dayAt(day) == null) return const [];
    if (!allNights) return [day];
    return [
      day,
      for (final x in p.days)
        if (x.day > day &&
            canEditDay(x.day) &&
            (x.stay == null || x.stay!.isSameStay) &&
            !enquiriesForNight(x.day).any((e) => e.isBooked))
          x.day,
    ];
  }

  OwnSaveResult setOwnStay(int day, {required String name, String? phone, String? note, bool allNights = false}) {
    final p = plan.value;
    if (p == null || p.dayAt(day) == null || !canEditDay(day)) return const OwnSaved();
    final nights = ownStayNights(day, allNights: allNights);
    final rows = <TripEnquiryModel>{
      for (final n in nights) ...enquiriesForNight(n).where((e) => e.isOpen),
    }.toList()
      ..sort(_newestFirst);
    final confirmed = rows.where((e) => e.isBooked).firstOrNull;
    if (confirmed != null) return OwnBlockedByConfirmed(confirmed);
    if (rows.isNotEmpty) return OwnNeedsWithdraw(rows);
    final ph = phone?.trim();
    final nt = note?.trim();
    final own = TripStayChoice(
      stayId: '',
      name: name.trim(),
      isOwn: true,
      ownPhone: ph == null || ph.isEmpty ? null : ph,
      note: nt == null || nt.isEmpty ? null : nt,
    );
    final copy = TripStayChoice(
      stayId: '',
      name: own.name,
      isOwn: true,
      ownPhone: own.ownPhone,
      note: own.note,
      sameAsDay: day,
    );
    final later = nights.where((n) => n != day).toSet();
    _applyChoice([
      for (final x in p.days)
        if (x.day == day)
          x.copyWith(stay: own, stayShortlist: const [])
        else if (later.contains(x.day))
          x.copyWith(stay: copy, stayShortlist: const [])
        else if (x.stay?.sameAsDay == day)
          x.copyWith(stay: x.stay!.copyWith(clearSameAsDay: true))
        else
          x,
    ]);
    return const OwnSaved();
  }

  void clearOwnStay(int day) {
    final p = plan.value;
    final stay = p?.dayAt(day)?.stay;
    if (p == null || stay == null || !stay.isOwn || !canEditDay(day)) return;
    final base = stay.sameAsDay ?? day;
    _applyChoice([
      for (final x in p.days)
        if (x.day == day || (stay.sameAsDay == null && x.stay != null && x.stay!.isOwn && x.stay!.sameAsDay == base))
          x.copyWith(clearStay: true)
        else
          x,
    ]);
  }

  bool setSameAsLastNight(int day) {
    final p = plan.value;
    if (p == null || day <= 1 || p.dayAt(day) == null || !canEditDay(day)) return false;
    var prev = p.dayAt(day - 1)?.stay;
    var baseDay = prev?.sameAsDay ?? day - 1;
    if (prev == null) {
      final e = primaryEnquiry(day - 1);
      if (e == null || !e.isBooked || e.isTaxi) return false;
      final total = e.agreedTotal;
      prev = TripStayChoice(
        stayId: e.listingId,
        name: e.listingName,
        pricePerNight: total == null ? null : (total / e.nights).ceil(),
        latitude: e.listingLatitude != null && e.listingLongitude != null ? e.listingLatitude : null,
        longitude: e.listingLatitude != null && e.listingLongitude != null ? e.listingLongitude : null,
      );
      baseDay = day - 1;
    }
    if (prev.isSkipped) return false;
    final copy = TripStayChoice(
      stayId: prev.stayId,
      name: prev.name,
      pricePerNight: prev.pricePerNight,
      sameAsDay: baseDay,
      latitude: prev.latitude,
      longitude: prev.longitude,
      isOwn: prev.isOwn,
      ownPhone: prev.ownPhone,
      note: prev.note,
    );
    _applyChoice([
      for (final x in p.days)
        if (x.day == day)
          x.copyWith(stay: copy, stayShortlist: const [])
        else if (x.stay?.sameAsDay == day)
          x.copyWith(stay: x.stay!.copyWith(clearSameAsDay: true))
        else
          x,
    ]);
    return true;
  }

  TripStayChoice? sameAsLastNightBase(int day) {
    if (day <= 1) return null;
    final prev = plan.value?.dayAt(day - 1)?.stay;
    if (prev != null) return prev.isSkipped ? null : prev;
    final e = primaryEnquiry(day - 1);
    if (e == null || !e.isBooked || e.isTaxi) return null;
    return TripStayChoice(stayId: e.listingId, name: e.listingName);
  }

  void setSkippedNight(int day) {
    final p = plan.value;
    if (p == null || p.dayAt(day) == null || !canEditDay(day)) return;
    _applyChoice([
      for (final x in p.days)
        if (x.day == day)
          x.copyWith(stay: const TripStayChoice.skippedNight(), stayShortlist: const [])
        else if (x.stay?.sameAsDay == day)
          x.copyWith(stay: x.stay!.copyWith(clearSameAsDay: true))
        else
          x,
    ]);
  }

  void clearSkippedNight(int day) {
    if (plan.value?.dayAt(day)?.stay?.isSkipped ?? false) clearStay(day);
  }

  List<StayNearbyModel>? shortlistAsModels(int day) {
    final items = plan.value?.dayAt(day)?.stayShortlist ?? const <TripStayShortlistItem>[];
    if (items.isEmpty) return null;
    return [
      for (final s in items)
        StayNearbyModel(
          id: s.stayId,
          name: s.name,
          latitude: s.latitude ?? 0,
          longitude: s.longitude ?? 0,
          minPricePerNight: s.pricePerNight,
          distanceKm: s.distanceKm ?? 0,
          isActive: !unavailableStayIds.contains(s.stayId),
        ),
    ];
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
      taxiSupply.value = trip.value == null ? null : false;
      return;
    }
    if (taxiTabOff.value) return;
    try {
      final page = await const TaxiBrowseRepository().browseLocal(districtId: districtId, localRate: true, pageSize: 1);
      if (seq != _supplySeq) return;
      cityHasTaxis.value = page.items.isNotEmpty;
      taxiSupply.value = page.items.isNotEmpty;
    } catch (e) {
      if (seq != _supplySeq) return;
      if (DioErrorMapper.errorType(e) == ApiService.tabInactiveType) taxiTabOff.value = true;
    }
  }

  bool get _saveBlocked => plannerOff.value || tripGone.value || needsUpdate.value || isCompleted;

  void scheduleSave() {
    if (_saveBlocked || plan.value == null) return;
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
    if (_saveBlocked || plan.value == null) return false;
    final creating = _creating;
    if (creating != null) await creating;
    while (_saving != null) {
      await _saving;
    }
    if (_saveBlocked || plan.value == null) return false;
    final f = _save(markPlanned);
    _saving = f;
    try {
      return await f;
    } finally {
      if (identical(_saving, f)) _saving = null;
    }
  }

  String _statusFor(bool markPlanned, TripPlan p) {
    if (isCompleted) return TripStatuses.planned;
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
          ? await _repo.create(title: _title, status: _statusFor(markPlanned, p), plan: p, clientTripId: _clientTripId)
          : await _update(current.id, _title, _statusFor(markPlanned, p), p);
      if (flow != _flow) return false;
      trip.value = saved.copyWith(enquiries: enquiryList.toList());
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
      final id = trip.value?.id;
      final type = DioErrorMapper.errorType(e);
      if (id != null && type == TripErrorTypes.tripNotFound) {
        _markGone(id);
        return false;
      }
      if (type == TripErrorTypes.tripNeedsUpdate) {
        _saveTimer?.cancel();
        needsUpdate.value = true;
        return false;
      }
      if (type == TripErrorTypes.tripCompleted) {
        _saveTimer?.cancel();
        final t = trip.value;
        if (t != null) trip.value = t.copyWith(status: TripStatuses.completed);
        AppToast.warning(TripStrings.tripCompletedEdits);
        return false;
      }
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
      if (DioErrorMapper.errorType(e) == TripErrorTypes.concurrentUpdate) {
        await _repo.get(id);
        return _repo.update(id, title: title, status: status, plan: p);
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
      StorageService.clearTripCache(id);
    }
    _reset();
    return true;
  }

  Future<void> releaseIfIdle() async {
    if (openPages > 0) return;
    await flushPendingSave();
    if (openPages > 0 || !Get.isRegistered<TripPlanController>()) return;
    if (!identical(Get.find<TripPlanController>(), this)) return;
    if (Get.isRegistered<MyTripsController>()) Get.find<MyTripsController>().load();
    if (Get.isRegistered<TripEnquiryController>()) Get.delete<TripEnquiryController>(force: true);
    Get.delete<TripPlanController>(force: true);
  }
}
