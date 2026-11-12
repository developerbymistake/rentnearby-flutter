import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import '../../../config/app_tabs.dart';
import '../../../controllers/location_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../models/browse_item.dart';
import '../../../models/place_result_model.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../taxi/ways/taxi_ways_controller.dart';
import '../../taxi/guest/taxi_browse_repository.dart';
import '../../taxi/guest/traveller_city.dart';
import '../../taxi/journeys/journey_models.dart';
import '../../taxi/journeys/journeys_controller.dart';
import '../../taxi/ways/models/ask_models.dart';
import '../../taxi/ways/trip_strings_mcb_a2.dart';
import '../data/trip_city_catalog.dart';
import '../data/trip_enquiry_repository.dart';
import '../data/trip_repository.dart';
import '../data/trip_segment_geometry_cache.dart';
import '../data/trip_today_cache.dart';
import '../models/trip_city_model.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_plan_result_model.dart';
import '../models/trip_spot_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_mca_a1.dart';
import '../trip_strings_mcb_a1.dart';
import '../trip_strings_mcb_k1.dart';
import '../trip_strings_steps_a3.dart';
import '../trip_strings_steps_k3.dart';
import '../trip_strings_v2_create.dart';
import '../trip_strings_v2_plan.dart';
import '../utils/trip_supply_area.dart';
import '../utils/trip_clock.dart';
import '../utils/trip_easy_rules.dart';
import '../utils/trip_days_rules.dart';
import '../utils/trip_day_load.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_guide_rules.dart';
import '../utils/trip_map_rules.dart';
import '../utils/trip_stay_base.dart';
import '../utils/trip_step_rules.dart';
import '../utils/trip_travel_rules.dart';
import '../utils/trip_whatsapp_text.dart';
import '../widgets/trip_status.dart';
import 'my_trips_controller.dart';
import 'trip_enquiry_controller.dart';
import 'trip_plan_guide.dart';
import 'trip_shortlist_controller.dart';
import 'trip_supply_controller.dart';

enum TripDayRemoveBlock { none, lastDay, placesDontFit, readOnly }

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
  final editMode = false.obs;
  static const int mapAll = 0;
  final selectedMapDay = 1.obs;
  final selectedMapLeg = 0.obs;
  final enquiryList = <TripEnquiryModel>[].obs;
  final enquiriesLoading = false.obs;
  final enquiriesFailed = false.obs;
  final startChangedNotes = <int, String>{}.obs;
  final offline = false.obs;
  final problemBusy = false.obs;
  final askBusy = false.obs;
  final taxiSupplyByLeg = <int, bool?>{}.obs;
  final citiesUnavailable = false.obs;
  Future<AskResult?> Function(String step, List<String> ids, String requestId)? carSender;
  Future<TaxiWaysController?> Function(TripEasyRowKey row)? carWays;
  final staySupplyByDistrict = <String, bool>{}.obs;
  final _stayProbing = <String>{};
  final supplyCheckFailed = <int>{}.obs;
  final lastAddedLeg = RxnInt();
  final travelGaps = <int, String?>{}.obs;
  final travelBusy = <int>{}.obs;
  final _supplyByDistrict = <String, bool>{};
  final _supplyInFlight = <String, Future<bool?>>{};
  final _supplyTried = <String>{};
  final unavailableCities = <int>{}.obs;
  final _legResults = <int, ({String body, TripPlanResult result})>{};
  Future<void> _legChain = Future<void>.value();
  ({int cityKey, int? maxDays, int? exactDays, bool keepDays})? _retryLeg;
  bool lastProblemQueued = false;
  ({bool dates, bool people, bool days}) lastSettingsChange = (dates: false, people: false, days: false);
  bool _spotsEdited = false;
  TripCityModel? picked;
  int openPages = 0;
  int _enquirySeq = 0;
  int _saveGen = 0;
  bool _startFromTried = false;
  final _pendingJourneyIds = <String>{};

  String? _title;
  String? _clientTripId;
  bool _settingsChangedWhilePlanning = false;
  String? _openingId;
  Future<TripModel?>? _creating;
  final ownPending = <String>{};
  bool _ownRetrying = false;

  @visibleForTesting
  Duration ownRetryDelay = const Duration(seconds: 8);
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
  Worker? _tripWorker;
  Worker? _legWorker;
  int? _daysSeen;
  int? _dayCountWas;
  Worker? _netWorker;
  AppLifecycleListener? _lifecycle;
  TripPlan? _pendingRetry;
  int _autoJobs = 0;
  bool _recalcAfterAuto = false;

  @override
  void onInit() {
    super.onInit();
    _tabWorker = ever(TabConfigController.to.version, (_) => checkSupply());
    _tripWorker = ever<TripModel?>(trip, _syncMyTrips);
    _legWorker = ever<TripPlan?>(plan, _trackDayCount);
    if (Get.isRegistered<LocationController>()) {
      _netWorker = ever<bool>(Get.find<LocationController>().isOffline, (off) {
        if (!off && offline.value) unawaited(retryConnection());
      });
    }
    _lifecycle = AppLifecycleListener(onHide: _toBackground, onPause: _toBackground, onDetach: _toBackground);
  }

  void _toBackground() => unawaited(flushForBackground());

  void _trackDayCount(TripPlan? p) {
    final now = p?.days.length;
    final seen = _daysSeen;
    if (now != null && seen != null && seen != now) {
      _dayCountWas ??= seen;
      if (trip.value != null && p?.settings.startDate != null) settingsChangedAt.value = DateTime.now();
    }
    _daysSeen = now;
  }

  void _syncMyTrips(TripModel? t) {
    if (t == null || !Get.isRegistered<MyTripsController>()) return;
    final my = Get.find<MyTripsController>();
    if (t.isCompleted) my.adoptCompleted(t.id, t.completedAt);
    my.adoptMuted(t.id, t.mutedAt);
  }

  @override
  void onClose() {
    _saveTimer?.cancel();
    _recalcTimer?.cancel();
    _recalcWaiter?.complete();
    _tabWorker?.dispose();
    _tripWorker?.dispose();
    _legWorker?.dispose();
    _netWorker?.dispose();
    _lifecycle?.dispose();
    if (Get.isRegistered<TripSupplyController>()) Get.delete<TripSupplyController>(force: true);
    super.onClose();
  }

  String get title {
    final fallback = TripStringsMcaA1.defaultTitle(plan.value?.legCities ?? [cityName]);
    final own = _title;
    if (own != null && own.isNotEmpty) return own;
    final t = trip.value?.title;
    if (t == null || t.isEmpty) return fallback;
    final stored = trip.value!;
    final storedDefault = t == TripStringsMcaA1.defaultTitle(stored.plan.legCities) ||
        t == TripStringsMcaA1.defaultTitle([stored.cityName]);
    return storedDefault ? fallback : t;
  }

  String get cityName => plan.value?.cityName ?? picked?.name ?? '';

  List<TripCityLeg> get legs => plan.value?.legs ?? const [];

  int get legCount => plan.value?.legCount ?? 1;

  bool get isMultiCity => plan.value?.isMultiCity ?? false;

  TripCityLeg legOf(int day) {
    final p = plan.value;
    if (p != null && p.legs.isNotEmpty) return p.legOf(day);
    return TripCityLeg(
      index: 1,
      cityKey: picked?.cityKey ?? 0,
      cityName: cityName,
      latitude: picked?.latitude ?? 0,
      longitude: picked?.longitude ?? 0,
    );
  }

  int legIndexOf(int day) => plan.value?.legIndexOf(day) ?? 1;

  bool isTravelDay(int day) => plan.value?.isTravelDay(day) ?? false;

  String cityNameOf(int day) {
    final p = plan.value;
    return p == null || !p.isMultiCity ? cityName : p.cityNameOf(day);
  }

  String? districtIdOf(int day) => plan.value?.districtIdOf(day);

  List<int> legDays(int legIndex) => [for (final d in plan.value?.daysOf(legIndex) ?? const <TripDay>[]) d.day];

  String get lastCityName {
    final p = plan.value;
    return p == null || p.legs.isEmpty ? cityName : p.legs.last.cityName;
  }

  PlaceResult? cityPlaceOf(int legIndex) {
    final p = plan.value;
    if (p == null || legIndex == 1 || !p.isMultiCity) return legIndex == 1 ? cityPlace : null;
    final leg = p.legAt(legIndex);
    if (leg == null || !leg.hasPoint || leg.cityName.isEmpty) return null;
    return leg.place;
  }

  PlaceResult? get lastCityPlace => cityPlaceOf(legCount);

  ({double lat, double lon})? get _lastPoint {
    final p = plan.value;
    if (p == null || !p.isMultiCity) return _cityPoint;
    final leg = p.legs.last;
    return leg.hasPoint ? (lat: leg.latitude, lon: leg.longitude) : null;
  }

  bool get endsInsideCity {
    final pt = _lastPoint;
    return TripStepRules.insideCity(startFrom, pt?.lat, pt?.lon);
  }

  bool legRunning(int legIndex) {
    for (final d in legDays(legIndex)) {
      if (isDayPast(d) || d == todayDay) return true;
    }
    return false;
  }

  int minDaysForLeg(int legIndex) => legRunning(legIndex) ? _pastDaysOf(legIndex) + 1 : 1;

  bool canEditLeg(int legIndex) => !isReadOnly && !legRunning(legIndex);

  bool legUnavailable(int legIndex) {
    final leg = plan.value?.legAt(legIndex);
    return leg != null && unavailableCities.contains(leg.cityKey);
  }

  bool canAddPlaces(int legIndex) {
    final leg = plan.value?.legAt(legIndex);
    return leg != null && !leg.notReady && !isReadOnly && !isCheckOutDay && !legUnavailable(legIndex);
  }

  void markLegReady(int legIndex) {
    final p = plan.value;
    final leg = p?.legAt(legIndex);
    if (p == null || leg == null || !leg.notReady) return;
    plan.value = p.copyWith(legs: [for (final l in p.legs) l.index == legIndex ? l.copyWith(notReady: false) : l]);
    scheduleSave();
  }

  Future<void> _refreshNotReadyLegs() async {
    final p = plan.value;
    if (p == null || !p.legs.any((l) => l.notReady)) return;
    final flow = _flow;
    try {
      final cities = await TripCityCatalog.to.load();
      if (flow != _flow) return;
      final ready = {for (final c in cities) if (c.isReady) c.cityKey};
      for (final l in plan.value?.legs ?? const <TripCityLeg>[]) {
        if (l.notReady && ready.contains(l.cityKey)) markLegReady(l.index);
      }
    } catch (_) {
      return;
    }
  }

  bool get _hasUnavailableLeg => plan.value?.legs.any((l) => unavailableCities.contains(l.cityKey)) ?? false;

  bool _legHasBookings(int legIndex, [Set<String> except = const {}]) {
    bool live(TripEnquiryModel e) => e.isOpen && !except.contains(e.id);
    for (final d in legDays(legIndex)) {
      if (enquiriesForNight(d).any(live) || taxiEnquiriesForDay(d).any(live)) return true;
    }
    return segmentRows(legIndex).any(live);
  }

  bool _hasOpenSegmentRows(int legIndex) => segmentRows(legIndex).any((e) => e.isOpen);

  bool _laterLegsHaveBookings(int legIndex, [Set<String> except = const {}]) {
    for (var k = legIndex + 1; k <= legCount; k++) {
      if (_legHasBookings(k, except)) return true;
    }
    return false;
  }

  WrongCityInfo? wrongCityOf(TripEnquiryModel e) {
    if (e.isSegment) return null;
    final p = plan.value;
    if (p != null) return TripEnquiryRules.wrongCity(e, p, p.settings);
    if (!e.wrongCity || e.wrongNights < 1) return null;
    return WrongCityInfo(
      wrong: e.wrongNights,
      total: e.wrongTotal < e.wrongNights ? e.wrongNights : e.wrongTotal,
      firstWrongDay: e.wrongFirstDay ?? e.day ?? 1,
      dayCity: e.wrongDayCity ?? '',
      homeLegIndex: WrongCityInfo.serverOnlyLeg,
      dayLegIndex: 0,
    );
  }

  int? wrongCityHomeLeg(WrongCityInfo info) {
    final k = info.homeLegIndex;
    return k >= 1 && plan.value?.legAt(k) != null ? k : null;
  }

  bool isOutsideTrip(TripEnquiryModel e) {
    final p = plan.value;
    if (p == null) return e.outsideTrip;
    return TripEnquiryRules.isOutsideTrip(e, p.settings, p.days.length);
  }

  List<TripEnquiryModel> get wrongCityRows =>
      [for (final e in enquiryList) if (e.isOpen && !e.isSegment && wrongCityOf(e) != null) e];

  bool _wrongOnDay(TripEnquiryModel e, int day) {
    if (!e.isOpen) return false;
    final info = wrongCityOf(e);
    return info != null && (info.homeLegIndex < 1 || info.homeLegIndex != legIndexOf(day));
  }

  bool wrongOnDay(TripEnquiryModel e, int day) => _wrongOnDay(e, day);

  TripEnquiryModel? wrongCityForDay(int day) {
    final stay = primaryEnquiry(day);
    if (stay != null && _wrongOnDay(stay, day)) return stay;
    for (final e in taxiEnquiriesForDay(day)) {
      if (_wrongOnDay(e, day)) return e;
    }
    return null;
  }

  List<TripEnquiryModel> _openRowsOnDays(Iterable<int> days) {
    final seen = <String>{};
    return [
      for (final d in days)
        for (final e in [...enquiriesForNight(d), ...taxiEnquiriesForDay(d)])
          if (e.isOpen && seen.add(e.id)) e,
    ];
  }

  List<TripEnquiryModel> _openCars(int legIndex) => [for (final e in segmentRows(legIndex)) if (e.isOpen) e];

  LegImpact _impactOf(
    List<TripEnquiryModel> rows,
    List<int> travelLegs, {
    required bool later,
    required List<String> cities,
    bool carsOrphaned = false,
    List<TripEnquiryModel> roleCars = const [],
  }) {
    final booked = <TripEnquiryModel>[];
    final open = <TripEnquiryModel>[];
    for (final e in rows) {
      (e.isBooked ? booked : open).add(e);
    }
    booked.sort(_newestFirst);
    open.sort(_newestFirst);
    final carIds = <String>{};
    final cars = <TripEnquiryModel>[
      for (final k in travelLegs)
        for (final e in _openCars(k))
          if (carIds.add(e.id)) e,
      for (final e in roleCars)
        if (carIds.add(e.id)) e,
    ];
    return LegImpact(
      open: open,
      booked: booked,
      cars: cars,
      travelLegs: travelLegs,
      laterKeepDates: later,
      laterCities: cities,
      carsBlockKeep: carsOrphaned && cars.isNotEmpty,
    );
  }

  List<String> _laterCitiesWithRows(int legIndex, [Set<String> except = const {}]) {
    final p = plan.value;
    if (p == null) return const [];
    return [
      for (var k = legIndex + 1; k <= p.legCount; k++)
        if (_legHasBookings(k, except)) ?p.legAt(k)?.cityName,
    ];
  }

  LegImpact legRemoveImpact(int legIndex) {
    final p = plan.value;
    if (p == null || p.legAt(legIndex) == null) return const LegImpact.empty();
    final rows = _openRowsOnDays(legDays(legIndex));
    final travel = [
      for (final k in [legIndex, legIndex + 1])
        if (p.legAt(k) != null && _openCars(k).isNotEmpty) k,
    ];
    final roleCars = [
      for (final r in TripStepRole.values)
        if ((r == TripStepRole.gettingThere ? legIndex == 1 : legIndex == p.legCount) && stepOf(r).hasJourney)
          for (final e in TripTravelRules.liveRowsOf(stepOf(r).journeyId!, enquiryList))
            if (e.isOpen) e,
    ];
    final leaving = {
      for (final e in rows) e.id,
      for (final k in travel)
        for (final e in _openCars(k)) e.id,
      for (final e in roleCars) e.id,
    };
    final later = _laterLegsHaveBookings(legIndex, leaving);
    return _impactOf(rows, travel,
        later: later,
        cities: later ? _laterCitiesWithRows(legIndex, leaving) : const [],
        carsOrphaned: true,
        roleCars: roleCars);
  }

  LegImpact legShrinkImpact(int legIndex, int days) {
    final p = plan.value;
    if (p == null || p.legAt(legIndex) == null) return const LegImpact.empty();
    final current = legDays(legIndex);
    final cut = days < 1 ? 1 : days;
    if (cut >= current.length) return const LegImpact.empty();
    final dropped = current.sublist(cut);
    final shifts = legIndex < p.legCount;
    final later = shifts && _laterLegsHaveBookings(legIndex);
    final rows = _openRowsOnDays([
      ...dropped,
      if (later)
        for (var k = legIndex + 1; k <= p.legCount; k++) ...legDays(k),
    ]);
    final travel = [
      if (shifts)
        for (var k = legIndex + 1; k <= p.legCount; k++)
          if (_openCars(k).isNotEmpty) k,
    ];
    return _impactOf(rows, travel, later: later, cities: later ? _laterCitiesWithRows(legIndex) : const []);
  }

  Future<LegCancelResult> cancelLegRows(LegImpact impact) async {
    final rows = [...impact.booked, ...impact.open, ...impact.cars];
    final total = rows.length;
    if (total == 0) return const LegCancelResult();
    if (offline.value || isReadOnly || impact.travelLegs.any(travelBusy.contains)) {
      return LegCancelResult(failed: total);
    }
    final enq = TripEnquiryController.to;
    var closed = 0;
    for (final e in rows) {
      if (!await enq.closeRow(e)) return LegCancelResult(closed: closed, failed: total - closed);
      closed++;
    }
    for (final k in impact.travelLegs) {
      _dropClosedJourney(k);
    }
    return LegCancelResult(closed: closed);
  }

  void _dropClosedJourney(int legIndex) {
    final a = _journeyArrival(legIndex);
    if (a == null || segmentRows(legIndex).any((e) => e.isOpen)) return;
    final id = a.journeyId;
    final never = _mayDeleteJourney(id, segmentJourney(legIndex));
    _setArrival(legIndex, null);
    _dropLocalJourney(id);
    travelGaps.remove(legIndex);
    if (never) unawaited(_deleteJourney(id));
  }

  Future<TripLegEditBlock> cancelAndRemoveLeg(int legIndex) async {
    final block = canRemoveLeg(legIndex);
    if (block != TripLegEditBlock.none) return block;
    final res = await cancelLegRows(legRemoveImpact(legIndex));
    if (!res.ok) return TripLegEditBlock.bookings;
    return removeLeg(legIndex, keepBookings: true);
  }

  Future<bool> cancelAndSetLegDays(int legIndex, int days) async {
    if (canSetLegDays(legIndex, days, keepBookings: true) != TripLegEditBlock.none) return false;
    final res = await cancelLegRows(legShrinkImpact(legIndex, days));
    if (!res.ok) return false;
    return setLegDays(legIndex, days, keepBookings: true);
  }

  bool supplyAvailableFor(int day) => TripSupplyArea.hasCity(legOf(day));

  static bool _isCitiesUnavailable(Object e) => DioErrorMapper.errorType(e) == TripErrorTypes.citiesUnavailable;

  bool supplyPendingFor(int day) => false;

  bool? taxiSupplyFor(int day) {
    final k = legIndexOf(day);
    if (k == 1 || !isMultiCity) return taxiSupply.value;
    if (!supplyAvailableFor(day)) return false;
    return taxiSupplyByLeg[k];
  }

  bool? staySupplyFor(int day) {
    final p = plan.value;
    return p == null ? null : staySupplyByDistrict[TripSupplyArea.keyOf(p.legAt(p.legIndexOf(day)))];
  }

  bool canFindStayOn(int day) => supplyAvailableFor(day) && !stayTabOff.value && !isReadOnly && staySupplyFor(day) != false;

  Future<void> ensureStaySupply(int day) async {
    await Future<void>.value();
    final p = plan.value;
    if (p == null || stayTabOff.value) return;
    final leg = p.legAt(p.legIndexOf(day));
    if (!TripSupplyArea.hasCity(leg) || !leg!.hasPoint) return;
    final key = TripSupplyArea.keyOf(leg);
    if (staySupplyByDistrict.containsKey(key) || !_stayProbing.add(key)) return;
    try {
      final res = await ApiService.get('/stays/nearby', params: {
        'cityKey': leg.cityKey,
        'latitude': leg.latitude,
        'longitude': leg.longitude,
      });
      final data = res['data'];
      final items = data is Map<String, dynamic> ? (data['items'] as List?) ?? const [] : const [];
      staySupplyByDistrict[key] = items.isNotEmpty;
      supplyCheckFailed.remove(isMultiCity ? p.legIndexOf(day) : 1);
    } catch (e) {
      if (_isCitiesUnavailable(e)) {
        citiesUnavailable.value = true;
        supplyCheckFailed.add(isMultiCity ? p.legIndexOf(day) : 1);
      }
    } finally {
      _stayProbing.remove(key);
    }
  }

  bool supplyCheckFailedFor(int day) => supplyCheckFailed.contains(isMultiCity ? legIndexOf(day) : 1);

  void retrySupply(int day) {
    final k = isMultiCity ? legIndexOf(day) : 1;
    supplyCheckFailed.remove(k);
    final stayLeg = plan.value?.legAt(plan.value?.legIndexOf(day) ?? 1);
    if (stayLeg != null) {
      staySupplyByDistrict.remove(TripSupplyArea.keyOf(stayLeg));
      unawaited(ensureStaySupply(day));
    }
    if (k == 1) {
      unawaited(checkSupply());
      return;
    }
    final leg = plan.value?.legAt(k);
    if (leg != null) _supplyTried.remove(TripSupplyArea.keyOf(leg));
    taxiSupplyByLeg.remove(k);
    unawaited(ensureSupply(k));
  }

  bool canFindTaxiOn(int day) => taxiSupplyFor(day) == true && !taxiTabOff.value && !isReadOnly;

  static int _legEndOf(TripPlan p, int day) {
    final end = p.legEnd(p.legIndexOf(day));
    return end > 0 ? end : p.days.length;
  }

  int get dayCount => plan.value?.days.length ?? 0;

  int get spotCount => plan.value?.spotCount ?? 0;

  bool get canFindStay => supplyAvailable && !stayTabOff.value && !isReadOnly;

  bool get canFindTaxi => taxiSupply.value == true && !taxiTabOff.value && !isReadOnly;

  bool get supplyAvailable => TripSupplyArea.hasCity(plan.value?.legAt(1));

  bool get supplyPending => false;

  int get dayLimitMinutes => plan.value?.settings.dayLimitMinutes ?? TripConstants.dayLimitMinutes;

  TripSettings get settings => plan.value?.settings ?? const TripSettings();

  bool get hasDates => settings.hasDates;

  DateTime? dateOf(int day) => settings.dateOf(day);

  int? dayOfDate(DateTime? date) {
    final start = settings.startDate;
    if (date == null || start == null) return null;
    final n = DateTime.utc(date.year, date.month, date.day)
            .difference(DateTime.utc(start.year, start.month, start.day))
            .inDays +
        1;
    return n >= 1 && n <= dayCount ? n : null;
  }

  int get defaultMapDay {
    final start = settings.startDate;
    final n = dayCount;
    final fallback = isMultiCity ? mapAll : 1;
    if (start == null || n < 1) return fallback;
    return TripClock.dayIndex(start, n, TripClock.today()) ?? fallback;
  }

  TripMapFocus get mapFocus {
    if (selectedMapDay.value > 0) return TripMapFocus.day;
    return selectedMapLeg.value > 0 ? TripMapFocus.city : TripMapFocus.all;
  }

  void selectMapAll() {
    selectedMapLeg.value = 0;
    selectedMapDay.value = mapAll;
  }

  void selectMapDay(int day) {
    selectedMapLeg.value = 0;
    selectedMapDay.value = day;
  }

  void selectMapLeg(int legIndex) {
    final p = plan.value;
    if (p != null && p.isSingleDayLeg(legIndex)) {
      selectMapDay(p.legStart(legIndex));
      return;
    }
    selectedMapDay.value = mapAll;
    selectedMapLeg.value = legAt(legIndex) == null ? 0 : legIndex;
  }

  void resetMap() {
    selectedMapLeg.value = 0;
    selectedMapDay.value = 1;
  }

  bool mapShowsDay(int day) => switch (mapFocus) {
        TripMapFocus.all => true,
        TripMapFocus.city => legIndexOf(day) == selectedMapLeg.value,
        TripMapFocus.day => day == selectedMapDay.value,
      };

  bool mapShowsSegment(int legIndex) {
    if (legIndex < 2 || legAt(legIndex) == null) return false;
    return switch (mapFocus) {
      TripMapFocus.all => true,
      TripMapFocus.city => legIndex == selectedMapLeg.value || legIndex == selectedMapLeg.value + 1,
      TripMapFocus.day => travelDayOf(legIndex) == selectedMapDay.value,
    };
  }

  TripCityLeg? legAt(int legIndex) => plan.value?.legAt(legIndex);

  TripJourneyLeg? carLeg(int legIndex, int car) {
    for (final l in segmentJourney(legIndex)?.legs ?? const <TripJourneyLeg>[]) {
      if (l.legIndex == car) return l;
    }
    return null;
  }

  List<LatLng>? segmentLine(int legIndex) {
    if (legIndex < 2) return null;
    final leg = legAt(legIndex);
    final prev = legAt(legIndex - 1);
    if (leg == null || prev == null) return null;
    final a = leg.arrival;
    if (a != null) {
      final cached = TripSegmentGeometryCache.get(a.planKey);
      if (cached != null && cached.length >= 2) return cached;
    }
    if (!leg.hasPoint || !prev.hasPoint) return null;
    return [LatLng(prev.latitude, prev.longitude), LatLng(leg.latitude, leg.longitude)];
  }

  bool segmentHasRoad(int legIndex) {
    final a = legIndex < 2 ? null : legAt(legIndex)?.arrival;
    final cached = a == null ? null : TripSegmentGeometryCache.get(a.planKey);
    return cached != null && cached.length >= 2;
  }

  List<TripChangePlace> segmentViaCities(int legIndex) {
    final a = legIndex < 2 ? null : legAt(legIndex)?.arrival;
    return a == null ? const [] : TripSegmentGeometryCache.viaFor(a.planKey);
  }

  List<TripChangePlace> segmentChangePlaces(int legIndex) {
    if (legIndex < 2) return const [];
    final a = legAt(legIndex)?.arrival;
    if (a == null) return const [];
    final cached = TripSegmentGeometryCache.get(a.planKey);
    if (cached == null || cached.length < 2) return const [];
    return TripSegmentGeometryCache.changePlacesFor(a.planKey);
  }

  List<LatLng> mapFocusPoints() {
    final p = plan.value;
    if (p == null) return const [];
    final multi = p.isMultiCity;
    final focus = mapFocus;
    final points = <LatLng>[];
    void addSegmentEnds(int k) {
      final line = segmentLine(k);
      if (line == null) return;
      points.addAll(line);
    }

    if (focus == TripMapFocus.all) {
      for (final s in p.allSpots) {
        points.add(LatLng(s.latitude, s.longitude));
      }
      if (multi) {
        for (final l in p.legs) {
          if (l.hasPoint) points.add(LatLng(l.latitude, l.longitude));
        }
        for (var k = 2; k <= p.legs.length; k++) {
          addSegmentEnds(k);
        }
      }
    } else if (focus == TripMapFocus.city) {
      final k = selectedMapLeg.value;
      final days = p.daysOf(k);
      for (final d in days) {
        for (final s in d.spots) {
          points.add(LatLng(s.latitude, s.longitude));
        }
      }
      final hasSpot = points.isNotEmpty;
      final leg = p.legAt(k);
      if (!hasSpot && leg != null && leg.hasPoint) points.add(LatLng(leg.latitude, leg.longitude));
    } else {
      final d = selectedMapDay.value;
      for (final s in p.dayAt(d)?.spots ?? const <TripSpotRef>[]) {
        points.add(LatLng(s.latitude, s.longitude));
      }
      if (multi && p.isTravelDay(d)) addSegmentEnds(p.legIndexOf(d));
    }
    return points;
  }

  String? travelHeadline(int legIndex) {
    final a = legIndex >= 2 ? legAt(legIndex)?.arrival : null;
    if (a == null) return null;
    final j = segmentJourney(legIndex);
    final cars = a.cars ?? (j == null || j.legs.isEmpty ? (j?.cars ?? 1) : j.legs.length);
    final shown = cars < 1 ? 1 : cars;
    final total = a.listedTotal ?? j?.listedTotal ?? 0;
    return total > 0
        ? TripStringsMcbA2.carsAbout(shown, BrowseItem.inr(total))
        : TripStringsStepsA3.carsLine(shown);
  }

  double cityKm(int legIndex) => legDays(legIndex).fold(0.0, (sum, d) => sum + dayKm(d));

  int cityMinutes(int legIndex) => legDays(legIndex).fold(0, (sum, d) => sum + dayTotalMinutes(d));

  int get travelDays => legCount > 1 ? legCount - 1 : 0;

  int? roadMinutesOf(int legIndex) => legIndex >= 2 ? legAt(legIndex)?.arrival?.roadMinutes : null;

  bool get isPlanned => trip.value?.status == TripStatuses.planned;

  bool get isCompleted => trip.value?.status == TripStatuses.completed;

  static DateTime get _today => TripClock.today();

  int? get todayDay {
    final start = settings.startDate;
    if (start == null) return null;
    return TripClock.dayIndex(start, dayCount, _today);
  }

  bool get isRunning => todayDay != null;

  bool get isLastDayOrAfter {
    final end = settings.endDate(dayCount);
    return end != null && !_today.isBefore(end);
  }

  DateTime? get checkOutDate => settings.checkOutDate(dayCount);

  bool get isPastTrip {
    final out = hasDates && dayCount > 0 ? checkOutDate : null;
    return out != null && _today.isAfter(out);
  }

  bool get isCheckOutDay {
    final out = hasDates && dayCount > 0 ? checkOutDate : null;
    return out != null && _sameDate(out, _today);
  }

  bool get problemOnTravelOnly => !isCompleted && todayDay == null && (isCheckOutDay || journeyToday != null);

  List<TripEnquiryModel> problemTaxiRows(int day) =>
      todayDay == null ? const [] : [for (final e in taxiEnquiriesForDay(day)) if (e.isBooked) e];

  List<TripEnquiryModel> problemStayRows(int day) =>
      todayDay == null ? const [] : [for (final e in enquiriesForNight(day)) if (e.isBooked) e];

  bool get isReadOnly => isCompleted || isPastTrip;

  bool isDayPast(int day) {
    final d = dateOf(day);
    return d != null && d.isBefore(_today);
  }

  bool canEditDay(int day) => !isReadOnly && !isDayPast(day);

  bool get canComplete => trip.value != null && !isCompleted && (!hasDates || isRunning || isLastDayOrAfter);

  TripSteps get steps => plan.value?.steps ?? const TripSteps();

  TripStartFrom? get startFrom => steps.startFrom;

  List<TripJourney> get journeys => trip.value?.journeys ?? const [];

  TripStep stepOf(TripStepRole role) => steps.of(role);

  DateTime? stepDate(TripStepRole role) => TripStepRules.expectedDate(role, stepOf(role), settings, dayCount);

  ({double lat, double lon})? get _cityPoint {
    final p = plan.value;
    final lat = p?.centreLatitude ?? picked?.latitude ?? trip.value?.cityLatitude;
    final lon = p?.centreLongitude ?? picked?.longitude ?? trip.value?.cityLongitude;
    if (lat == null || lon == null || (lat == 0 && lon == 0)) return null;
    return (lat: lat, lon: lon);
  }

  PlaceResult? get cityPlace {
    final pt = _cityPoint;
    if (pt == null || cityName.isEmpty) return null;
    return PlaceResult(name: cityName, subtitle: '', latLng: LatLng(pt.lat, pt.lon));
  }

  bool get startsInsideCity {
    final pt = _cityPoint;
    return TripStepRules.insideCity(startFrom, pt?.lat, pt?.lon);
  }

  TripJourney? journeyFor(TripStepRole role) {
    final s = stepOf(role);
    if (!s.hasJourney) return null;
    final j = trip.value?.journeyById(s.journeyId);
    if (j == null) return null;
    final expected = stepDate(role);
    final city = _stepCityPoint(role);
    return j.withFlags(
      role: role,
      expectedDate: expected,
      dateChanged: TripStepRules.dateChanged(expected, j.date),
      startChanged: TripStepRules.startChanged(role, steps.endOf(role), j, cityLat: city?.lat, cityLon: city?.lon),
    );
  }

  ({double lat, double lon})? _stepCityPoint(TripStepRole role) =>
      role == TripStepRole.gettingThere ? _cityPoint : _lastPoint;

  bool journeyCityChanged(TripStepRole role) {
    final s = stepOf(role);
    if (!s.hasJourney) return false;
    final j = trip.value?.journeyById(s.journeyId);
    final city = _stepCityPoint(role);
    return j != null && TripStepRules.cityChanged(role, j, city?.lat, city?.lon);
  }

  bool stepNeedsAttention(TripStepRole role) {
    if (isReadOnly) return false;
    if (journeyFor(role)?.needsAttention ?? false) return true;
    return role == TripStepRole.gettingThere &&
        TripStepRules.needsNudge(stepOf(role), startFrom, settings.startDate, _today);
  }

  bool stepCanAsk(TripStepRole role) {
    if (isReadOnly) return false;
    final j = journeyFor(role);
    return j == null || !(j.dateChanged || j.startChanged);
  }

  TripStepRole? get startChangedRole {
    for (final r in TripStepRole.values) {
      if (journeyFor(r)?.startChanged ?? false) return r;
    }
    return null;
  }

  TripJourney? get journeyToday {
    if (isCompleted) return null;
    for (final r in TripStepRole.values) {
      final j = journeyFor(r);
      if (j != null && _sameDate(j.date, _today)) return j;
    }
    return null;
  }

  void setRestDay(int day, bool value) {
    final p = plan.value;
    final d = p?.dayAt(day);
    if (p == null || d == null || !canEditDay(day) || d.restDay == value) return;
    plan.value = p.copyWith(days: [for (final x in p.days) x.day == day ? x.copyWith(restDay: value) : x]);
    scheduleSave();
  }

  // Live Coming back rows whose journey no longer fits the leave time.
  List<TripEnquiryModel> leaveImpact(TripLeaveOn value) {
    final p = plan.value;
    final cur = p?.steps.comingBack;
    final id = cur?.journeyId;
    if (p == null || cur == null || id == null) return const [];
    final j = trip.value?.journeyById(id);
    final next = TripStepRules.expectedDate(
        TripStepRole.comingBack, cur.copyWith(leaveOn: value, clearDate: true), settings, dayCount);
    if (j == null || next == null || !TripStepRules.dateChanged(next, j.date)) return const [];
    return [for (final e in journeyRowsOf(role: TripStepRole.comingBack)) if (TripTravelRules.isLive(e)) e];
  }

  Future<void> setLeaveOn(TripLeaveOn value, {bool cancelBooked = false}) async {
    final p = plan.value;
    if (p == null || isReadOnly) return;
    final cur = p.steps.comingBack;
    if (cur.leaveOn == value) return;
    final rows = leaveImpact(value);
    _setSteps(p.steps.withStep(TripStepRole.comingBack, cur.copyWith(leaveOn: value, clearDate: true)));
    for (final e in rows) {
      if (TripTravelRules.bookedStatuses.contains(e.status)) {
        if (cancelBooked) await TripEnquiryController.to.cancel(e.id);
      } else if (e.isWithdrawable) {
        await TripEnquiryController.to.withdraw(e.id);
      }
    }
  }

  final planStep = 1.obs;
  final guideState = TripGuideState();

  int get initialStep => pendingStep;

  int get pendingStep => spotCount == 0 ? 1 : 2;

  ({int done, int total, int percent}) get stepProgress {
    final e = easyProgress;
    final percent = (spotCount > 0 ? 50 : 0) + (50 * e.percent / 100).round();
    return (done: e.done, total: e.total, percent: percent.clamp(0, 100));
  }

  List<TripEasyRowInfo> get easyRows {
    final p = plan.value;
    if (p == null) return const [];
    return TripEasyRules.rows(p, enquiryList.toList(), trip.value?.journeys ?? const []);
  }

  ({int done, int total, int percent}) get easyProgress {
    final server = trip.value?.progress;
    final rows = easyRows;
    return enquiriesFailed.value && server != null && server.total > 0
        ? TripEasyRules.progressOf(const [], server)
        : TripEasyRules.progress(rows);
  }

  TripEasyRowInfo? get easyInProgress => TripEasyRules.firstInProgress(easyRows);

  TripEasyRowInfo? easyRowOf(TripEasyRowKey key) => TripEasyRules.rowOf(easyRows, key);

  List<TripEnquiryModel> openRowsOf(TripEasyRowKey key) {
    final row = easyRowOf(key);
    if (row == null) return const [];
    return [for (final e in row.enquiries) if (e.isOpen && e.isWithdrawable) e]..sort(_newestFirst);
  }

  TripEnquiryModel? confirmedRowOf(TripEasyRowKey key) {
    final row = easyRowOf(key);
    if (row == null) return null;
    final booked = [for (final e in row.enquiries) if (e.isOpen && e.isBooked) e]..sort(_newestFirst);
    return booked.firstOrNull;
  }

  TripStepRole? _roleOfRow(TripEasyRowKey key) => switch (key.kind) {
        TripEasyRowKind.gettingThere => TripStepRole.gettingThere,
        TripEasyRowKind.comingBack => TripStepRole.comingBack,
        _ => null,
      };

  bool canMarkRow(TripEasyRowKey key) => !isReadOnly && plan.value != null;

  Future<TripMarkResult> markOwn(TripEasyRowKey key, {bool withdrawOpen = false, bool serverClosed = false}) async {
    final p = plan.value;
    if (p == null || isReadOnly) return const TripMarked();
    final booked = confirmedRowOf(key);
    if (booked != null) return TripMarkBlocked(booked);
    final open = openRowsOf(key);
    if (open.isNotEmpty && !withdrawOpen) return TripMarkNeedsWithdraw(open);
    const own = TripRowMark.own();
    final role = _roleOfRow(key);
    switch (key.kind) {
      case TripEasyRowKind.stay:
        plan.value = p.withStayMark(key.legIndex ?? 1, own);
        scheduleSave();
      case TripEasyRowKind.taxi:
        plan.value = p.withTaxiMark(own);
        scheduleSave();
      case TripEasyRowKind.between:
        final k = key.legIndex ?? 2;
        final old = p.legAt(k)?.arrival?.journeyId;
        plan.value = p.withTravelMark(k, own);
        scheduleSave();
        if (old != null && old.isNotEmpty) await releaseJourneyLink(old);
      case TripEasyRowKind.gettingThere || TripEasyRowKind.comingBack:
        if (role != null) {
          unlinkJourney(role);
          final q = plan.value;
          if (q != null) _setSteps(q.steps.withStep(role, q.steps.of(role).copyWith(status: TripStepStatus.own)));
        }
    }
    if (open.isNotEmpty && !serverClosed) await _closeOpenOnServer(key.id);
    return const TripMarked();
  }

  void skipRow(TripEasyRowKey key) {
    final p = plan.value;
    if (p == null || isReadOnly || openRowsOf(key).isNotEmpty || confirmedRowOf(key) != null) return;
    const skipped = TripRowMark.skipped();
    final role = _roleOfRow(key);
    switch (key.kind) {
      case TripEasyRowKind.stay:
        plan.value = p.withStayMark(key.legIndex ?? 1, skipped);
        scheduleSave();
      case TripEasyRowKind.taxi:
        plan.value = p.withTaxiMark(skipped);
        scheduleSave();
      case TripEasyRowKind.between:
        final k = key.legIndex ?? 2;
        final old = p.legAt(k)?.arrival?.journeyId;
        plan.value = p.withTravelMark(k, skipped);
        scheduleSave();
        if (old != null && old.isNotEmpty) unawaited(releaseJourneyLink(old));
      case TripEasyRowKind.gettingThere || TripEasyRowKind.comingBack:
        if (role != null && !p.steps.of(role).hasJourney) {
          _setSteps(p.steps.withStep(role, p.steps.of(role).copyWith(status: TripStepStatus.skipped)));
        }
    }
  }

  void undoMark(TripEasyRowKey key) {
    ownPending.remove(key.id);
    final p = plan.value;
    if (p == null || isReadOnly) return;
    final role = _roleOfRow(key);
    switch (key.kind) {
      case TripEasyRowKind.stay:
        if (p.legAt(key.legIndex ?? 1)?.stayMark != null) {
          plan.value = p.withStayMark(key.legIndex ?? 1, null);
          scheduleSave();
        }
      case TripEasyRowKind.taxi:
        if (p.taxiMark != null) {
          plan.value = p.withTaxiMark(null);
          scheduleSave();
        }
      case TripEasyRowKind.between:
        if (p.legAt(key.legIndex ?? 2)?.travelMark != null) {
          plan.value = p.withTravelMark(key.legIndex ?? 2, null);
          scheduleSave();
        }
      case TripEasyRowKind.gettingThere || TripEasyRowKind.comingBack:
        if (role != null) resetStep(role);
    }
  }

  void unskipRow(TripEasyRowKey key) => undoMark(key);

  Future<bool> _closeOpenOnServer(String step) async {
    final res = await TripShortlistController.to.markBooked(step);
    if (res != null) {
      ownPending.remove(step);
      unawaited(refreshEnquiries());
      return true;
    }
    ownPending.add(step);
    unawaited(_retryOwnPending());
    return false;
  }

  Future<void> _retryOwnPending() async {
    if (_ownRetrying) return;
    _ownRetrying = true;
    try {
      var wait = ownRetryDelay;
      while (ownPending.isNotEmpty && !isClosed) {
        await Future<void>.delayed(wait);
        if (isClosed) return;
        for (final step in ownPending.toList()) {
          final res = await TripShortlistController.to.markBooked(step);
          if (res != null) ownPending.remove(step);
        }
        if (ownPending.isEmpty) {
          unawaited(refreshEnquiries());
          return;
        }
        final next = wait * 2;
        wait = next > const Duration(minutes: 5) ? const Duration(minutes: 5) : next;
      }
    } finally {
      _ownRetrying = false;
    }
  }

  void setOwnCar(TripStepRole? role, int? legIndex, int car, bool own) {
    final p = plan.value;
    if (p == null || isReadOnly || car < 1 || car > TripConstants.maxJourneyCars) return;
    if (role != null) {
      final cur = p.steps.of(role);
      if (!cur.hasJourney || cur.ownCars.contains(car) == own) return;
      _setSteps(p.steps.withStep(role, cur.withOwnCar(car, own)));
      return;
    }
    final k = legIndex;
    final a = k == null ? null : p.legAt(k)?.arrival;
    if (k == null || a == null || a.ownCars.contains(car) == own) return;
    plan.value = p.withArrival(k, a.withOwnCar(car, own));
    scheduleSave();
  }

  DateChangeImpact clearDatesImpact() {
    final booked = <TripEnquiryModel>[];
    final open = <TripEnquiryModel>[];
    for (final e in enquiryList) {
      if (!e.isOpen) continue;
      if (e.isBooked) {
        booked.add(e);
      } else if (e.isWithdrawable) {
        open.add(e);
      }
    }
    booked.sort(_newestFirst);
    open.sort(_newestFirst);
    return DateChangeImpact(booked: booked, open: open);
  }

  List<TripEnquiryModel> get undatedBookedRows =>
      hasDates ? const [] : ([for (final e in enquiryList) if (e.isOpen && e.isBooked) e]..sort(_newestFirst));

  bool get hasPendingCopy => _pendingRetry != null;

  // Either the last trip call failed on the network or the phone has no signal.
  bool get netOff =>
      offline.value || (Get.isRegistered<LocationController>() && Get.find<LocationController>().isOffline.value);

  Future<void> retryConnection() async {
    if (trip.value == null) return;
    await refreshEnquiries();
    if (!offline.value && hasPendingCopy) await retrySave();
  }

  Future<bool> retrySave() {
    final copy = _pendingRetry;
    if (copy != null && !isReadOnly) {
      _pendingRetry = null;
      plan.value = copy;
    }
    return saveNow();
  }

  void _writeAhead() {
    final t = trip.value;
    final p = plan.value;
    if (t == null || t.raw == null || p == null || _saveBlocked) return;
    StorageService.saveTripPending(t.id, plan: p.toJson(), baseUpdatedAt: t.updatedAt);
  }

  Future<void> flushForBackground() async {
    final dirty = (_saveTimer?.isActive ?? false) || saveFailed.value || _saving != null || _dirtyDuringCreate;
    if (dirty) _writeAhead();
    await flushPendingSave();
  }

  static TripStartFrom? _cleanStart(TripStartFrom? v) {
    if (v == null) return null;
    var name = v.name.trim();
    if (name.isEmpty) return null;
    if (name.length > TripConstants.startFromNameMax) name = name.substring(0, TripConstants.startFromNameMax).trim();
    return TripStartFrom(name: name, lat: v.lat, lon: v.lon);
  }

  void _setSteps(TripSteps next) {
    final p = plan.value;
    if (p == null) return;
    plan.value = p.copyWith(steps: next);
    scheduleSave();
  }

  void _dropLocalJourney(String? id) {
    if (id == null) return;
    _pendingJourneyIds.remove(id);
    final t = trip.value;
    if (t == null || !t.journeys.any((j) => j.id == id)) return;
    trip.value = t.copyWith(journeys: t.journeys.where((j) => j.id != id).toList());
  }

  Future<void> ensureStartFrom() async {
    final p = plan.value;
    if (p == null || _startFromTried || p.steps.startFrom != null) return;
    if (isReadOnly || offline.value || tripGone.value || plannerOff.value || needsUpdate.value) return;
    if (!Get.isRegistered<LocationController>()) return;
    final city = travellerCity(Get.find<LocationController>());
    final start = city == null
        ? null
        : _cleanStart(TripStartFrom(
            name: city.place.name,
            lat: city.place.latLng.latitude,
            lon: city.place.latLng.longitude,
          ));
    if (start == null) return;
    _startFromTried = true;
    _setSteps(p.steps.copyWith(startFrom: start));
  }

  Future<bool> setStartFrom(TripStartFrom? v) async {
    final p = plan.value;
    if (p == null || isReadOnly) return false;
    final next = _cleanStart(v);
    final old = p.steps.startFrom;
    if (next == null ? old == null : next.sameAs(old)) return false;
    _startFromTried = true;
    _setSteps(next == null ? p.steps.copyWith(clearStartFrom: true) : p.steps.copyWith(startFrom: next));
    return startChangedRole != null;
  }

  void linkJourney(TripStepRole role, SavedJourney j) {
    final p = plan.value;
    if (p == null || isReadOnly || j.id.isEmpty) return;
    var next = p.steps;
    if (next.of(role.other).journeyId == j.id) next = next.withStep(role.other, next.of(role.other).cleared);
    final cur = next.of(role);
    final oldId = cur.journeyId;
    final same = oldId == j.id;
    final keepBooked = cur.status == TripStepStatus.booked && same;
    final def = TripStepRules.expectedDate(role, cur.cleared, settings, dayCount);
    final date = def != null && TripStepRules.dateChanged(def, j.date) ? j.date : null;
    next = next.withStep(
      role,
      TripStep(
        status: keepBooked ? TripStepStatus.booked : TripStepStatus.chosen,
        journeyId: j.id,
        date: date,
        leaveOn: cur.leaveOn,
        ownCars: same ? cur.ownCars : const [],
      ),
    );
    if (oldId != null && oldId != j.id) _dropLocalJourney(oldId);
    final t = trip.value;
    if (t != null) {
      final local = TripJourney.fromSaved(j, role, expectedDate: date ?? def, startFrom: next.endOf(role));
      trip.value = t.copyWith(journeys: [
        for (final x in t.journeys)
          if (x.id != j.id) x,
        local,
      ]);
    }
    _pendingJourneyIds.add(j.id);
    _setSteps(next);
  }

  void refreshLinkedJourney(SavedJourney j) {
    final t = trip.value;
    final p = plan.value;
    if (t == null || p == null) return;
    final k = p.segmentLegOf(j.id);
    if (k != null) {
      final local = TripJourney.fromSavedSegment(j, k, p.legStart(k), travelDateOf(k));
      trip.value = t.copyWith(journeys: [
        for (final x in t.journeys)
          if (x.id != j.id) x,
        local,
      ]);
      return;
    }
    for (final r in TripStepRole.values) {
      if (stepOf(r).journeyId != j.id) continue;
      final local = TripJourney.fromSaved(j, r, expectedDate: stepDate(r), startFrom: steps.endOf(r));
      trip.value = t.copyWith(journeys: [
        for (final x in t.journeys)
          if (x.id != j.id) x,
        local,
      ]);
      return;
    }
  }

  void unlinkJourney(TripStepRole role) {
    final p = plan.value;
    if (p == null) return;
    final cur = p.steps.of(role);
    if (cur.journeyId == null && !cur.status.linksJourney) return;
    _dropLocalJourney(cur.journeyId);
    _setSteps(p.steps.withStep(role, cur.cleared));
  }

  void markStepBooked(TripStepRole role) {
    final p = plan.value;
    final cur = p?.steps.of(role);
    if (p == null || cur == null || isReadOnly || cur.status != TripStepStatus.chosen || !cur.hasJourney) return;
    _setSteps(p.steps.withStep(role, cur.copyWith(status: TripStepStatus.booked)));
  }

  void unmarkStepBooked(TripStepRole role) {
    final p = plan.value;
    final cur = p?.steps.of(role);
    if (p == null || cur == null || isReadOnly || cur.status != TripStepStatus.booked) return;
    _setSteps(p.steps.withStep(role, cur.copyWith(status: TripStepStatus.chosen)));
  }

  void resetStep(TripStepRole role) {
    final p = plan.value;
    if (p == null || isReadOnly) return;
    final cur = p.steps.of(role);
    final s = cur.status;
    if (s != TripStepStatus.own && s != TripStepStatus.skipped) return;
    _setSteps(p.steps.withStep(role, cur.cleared));
  }

  void reconcileSteps([TripModel? fresh]) {
    final p = plan.value;
    final t = fresh ?? trip.value;
    if (p == null || t == null || offline.value || !t.journeysKnown || isCompleted) return;
    var next = p.steps;
    var changed = false;
    for (final r in TripStepRole.values) {
      final s = next.of(r);
      if (!s.status.linksJourney) continue;
      final id = s.journeyId;
      final gone = id == null ||
          (!_pendingJourneyIds.contains(id) && t.plan.steps.of(r).journeyId == id && t.journeyById(id) == null);
      if (gone) {
        next = next.withStep(r, s.cleared);
        changed = true;
      }
    }
    if (changed) _setSteps(next);
  }

  bool _serverLinks(TripModel server, String id) =>
      TripStepRole.values.any((r) => server.plan.steps.of(r).journeyId == id) || server.plan.segmentLegOf(id) != null;

  bool _locallyLinked(String id) {
    final p = plan.value;
    if (p == null) return false;
    return TripStepRole.values.any((r) => p.steps.of(r).journeyId == id) || p.segmentLegOf(id) != null;
  }

  List<TripJourney> _mergedJourneys(TripModel server, {bool keepLinked = true}) {
    final local = trip.value?.journeys ?? const <TripJourney>[];
    if (!server.journeysKnown) return local;
    final ids = {for (final j in server.journeys) j.id};
    return [
      ...server.journeys,
      for (final j in local)
        if (!ids.contains(j.id) &&
            (_pendingJourneyIds.contains(j.id) ||
                (keepLinked && _locallyLinked(j.id) && !_serverLinks(server, j.id))))
          j,
    ];
  }

  @visibleForTesting
  void adoptServerStepsForTest(TripPlan sent, TripModel saved) => _adoptServerSteps(sent, saved);

  void _adoptServerSteps(TripPlan sent, TripModel saved) {
    final local = plan.value;
    if (local == null || !saved.stepsKnown) return;
    var next = local.steps;
    var changed = false;
    for (final r in TripStepRole.values) {
      final asSent = sent.steps.of(r);
      final server = saved.plan.steps.of(r);
      if (asSent.journeyId != null && server.journeyId != asSent.journeyId && next.of(r).journeyId == asSent.journeyId) {
        next = next.withStep(r, server);
        changed = true;
      }
    }
    if (changed) plan.value = local.copyWith(steps: next);
  }

  TripEnquiryModel? todayStay(int day) {
    final e = primaryEnquiry(day);
    return e != null && e.isBooked ? e : null;
  }

  TripEnquiryModel? todayTaxi(int day) {
    final e = primaryTaxiEnquiry(day);
    return e != null && e.isBooked ? e : null;
  }

  List<String> todaySpotNames(int day) =>
      plan.value?.dayAt(day)?.spots.map((s) => s.name).where((n) => n.isNotEmpty).toList() ?? const [];

  static bool _isJourneyRow(TripEnquiryModel e) => e.isTaxi && (e.isSegment || e.context.journeyId != null);

  // Steps as saveSettings leaves them after a date move: their own dates are cleared.
  DateTime? _journeyRowDate(TripEnquiryModel e, TripSettings s, int days) {
    final p = plan.value;
    final id = e.context.journeyId;
    if (p == null || id == null) return null;
    final k = p.segmentLegOf(id);
    if (k != null) return s.dateOf(p.legStart(k));
    for (final r in TripStepRole.values) {
      if (p.steps.of(r).journeyId == id) {
        return TripStepRules.expectedDate(r, p.steps.of(r).copyWith(clearDate: true), s, days);
      }
    }
    final role = TripJourneyRole.parse(e.context.role)?.stepRole;
    return role == null ? null : TripStepRules.expectedDate(role, p.steps.of(role).copyWith(clearDate: true), s, days);
  }

  bool _journeyRowMoved(TripEnquiryModel e, TripSettings s, int days) {
    final ci = e.checkIn;
    final want = _journeyRowDate(e, s, days);
    return ci != null && want != null && !_sameDate(want, ci);
  }

  static bool _outsideWindow(TripEnquiryModel e, DateTime start, DateTime checkOut) {
    if (_isJourneyRow(e)) return false;
    if (e.isTaxi) {
      final dates = e.taxiDates;
      return dates.any((d) => d.isBefore(start) || !d.isBefore(checkOut));
    }
    final ci = e.checkIn;
    if (ci == null) return false;
    final co = e.checkOut ?? DateTime(ci.year, ci.month, ci.day + 1);
    return ci.isBefore(start) || co.isAfter(checkOut);
  }

  bool _stayShortOfLeg(TripEnquiryModel e, TripPlan p) {
    final home = TripEnquiryRules.homeLegIndex(e, p);
    if (home == null || p.legAt(home) == null) return false;
    final nights = TripEasyRules.nightsOf(e, p);
    final legNights = p.legDayCount(home);
    if (nights.isEmpty || nights.length >= legNights || nights.reduce((a, b) => a < b ? a : b) != p.legStart(home)) return false;
    if (e.nights >= 2) return true;
    final first = p.legStart(home);
    final others = TripEasyRules.stayRows(p, enquiryList, home).where((x) => x.id != e.id && x.isOpen);
    return others.every((x) => !TripEasyRules.nightsOf(x, p).any((n) => n > first));
  }

  bool _landsInOtherCity(TripEnquiryModel e, TripPlan p, TripSettings moved) =>
      p.isMultiCity &&
      TripEnquiryRules.wrongCity(e, p, moved) != null &&
      TripEnquiryRules.wrongCity(e, p, p.settings) == null;

  int daysAfterLimit(int? maxDays) => maxDays != null && maxDays < dayCount ? maxDays : dayCount;

  DateChangeImpact dateChangeImpact(DateTime newStart, {int? days}) {
    final start = DateTime(newStart.year, newStart.month, newStart.day);
    final n = days ?? dayCount;
    final checkOut = DateTime(start.year, start.month, start.day + (n < 1 ? 1 : n));
    final moved = settings.copyWith(startDate: start);
    final p = plan.value;
    final booked = <TripEnquiryModel>[];
    final open = <TripEnquiryModel>[];
    for (final e in enquiryList) {
      if (!e.isOpen) continue;
      final out = _isJourneyRow(e)
          ? _journeyRowMoved(e, moved, n)
          : _outsideWindow(e, start, checkOut) || (p != null && _landsInOtherCity(e, p, moved));
      if (!out) continue;
      (e.isBooked ? booked : open).add(e);
    }
    booked.sort(_newestFirst);
    open.sort(_newestFirst);
    return DateChangeImpact(booked: booked, open: open);
  }

  List<TripEnquiryModel> bookingsOutsideDates(DateTime newStart) => dateChangeImpact(newStart).all;

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
      AppToast.error(DioErrorMapper.toMessage(e, TripStrings.checkConnection, showRawMessageForStatusCodes: {400, 403, 409, 422, 429}));
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
      } catch (e) {
        if (DioErrorMapper.isNetworkError(e)) TripTodayCache.queueProblem(it);
      }
    }
  }

  void _cacheResult(TripPlanResult r) {
    final id = trip.value?.id;
    if (id != null) TripTodayCache.saveResult(id, r);
  }

  static TripCityModel _firstCity(TripModel t) => t.plan.legs.isNotEmpty
      ? t.plan.legs.first.city
      : TripCityModel(cityKey: t.cityKey, name: t.cityName, latitude: t.cityLatitude, longitude: t.cityLongitude);

  bool _openFromCache(String tripId, Object e) => DioErrorMapper.isNetworkError(e) && _showCached(tripId);

  // The saved copy renders at once (marked offline) while the server copy loads behind it.
  bool _showCached(String tripId) {
    final cached = TripTodayCache.trip(tripId);
    if (cached == null) return false;
    trip.value = cached;
    plan.value = cached.plan;
    final pending = StorageService.getTripPending(tripId);
    if (pending != null) {
      try {
        plan.value = TripPlan.fromJson(pending.plan);
      } catch (_) {}
    }
    enquiryList.assignAll(cached.enquiries);
    result.value = TripTodayCache.result(tripId);
    picked = _firstCity(cached);
    offline.value = true;
    openFailed.value = false;
    return true;
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

  int dayTotalMinutes(int day) =>
      TripDayLoad.route(serverTotal: resultDay(day)?.totalMinutes, visitMinutes: plan.value?.dayAt(day)?.visitMinutes ?? 0);

  int? roadDayMinutes(int day, List<String> spotNames) {
    final d = plan.value?.dayAt(day);
    final r = resultDay(day);
    if (d == null || r == null || !listEquals([for (final s in d.spots) s.name], spotNames)) return null;
    return TripDayLoad.route(serverTotal: r.totalMinutes, visitMinutes: d.visitMinutes);
  }

  int dayReservedMinutes(int day) {
    final p = plan.value;
    if (p == null || p.dayAt(day) == null || !p.isTravelDay(day)) return 0;
    return roadMinutesOf(p.legIndexOf(day)) ?? 0;
  }

  int dayLoadMinutes(int day) => TripDayLoad.load(reserved: dayReservedMinutes(day), route: dayTotalMinutes(day));

  bool isOverLimit(int day) => TripDayLoad.isOver(dayLoadMinutes(day), dayLimitMinutes);

  int _legMinutes(TripPlanDay? r, TripSpotRef a, TripSpotRef b) {
    if (r != null) {
      for (final l in r.legs) {
        if (l.fromId == a.id && l.toId == b.id) return l.minutes;
      }
    }
    return TripDayLoad.estimateMinutes((lat: a.latitude, lng: a.longitude), (lat: b.latitude, lng: b.longitude));
  }

  ({int index, int deltaMinutes})? _insertion(String id, int toDay) {
    final p = plan.value;
    final x = p?.spotById(id);
    final d = p?.dayAt(toDay);
    if (x == null || d == null) return null;
    final r = resultDay(toDay);
    final s = [for (final y in d.spots) if (y.id != id) y];
    return TripDayLoad.cheapestInsertion(
      count: s.length,
      toNew: (i) => _legMinutes(r, s[i], x),
      fromNew: (i) => _legMinutes(r, x, s[i]),
      legAfter: (i) => _legMinutes(r, s[i], s[i + 1]),
    );
  }

  int moveLoadMinutes(String id, int toDay) {
    final p = plan.value;
    final x = p?.spotById(id);
    final d = p?.dayAt(toDay);
    if (x == null || d == null || d.spots.any((s) => s.id == id)) return dayLoadMinutes(toDay);
    final ins = _insertion(id, toDay);
    var base = dayLoadMinutes(toDay);
    if (resultDay(toDay) == null) {
      for (var i = 0; i + 1 < d.spots.length; i++) {
        base += _legMinutes(null, d.spots[i], d.spots[i + 1]);
      }
    }
    return base + x.visitMinutes + (ins?.deltaMinutes ?? 0);
  }

  int dayMinutesLeft(int day) => dayLimitMinutes - dayLoadMinutes(day);

  ({int index, int deltaMinutes}) _pickInsertion(TripSpotRef x, int day, {String? skipId}) {
    final r = resultDay(day);
    final s = [
      for (final y in plan.value?.dayAt(day)?.spots ?? const <TripSpotRef>[])
        if (y.id != skipId && y.id != x.id) y,
    ];
    final at = (lat: x.latitude, lng: x.longitude);
    int est(TripSpotRef a) => TripDayLoad.estimateMinutes((lat: a.latitude, lng: a.longitude), at);
    return TripDayLoad.cheapestInsertion(
      count: s.length,
      toNew: (i) => est(s[i]),
      fromNew: (i) => est(s[i]),
      legAfter: (i) => _legMinutes(r, s[i], s[i + 1]),
    );
  }

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
      cityName: cityNameOf(day),
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
    _recalcAfterAuto = false;
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
    resetMap();
    _enquirySeq++;
    enquiryList.clear();
    enquiriesLoading.value = false;
    enquiriesFailed.value = false;
    startChangedNotes.clear();
    _pendingRetry = null;
    offline.value = false;
    picked = null;
    taxiSupplyByLeg.clear();
    staySupplyByDistrict.clear();
    supplyCheckFailed.clear();
    _supplyTried.clear();
    lastAddedLeg.value = null;
    travelGaps.clear();
    travelBusy.clear();
    _legChain = Future<void>.value();
    _retryLeg = null;
    _legResults.clear();
    unavailableCities.clear();
    _startFromTried = false;
    _pendingJourneyIds.clear();
    if (Get.isRegistered<TripSupplyController>()) Get.delete<TripSupplyController>(force: true);
  }

  Future<bool> flushPendingSave() async {
    if (tripGone.value || needsUpdate.value || plannerOff.value) return false;
    if (planFailed.value && trip.value == null && _creating == null) return false;
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

  void _markLegUnavailable(Object e, int cityKey) {
    final p = plan.value;
    if (p == null || !p.isMultiCity || DioErrorMapper.errorType(e) != TripErrorTypes.cityNotFound) return;
    if (p.legIndexOfCity(cityKey) != null) unavailableCities.add(cityKey);
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
      final leg = p.isMultiCity ? p.legAt(_errorLegIndex(e) ?? 0) : null;
      if (leg != null) {
        if (unavailableCities.add(leg.cityKey)) {
          AppToast.error(DioErrorMapper.toMessage(e, TripStrings.cityUnavailable));
        }
      } else {
        AppToast.error(p.isMultiCity
            ? DioErrorMapper.toMessage(e, TripStrings.cityUnavailable)
            : TripStrings.cityUnavailable);
      }
    } else if (type == TripErrorTypes.citiesUnavailable) {
      AppToast.error(TripStrings.citiesFailed);
    } else if (_status(e) == 400) {
      _rejectedPlan = p;
      _rejectedTitle = _title;
      AppToast.error(DioErrorMapper.toMessage(e, TripStrings.saveFailed));
    } else {
      AppToast.error(DioErrorMapper.toMessage(e, TripStrings.saveFailed));
    }
    saveFailed.value = true;
  }

  static int? _errorLegIndex(Object e) {
    if (e is! DioException) return null;
    final body = e.response?.data;
    final data = body is Map ? body['data'] : null;
    final v = data is Map ? data['legIndex'] : null;
    return v is num ? v.toInt() : null;
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

  Future<void> startFromSelection(TripCityModel city, List<TripSpotModel> chosen) =>
      startFromSelections([(city: city, spots: chosen)]);

  Future<void> startFromSelections(
    List<({TripCityModel city, List<TripSpotModel> spots})> selections,
  ) async {
    if (selections.isEmpty) return;
    final pendingSave = _detachPendingSave();
    _reset();
    if (pendingSave != null) unawaited(pendingSave());
    final legs = <TripCityLeg>[];
    final tripDays = <TripDay>[];
    final seenSpots = <String>{};
    var room = TripConstants.maxSpots;
    for (final e in selections) {
      if (legs.length >= TripConstants.maxLegs) break;
      if (legs.any((l) => l.cityKey == e.city.cityKey)) continue;
      final n = legs.length + 1;
      final refs = <TripSpotRef>[];
      for (final s in e.spots) {
        if (room <= 0) break;
        if (!seenSpots.add(s.id)) continue;
        refs.add(TripSpotRef.fromSpot(s));
        room--;
      }
      legs.add(TripCityLeg.fromCity(n, e.city));
      tripDays.add(TripDay(day: n, leg: n, spots: refs));
    }
    picked = selections.first.city;
    _clientTripId = const Uuid().v4();
    final autoDays = TripDaysRules.autoTotal([for (final d in tripDays) [for (final s in d.spots) s.visitMinutes]], TripPace.relaxed);
    final chosenDays = autoDays.clamp(legs.length, TripConstants.maxDaysCap).toInt();
    plan.value = TripPlan(
      legs: legs,
      days: tripDays,
      settings: TripSettings(dayLimitMinutes: TripPace.relaxed, maxDays: chosenDays),
    );
    checkSupply();
    final flow = _flow;
    await autoPlan();
    if (flow != _flow || plan.value == null) return;
    if (planFailed.value || plannerOff.value) return;
    await _createDraft();
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
      StorageService.clearTripNewDraft();
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
    if (p == null || p.legs.isEmpty) return;
    final byCity = <int, String>{
      for (final l in saved.plan.legs)
        if (l.districtId != null) l.cityKey: l.districtId!,
    };
    final rowDistrict = saved.districtId;
    if (rowDistrict != null && saved.cityKey == p.cityKey) byCity.putIfAbsent(p.cityKey, () => rowDistrict);
    final changed = <int>[];
    final legs = [
      for (final l in p.legs)
        if (l.districtId == null && byCity[l.cityKey] != null) l.copyWith(districtId: byCity[l.cityKey]) else l,
    ];
    for (var i = 0; i < legs.length; i++) {
      if (!identical(legs[i], p.legs[i])) changed.add(legs[i].index);
    }
    if (changed.isEmpty) return;
    plan.value = p.copyWith(legs: legs);
    if (changed.contains(1)) checkSupply();
    for (final k in changed) {
      if (k == 1 || !taxiSupplyByLeg.containsKey(k)) continue;
      taxiSupplyByLeg.remove(k);
      unawaited(ensureSupply(k));
    }
  }

  Future<void> open(String tripId, {bool fresh = false}) async {
    if (!fresh && trip.value?.id == tripId && plan.value != null && !tripGone.value) return;
    if (_openingId == tripId && isOpening.value) return;
    _daysSeen = null;
    _dayCountWas = null;
    final pendingSave = _detachPendingSave();
    _reset();
    if (pendingSave != null) unawaited(pendingSave());
    _openingId = tripId;
    isOpening.value = true;
    final shown = _showCached(tripId);
    final gen = _saveGen;
    try {
      final t = await _repo.get(tripId);
      if (_openingId != tripId) return;
      if (shown) {
        offline.value = false;
        // A save from the copy already reached the server: this answer is older, so only the rows are refreshed.
        if (gen != _saveGen || _saving != null) {
          _adoptDistrict(t);
          checkSupply();
          unawaited(refreshEnquiries());
          return;
        }
      }
      TripTodayCache.saveTrip(t);
      trip.value = t;
      enquiryList.assignAll(t.enquiries);
      final resend = _adoptPendingCopy(t);
      picked = _firstCity(t);
      _adoptDistrict(t);
      checkSupply();
      reconcileSteps(t);
      reconcileTravel(t);
      if (resend) unawaited(saveNow());
      unawaited(_refreshNotReadyLegs());
      unawaited(flushProblemQueue());
      await _runRecalculate();
    } catch (e) {
      if (_openingId != tripId) return;
      if (_isPlannerOff(e)) {
        plannerOff.value = true;
      } else if (_isGone(e)) {
        _markGone(tripId);
      } else if (!_isUnauthorized(e)) {
        if (!shown && !_openFromCache(tripId, e)) openFailed.value = true;
      }
    } finally {
      if (_openingId == tripId) isOpening.value = false;
    }
  }

  bool _adoptPendingCopy(TripModel t) {
    plan.value = t.plan;
    final pending = StorageService.getTripPending(t.id);
    if (pending == null) return false;
    TripPlan? local;
    try {
      local = TripPlan.fromJson(pending.plan);
    } catch (_) {
      local = null;
    }
    final base = pending.baseUpdatedAt;
    if (local == null || t.isCompleted) {
      StorageService.clearTripPending(t.id);
      return false;
    }
    if (base != null && base.isAtSameMomentAs(t.updatedAt)) {
      plan.value = local;
      return true;
    }
    _pendingRetry = local;
    saveFailed.value = true;
    return false;
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
    final job = _retryLeg;
    if (job != null && _lastPlanWasAuto) {
      await _planLegByCity(job.cityKey, maxDays: job.maxDays, exactDays: job.exactDays, keepDays: job.keepDays);
      return;
    }
    await (_lastPlanWasAuto ? autoPlan() : _runRecalculate());
  }

  int _otherLegDays(TripPlan p, int legIndex) => p.days.length - p.legDayCount(legIndex);

  int _legMaxDays(TripPlan p, int legIndex) {
    final room = TripConstants.maxDaysCap - _otherLegDays(p, legIndex);
    var cap = room < 1 ? 1 : room;
    final spots = p.legSpotCount(legIndex);
    if (spots > 0) {
      final tight = TripDaysRules.autoDaysFor(_legVisits(p, legIndex), p.settings.dayLimitMinutes) + 1;
      final own = p.legDayCount(legIndex);
      final limit = tight > own ? tight : own;
      if (limit < cap) cap = limit;
    }
    if (legIndex < p.legCount && _laterLegsHaveBookings(legIndex)) {
      final own = p.legDayCount(legIndex);
      return own < 1 ? 1 : (own > cap ? cap : own);
    }
    return cap;
  }

  Map<String, dynamic> _planBody(TripPlan p, int legIndex, String mode, {int? maxDays}) {
    if (!p.isMultiCity) {
      return {
        'cityKey': p.cityKey,
        'mode': mode,
        if (mode == 'auto') 'spots': p.allSpots.map((s) => s.toPlanInput()).toList(),
        if (mode != 'auto')
          'days': p.days
              .where((d) => d.spots.isNotEmpty)
              .map((d) => {
                    'day': d.day,
                    'spots': d.spots.map((s) => s.toPlanInput()).toList(),
                    ...TripStayBase.dayBodyOf(p, d.day, enquiryList),
                  })
              .toList(),
        'dayLimitMinutes': p.settings.dayLimitMinutes,
        'startDate': ?p.settings.startDateIso,
        if (mode == 'auto') 'maxDays': ?(maxDays ?? p.settings.maxDays),
        ...TripStayBase.bodyOf(p, 1, enquiryList),
      };
    }
    final leg = p.legAt(legIndex) ?? p.legs.first;
    final legDays = p.daysOf(legIndex);
    final start = p.legStart(legIndex);
    final offset = start < 1 ? 0 : start - 1;
    final startDate = start < 1 ? null : p.settings.dateOf(start);
    final firstHasSpots = legDays.isNotEmpty && legDays.first.spots.isNotEmpty;
    final used = legIndex >= 2 && (mode == 'auto' || firstHasSpots) ? (leg.arrival?.roadMinutes ?? 0) : 0;
    return {
      'cityKey': leg.cityKey,
      'mode': mode,
      if (mode == 'auto') 'spots': [for (final d in legDays) ...d.spots.map((s) => s.toPlanInput())],
      if (mode != 'auto')
        'days': legDays
            .where((d) => d.spots.isNotEmpty)
            .map((d) => {
                  'day': d.day - offset,
                  'spots': d.spots.map((s) => s.toPlanInput()).toList(),
                  ...TripStayBase.dayBodyOf(p, d.day, enquiryList),
                })
            .toList(),
      'dayLimitMinutes': p.settings.dayLimitMinutes,
      if (startDate != null) 'startDate': _isoDate(startDate),
      if (mode == 'auto') 'maxDays': maxDays ?? _legMaxDays(p, legIndex),
      if (used > 0) 'firstDayUsedMinutes': used,
      ...TripStayBase.bodyOf(p, leg.index, enquiryList),
      'legIndex': legIndex,
    };
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @visibleForTesting
  Map<String, dynamic> planBodyForTest(TripPlan p, int legIndex, String mode, {int? maxDays}) =>
      _planBody(p, legIndex, mode, maxDays: maxDays);

  Future<void> _enqueue(Future<void> Function() job) {
    final flow = _flow;
    final f = _legChain.then((_) async {
      if (flow != _flow) return;
      await job();
    }).catchError((Object _) {});
    _legChain = f;
    return f;
  }

  Future<void> autoPlan() => _enqueue(_runAutoPlan);

  List<int> _allocationFor(TripPlan p) {
    final counts = [for (final l in p.legs) p.legSpotCount(l.index)];
    final least = TripDaysRules.minDays(counts.length, counts);
    final low = least > TripConstants.maxDaysCap ? TripConstants.maxDaysCap : least;
    final wanted = (p.settings.maxDays ?? p.days.length).clamp(low, TripConstants.maxDaysCap).toInt();
    return TripDaysRules.allocate(wanted, [for (final l in p.legs) _legVisits(p, l.index)], p.settings.dayLimitMinutes);
  }

  static List<int> _legVisits(TripPlan p, int legIndex) => [
        for (final d in p.daysOf(legIndex)) for (final s in d.spots) s.visitMinutes,
      ];

  Future<void> _runAutoPlan() async {
    final p = plan.value;
    if (p == null || p.spotCount == 0) return;
    _lastPlanWasAuto = true;
    _retryLeg = null;
    final seq = ++_planSeq;
    final edit = _editSeq;
    isPlanning.value = true;
    _clearPlanError();
    int? inFlight;
    _autoJobs++;
    try {
      final targets = [
        for (final l in p.legs)
          if (p.legSpotCount(l.index) > 0) l.cityKey,
      ];
      if (targets.isEmpty) targets.add(p.cityKey);
      final alloc = _allocationFor(p);
      TripPlanResult? last;
      for (final cityKey in targets) {
        final cur = plan.value;
        if (cur == null) return;
        final k = cur.legIndexOfCity(cityKey) ?? 1;
        final keep = alloc[(k - 1).clamp(0, alloc.length - 1).toInt()];
        final sent = _legSpotIds(cur, k);
        inFlight = cityKey;
        final r = await _repo.plan(_planBody(cur, k, 'auto', maxDays: keep));
        inFlight = null;
        if (seq != _planSeq) return;
        final now = plan.value;
        final k2 = now?.legIndexOfCity(cityKey) ?? 1;
        if (now == null || (edit != _editSeq && !_sameLegSpots(sent, _legSpotIds(now, k2)))) {
          _lastPlanWasAuto = false;
          unawaited(_runRecalculate());
          return;
        }
        if (edit != _editSeq) _recalcAfterAuto = true;
        final before = now;
        final after = _applyAutoLeg(before, k2, r);
        plan.value = after;
        result.value = last = _mergeLegResult(before, after, k2, r);
      }
      _lastPlanWasAuto = false;
      if (last != null) _cacheResult(last);
      scheduleSave();
      _recalcForDayEnds();
      if (_settingsChangedWhilePlanning) {
        _settingsChangedWhilePlanning = false;
        unawaited(recalculate());
      }
    } catch (e) {
      if (seq != _planSeq) return;
      if (_isPlannerOff(e)) {
        plannerOff.value = true;
      } else if (!_isUnauthorized(e)) {
        if (inFlight != null) _markLegUnavailable(e, inFlight);
        _onPlanError(e);
      }
    } finally {
      if (seq == _planSeq) isPlanning.value = false;
      _autoJobs--;
      _flushDeferredRecalc();
    }
  }

  void _flushDeferredRecalc() {
    if (_autoJobs > 0 || !_recalcAfterAuto) return;
    _recalcAfterAuto = false;
    unawaited(recalculate());
  }

  static List<List<String>> _legSpotIds(TripPlan p, int legIndex) => [
        for (final d in p.daysOf(legIndex)) [for (final s in d.spots) s.id],
      ];

  static bool _sameLegSpots(List<List<String>> a, List<List<String>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!listEquals(a[i], b[i])) return false;
    }
    return true;
  }

  Future<void> _planLegByCity(int cityKey, {int? maxDays, int? exactDays, bool keepDays = false}) =>
      _enqueue(() => _runPlanLeg(cityKey, maxDays: maxDays, exactDays: exactDays, keepDays: keepDays));

  Future<bool> _planLegToDays(int cityKey, int days) async {
    var ok = false;
    await _enqueue(() async {
      ok = await _runPlanLeg(cityKey, exactDays: days);
    });
    return ok;
  }

  Future<bool> _runPlanLeg(int cityKey, {int? maxDays, int? exactDays, bool keepDays = false}) async {
    final p = plan.value;
    final k = p?.legIndexOfCity(cityKey);
    if (p == null || k == null) return false;
    if (p.legSpotCount(k) == 0) {
      if (exactDays == null) return false;
      _sizeLeg(k, exactDays);
      return true;
    }
    _lastPlanWasAuto = true;
    _retryLeg = (cityKey: cityKey, maxDays: maxDays, exactDays: null, keepDays: keepDays || exactDays != null);
    final seq = ++_planSeq;
    final edit = _editSeq;
    final hold = keepDays || (k < p.legCount && _laterLegsHaveBookings(k));
    final keep = exactDays ?? (hold ? p.legDayCount(k) : null);
    final sent = _legSpotIds(p, k);
    isPlanning.value = true;
    _clearPlanError();
    _autoJobs++;
    try {
      final r = await _repo.plan(_planBody(p, k, 'auto', maxDays: exactDays ?? maxDays));
      final edited = plan.value?.legIndexOfCity(cityKey);
      if (seq != _planSeq) {
        if (exactDays == null || edited == null) return false;
        _sizeLeg(edited, exactDays);
        return true;
      }
      _lastPlanWasAuto = false;
      _retryLeg = null;
      final cur = plan.value;
      final untouched = cur != null && edited != null && _sameLegSpots(sent, _legSpotIds(cur, edited));
      if (edit != _editSeq && !untouched) {
        if (exactDays != null && edited != null) {
          _sizeLeg(edited, exactDays);
          return true;
        }
        unawaited(_runRecalculate());
        return exactDays == null;
      }
      if (cur == null) return false;
      if (edit != _editSeq) _recalcAfterAuto = true;
      final before = cur;
      final k2 = edited;
      if (k2 == null) return false;
      final after = _applyAutoLeg(before, k2, r, minDays: keep);
      plan.value = after;
      final merged = _mergeLegResult(before, after, k2, r);
      result.value = merged;
      _cacheResult(merged);
      scheduleSave();
      _recalcForDayEnds();
      return true;
    } catch (e) {
      if (seq != _planSeq) return false;
      if (_isPlannerOff(e)) {
        plannerOff.value = true;
      } else if (!_isUnauthorized(e)) {
        _markLegUnavailable(e, cityKey);
        _onPlanError(e);
      }
      return false;
    } finally {
      if (seq == _planSeq) isPlanning.value = false;
      _autoJobs--;
      _flushDeferredRecalc();
    }
  }

  static TripPlanDay _shiftDay(TripPlanDay d, int by) => by == 0
      ? d
      : TripPlanDay(
          day: d.day + by,
          spotIds: d.spotIds,
          visitMinutes: d.visitMinutes,
          driveMinutes: d.driveMinutes,
          totalMinutes: d.totalMinutes,
          km: d.km,
          overLimit: d.overLimit,
          isEstimate: d.isEstimate,
          legs: d.legs,
          routeGeoJson: d.routeGeoJson,
        );

  static TripWarning _shiftWarning(TripWarning w, int by) => by == 0 || w.day == null
      ? w
      : TripWarning(code: w.code, message: w.message, spotId: w.spotId, day: w.day! + by);

  TripPlanResult _mergeLegResult(TripPlan before, TripPlan after, int legIndex, TripPlanResult legLocal) {
    if (!after.isMultiCity) return legLocal;
    final old = result.value;
    final days = <TripPlanDay>[];
    final warnings = <TripWarning>[];
    final codes = <String>{};
    for (var k = 1; k <= after.legCount; k++) {
      if (k == legIndex) {
        final off = after.legStart(k) - 1;
        days.addAll(legLocal.days.map((d) => _shiftDay(d, off)));
        for (final w in legLocal.warnings) {
          if (w.day != null) {
            warnings.add(_shiftWarning(w, off));
          } else if (codes.add(w.code)) {
            warnings.add(w);
          }
        }
        continue;
      }
      if (old == null) continue;
      final ob = before.legStart(k);
      final oe = before.legEnd(k);
      if (ob < 1) continue;
      final delta = after.legStart(k) - ob;
      days.addAll(old.days.where((d) => d.day >= ob && d.day <= oe).map((d) => _shiftDay(d, delta)));
      warnings.addAll(old.warnings
          .where((w) => w.day != null && w.day! >= ob && w.day! <= oe)
          .map((w) => _shiftWarning(w, delta)));
    }
    for (final w in old?.warnings ?? const <TripWarning>[]) {
      if (w.day == null && codes.add(w.code)) warnings.add(w);
    }
    days.sort((a, b) => a.day.compareTo(b.day));
    return TripPlanResult(
      days: days,
      centreLatitude: after.centreLatitude,
      centreLongitude: after.centreLongitude,
      warnings: warnings,
      osrmAvailable: legLocal.osrmAvailable,
      dayLimitMinutes: legLocal.dayLimitMinutes,
    );
  }

  TripPlan _applyAutoLeg(TripPlan p, int legIndex, TripPlanResult r, {int? minDays}) {
    final legDays = p.daysOf(legIndex);
    final byId = {for (final d in legDays) for (final s in d.spots) s.id: s};
    final used = <String>{};
    final built = <TripDay>[];
    TripDay carry(int pos, List<TripSpotRef> spots) {
      final old = pos < legDays.length ? legDays[pos] : null;
      return TripDay(
        day: old?.day ?? -(pos + 1),
        leg: legIndex,
        spots: spots,
        restDay: spots.isEmpty && (old?.restDay ?? false),
      );
    }

    for (final rd in r.days) {
      final spots = <TripSpotRef>[];
      for (final id in rd.spotIds) {
        final s = byId[id];
        if (s != null && used.add(id)) spots.add(s);
      }
      built.add(carry(built.length, spots));
    }
    while (built.isNotEmpty && built.last.spots.isEmpty) {
      built.removeLast();
    }
    final leftover = byId.values.where((s) => !used.contains(s.id)).toList();
    if (built.isEmpty) {
      built.add(carry(0, leftover));
    } else if (leftover.isNotEmpty) {
      built[built.length - 1] = built.last.copyWith(spots: [...built.last.spots, ...leftover]);
    }
    if (minDays != null) {
      final room = TripConstants.maxDaysCap - _otherLegDays(p, legIndex);
      final target = minDays > room ? room : minDays;
      while (built.length < target) {
        built.add(carry(built.length, const []));
      }
    }
    final leg = p.legAt(legIndex);
    final legs = leg == null || r.centreLatitude == null || r.centreLongitude == null
        ? p.legs
        : [
            for (final l in p.legs)
              l.index == legIndex ? l.copyWith(latitude: r.centreLatitude, longitude: r.centreLongitude) : l,
          ];
    if (!p.isMultiCity) {
      return p.copyWith(legs: legs, days: _renumber(built, keepEmptyDays: true, legCount: 1));
    }
    final before = p.days.where((d) => d.leg < legIndex).toList();
    final after = p.days.where((d) => d.leg > legIndex).toList();
    return p.copyWith(
      legs: legs,
      days: _renumber([...before, ...built, ...after], keepEmptyDays: true, legCount: p.legCount),
    );
  }

  @visibleForTesting
  TripPlan applyAutoForTest(TripPlan p, int legIndex, TripPlanResult r) => _applyAutoLeg(p, legIndex, r);

  @visibleForTesting
  List<TripDay> renumberForTest(List<TripDay> days, {bool keepEmptyDays = false}) =>
      _renumber(days, keepEmptyDays: keepEmptyDays);

  Future<void> recalculate() {
    _recalcTimer?.cancel();
    final waiter = _recalcWaiter ??= Completer<void>();
    final wait = _planWait;
    final delay = wait != null && wait > TripConstants.recalcDebounce ? wait : TripConstants.recalcDebounce;
    _recalcTimer = Timer(delay, () {
      if (_autoJobs > 0) {
        _recalcAfterAuto = true;
        return;
      }
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
    int? inFlight;
    try {
      if (!p.isMultiCity) {
        final r = await _repo.plan(_planBody(p, 1, 'recalculate'));
        if (seq != _planSeq) return;
        result.value = r;
        _cacheResult(r);
        final current = plan.value;
        if (current != null && (r.centreLatitude != current.centreLatitude || r.centreLongitude != current.centreLongitude)) {
          plan.value = current.copyWith(centreLatitude: r.centreLatitude, centreLongitude: r.centreLongitude);
        }
        return;
      }
      final days = <TripPlanDay>[];
      final warnings = <TripWarning>[];
      final codes = <String>{};
      var osrm = true;
      var limit = p.settings.dayLimitMinutes;
      for (final l in p.legs) {
        if (p.legSpotCount(l.index) == 0) continue;
        final body = _planBody(p, l.index, 'recalculate');
        final sig = jsonEncode({...body}..remove('legIndex'));
        final hit = _legResults[l.cityKey];
        inFlight = l.cityKey;
        final r = hit != null && hit.body == sig ? hit.result : await _repo.plan(body);
        inFlight = null;
        if (seq != _planSeq) return;
        _legResults[l.cityKey] = (body: sig, result: r);
        final off = p.legStart(l.index) - 1;
        days.addAll(r.days.map((d) => _shiftDay(d, off)));
        for (final w in r.warnings) {
          if (w.day != null) {
            warnings.add(_shiftWarning(w, off));
          } else if (codes.add(w.code)) {
            warnings.add(w);
          }
        }
        osrm = osrm && r.osrmAvailable;
        limit = r.dayLimitMinutes;
      }
      days.sort((a, b) => a.day.compareTo(b.day));
      final merged = TripPlanResult(
        days: days,
        centreLatitude: p.centreLatitude,
        centreLongitude: p.centreLongitude,
        warnings: warnings,
        osrmAvailable: osrm,
        dayLimitMinutes: limit,
      );
      result.value = merged;
      _cacheResult(merged);
    } catch (e) {
      if (seq != _planSeq) return;
      if (_isPlannerOff(e)) {
        plannerOff.value = true;
      } else if (!_isUnauthorized(e)) {
        if (inFlight != null) _markLegUnavailable(e, inFlight);
        _onPlanError(e);
      }
    } finally {
      if (seq == _planSeq) isPlanning.value = false;
    }
  }

  List<TripDay> _renumber(
    List<TripDay> days, {
    bool keepEmptyDays = false,
    Set<int> keepLegs = const {},
    int? legCount,
  }) {
    final maxLeg = days.fold<int>(1, (m, d) => d.leg > m ? d.leg : m);
    final count = legCount ?? maxLeg;
    if (count <= 1) {
      final single = [for (final d in days) d.leg == 1 ? d : d.copyWith(leg: 1)];
      final lastFull = keepEmptyDays ? single.length - 1 : single.lastIndexWhere(_keptDay);
      final kept = lastFull < 0 ? <TripDay>[] : single.sublist(0, lastFull + 1);
      if (kept.isEmpty) return [const TripDay(day: 1)];
      return _numbered(kept);
    }
    final kept = <TripDay>[];
    for (var k = 1; k <= count; k++) {
      final group = [
        for (final d in days)
          if (d.leg.clamp(1, count) == k) d.leg == k ? d : d.copyWith(leg: k),
      ];
      if (group.isEmpty) {
        kept.add(TripDay(day: -1000 - k, leg: k));
        continue;
      }
      final keepAll = keepEmptyDays || keepLegs.contains(k);
      final lastFull = keepAll ? group.length - 1 : group.lastIndexWhere(_keptDay);
      kept.addAll(group.sublist(0, lastFull < 0 ? 1 : lastFull + 1));
    }
    return _numbered(kept);
  }

  static bool _keptDay(TripDay d) => d.spots.isNotEmpty || d.restDay;

  List<TripDay> _numbered(List<TripDay> kept) => [
        for (var i = 0; i < kept.length; i++)
          TripDay(day: i + 1, leg: kept[i].leg, spots: kept[i].spots, restDay: kept[i].restDay && kept[i].spots.isEmpty),
      ];

  void _applyEdit(List<TripDay> days, {bool keepEmptyDays = false}) {
    final p = plan.value;
    if (p == null) return;
    _editSeq++;
    final trim = _trimmedLegs(p, days);
    if (days.length == p.days.length) _spotsEdited = true;
    plan.value = p.copyWith(
      days: _renumber(
        days,
        keepEmptyDays: keepEmptyDays,
        keepLegs: {for (var k = 1; k <= p.legCount; k++) if (!trim.contains(k)) k},
        legCount: p.legCount,
      ),
    );
    recalculate();
    scheduleSave();
  }

  // Only a leg whose own spots moved between days may lose trailing empty days.
  Set<int> _trimmedLegs(TripPlan p, List<TripDay> next) {
    if (!p.isMultiCity) return const {};
    final anchored = _anchoredLegs(p);
    return {
      for (final d in next)
        if (!anchored.contains(d.leg) && !_sameSpotSet(p.dayAt(d.day)?.spots, d.spots)) d.leg,
    };
  }

  static bool _sameSpotSet(List<TripSpotRef>? a, List<TripSpotRef> b) {
    if (a == null || a.length != b.length) return false;
    final ids = {for (final s in a) s.id};
    return b.every((s) => ids.contains(s.id));
  }

  @visibleForTesting
  Set<int> trimmedLegsForTest(TripPlan p, List<TripDay> next) => _trimmedLegs(p, next);

  // Earlier legs keep their day count while a later leg has a dated booking, so its dates never move.
  Set<int> _anchoredLegs(TripPlan p) {
    if (!p.isMultiCity) return const {};
    return {
      for (var k = 1; k < p.legCount; k++)
        if (_laterLegsHaveBookings(k)) k,
    };
  }

  List<TripDay>? _movedDays(String id, int toDay) {
    final p = plan.value;
    if (p == null) return null;
    final fromDay = p.dayOfSpot(id);
    final spot = p.spotById(id);
    if (fromDay == null || spot == null || fromDay == toDay || p.dayAt(toDay) == null) return null;
    if (p.legIndexOf(fromDay) != p.legIndexOf(toDay)) return null;
    final at = _insertion(id, toDay)?.index;
    return [
      for (final d in p.days)
        if (d.day == fromDay)
          d.copyWith(spots: d.spots.where((s) => s.id != id).toList())
        else if (d.day == toDay)
          d.copyWith(spots: [...d.spots]..insert((at ?? d.spots.length).clamp(0, d.spots.length).toInt(), spot))
        else
          d,
    ];
  }

  List<TripDay>? _removedDays(String id) {
    final p = plan.value;
    if (p == null || p.dayOfSpot(id) == null) return null;
    return [for (final d in p.days) d.copyWith(spots: d.spots.where((s) => s.id != id).toList())];
  }

  bool moveSpot(String id, int toDay, {bool keepEmptyDays = false}) {
    final p = plan.value;
    if (p == null || isReadOnly) return false;
    final fromDay = p.dayOfSpot(id);
    if (fromDay != null && p.dayAt(toDay) != null && p.legIndexOf(fromDay) != p.legIndexOf(toDay)) {
      AppToast.warning(TripStringsMcaA1.differentCity);
      return false;
    }
    if (fromDay != null && fromDay != toDay && !TripDaysRules.canAddOnDay(p, toDay)) {
      AppToast.warning(TripStringsV2Plan.dayFull);
      return false;
    }
    final next = _movedDays(id, toDay);
    if (next == null) return false;
    _applyEdit(next, keepEmptyDays: keepEmptyDays);
    return true;
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
    _applyEdit([for (final x in p.days) x.day == day ? x.copyWith(spots: spots) : x], keepEmptyDays: true);
  }

  void removeSpot(String id, {bool keepEmptyDays = false}) {
    if (isReadOnly) return;
    final next = _removedDays(id);
    if (next != null) _applyEdit(next, keepEmptyDays: keepEmptyDays);
  }

  Future<void> setPace(int minutes) async {
    final p = plan.value;
    if (p == null || isReadOnly || p.settings.dayLimitMinutes == minutes) return;
    plan.value = p.copyWith(settings: p.settings.copyWith(dayLimitMinutes: minutes));
    scheduleSave();
    await recalculate();
  }

  void insertSpotAt(TripSpotRef spot, int day, int index) {
    final p = plan.value;
    final d = p?.dayAt(day);
    if (p == null || d == null || isReadOnly || p.spotById(spot.id) != null) return;
    if (d.spots.length >= TripConstants.maxSpotsPerDay) {
      AppToast.warning(TripStringsV2Plan.dayFull);
      return;
    }
    final at = index.clamp(0, d.spots.length).toInt();
    _applyEdit([
      for (final x in p.days) x.day == day ? x.copyWith(spots: [...x.spots]..insert(at, spot)) : x,
    ], keepEmptyDays: true);
  }

  bool get canAddDay {
    final p = plan.value;
    return p != null && !isReadOnly && !needsUpdate.value && p.days.length < TripConstants.maxDaysCap;
  }

  void addDay({int? afterDay}) {
    final p = plan.value;
    if (p == null || isReadOnly || p.days.isEmpty) return;
    if (p.days.length >= TripConstants.maxDaysCap) {
      AppToast.warning(TripStringsV2Plan.maxDays);
      return;
    }
    final at = afterDay != null && p.dayAt(afterDay) != null ? afterDay : p.days.last.day;
    final leg = p.legIndexOf(at);
    final next = <TripDay>[];
    for (final d in p.days) {
      next.add(d);
      if (d.day == at) next.add(TripDay(day: -1, leg: leg));
    }
    _applyEdit(next, keepEmptyDays: true);
  }

  TripDayRemoveBlock removeDay(int day) {
    final p = plan.value;
    final d = p?.dayAt(day);
    if (p == null || d == null || !canEditDay(day) || legRunning(d.leg) || _saveBlocked) return TripDayRemoveBlock.readOnly;
    if (p.legDayCount(d.leg) <= 1) return TripDayRemoveBlock.lastDay;
    if (!TripDaysRules.canRemoveDay(p, day)) return TripDayRemoveBlock.placesDontFit;
    final block = p.daysOf(d.leg).where((x) => x.day != day).toList();
    final lists = {for (final x in block) x.day: [...x.spots]};
    final order = [...block]..sort((a, b) => (a.day - day).abs().compareTo((b.day - day).abs()));
    for (final s in d.spots) {
      final target = order.firstWhereOrNull((x) => lists[x.day]!.length < TripConstants.maxSpotsPerDay && canEditDay(x.day));
      if (target == null) return TripDayRemoveBlock.placesDontFit;
      lists[target.day]!.add(s);
    }
    _applyEdit([
      for (final x in p.days)
        if (x.day != day) lists.containsKey(x.day) ? x.copyWith(spots: lists[x.day]) : x,
    ], keepEmptyDays: true);
    return TripDayRemoveBlock.none;
  }

  bool addSpots(List<TripSpotModel> spots, {int? legIndex, int? day}) {
    final p = plan.value;
    if (p == null || p.days.isEmpty || isReadOnly) return false;
    final existing = p.spotIds;
    final room = TripConstants.maxSpots - existing.length;
    final fresh = spots.where((s) => !existing.contains(s.id)).toList();
    if (fresh.isEmpty) return false;
    if (fresh.length > room) AppToast.warning(TripStringsMcaA1.maxPlaces);
    final adding = fresh.take(room < 0 ? 0 : room).map(TripSpotRef.fromSpot).toList();
    if (adding.isEmpty) return false;
    const cap = TripConstants.maxSpotsPerDay;
    final picked = day != null && p.dayAt(day) != null;
    final edited = <int, List<TripSpotRef>>{};
    var refused = 0;
    if (picked) {
      final spotsOnDay = p.dayAt(day)!.spots;
      if (spotsOnDay.length + adding.length > cap) {
        refused = adding.length;
      } else {
        final at = _pickInsertion(adding.first, day).index.clamp(0, spotsOnDay.length).toInt();
        edited[day] = adding.length == 1 ? ([...spotsOnDay]..insert(at, adding.first)) : [...spotsOnDay, ...adding];
      }
    } else {
      var left = adding;
      for (final d in _addOrder(p, legIndex ?? p.legCount)) {
        final free = cap - d.spots.length;
        if (free <= 0) continue;
        final take = left.take(free).toList();
        left = left.sublist(take.length);
        edited[d.day] = [...d.spots, ...take];
        if (left.isEmpty) break;
      }
      refused = left.length;
    }
    if (refused > 0) AppToast.warning(TripStringsV2Create.dayFull);
    if (edited.isEmpty) return false;
    _applyEdit(
      [for (final d in p.days) edited.containsKey(d.day) ? d.copyWith(spots: edited[d.day]) : d],
      keepEmptyDays: picked,
    );
    return true;
  }

  int addCapacity(int legIndex) {
    final p = plan.value;
    if (p == null) return 0;
    var n = 0;
    for (final d in _addOrder(p, legIndex)) {
      final free = TripConstants.maxSpotsPerDay - d.spots.length;
      if (free > 0) n += free;
    }
    return n;
  }

  // New places fill the last day of the city that is not a rest day first, then the days before it.
  static List<TripDay> _addOrder(TripPlan p, int leg) {
    final days = [for (final d in p.days) if (!p.isMultiCity || d.leg == leg) d];
    final open = days.where((d) => !d.restDay).toList();
    final pool = open.isEmpty ? days : open;
    if (pool.isEmpty) return const [];
    return [pool.last, ...pool.reversed.skip(1)];
  }

  void showLegBlock(TripLegEditBlock block, {String? city}) {
    switch (block) {
      case TripLegEditBlock.maxLegs:
        AppToast.warning(TripStringsMcaA1.maxCities);
      case TripLegEditBlock.noDays:
        AppToast.warning(TripStringsMcaA1.noDaysLeft);
      case TripLegEditBlock.duplicate:
        AppToast.warning(TripStringsMcaA1.alreadyInTrip(city ?? ''));
      case TripLegEditBlock.offline:
        AppToast.warning(TripStrings.checkConnection);
      case TripLegEditBlock.bookings:
        AppToast.warning(TripStringsMcaA1.cancelBookingsFirst(city ?? ''));
      default:
        return;
    }
  }

  TripLegEditBlock canAddLeg(TripCityModel? city) {
    final p = plan.value;
    if (p == null || isReadOnly || _saveBlocked) return TripLegEditBlock.readOnly;
    if (offline.value) return TripLegEditBlock.offline;
    if (p.legs.length >= TripConstants.maxLegs) return TripLegEditBlock.maxLegs;
    if (p.days.length >= TripConstants.maxDaysCap) return TripLegEditBlock.noDays;
    if (city != null && p.legs.any((l) => l.cityKey == city.cityKey)) return TripLegEditBlock.duplicate;
    return TripLegEditBlock.none;
  }

  Future<TripLegEditBlock> addLeg(TripCityModel city, List<TripSpotModel> spots) async {
    final block = canAddLeg(city);
    if (block != TripLegEditBlock.none) {
      showLegBlock(block, city: city.name);
      return block;
    }
    final p = plan.value!;
    final n = p.legs.length + 1;
    final existing = p.spotIds;
    final room = TripConstants.maxSpots - existing.length;
    final fresh = spots.where((s) => !existing.contains(s.id)).toList();
    if (fresh.length > room) AppToast.warning(TripStringsMcaA1.maxPlaces);
    final adding = fresh.take(room < 0 ? 0 : room).map(TripSpotRef.fromSpot).toList();
    plan.value = p.copyWith(
      legs: [...p.legs, TripCityLeg.fromCity(n, city)],
      days: [...p.days, TripDay(day: p.days.length + 1, leg: n, spots: adding)],
    );
    lastAddedLeg.value = n;
    _refreshLegSupply();
    scheduleSave();
    AppToast.success(TripStringsMcaA1.cityAdded(city.name));
    if (adding.isNotEmpty) unawaited(_planLegByCity(city.cityKey));
    return TripLegEditBlock.none;
  }

  void _refreshLegSupply() {
    final p = plan.value;
    if (p == null) return;
    final next = <int, bool?>{};
    for (final l in p.legs) {
      if (l.index == 1) {
        if (taxiSupplyByLeg.containsKey(1)) next[1] = taxiSupply.value;
        continue;
      }
      final key = TripSupplyArea.keyOf(l);
      if (_supplyByDistrict.containsKey(key)) next[l.index] = _supplyByDistrict[key];
    }
    taxiSupplyByLeg.assignAll(next);
  }

  Future<void> ensureSupply(int legIndex) async {
    await Future<void>.value();
    final p = plan.value;
    final leg = p?.legAt(legIndex);
    if (p == null || leg == null) return;
    if (legIndex == 1 || taxiSupplyByLeg[legIndex] != null) return;
    if (!TripSupplyArea.hasCity(leg)) {
      taxiSupplyByLeg[legIndex] = false;
      return;
    }
    final key = TripSupplyArea.keyOf(leg);
    final cached = _supplyByDistrict[key];
    if (cached != null) {
      taxiSupplyByLeg[legIndex] = cached;
      return;
    }
    if (taxiTabOff.value || !_supplyTried.add(key)) {
      if (!taxiSupplyByLeg.containsKey(legIndex)) taxiSupplyByLeg[legIndex] = null;
      return;
    }
    final has = await _browseLeg(leg);
    if (has == null) {
      if (!taxiSupplyByLeg.containsKey(legIndex)) taxiSupplyByLeg[legIndex] = null;
      if (!taxiTabOff.value) supplyCheckFailed.add(legIndex);
      return;
    }
    final now = plan.value;
    final k = now?.legIndexOfCity(leg.cityKey);
    if (now == null || k == null) return;
    taxiSupplyByLeg[k] = has;
    supplyCheckFailed.remove(k);
  }

  Future<bool?> _browseLeg(TripCityLeg leg) {
    final key = TripSupplyArea.keyOf(leg);
    final running = _supplyInFlight[key];
    if (running != null) return running;
    final f = () async {
      try {
        final page = await const TaxiBrowseRepository().browseLocal(
          cityKey: leg.cityKey,
          localRate: true,
          pageSize: 1,
          centre: TripSupplyArea.centreOf(leg),
        );
        final has = page.items.isNotEmpty;
        _supplyByDistrict[key] = has;
        return has;
      } catch (e) {
        if (DioErrorMapper.errorType(e) == ApiService.tabInactiveType) taxiTabOff.value = true;
        if (_isCitiesUnavailable(e)) citiesUnavailable.value = true;
        return null;
      } finally {
        _supplyInFlight.remove(key);
      }
    }();
    _supplyInFlight[key] = f;
    return f;
  }

  void _applyLegChange(TripPlan changed) {
    var next = changed;
    final before = plan.value;
    if (before != null) {
      final stale = TripGuideRules.staleKeys(before, next);
      final g = before.guide;
      if (g != null) {
        final keep = {for (final e in g.choices.entries) if (!stale.contains(e.key)) e.key: e.value};
        next = next.withGuide(TripGuide(step: stale.contains(g.step) ? '' : g.step, choices: keep, overview: g.overview));
      }
      guideDropStale(before, next);
    }
    final oldFirst = plan.value?.cityKey;
    _remapTravelGaps(plan.value, next);
    _editSeq++;
    plan.value = next;
    final added = lastAddedLeg.value;
    if (added != null && added > next.legCount) lastAddedLeg.value = null;
    if (next.legs.isNotEmpty) picked = next.legs.first.city;
    if (oldFirst != next.cityKey) {
      cityHasTaxis.value = null;
      taxiSupply.value = null;
      taxiSupplyByLeg.remove(1);
      unawaited(checkSupply());
    }
    _refreshLegSupply();
    recalculate();
    scheduleSave();
    guideRefresh();
  }

  void _remapTravelGaps(TripPlan? old, TripPlan next) {
    if (travelGaps.isEmpty) return;
    final moved = <int, String?>{};
    for (final e in travelGaps.entries) {
      final to = old?.legAt(e.key);
      final from = old?.legAt(e.key - 1);
      if (to == null || from == null) continue;
      for (var k = 2; k <= next.legCount; k++) {
        if (next.legAt(k)?.cityKey == to.cityKey && next.legAt(k - 1)?.cityKey == from.cityKey) {
          moved[k] = e.value;
          break;
        }
      }
    }
    travelGaps.assignAll(moved);
  }

  @visibleForTesting
  void remapTravelGapsForTest(TripPlan? old, TripPlan next) => _remapTravelGaps(old, next);

  TripLegEditBlock canRemoveLeg(int legIndex) {
    final p = plan.value;
    if (p == null || isReadOnly || _saveBlocked) return TripLegEditBlock.readOnly;
    if (p.legs.length < 2) return TripLegEditBlock.onlyLeg;
    if (p.legAt(legIndex) == null) return TripLegEditBlock.edge;
    if (legRunning(legIndex)) return TripLegEditBlock.running;
    return TripLegEditBlock.none;
  }

  TripLegRemoveMode removeLegMode(int legIndex) =>
      legRemoveImpact(legIndex).laterKeepDates ? TripLegRemoveMode.keepLaterDates : TripLegRemoveMode.shift;

  TripLegEditBlock removeLeg(int legIndex, {bool keepBookings = false}) {
    final block = canRemoveLeg(legIndex);
    if (block != TripLegEditBlock.none) return block;
    final impact = legRemoveImpact(legIndex);
    if (!impact.isEmpty && (!keepBookings || impact.carsBlockKeep)) return TripLegEditBlock.bookings;
    final p = plan.value!;
    final name = p.legAt(legIndex)!.cityName;
    final mode = impact.laterKeepDates ? TripLegRemoveMode.keepLaterDates : TripLegRemoveMode.shift;
    _applyLegChange(_removeLegPlan(p, legIndex, mode));
    AppToast.success(TripStringsMcaA1.cityRemoved(name));
    return TripLegEditBlock.none;
  }

  TripPlan _removeLegPlan(TripPlan p, int legIndex, TripLegRemoveMode mode) {
    if (p.legAt(legIndex) == null || p.legs.length < 2) return p;
    final keep = mode == TripLegRemoveMode.keepLaterDates;
    final legs = [
      for (final l in p.legs)
        if (l.index != legIndex) l.index == legIndex + 1 ? l.copyWith(clearArrival: true) : l,
    ];
    final removed = p.legDayCount(legIndex);
    final days = <TripDay>[];
    for (final d in p.days) {
      if (d.leg < legIndex) {
        days.add(d);
      } else if (d.leg > legIndex) {
        days.add(d.copyWith(leg: d.leg - 1));
      } else if (keep && legIndex > 1) {
        days.add(TripDay(day: d.day, leg: legIndex - 1));
      }
    }
    var settings = p.settings;
    final start = settings.startDate;
    if (keep && legIndex == 1 && start != null) {
      settings = settings.copyWith(startDate: DateTime(start.year, start.month, start.day + removed));
    }
    return TripPlan(
      version: p.version,
      legs: TripPlan.reindex(legs),
      days: _renumber(days, keepEmptyDays: true, legCount: legs.length),
      settings: settings,
      steps: p.steps,
      taxiMark: p.taxiMark,
      dismissedEnquiryIds: p.dismissedEnquiryIds,
      guide: p.guide,
    );
  }

  @visibleForTesting
  TripPlan removeLegForTest(TripPlan p, int legIndex, TripLegRemoveMode mode) => _removeLegPlan(p, legIndex, mode);

  TripLegEditBlock canMoveLeg(int legIndex, bool up) {
    final p = plan.value;
    if (p == null || isReadOnly || _saveBlocked) return TripLegEditBlock.readOnly;
    final other = up ? legIndex - 1 : legIndex + 1;
    if (p.legAt(legIndex) == null || p.legAt(other) == null) return TripLegEditBlock.edge;
    if (legRunning(legIndex) || legRunning(other)) return TripLegEditBlock.running;
    final below = (legIndex > other ? legIndex : other) + 1;
    if (_legHasBookings(legIndex) || _legHasBookings(other) || _hasOpenSegmentRows(below)) {
      return TripLegEditBlock.bookings;
    }
    return TripLegEditBlock.none;
  }

  TripLegEditBlock moveLeg(int legIndex, bool up) {
    final block = canMoveLeg(legIndex, up);
    if (block != TripLegEditBlock.none) return block;
    _applyLegChange(_moveLegPlan(plan.value!, legIndex, up));
    return TripLegEditBlock.none;
  }

  TripPlan _moveLegPlan(TripPlan p, int legIndex, bool up) {
    final a = up ? legIndex - 1 : legIndex;
    final b = a + 1;
    if (p.legAt(a) == null || p.legAt(b) == null) return p;
    final legs = [
      for (final l in p.legs)
        if (l.index == a)
          p.legAt(b)!.copyWith(clearArrival: true)
        else if (l.index == b)
          p.legAt(a)!.copyWith(clearArrival: true)
        else if (l.index == b + 1)
          l.copyWith(clearArrival: true)
        else
          l,
    ];
    final days = [
      for (final d in p.days)
        if (d.leg < a) d,
      for (final d in p.days)
        if (d.leg == b) d.copyWith(leg: a),
      for (final d in p.days)
        if (d.leg == a) d.copyWith(leg: b),
      for (final d in p.days)
        if (d.leg > b) d,
    ];
    return TripPlan(
      version: p.version,
      legs: TripPlan.reindex(legs),
      days: _renumber(days, keepEmptyDays: true, legCount: legs.length),
      settings: p.settings,
      steps: p.steps,
      taxiMark: p.taxiMark,
      dismissedEnquiryIds: p.dismissedEnquiryIds,
      guide: p.guide,
    );
  }

  @visibleForTesting
  TripPlan moveLegForTest(TripPlan p, int legIndex, bool up) => _moveLegPlan(p, legIndex, up);

  int maxDaysForLeg(int legIndex) {
    final p = plan.value;
    if (p == null) return 1;
    return _legMaxDays(p, legIndex);
  }

  bool growthBlockedByBookings(int legIndex) {
    final p = plan.value;
    return p != null && legIndex < p.legCount && _laterLegsHaveBookings(legIndex);
  }

  int _pastDaysOf(int legIndex) => legDays(legIndex).where(isDayPast).length;

  TripLegEditBlock canSetLegDays(int legIndex, int days, {bool keepBookings = false}) {
    final p = plan.value;
    if (p == null || isReadOnly || _saveBlocked) return TripLegEditBlock.readOnly;
    if (p.legAt(legIndex) == null || days < 1 || days * TripConstants.maxSpotsPerDay < p.legSpotCount(legIndex)) {
      return TripLegEditBlock.edge;
    }
    if (days == p.legDayCount(legIndex)) return TripLegEditBlock.none;
    if (days > p.legDayCount(legIndex) && growthBlockedByBookings(legIndex)) return TripLegEditBlock.bookings;
    if (days > maxDaysForLeg(legIndex)) return TripLegEditBlock.noDays;
    if (days < minDaysForLeg(legIndex)) return TripLegEditBlock.running;
    if (!keepBookings && !legShrinkImpact(legIndex, days).isEmpty) return TripLegEditBlock.bookings;
    return TripLegEditBlock.none;
  }

  Future<bool> setLegDays(int legIndex, int days, {bool keepBookings = false}) async {
    if (canSetLegDays(legIndex, days, keepBookings: keepBookings) != TripLegEditBlock.none) return false;
    final p = plan.value!;
    final leg = p.legAt(legIndex)!;
    if (days == p.legDayCount(legIndex)) return true;
    if (p.legSpotCount(legIndex) > 0 && !legRunning(legIndex) && !offline.value) {
      return _planLegToDays(leg.cityKey, days);
    }
    _sizeLeg(legIndex, days);
    return true;
  }

  void _sizeLeg(int legIndex, int days) {
    final p = plan.value;
    if (p == null || p.legAt(legIndex) == null || days < 1 || days == p.legDayCount(legIndex)) return;
    final block = p.daysOf(legIndex);
    final List<TripDay> sized;
    if (days < block.length) {
      final keep = block.sublist(0, days);
      final moved = [for (final d in block.sublist(days)) ...d.spots];
      sized = moved.isEmpty
          ? keep
          : [...keep.sublist(0, days - 1), keep.last.copyWith(spots: [...keep.last.spots, ...moved])];
    } else {
      sized = [
        ...block,
        for (var i = 0; i < days - block.length; i++) TripDay(day: -(i + 1), leg: legIndex),
      ];
    }
    _editSeq++;
    plan.value = p.copyWith(
      days: _renumber(
        [...p.days.where((d) => d.leg < legIndex), ...sized, ...p.days.where((d) => d.leg > legIndex)],
        keepEmptyDays: true,
        legCount: p.legCount,
      ),
    );
    recalculate();
    scheduleSave();
  }

  void clearTravel(int legIndex) {
    final p = plan.value;
    final leg = p?.legAt(legIndex);
    if (p == null || leg == null || legIndex < 2 || leg.arrival == null || isReadOnly) return;
    unawaited(removeTravel(legIndex));
  }

  void _setArrival(int legIndex, TripTravel? next) {
    final p = plan.value;
    final leg = p?.legAt(legIndex);
    if (p == null || leg == null) return;
    final oldRoad = leg.arrival?.roadMinutes;
    plan.value = p.withArrival(legIndex, next);
    scheduleSave();
    if (oldRoad != next?.roadMinutes && p.legSpotCount(legIndex) > 0 && canEditLeg(legIndex)) {
      unawaited(_planLegByCity(leg.cityKey, keepDays: true));
    }
  }

  TripTravel? _journeyArrival(int legIndex) {
    final a = legIndex >= 2 ? plan.value?.legAt(legIndex)?.arrival : null;
    final id = a?.journeyId;
    return a != null && id != null && id.isNotEmpty ? a : null;
  }

  int? travelDayOf(int legIndex) {
    final start = legIndex >= 2 ? plan.value?.legStart(legIndex) ?? 0 : 0;
    return start > 0 ? start : null;
  }

  DateTime? travelDateOf(int legIndex) {
    final day = travelDayOf(legIndex);
    return day == null ? null : dateOf(day);
  }

  TripJourney? segmentJourney(int legIndex) {
    final a = _journeyArrival(legIndex);
    final j = a == null ? null : trip.value?.journeyById(a.journeyId);
    return j?.asSegment(legIndex, travelDayOf(legIndex), travelDateOf(legIndex));
  }

  List<TripEnquiryModel> segmentRows(int legIndex) {
    final a = _journeyArrival(legIndex);
    return a == null ? const [] : TripTravelRules.liveRowsOf(a.journeyId, enquiryList);
  }

  TripEnquiryModel? carBooking(int legIndex, int carIndex) =>
      TripTravelRules.carBooking(carIndex, segmentRows(legIndex));

  TripTravelState travelStateOf(int legIndex) {
    final a = legIndex >= 2 ? plan.value?.legAt(legIndex)?.arrival : null;
    final j = segmentJourney(legIndex);
    if (a != null && j == null && offline.value) return TripTravelState.saved;
    return TripTravelRules.stateOf(
      role: TripJourneyRole.segment,
      arrival: a,
      journey: j,
      journeyRows: segmentRows(legIndex),
      travelDate: travelDateOf(legIndex),
      gap: travelGaps.containsKey(legIndex),
    );
  }

  int get travelPeople {
    final n = settings.peopleCount;
    return (n > 0 ? n : TripConstants.defaultTravelPeople).clamp(1, TripConstants.maxTravelPeople).toInt();
  }

  DateTime? travelSearchDateOf(int legIndex) {
    final d = travelDateOf(legIndex);
    if (d == null) return null;
    final t = _today;
    final today = DateTime(t.year, t.month, t.day);
    return d.isBefore(today) ? today : d;
  }

  bool get travelPeopleCapped => settings.peopleCount > TripConstants.maxTravelPeople;

  PlaceResult? prevCityPlace(int legIndex) {
    if (legIndex < 2) return null;
    final leg = plan.value?.legAt(legIndex - 1);
    if (leg != null && leg.hasPoint && leg.cityName.isNotEmpty) return leg.place;
    return cityPlaceOf(legIndex - 1);
  }

  TravelFindBlock findWayBlock(int legIndex) {
    final p = plan.value;
    final day = travelDayOf(legIndex);
    if (p == null || p.legAt(legIndex) == null || day == null || trip.value == null || isReadOnly || _saveBlocked) {
      return TravelFindBlock.readOnly;
    }
    if (taxiTabOff.value) return TravelFindBlock.taxiOff;
    if (!hasDates) return TravelFindBlock.noDates;
    if (!canEditDay(day)) return TravelFindBlock.readOnly;
    final date = dateOf(day);
    final t = _today;
    if (date != null && date.isAfter(DateTime(t.year, t.month, t.day + TripConstants.journeyMaxDaysAhead))) {
      return TravelFindBlock.tooFarAhead;
    }
    if (netOff) return TravelFindBlock.offline;
    return TravelFindBlock.none;
  }

  bool hidesLocalTaxi(int day) => isTravelDay(day) && legOf(day).arrival != null;

  bool hasLocalTaxiOn(int day) {
    return taxiEnquiriesForDay(day).any((e) => e.isOpen);
  }

  Future<void> cancelLocalTaxiTravelDay(int day) async {
    final p = plan.value;
    if (p == null || isReadOnly || !canEditDay(day)) return;
    final enq = TripEnquiryController.to;
    var ok = true;
    var kept = false;
    for (final e in taxiEnquiriesForDay(day).where((e) => e.isOpen).toList()) {
      final only = planDaysOf(e).every((d) => d == day);
      if (!only) {
        kept = true;
      } else if (e.isBooked) {
        ok = await enq.cancel(e.id) && ok;
      } else if (e.isWithdrawable) {
        ok = await enq.withdraw(e.id) && ok;
      }
    }
    if (!ok) return;
    if (kept) {
      AppToast.warning(TripStringsMcbK1.localTaxiLeadKept);
    } else {
      AppToast.success(TripStringsMcbK1.localTaxiDayRemoved(day));
    }
  }

  TravelImpact travelImpact(int legIndex) {
    final a = _journeyArrival(legIndex);
    if (a == null) return const TravelImpact();
    return TripTravelRules.impactOf(segmentRows(legIndex),
        cars: a.cars ?? segmentJourney(legIndex)?.legs.length ?? 0);
  }

  void markTravelGap(int legIndex, String? hubName) {
    if (legIndex < 2) return;
    final hub = hubName?.trim();
    travelGaps[legIndex] = hub == null || hub.isEmpty ? null : hub;
  }

  void clearTravelGap(int legIndex) => travelGaps.remove(legIndex);

  bool _neverAsked(String journeyId, TripJourney? j) =>
      j != null && !j.isAsked && !enquiryList.any((e) => e.isSegment && e.context.journeyId == journeyId);

  Future<bool> _closeSegmentRows(List<TripEnquiryModel> rows) async {
    for (final e in rows) {
      if (!TripTravelRules.isLive(e)) continue;
      if (TripTravelRules.bookedStatuses.contains(e.status)) {
        if (!await TripEnquiryController.to.cancel(e.id)) return false;
      } else if (e.isWithdrawable) {
        if (!await TripEnquiryController.to.withdraw(e.id)) return false;
      }
    }
    return true;
  }

  Future<void> _deleteJourney(String journeyId) async {
    try {
      await flushPendingSave();
      await JourneysController.to.remove(journeyId);
    } catch (_) {
      return;
    }
  }

  void _putLocalJourney(TripJourney j) {
    final t = trip.value;
    if (t == null) return;
    trip.value = t.copyWith(journeys: [
      for (final x in t.journeys)
        if (x.id != j.id) x,
      j,
    ]);
  }

  Future<String?> prepareSegmentLink(int legIndex) async {
    final leg = plan.value?.legAt(legIndex);
    if (leg == null || legIndex < 2 || isReadOnly || _saveBlocked || travelBusy.contains(legIndex)) {
      return TripStringsStepsK3.notSavedToTrip;
    }
    if (_hasUnavailableLeg) return TripStrings.cityUnavailable;
    if (!await flushPendingSave() || trip.value == null) return TripStringsStepsK3.notSavedToTrip;
    return null;
  }

  bool travelMatches(int legIndex, String planKey, DateTime date, int people) {
    final a = _journeyArrival(legIndex);
    if (a == null || a.planKey != planKey) return false;
    final j = segmentJourney(legIndex);
    return j == null || (_sameDate(j.date, date) && j.people == people);
  }

  Future<void> releaseJourneyLink(String journeyId) async {
    if (journeyId.isEmpty || _locallyLinked(journeyId)) return;
    _dropLocalJourney(journeyId);
    if (trip.value == null || _saveBlocked) return;
    await saveNow();
  }

  bool _mayDeleteJourney(String journeyId, TripJourney? j) {
    final tripId = trip.value?.id;
    return tripId != null &&
        _neverAsked(journeyId, j) &&
        Get.isRegistered<JourneysController>() &&
        Get.find<JourneysController>().createdForTrip(journeyId, tripId);
  }

  int? segmentLegOf(String journeyId) => plan.value?.segmentLegOf(journeyId);

  Future<TripLinkResult> linkSegmentJourney(
    int legIndex,
    SavedJourney j, {
    bool replaceBooked = false,
    int? roadMinutes,
  }) async {
    final p = plan.value;
    final leg = p?.legAt(legIndex);
    if (p == null || leg == null || legIndex < 2 || isReadOnly || j.id.isEmpty || travelBusy.contains(legIndex)) {
      return TripLinkResult.notSaved;
    }
    if (_hasUnavailableLeg) return TripLinkResult.notSaved;
    final old = _journeyArrival(legIndex);
    final oldId = old?.journeyId;
    final same = oldId == j.id;
    var oldRows = const <TripEnquiryModel>[];
    TripJourney? oldJourney;
    if (old != null && !same) {
      oldRows = segmentRows(legIndex);
      if (TripTravelRules.impactOf(oldRows).hasBooked && !replaceBooked) return TripLinkResult.needsConfirm;
      oldJourney = segmentJourney(legIndex);
    }
    travelBusy.add(legIndex);
    try {
      if (oldRows.isNotEmpty && !await _closeSegmentRows(oldRows)) return TripLinkResult.notSaved;
      final cur = plan.value;
      final now = cur?.legAt(legIndex);
      final prev = cur?.legAt(legIndex - 1);
      if (cur == null || now == null || prev == null || now.cityKey != leg.cityKey) return TripLinkResult.notSaved;
      var next = cur;
      for (final r in TripStepRole.values) {
        if (next.steps.of(r).journeyId == j.id) next = next.copyWith(steps: next.steps.withStep(r, next.steps.of(r).cleared));
      }
      for (final l in cur.legs) {
        if (l.index != legIndex && l.index >= 2 && l.arrival?.journeyId == j.id) next = next.withArrival(l.index, null);
      }
      final arrival = TripTravel(
        fromName: prev.cityName,
        journeyId: j.id,
        planKey: j.planKey.isEmpty ? null : j.planKey,
        cars: j.cars > 0 ? j.cars.clamp(1, TripConstants.maxJourneyCars).toInt() : null,
        listedTotal: j.listedTotal,
        roadMinutes: roadMinutes?.clamp(0, TripConstants.journeyRoadMinutesMax).toInt() ??
            (same ? old?.roadMinutes : null) ??
            now.arrival?.roadMinutes ??
            TripConstants.travelWholeDayMinutes,
      );
      final oldRoad = now.arrival?.roadMinutes;
      plan.value = next.withArrival(legIndex, arrival);
      if (oldId != null && !same) _dropLocalJourney(oldId);
      _putLocalJourney(TripJourney.fromSavedSegment(
          j, legIndex, travelDayOf(legIndex) ?? cur.legStart(legIndex), travelDateOf(legIndex)));
      _pendingJourneyIds.add(j.id);
      travelGaps.remove(legIndex);
      scheduleSave();
      if (oldRoad != arrival.roadMinutes && cur.legSpotCount(legIndex) > 0 && canEditLeg(legIndex)) {
        unawaited(_planLegByCity(now.cityKey, keepDays: true));
      }
      final deleteOld = oldId != null && !same && _mayDeleteJourney(oldId, oldJourney);
      final ok = await flushPendingSave();
      if (deleteOld) unawaited(_deleteJourney(oldId));
      return ok ? TripLinkResult.saved : TripLinkResult.notSaved;
    } finally {
      travelBusy.remove(legIndex);
    }
  }

  Future<bool> removeTravel(int legIndex, {bool cancelBooked = false}) async {
    final p = plan.value;
    final leg = p?.legAt(legIndex);
    if (p == null || leg == null || legIndex < 2 || isReadOnly) return false;
    final a = leg.arrival;
    if (a == null) {
      travelGaps.remove(legIndex);
      return true;
    }
    if (travelBusy.contains(legIndex)) return false;
    if (_hasUnavailableLeg) {
      AppToast.warning(TripStrings.cityUnavailable);
      return false;
    }
    final rows = segmentRows(legIndex);
    if (TripTravelRules.impactOf(rows).hasBooked && !cancelBooked) return false;
    final id = a.journeyId;
    final j = segmentJourney(legIndex);
    travelBusy.add(legIndex);
    try {
      if (!await _closeSegmentRows(rows)) return false;
      if (plan.value?.legAt(legIndex)?.arrival?.journeyId != id) return true;
      final never = _mayDeleteJourney(id, j);
      _setArrival(legIndex, null);
      _dropLocalJourney(id);
      travelGaps.remove(legIndex);
      AppToast.success(TripStringsMcbA1.travelRemoved);
      if (never) unawaited(_deleteJourney(id));
      return true;
    } finally {
      travelBusy.remove(legIndex);
    }
  }

  void unlinkSegmentJourney(String journeyId) {
    final k = plan.value?.segmentLegOf(journeyId);
    if (k == null) return;
    _setArrival(k, null);
    _dropLocalJourney(journeyId);
  }

  String? journeyIdOf({TripStepRole? role, int? legIndex}) {
    if (legIndex != null) return _journeyArrival(legIndex)?.journeyId;
    if (role == null) return null;
    final s = stepOf(role);
    return s.hasJourney ? s.journeyId : null;
  }

  List<TripEnquiryModel> journeyRowsOf({TripStepRole? role, int? legIndex}) {
    if (legIndex != null) return segmentRows(legIndex);
    final id = journeyIdOf(role: role);
    return id == null ? const [] : TripTravelRules.liveRowsOf(id, enquiryList);
  }

  DateTime? journeyDateOf({TripStepRole? role, int? legIndex}) =>
      legIndex != null ? travelDateOf(legIndex) : (role == null ? null : stepDate(role));

  TravelImpact stepImpact(TripStepRole role) => TripTravelRules.impactOf(journeyRowsOf(role: role));

  Future<bool> closeStepRows(TripStepRole role) => _closeSegmentRows(journeyRowsOf(role: role));

  Future<bool> closeRows(List<TripEnquiryModel> rows) => _closeSegmentRows(rows);

  bool isDatePast(DateTime? date) => date != null && date.isBefore(_today);

  Future<TripEnquiryModel?> bookJourneyCar({
    required String journeyId,
    TripStepRole? role,
    int? legIndex,
    required int carIndex,
    required String taxiId,
    int? agreedFare,
    required bool tollExtra,
    required String pickupTime,
    required String pickupPlace,
    String? note,
    List<String> replaceEnquiryIds = const [],
  }) async {
    final enq = TripEnquiryController.to;
    enq.lastConflict = null;
    enq.lastErrorType = null;
    enq.lastErrorMessage = null;
    if (isReadOnly) return null;
    if (journeyIdOf(role: role, legIndex: legIndex) != journeyId) {
      AppToast.warning(TripStringsMcbK1.journeyNotInTrip);
      return null;
    }
    final ok = await flushPendingSave();
    final tripId = trip.value?.id;
    if (!ok || tripId == null) {
      AppToast.warning(TripStrings.notSavedCheckConnection);
      return null;
    }
    if (journeyIdOf(role: role, legIndex: legIndex) != journeyId) {
      AppToast.warning(TripStringsMcbK1.journeyNotInTrip);
      return null;
    }
    try {
      final e = await const TripEnquiryRepository().journeyCarBooking(
        tripId,
        journeyId: journeyId,
        journeyLegIndex: carIndex,
        taxiId: taxiId,
        agreedFare: agreedFare,
        tollExtra: tollExtra,
        pickupTime: pickupTime,
        pickupPlace: pickupPlace,
        replaceEnquiryIds: replaceEnquiryIds,
      );
      if (trip.value?.id != tripId) return e;
      applyEnquiries([e]);
      _markCarBooked(journeyId, carIndex, e.id, agreedFare);
      unawaited(refreshEnquiries());
      if (Get.isRegistered<JourneysController>()) {
        unawaited(Get.find<JourneysController>().refreshOne(journeyId, silent: true));
      }
      return e;
    } catch (e) {
      final network = DioErrorMapper.isNetworkError(e);
      final type = network ? null : DioErrorMapper.errorType(e);
      enq.lastConflict = enq.conflictOf(e);
      enq.lastErrorType = type;
      enq.lastErrorMessage = network
          ? TripStrings.noNetwork
          : DioErrorMapper.toMessage(e, TripStringsMcbA1.bookFailed, showRawMessageForStatusCodes: {400, 403, 404, 409, 422, 429});
      if (enq.lastConflict != null) return null;
      if (network) {
        AppToast.error(TripStrings.noNetwork);
      } else {
        AppToast.error(DioErrorMapper.toMessage(e, TripStringsMcbA1.bookFailed,
            showRawMessageForStatusCodes: {400, 403, 404, 409, 422, 429}));
      }
      if (type == TripErrorTypes.journeyNotInPlan || type == TripErrorTypes.travelDateChanged) {
        unawaited(refreshEnquiries());
      }
      return null;
    }
  }

  void _markCarBooked(String journeyId, int carIndex, String enquiryId, int? fare) {
    final t = trip.value;
    final j = t?.journeyById(journeyId);
    if (t == null || j == null) return;
    _putLocalJourney(j.withLegs([
      for (final l in j.legs)
        l.legIndex == carIndex
            ? l.copyWith(lastEnquiryId: enquiryId, lastKnownStatus: TripTravelRules.freeStatus, lastQuotedFare: fare)
            : l,
    ]));
  }

  void reconcileTravel([TripModel? fresh]) {
    final p = plan.value;
    final t = fresh ?? trip.value;
    if (p == null || t == null || offline.value || !t.journeysKnown || isCompleted) return;
    var next = p;
    for (final l in p.legs) {
      final a = l.arrival;
      final id = a?.journeyId;
      if (l.index < 2 || a == null || id == null) continue;
      if (_pendingJourneyIds.contains(id) || t.journeyById(id) != null || trip.value?.journeyById(id) != null) continue;
      next = next.withArrival(l.index, null);
    }
    if (identical(next, p)) return;
    plan.value = next;
    scheduleSave();
  }

  @visibleForTesting
  void adoptServerArrivalsForTest(TripPlan sent, TripModel saved) => _adoptServerArrivals(sent, saved);

  void _adoptServerArrivals(TripPlan sent, TripModel saved) {
    final local = plan.value;
    if (local == null || saved.plan.legs.isEmpty) return;
    var next = local;
    for (final l in sent.legs) {
      final a = l.arrival;
      final id = a?.journeyId;
      if (l.index < 2 || a == null || id == null) continue;
      final server = saved.plan.legAt(l.index);
      if (server == null || server.cityKey != l.cityKey) continue;
      final sa = server.arrival;
      if (sa != null && sa.journeyId == id) continue;
      final mine = next.legAt(l.index);
      if (mine == null || mine.cityKey != l.cityKey || mine.arrival?.journeyId != id) continue;
      next = next.withArrival(l.index, sa);
      _dropLocalJourney(id);
    }
    if (!identical(next, local)) plan.value = next;
  }

  // The auto split plans every day from one base; days that start or end at another stay get their real times.
  void _recalcForDayEnds() {
    final p = plan.value;
    if (p != null && _hasDayEnds(p)) _recalcAfterAuto = true;
  }

  bool _hasDayEnds(TripPlan p) {
    for (final d in p.days) {
      if (d.spots.isEmpty) continue;
      final base = TripStayBase.of(p, p.legIndexOf(d.day), enquiryList);
      final e = TripStayBase.dayEnds(p, d.day, enquiryList);
      if (e.start != base || e.end != base) return true;
    }
    return false;
  }


  final settingsChangedAt = Rxn<DateTime>();

  bool get hasPeople => settings.hasPeople;
  List<TripEnquiryModel> stayEnquiriesOf(int legIndex) {
    final p = plan.value;
    if (p == null) return const [];
    final out = <String, TripEnquiryModel>{};
    for (final d in p.daysOf(legIndex)) {
      for (final e in enquiriesForNight(d.day)) {
        if (!e.isSegment) out[e.id] = e;
      }
    }
    return out.values.toList()..sort(_newestFirst);
  }

  List<TripEnquiryModel> get taxiEnquiries =>
      enquiryList.where((e) => e.isTaxi && !e.isSegment).toList()..sort(_newestFirst);

  List<int> get taxiAskedDays {
    final days = <int>{};
    for (final e in taxiEnquiries) {
      if (e.isOpen) days.addAll(planDaysOf(e));
    }
    return days.toList()..sort();
  }

  SettingsSaveResult staleAsks() {
    lastSettingsChange = (dates: false, people: false, days: true);
    final daysWas = _dayCountWas;
    _dayCountWas = null;
    final start = settings.startDate;
    final end = checkOutDate;
    if (start == null || end == null) return const SettingsSaveResult(saved: true);
    final confirmed = <TripEnquiryModel>[];
    final open = <TripEnquiryModel>[];
    final bookedTaxis = <TripEnquiryModel>[];
    final openTaxis = <TripEnquiryModel>[];
    for (final e in enquiryList) {
      if (!e.isOpen || _isJourneyRow(e)) continue;
      final shifted = !e.isTaxi && plan.value != null && TripEnquiryRules.wrongCity(e, plan.value!, settings) != null;
      final short = !e.isTaxi && plan.value != null && _stayShortOfLeg(e, plan.value!);
      final grown = daysWas != null && TripEnquiryRules.grewWithTrip(e, daysWas, dayCount);
      if (!shifted && !short && !grown && !_outsideWindow(e, start, end)) continue;
      if (e.isTaxi) {
        (e.isBooked ? bookedTaxis : openTaxis).add(e);
      } else if (e.isBooked) {
        confirmed.add(e);
      } else {
        open.add(e);
      }
    }
    return SettingsSaveResult(
      saved: true,
      confirmedAffected: confirmed..sort(_newestFirst),
      openAffected: open..sort(_newestFirst),
      bookedTaxiAffected: bookedTaxis..sort(_newestFirst),
      openTaxiAffected: openTaxis..sort(_newestFirst),
    );
  }

  Future<SettingsSaveResult> saveSettings(TripSettings next) async {
    final p = plan.value;
    if (p == null || isReadOnly) return const SettingsSaveResult(saved: false);
    final old = p.settings;
    final replan = next.dayLimitMinutes != old.dayLimitMinutes || next.startDateIso != old.startDateIso;
    final redo = next.maxDays != old.maxDays;
    final peopleChanged = next.adults != old.adults || next.kids != old.kids;
    final confirmed = <TripEnquiryModel>[];
    final open = <TripEnquiryModel>[];
    final bookedTaxis = <TripEnquiryModel>[];
    final openTaxis = <TripEnquiryModel>[];
    if (peopleChanged) {
      for (final e in enquiryList) {
        if (!e.isOpen) continue;
        if (e.isTaxi) {
          (e.isBooked ? bookedTaxis : openTaxis).add(e);
        } else if (e.isConfirmed) {
          confirmed.add(e);
        } else if (!e.isBooked) {
          open.add(e);
        }
      }
      confirmed.sort(_newestFirst);
      open.sort(_newestFirst);
      bookedTaxis.sort(_newestFirst);
      openTaxis.sort(_newestFirst);
    }
    final daysCut = redo && next.maxDays != null && next.maxDays! < dayCount;
    final newStart = next.startDate;
    final moving = (next.startDateIso != old.startDateIso || daysCut) && newStart != null && old.startDate != null;
    final keptDays = daysAfterLimit(next.maxDays);
    final movedAsks = <TripEnquiryModel>[];
    if (moving) {
      final start = DateTime(newStart.year, newStart.month, newStart.day);
      final checkOut = DateTime(start.year, start.month, start.day + keptDays);
      final moved = settings.copyWith(startDate: start);
      for (final e in dateChangeImpact(newStart, days: keptDays).open) {
        if (!e.isWithdrawable) continue;
        // Rows outside the new window are closed by the server on save.
        if (_isJourneyRow(e) || (!_outsideWindow(e, start, checkOut) && _landsInOtherCity(e, p, moved))) movedAsks.add(e);
      }
      final seen = {for (final e in [...confirmed, ...open, ...bookedTaxis, ...openTaxis]) e.id};
      for (final e in dateChangeImpact(newStart, days: keptDays).all) {
        if (_isJourneyRow(e) || !seen.add(e.id)) continue;
        if (e.isTaxi) {
          (e.isBooked ? bookedTaxis : openTaxis).add(e);
        } else if (e.isBooked) {
          confirmed.add(e);
        } else {
          open.add(e);
        }
      }
    }
    var steps = p.steps;
    if (next.startDateIso != old.startDateIso || daysCut) {
      steps = steps
          .withStep(TripStepRole.gettingThere, steps.gettingThere.copyWith(clearDate: true))
          .withStep(TripStepRole.comingBack, steps.comingBack.copyWith(clearDate: true));
    } else if (redo) {
      steps = steps.withStep(TripStepRole.comingBack, steps.comingBack.copyWith(clearDate: true));
    }
    plan.value = p.copyWith(settings: next, steps: steps);
    if (replan || redo || peopleChanged) settingsChangedAt.value = DateTime.now();
    if (redo) {
      unawaited(autoPlan());
    } else if (replan) {
      if (isPlanning.value && _lastPlanWasAuto) {
        _settingsChangedWhilePlanning = true;
      } else {
        recalculate();
      }
    }
    if (movedAsks.isEmpty) {
      scheduleSave();
    } else {
      unawaited(saveNow().then((ok) => ok ? _withdrawMoved(movedAsks) : null));
    }
    lastSettingsChange = (dates: next.startDateIso != old.startDateIso, people: peopleChanged, days: redo);
    return SettingsSaveResult(
      saved: true,
      confirmedAffected: confirmed,
      openAffected: open,
      bookedTaxiAffected: bookedTaxis,
      openTaxiAffected: openTaxis,
    );
  }

  Future<void> _withdrawMoved(List<TripEnquiryModel> rows) async {
    for (final e in rows) {
      await TripEnquiryController.to.withdraw(e.id);
    }
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
      if (e.isRed && isDismissed(e.id)) continue;
      final r = _rank(e.display);
      if (r < bestRank) {
        best = e;
        bestRank = r;
      }
    }
    return best;
  }

  List<TripEnquiryModel> taxiEnquiriesForDay(int day) {
    final date = dateOf(day);
    return enquiryList
        .where((e) =>
            e.isTaxi &&
            !e.isSegment &&
            (date != null && e.checkIn != null ? e.coversTaxiDate(date) : e.days.contains(day)))
        .toList()
      ..sort(_newestFirst);
  }

  List<int> planDaysOf(TripEnquiryModel e, [List<TripDay>? within]) {
    final days = within ?? plan.value?.days ?? const <TripDay>[];
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

  int? firstPlanDayOf(TripEnquiryModel e) {
    final days = planDaysOf(e);
    return days.isEmpty ? null : days.reduce((a, b) => a < b ? a : b);
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
      if (e.isRed && isDismissed(e.id)) continue;
      final r = _taxiRank(e.display);
      if (r < bestRank) {
        best = e;
        bestRank = r;
      }
    }
    return best;
  }

  bool get hasOpenAdvance => enquiryList.any((e) => !e.isTaxi && e.isConfirmedByBoth && e.advance.isOpenRequest);

  bool isDismissed(String enquiryId) => plan.value?.dismissedEnquiryIds.contains(enquiryId) ?? false;

  void dismissProblem(String enquiryId) {
    final p = plan.value;
    if (p == null || isReadOnly || enquiryId.isEmpty) return;
    final next = p.withDismissed(enquiryId);
    if (identical(next, p)) return;
    plan.value = next;
    scheduleSave();
  }

  void applyEnquiries(Iterable<TripEnquiryModel> items) {
    final tripId = trip.value?.id;
    var changed = false;
    final freshLeads = <TripEnquiryModel>[];
    for (final e in items) {
      if (e.id.isEmpty || (tripId != null && e.tripId != null && e.tripId != tripId)) continue;
      final i = enquiryList.indexWhere((x) => x.id == e.id);
      if (i >= 0) {
        enquiryList[i] = e;
      } else {
        enquiryList.insert(0, e);
        if (e.isTaxi && !e.isSegment) freshLeads.add(e);
      }
      changed = true;
    }
    if (!changed) return;
    final t = trip.value;
    if (t != null) trip.value = t.copyWith(enquiries: enquiryList.toList());
  }

  void clearStartNote(int day) => startChangedNotes.remove(day);

  Future<void> refreshEnquiries() async {
    final id = trip.value?.id;
    if (id == null) return;
    final seq = ++_enquirySeq;
    final flow = _flow;
    final gen = _saveGen;
    enquiriesLoading.value = true;
    try {
      final t = await _repo.get(id);
      if (flow != _flow || seq != _enquirySeq) return;
      final stale = gen != _saveGen || _saving != null;
      if (!stale) TripTodayCache.saveTrip(t);
      enquiryList.assignAll(t.enquiries);
      trip.value = (trip.value ?? t).copyWith(
        enquiries: t.enquiries,
        journeys: _mergedJourneys(t),
        journeysKnown: t.journeysKnown || (trip.value?.journeysKnown ?? false),
      );
      enquiriesFailed.value = false;
      offline.value = false;
      if (!stale) {
        reconcileSteps(t);
        reconcileTravel(t);
      }
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

  Set<String> get unavailableStayIds {
    if (!Get.isRegistered<TripSupplyController>()) return const {};
    return {for (final s in Get.find<TripSupplyController>().stays) if (!s.isActive) s.id};
  }

  List<int> enquiryNightsRun(int day, {String? ignoreEnquiryId}) {
    final p = plan.value;
    if (p == null || p.dayAt(day) == null) return const [];
    final run = [day];
    final end = _legEndOf(p, day);
    for (var d = day + 1; d <= end; d++) {
      if (!canEditDay(d) || enquiriesForNight(d).any((e) => e.isBooked && e.id != ignoreEnquiryId)) break;
      run.add(d);
    }
    return run;
  }

  Future<void> checkSupply() async {
    final p = plan.value;
    if (p == null) return;
    final tabs = Get.isRegistered<TabConfigController>() ? TabConfigController.to : null;
    taxiTabOff.value = tabs != null && !tabs.isActiveForIndex(AppTabs.taxi);
    stayTabOff.value = tabs != null && !tabs.isActiveForIndex(AppTabs.stays);
    final seq = ++_supplySeq;
    final recheck = [for (final k in taxiSupplyByLeg.keys) if (k >= 2) k];
    final leg1 = p.legAt(1);
    if (!TripSupplyArea.hasCity(leg1)) {
      cityHasTaxis.value = null;
      taxiSupply.value = null;
      taxiSupplyByLeg[1] = null;
      _recheckLegs(recheck);
      return;
    }
    if (taxiTabOff.value) return;
    final key = TripSupplyArea.keyOf(leg1);
    taxiSupply.value = _supplyByDistrict[key];
    taxiSupplyByLeg[1] = taxiSupply.value;
    try {
      final page = await const TaxiBrowseRepository().browseLocal(
        cityKey: leg1!.cityKey,
        localRate: true,
        pageSize: 1,
        centre: TripSupplyArea.centreOf(leg1),
      );
      if (seq != _supplySeq) return;
      citiesUnavailable.value = false;
      cityHasTaxis.value = page.items.isNotEmpty;
      taxiSupply.value = page.items.isNotEmpty;
      taxiSupplyByLeg[1] = page.items.isNotEmpty;
      _supplyByDistrict[key] = page.items.isNotEmpty;
      supplyCheckFailed.remove(1);
    } catch (e) {
      if (seq != _supplySeq) return;
      if (DioErrorMapper.errorType(e) == ApiService.tabInactiveType) {
        taxiTabOff.value = true;
      } else {
        if (_isCitiesUnavailable(e)) citiesUnavailable.value = true;
        supplyCheckFailed.add(1);
      }
    }
    _recheckLegs(recheck);
  }

  void _recheckLegs(List<int> legs) {
    for (final k in legs) {
      if (taxiSupplyByLeg[k] != null) continue;
      final leg = plan.value?.legAt(k);
      if (leg != null) _supplyTried.remove(TripSupplyArea.keyOf(leg));
      taxiSupplyByLeg.remove(k);
      unawaited(ensureSupply(k));
    }
  }

  bool get _saveBlocked => plannerOff.value || tripGone.value || needsUpdate.value || isCompleted;

  void scheduleSave() {
    if (_saveBlocked || plan.value == null) return;
    if (identical(plan.value, _rejectedPlan) && _title == _rejectedTitle) return;
    if (_hasUnavailableLeg) {
      _saveTimer?.cancel();
      return;
    }
    if (_creating != null) {
      _dirtyDuringCreate = true;
      return;
    }
    _writeAhead();
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
    if (markPlanned || TripEasyRules.hasOwnMark(p)) return TripStatuses.planned;
    return trip.value?.status ?? TripStatuses.draft;
  }

  TripPlan _clearDatesOnEndCut(TripPlan p, DateTime? storedEnd) {
    final nextEnd = p.settings.endDate(p.days.length);
    final s = p.steps;
    if (storedEnd == null || nextEnd == null || (s.gettingThere.date == null && s.comingBack.date == null)) return p;
    final cut = DateTime(nextEnd.year, nextEnd.month, nextEnd.day)
        .isBefore(DateTime(storedEnd.year, storedEnd.month, storedEnd.day));
    if (!cut) return p;
    return p.copyWith(
      steps: s
          .withStep(TripStepRole.gettingThere, s.gettingThere.copyWith(clearDate: true))
          .withStep(TripStepRole.comingBack, s.comingBack.copyWith(clearDate: true)),
    );
  }

  Future<bool> _save(bool markPlanned) async {
    final p = _clearDatesOnEndCut(plan.value!, trip.value?.endDate);
    if (!identical(p, plan.value)) plan.value = p;
    final flow = _flow;
    isSaving.value = true;
    try {
      final current = trip.value;
      final saved = current == null
          ? await _repo.create(title: _title, status: _statusFor(markPlanned, p), plan: p, clientTripId: _clientTripId)
          : await _update(current.id, _title, _statusFor(markPlanned, p), p);
      if (flow != _flow) return false;
      _saveGen++;
      if (_spotsEdited) {
        _spotsEdited = false;
        final ids = [for (final e in enquiryList) if (TripEnquiryRules.contextStale(e, p)) e.id];
        if (ids.isNotEmpty && !netOff && Get.isRegistered<TripEnquiryController>()) {
          unawaited(TripEnquiryController.to.refreshStayContexts(ids));
        }
      }
      final datesMoved = current != null && (current.startDate != saved.startDate || current.endDate != saved.endDate);
      _pendingJourneyIds.removeAll(p.segmentJourneyIds);
      if (saved.stepsKnown) {
        _pendingJourneyIds.removeAll([?p.steps.gettingThere.journeyId, ?p.steps.comingBack.journeyId]);
        if (Get.isRegistered<JourneysController>()) {
          final s = saved.plan.steps;
          unawaited(Get.find<JourneysController>().syncTripLinks(
            saved.id,
            {?s.gettingThere.journeyId, ?s.comingBack.journeyId, ...saved.plan.segmentJourneyIds},
            links: _journeyLinksOf(saved.plan),
            tripTitle: saved.title,
          ));
        }
      }
      trip.value = saved.copyWith(
        enquiries: enquiryList.toList(),
        journeys: _mergedJourneys(saved, keepLinked: false),
        journeysKnown: saved.journeysKnown || (current?.journeysKnown ?? false),
      );
      _adoptServerSteps(p, saved);
      _adoptServerArrivals(p, saved);
      reconcileTravel();
      _adoptDistrict(saved);
      unavailableCities.clear();
      saveFailed.value = false;
      _pendingRetry = null;
      if (identical(plan.value, p) && !(_saveTimer?.isActive ?? false)) {
        StorageService.clearTripPending(saved.id);
      } else {
        _writeAhead();
      }
      lastSavedAt.value = DateTime.now();
      final latest = plan.value;
      final cached = trip.value;
      if (latest != null && cached != null) TripTodayCache.savePlan(cached, latest);
      if (datesMoved && enquiryList.isNotEmpty) unawaited(refreshEnquiries());
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

  static Map<String, JourneyTripLink> _journeyLinksOf(TripPlan p) {
    final links = <String, JourneyTripLink>{};
    for (final r in TripStepRole.values) {
      final id = p.steps.of(r).journeyId;
      if (id != null && id.isNotEmpty) links[id] = (role: r.name, legIndex: null, travelDay: null);
    }
    for (final l in p.legs) {
      final id = l.arrival?.journeyId;
      if (l.index < 2 || l.arrival == null || id == null || id.isEmpty || links.containsKey(id)) continue;
      links[id] = (role: TripJourney.segmentRole, legIndex: l.index, travelDay: p.legStart(l.index));
    }
    return links;
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
