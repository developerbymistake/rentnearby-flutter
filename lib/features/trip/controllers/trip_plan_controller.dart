import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import '../../../config/app_tabs.dart';
import '../../../controllers/location_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../models/place_result_model.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../../taxi/guest/taxi_browse_repository.dart';
import '../../taxi/guest/traveller_city.dart';
import '../../taxi/journeys/journey_models.dart';
import '../../taxi/journeys/journeys_controller.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../../taxi/taxi_option_sets.dart';
import '../data/trip_enquiry_repository.dart';
import '../data/trip_repository.dart';
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
import '../trip_strings_steps_k3.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_step_rules.dart';
import '../utils/trip_travel_rules.dart';
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
  final taxiSupplyByLeg = <int, bool?>{}.obs;
  final lastAddedLeg = RxnInt();
  final pendingNextCity = Rxn<TripCityModel>();
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
  TripCityModel? picked;
  int openPages = 0;
  int _enquirySeq = 0;
  int _saveGen = 0;
  final _legacySynced = <String>{};
  bool _startFromTried = false;
  final _pendingJourneyIds = <String>{};

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
    return leg != null && !leg.notReady && !isReadOnly && !legUnavailable(legIndex);
  }

  bool get _hasUnavailableLeg => plan.value?.legs.any((l) => unavailableCities.contains(l.cityKey)) ?? false;

  bool _legHasBookings(int legIndex) {
    for (final d in legDays(legIndex)) {
      if (enquiriesForNight(d).any((e) => e.isOpen) || taxiEnquiriesForDay(d).any((e) => e.isOpen)) return true;
    }
    return _hasOpenSegmentRows(legIndex);
  }

  bool _hasOpenSegmentRows(int legIndex) => segmentRows(legIndex).any((e) => e.isOpen);

  bool _laterLegsHaveBookings(int legIndex) {
    for (var k = legIndex + 1; k <= legCount; k++) {
      if (_legHasBookings(k)) return true;
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
      homeLegIndex: 0,
      dayLegIndex: 0,
    );
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

  LegImpact _impactOf(List<TripEnquiryModel> rows, List<int> travelLegs, {required bool later, required List<String> cities}) {
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
    ];
    return LegImpact(
      open: open,
      booked: booked,
      cars: cars,
      travelLegs: travelLegs,
      laterKeepDates: later,
      laterCities: cities,
    );
  }

  List<String> _laterCitiesWithRows(int legIndex) {
    final p = plan.value;
    if (p == null) return const [];
    return [
      for (var k = legIndex + 1; k <= p.legCount; k++)
        if (_legHasBookings(k)) ?p.legAt(k)?.cityName,
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
    final later = _laterLegsHaveBookings(legIndex);
    return _impactOf(rows, travel, later: later, cities: later ? _laterCitiesWithRows(legIndex) : const []);
  }

  LegImpact legShrinkImpact(int legIndex, int days) {
    final p = plan.value;
    if (p == null || p.legAt(legIndex) == null) return const LegImpact.empty();
    final current = legDays(legIndex);
    final cut = days < 1 ? 1 : days;
    final dropped = cut < current.length ? current.sublist(cut) : const <int>[];
    final shifts = cut != current.length && legIndex < p.legCount;
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
    final total = impact.open.length + impact.booked.length + impact.cars.length;
    if (total == 0) return const LegCancelResult();
    if (offline.value || isReadOnly) return LegCancelResult(failed: total);
    final enq = TripEnquiryController.to;
    var closed = 0;
    for (final e in [...impact.booked, ...impact.open]) {
      final ok = e.isBooked ? await enq.cancel(e.id) : await enq.withdraw(e.id);
      if (!ok) return LegCancelResult(closed: closed, failed: total - closed);
      closed++;
    }
    for (final k in impact.travelLegs) {
      final n = impact.cars.where((e) => segmentRows(k).any((x) => x.id == e.id)).length;
      if (!await removeTravel(k, cancelBooked: true)) return LegCancelResult(closed: closed, failed: total - closed);
      closed += n;
    }
    return LegCancelResult(closed: closed, failed: closed >= total ? 0 : total - closed);
  }

  Future<TripLegEditBlock> cancelAndRemoveLeg(int legIndex) async {
    final block = canRemoveLeg(legIndex);
    if (block != TripLegEditBlock.none) return block;
    final res = await cancelLegRows(legRemoveImpact(legIndex));
    if (!res.ok) return TripLegEditBlock.bookings;
    return removeLeg(legIndex, keepBookings: true);
  }

  Future<TripLegEditBlock> cancelAndSetLegDays(int legIndex, int days) async {
    final p = plan.value;
    if (p == null || isReadOnly || _saveBlocked) return TripLegEditBlock.readOnly;
    if (p.legAt(legIndex) == null || days < 1) return TripLegEditBlock.edge;
    if (days > maxDaysForLeg(legIndex)) return TripLegEditBlock.noDays;
    if (days < minDaysForLeg(legIndex)) return TripLegEditBlock.running;
    final res = await cancelLegRows(legShrinkImpact(legIndex, days));
    if (!res.ok) return TripLegEditBlock.bookings;
    return setLegDays(legIndex, days, keepBookings: true);
  }

  bool supplyAvailableFor(int day) => districtIdOf(day) != null;

  bool _legUnsaved(int cityKey) {
    final t = trip.value;
    return t == null || !t.plan.legs.any((l) => l.cityKey == cityKey);
  }

  bool supplyPendingFor(int day) {
    if (legIndexOf(day) == 1 || !isMultiCity) return supplyPending;
    return !supplyAvailableFor(day) && _legUnsaved(legOf(day).cityKey);
  }

  bool? taxiSupplyFor(int day) {
    final k = legIndexOf(day);
    if (k == 1 || !isMultiCity) return taxiSupply.value;
    if (districtIdOf(day) == null) return _legUnsaved(legOf(day).cityKey) ? null : false;
    return taxiSupplyByLeg[k];
  }

  bool canFindStayOn(int day) => supplyAvailableFor(day) && !stayTabOff.value && !isReadOnly;

  bool canFindTaxiOn(int day) => taxiSupplyFor(day) == true && !taxiTabOff.value && !isReadOnly;

  static int _legEndOf(TripPlan p, int day) {
    final end = p.legEnd(p.legIndexOf(day));
    return end > 0 ? end : p.days.length;
  }

  static int _legStartOf(TripPlan p, int day) {
    final start = p.legStart(p.legIndexOf(day));
    return start > 0 ? start : 1;
  }

  static bool _sameLeg(TripPlan p, int a, int b) => p.legIndexOf(a) == p.legIndexOf(b);

  int get dayCount => plan.value?.days.length ?? 0;

  int get spotCount => plan.value?.spotCount ?? 0;

  int get priceSoFar {
    var sum = 0;
    for (final d in plan.value?.days ?? const <TripDay>[]) {
      final taxi = d.taxi;
      if (taxi != null && !taxi.isSkipped) sum += taxi.fare ?? 0;
      final stay = d.stay;
      if (stay != null && !stay.isSkipped) sum += stay.pricePerNight ?? 0;
    }
    return sum;
  }

  int get taxisChosen =>
      (plan.value?.days ?? const <TripDay>[]).where((d) => d.taxi != null && !d.taxi!.isSkipped).length;

  bool get hasChoice => (plan.value?.days ?? const <TripDay>[]).any((d) => d.taxi != null || d.stay != null);

  bool get showTaxiOption =>
      (!taxiTabOff.value &&
          (cityHasTaxis.value != false ||
              [for (var k = 2; k <= legCount; k++) k].any((k) => taxiSupplyByLeg[k] != false))) ||
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
      startChanged: TripStepRules.startChanged(role, startFrom, j, cityLat: city?.lat, cityLon: city?.lon),
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

  TripStepDisplay stepDisplay(TripStepRole role) => TripStepRules.display(stepOf(role), journeyFor(role));

  bool stepNeedsAttention(TripStepRole role) {
    if (isReadOnly) return false;
    if (journeyFor(role)?.needsAttention ?? false) return true;
    return role == TripStepRole.gettingThere &&
        TripStepRules.needsNudge(stepOf(role), startFrom, settings.startDate, _today);
  }

  TripStepRole? get startChangedRole {
    for (final r in TripStepRole.values) {
      if (journeyFor(r)?.startChanged ?? false) return r;
    }
    return null;
  }

  TripStepDisplay get itineraryDisplay => spotCount > 0 ? TripStepDisplay.chosen : TripStepDisplay.notStarted;

  bool _nightSorted(TripDay d) => d.stay != null || (primaryEnquiry(d.day)?.isBooked ?? false);

  bool _taxiDaySorted(TripDay d) =>
      d.taxi != null || bookedTaxiEnquiryFor(d.day) != null || hidesLocalTaxi(d.day);

  ({TripStepDisplay display, int sorted, int total, int? firstUnsorted}) get stayStep {
    final days = plan.value?.days ?? const <TripDay>[];
    var sorted = 0;
    var skipped = 0;
    var own = 0;
    int? first;
    for (final d in days) {
      if (!_nightSorted(d)) {
        first ??= d.day;
        continue;
      }
      sorted++;
      if (d.stay?.isSkipped ?? false) {
        skipped++;
      } else if (ownStayOf(d.day) != null) {
        own++;
      }
    }
    return (
      display: TripStepRules.groupDisplay(total: days.length, sorted: sorted, skipped: skipped, own: own),
      sorted: sorted,
      total: days.length,
      firstUnsorted: first,
    );
  }

  ({TripStepDisplay display, int sorted, int total, int? firstUnsorted}) get taxiStep {
    final days = plan.value?.days ?? const <TripDay>[];
    var sorted = 0;
    var skipped = 0;
    var own = 0;
    int? first;
    for (final d in days) {
      if (!_taxiDaySorted(d)) {
        first ??= d.day;
        continue;
      }
      sorted++;
      if (d.taxi?.isSkipped ?? false) {
        skipped++;
      } else if (d.taxi?.isOwn ?? false) {
        own++;
      }
    }
    return (
      display: TripStepRules.groupDisplay(total: days.length, sorted: sorted, skipped: skipped, own: own),
      sorted: sorted,
      total: days.length,
      firstUnsorted: first,
    );
  }

  bool get stayNeedsAttention =>
      !isReadOnly && (plan.value?.days ?? const <TripDay>[]).any((d) => primaryEnquiry(d.day)?.isRed ?? false);

  bool get taxiNeedsAttention =>
      !isReadOnly && (plan.value?.days ?? const <TripDay>[]).any((d) => primaryTaxiEnquiry(d.day)?.isRed ?? false);

  TripStepDisplay displayOf(TripStepKind k) => switch (k) {
        TripStepKind.itinerary => itineraryDisplay,
        TripStepKind.gettingThere => stepDisplay(TripStepRole.gettingThere),
        TripStepKind.stay => stayStep.display,
        TripStepKind.localTaxi => taxiStep.display,
        TripStepKind.comingBack => stepDisplay(TripStepRole.comingBack),
      };

  bool attentionOf(TripStepKind k) => switch (k) {
        TripStepKind.itinerary => false,
        TripStepKind.gettingThere => stepNeedsAttention(TripStepRole.gettingThere),
        TripStepKind.stay => stayNeedsAttention,
        TripStepKind.localTaxi => taxiNeedsAttention,
        TripStepKind.comingBack => stepNeedsAttention(TripStepRole.comingBack),
      };

  int get stepsSorted => TripStepRules.sortedCount([for (final k in TripStepKind.values) displayOf(k)]);

  TripJourney? get journeyToday {
    if (isCompleted) return null;
    for (final r in TripStepRole.values) {
      final j = journeyFor(r);
      if (j != null && _sameDate(j.date, _today)) return j;
    }
    return null;
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
    plan.value = p.copyWith(steps: _autoSteps(next));
    scheduleSave();
  }

  TripSteps _autoSteps(TripSteps next) {
    final pt = _cityPoint;
    final last = _lastPoint;
    return TripStepRules.withAutoNotNeeded(next, pt?.lat, pt?.lon, last?.lat, last?.lon);
  }

  void _refreshAutoSteps() {
    final p = plan.value;
    if (p == null) return;
    final next = _autoSteps(p.steps);
    if (!identical(next, p.steps)) plan.value = p.copyWith(steps: next);
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
    if (next.of(role.other).journeyId == j.id) next = next.withStep(role.other, const TripStep());
    final cur = next.of(role);
    final oldId = cur.journeyId;
    final keepBooked = cur.status == TripStepStatus.booked && oldId == j.id;
    final def = TripStepRules.expectedDate(role, const TripStep(), settings, dayCount);
    final date = def != null && TripStepRules.dateChanged(def, j.date) ? j.date : null;
    next = next.withStep(
      role,
      TripStep(status: keepBooked ? TripStepStatus.booked : TripStepStatus.chosen, journeyId: j.id, date: date),
    );
    if (oldId != null && oldId != j.id) _dropLocalJourney(oldId);
    final t = trip.value;
    if (t != null) {
      final local = TripJourney.fromSaved(j, role, expectedDate: date ?? def, startFrom: next.startFrom);
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
      final local = TripJourney.fromSaved(j, r, expectedDate: stepDate(r), startFrom: startFrom);
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
    _setSteps(p.steps.withStep(role, const TripStep()));
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

  void markStepOwn(TripStepRole role, {String? note}) {
    final p = plan.value;
    if (p == null || isReadOnly) return;
    var n = note?.trim();
    if (n != null && n.length > TripConstants.noteMax) n = n.substring(0, TripConstants.noteMax).trim();
    _dropLocalJourney(p.steps.of(role).journeyId);
    _setSteps(p.steps.withStep(role, TripStep(status: TripStepStatus.own, note: n == null || n.isEmpty ? null : n)));
  }

  void skipStep(TripStepRole role) {
    final p = plan.value;
    if (p == null || isReadOnly) return;
    _dropLocalJourney(p.steps.of(role).journeyId);
    _setSteps(p.steps.withStep(role, const TripStep(status: TripStepStatus.skipped)));
  }

  void resetStep(TripStepRole role) {
    final p = plan.value;
    if (p == null || isReadOnly) return;
    final s = p.steps.of(role).status;
    if (s != TripStepStatus.own && s != TripStepStatus.skipped && s != TripStepStatus.notNeeded) return;
    _setSteps(p.steps.withStep(role, const TripStep()));
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
        next = next.withStep(r, const TripStep());
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

  static TripCityModel _firstCity(TripModel t) => t.plan.legs.isNotEmpty
      ? t.plan.legs.first.city
      : TripCityModel(cityKey: t.cityKey, name: t.cityName, latitude: t.cityLatitude, longitude: t.cityLongitude);

  bool _openFromCache(String tripId, Object e) {
    if (!DioErrorMapper.isNetworkError(e)) return false;
    final cached = TripTodayCache.trip(tripId);
    if (cached == null) return false;
    trip.value = cached;
    plan.value = cached.plan;
    enquiryList.assignAll(cached.enquiries);
    result.value = TripTodayCache.result(tripId);
    picked = _firstCity(cached);
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
    taxiSupplyByLeg.clear();
    _supplyTried.clear();
    lastAddedLeg.value = null;
    pendingNextCity.value = null;
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
      AppToast.error(TripStrings.saveFailed);
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

  Future<void> startFromSelection(
    TripCityModel city,
    List<TripSpotModel> chosen, {
    TripSettings? settings,
    TripCityModel? queuedNext,
  }) async {
    final pendingSave = _detachPendingSave();
    _reset();
    if (pendingSave != null) unawaited(pendingSave());
    picked = city;
    _clientTripId = const Uuid().v4();
    plan.value = TripPlan(
      legs: [TripCityLeg.fromCity(1, city)],
      days: [
        TripDay(day: 1, leg: 1, spots: chosen.take(TripConstants.maxSpots).map(TripSpotRef.fromSpot).toList()),
      ],
      settings: settings ?? const TripSettings(),
    );
    pendingNextCity.value = queuedNext != null && queuedNext.cityKey != city.cityKey ? queuedNext : null;
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
      picked = _firstCity(t);
      checkSupply();
      _adoptDistrict(t);
      reconcilePlan();
      reconcileSteps(t);
      reconcileTravel(t);
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
    final cap = room < 1 ? 1 : room;
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
              .map((d) => {'day': d.day, 'spots': d.spots.map((s) => s.toPlanInput()).toList()})
              .toList(),
        'dayLimitMinutes': p.settings.dayLimitMinutes,
        'startDate': ?p.settings.startDateIso,
        if (mode == 'auto') 'maxDays': ?(maxDays ?? p.settings.maxDays),
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
            .map((d) => {'day': d.day - offset, 'spots': d.spots.map((s) => s.toPlanInput()).toList()})
            .toList(),
      'dayLimitMinutes': p.settings.dayLimitMinutes,
      if (startDate != null) 'startDate': _isoDate(startDate),
      if (mode == 'auto') 'maxDays': maxDays ?? _legMaxDays(p, legIndex),
      if (used > 0) 'firstDayUsedMinutes': used,
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
    try {
      final targets = [
        for (final l in p.legs)
          if (p.legSpotCount(l.index) > 0) l.cityKey,
      ];
      if (targets.isEmpty) targets.add(p.cityKey);
      TripPlanResult? last;
      for (final cityKey in targets) {
        final cur = plan.value;
        if (cur == null) return;
        final k = cur.legIndexOfCity(cityKey) ?? 1;
        final keep = cur.isMultiCity ? cur.legDayCount(k) : null;
        inFlight = cityKey;
        final r = await _repo.plan(_planBody(cur, k, 'auto'));
        inFlight = null;
        if (seq != _planSeq) return;
        if (edit != _editSeq || plan.value == null) {
          _lastPlanWasAuto = false;
          unawaited(_runRecalculate());
          return;
        }
        final before = plan.value!;
        final k2 = before.legIndexOfCity(cityKey) ?? 1;
        final after = _applyAutoLeg(before, k2, r, minDays: keep);
        plan.value = after;
        result.value = last = _mergeLegResult(before, after, k2, r);
      }
      _lastPlanWasAuto = false;
      if (last != null) _cacheResult(last);
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
        if (inFlight != null) _markLegUnavailable(e, inFlight);
        _onPlanError(e);
      }
    } finally {
      if (seq == _planSeq) isPlanning.value = false;
    }
  }

  Future<void> _planLegByCity(int cityKey, {int? maxDays, int? exactDays, bool keepDays = false}) =>
      _enqueue(() => _runPlanLeg(cityKey, maxDays: maxDays, exactDays: exactDays, keepDays: keepDays));

  Future<void> _runPlanLeg(int cityKey, {int? maxDays, int? exactDays, bool keepDays = false}) async {
    final p = plan.value;
    final k = p?.legIndexOfCity(cityKey);
    if (p == null || k == null || p.legSpotCount(k) == 0) return;
    _lastPlanWasAuto = true;
    _retryLeg = (cityKey: cityKey, maxDays: maxDays, exactDays: exactDays, keepDays: keepDays);
    final seq = ++_planSeq;
    final edit = _editSeq;
    final hold = keepDays || (k < p.legCount && _laterLegsHaveBookings(k));
    final keep = exactDays ?? (hold ? p.legDayCount(k) : null);
    isPlanning.value = true;
    _clearPlanError();
    try {
      final r = await _repo.plan(_planBody(p, k, 'auto', maxDays: exactDays ?? maxDays));
      if (seq != _planSeq) return;
      _lastPlanWasAuto = false;
      _retryLeg = null;
      if (edit != _editSeq || plan.value == null) {
        unawaited(_runRecalculate());
        return;
      }
      final before = plan.value!;
      final k2 = before.legIndexOfCity(cityKey);
      if (k2 == null) return;
      final after = _applyAutoLeg(before, k2, r, minDays: keep);
      plan.value = after;
      final merged = _mergeLegResult(before, after, k2, r);
      result.value = merged;
      _cacheResult(merged);
      reconcilePlan();
      scheduleSave();
    } catch (e) {
      if (seq != _planSeq) return;
      if (_isPlannerOff(e)) {
        plannerOff.value = true;
      } else if (!_isUnauthorized(e)) {
        _markLegUnavailable(e, cityKey);
        _onPlanError(e);
      }
    } finally {
      if (seq == _planSeq) isPlanning.value = false;
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
        taxi: old?.taxi,
        stay: old?.stay,
        stayShortlist: old?.stayShortlist ?? const [],
        taxiShortlist: old?.taxiShortlist ?? const [],
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
      final days = [for (var i = 0; i < built.length; i++) built[i].copyWith(day: i + 1, leg: 1)];
      return p.copyWith(legs: legs, days: _fixSameStay(days));
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
      final lastFull = keepEmptyDays ? single.length - 1 : single.lastIndexWhere((d) => d.spots.isNotEmpty);
      final kept = lastFull < 0 ? <TripDay>[] : single.sublist(0, lastFull + 1);
      if (kept.isEmpty) {
        final first = single.isEmpty ? null : single.first;
        return [
          TripDay(
            day: 1,
            taxi: _remapBooking(first?.taxi, map: const {1: 1}),
            stay: first?.stay?.copyWith(clearSameAsDay: true),
          ),
        ];
      }
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
      final lastFull = keepAll ? group.length - 1 : group.lastIndexWhere((d) => d.spots.isNotEmpty);
      kept.addAll(group.sublist(0, lastFull < 0 ? 1 : lastFull + 1));
    }
    return _numbered(kept);
  }

  List<TripDay> _numbered(List<TripDay> kept) {
    final map = <int, int>{};
    final legOfNew = <int, int>{};
    for (var i = 0; i < kept.length; i++) {
      map[kept[i].day] = i + 1;
      legOfNew[i + 1] = kept[i].leg;
    }
    int? sameLeg(int? same, int leg) {
      final target = same == null ? null : map[same];
      return target != null && legOfNew[target] == leg ? target : null;
    }

    final out = <TripDay>[];
    for (var i = 0; i < kept.length; i++) {
      final d = kept[i];
      var stay = d.stay;
      final same = stay?.sameAsDay;
      if (stay != null && same != null) {
        final target = sameLeg(same, d.leg);
        stay = target == null ? stay.copyWith(clearSameAsDay: true) : stay.copyWith(sameAsDay: target);
      }
      final legMap = <int, int>{
        for (final e in map.entries)
          if (legOfNew[e.value] == d.leg) e.key: e.value,
      };
      out.add(TripDay(
        day: i + 1,
        leg: d.leg,
        spots: d.spots,
        taxi: _remapBooking(d.taxi, map: legMap),
        stay: stay,
        stayShortlist: [
          for (final s in d.stayShortlist)
            if (s.sameAsDay == null)
              s
            else if (sameLeg(s.sameAsDay, d.leg) == null)
              s.copyWith(clearSameAsDay: true)
            else
              s.copyWith(sameAsDay: sameLeg(s.sameAsDay, d.leg)),
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
    final trim = _trimmedLegs(p, days);
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

  bool _dayHasBookings(TripDay d) =>
      d.stay != null ||
      d.taxi != null ||
      d.stayShortlist.isNotEmpty ||
      d.taxiShortlist.isNotEmpty ||
      enquiriesForNight(d.day).any((e) => e.isOpen) ||
      taxiEnquiriesForDay(d.day).any((e) => e.isOpen);

  EditImpact editImpact(List<TripDay> next) {
    final p = plan.value;
    if (p == null || !p.isMultiCity) {
      final lastFull = next.lastIndexWhere((d) => d.spots.isNotEmpty);
      final keep = lastFull < 0 ? 1 : lastFull + 1;
      final dropped = <int>[
        for (var i = keep; i < next.length; i++)
          if (_dayHasBookings(plan.value?.dayAt(next[i].day) ?? next[i])) next[i].day,
      ];
      return EditImpact(droppedDaysWithBookings: dropped);
    }
    final trim = _trimmedLegs(p, next);
    final dropped = <int>[];
    for (var k = 1; k <= p.legCount; k++) {
      if (!trim.contains(k)) continue;
      final group = next.where((d) => d.leg == k).toList();
      final lastFull = group.lastIndexWhere((d) => d.spots.isNotEmpty);
      final keep = lastFull < 0 ? 1 : lastFull + 1;
      for (var i = keep; i < group.length; i++) {
        if (_dayHasBookings(p.dayAt(group[i].day) ?? group[i])) dropped.add(group[i].day);
      }
    }
    return EditImpact(droppedDaysWithBookings: dropped);
  }

  List<TripDay>? _movedDays(String id, int toDay) {
    final p = plan.value;
    if (p == null) return null;
    final fromDay = p.dayOfSpot(id);
    final spot = p.spotById(id);
    if (fromDay == null || spot == null || fromDay == toDay || p.dayAt(toDay) == null) return null;
    if (p.legIndexOf(fromDay) != p.legIndexOf(toDay)) return null;
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

  bool moveSpot(String id, int toDay, {bool keepEmptyDays = false}) {
    final p = plan.value;
    if (p == null || isReadOnly) return false;
    final fromDay = p.dayOfSpot(id);
    if (fromDay != null && p.dayAt(toDay) != null && p.legIndexOf(fromDay) != p.legIndexOf(toDay)) {
      AppToast.warning(TripStringsMcaA1.differentCity);
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
    _applyEdit([for (final x in p.days) x.day == day ? x.copyWith(spots: spots) : x]);
  }

  void removeSpot(String id, {bool keepEmptyDays = false}) {
    if (isReadOnly) return;
    final next = _removedDays(id);
    if (next != null) _applyEdit(next, keepEmptyDays: keepEmptyDays);
  }

  void addSpots(List<TripSpotModel> spots, {int? legIndex}) {
    final p = plan.value;
    if (p == null || p.days.isEmpty || isReadOnly) return;
    final existing = p.spotIds;
    final room = TripConstants.maxSpots - existing.length;
    final fresh = spots.where((s) => !existing.contains(s.id)).toList();
    if (fresh.isEmpty) return;
    if (fresh.length > room) AppToast.warning(TripStringsMcaA1.maxPlaces);
    final adding = fresh.take(room < 0 ? 0 : room).map(TripSpotRef.fromSpot).toList();
    if (adding.isEmpty) return;
    final k = legIndex ?? p.legCount;
    final end = p.isMultiCity ? p.legEnd(k) : p.days.last.day;
    final target = end > 0 ? end : p.days.last.day;
    _applyEdit([for (final d in p.days) d.day == target ? d.copyWith(spots: [...d.spots, ...adding]) : d]);
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
    pendingNextCity.value = null;
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
    _refreshAutoSteps();
    _refreshLegSupply();
    scheduleSave();
    AppToast.success(TripStringsMcaA1.cityAdded(city.name));
    if (adding.isNotEmpty) unawaited(_planLegByCity(city.cityKey));
    return TripLegEditBlock.none;
  }

  void clearPendingNext() => pendingNextCity.value = null;

  void _refreshLegSupply() {
    final p = plan.value;
    if (p == null) return;
    final next = <int, bool?>{};
    for (final l in p.legs) {
      if (l.index == 1) {
        if (taxiSupplyByLeg.containsKey(1)) next[1] = taxiSupply.value;
        continue;
      }
      final d = l.districtId;
      if (d != null && _supplyByDistrict.containsKey(d)) next[l.index] = _supplyByDistrict[d];
    }
    taxiSupplyByLeg.assignAll(next);
  }

  Future<void> ensureSupply(int legIndex) async {
    await Future<void>.value();
    final p = plan.value;
    final leg = p?.legAt(legIndex);
    if (p == null || leg == null) return;
    if (legIndex == 1 || taxiSupplyByLeg[legIndex] != null) return;
    final districtId = leg.districtId;
    if (districtId == null) {
      if (!_legUnsaved(leg.cityKey)) taxiSupplyByLeg[legIndex] = false;
      return;
    }
    final cached = _supplyByDistrict[districtId];
    if (cached != null) {
      taxiSupplyByLeg[legIndex] = cached;
      return;
    }
    if (taxiTabOff.value || !_supplyTried.add(districtId)) {
      if (!taxiSupplyByLeg.containsKey(legIndex)) taxiSupplyByLeg[legIndex] = null;
      return;
    }
    final has = await _browseDistrict(districtId);
    if (has == null) {
      if (!taxiSupplyByLeg.containsKey(legIndex)) taxiSupplyByLeg[legIndex] = null;
      return;
    }
    final now = plan.value;
    final k = now?.legIndexOfCity(leg.cityKey);
    if (now == null || k == null || now.legAt(k)?.districtId != districtId) return;
    taxiSupplyByLeg[k] = has;
  }

  Future<bool?> _browseDistrict(String districtId) {
    final running = _supplyInFlight[districtId];
    if (running != null) return running;
    final f = () async {
      try {
        final page = await const TaxiBrowseRepository().browseLocal(districtId: districtId, localRate: true, pageSize: 1);
        final has = page.items.isNotEmpty;
        _supplyByDistrict[districtId] = has;
        return has;
      } catch (e) {
        if (DioErrorMapper.errorType(e) == ApiService.tabInactiveType) taxiTabOff.value = true;
        return null;
      } finally {
        _supplyInFlight.remove(districtId);
      }
    }();
    _supplyInFlight[districtId] = f;
    return f;
  }

  void _applyLegChange(TripPlan next) {
    final oldFirst = plan.value?.cityKey;
    _editSeq++;
    plan.value = next;
    final added = lastAddedLeg.value;
    if (added != null && added > next.legCount) lastAddedLeg.value = null;
    if (next.legs.isNotEmpty) picked = next.legs.first.city;
    _refreshAutoSteps();
    if (oldFirst != next.cityKey) {
      cityHasTaxis.value = null;
      taxiSupply.value = null;
      taxiSupplyByLeg.remove(1);
      unawaited(checkSupply());
    }
    _refreshLegSupply();
    recalculate();
    scheduleSave();
  }

  TripLegEditBlock canRemoveLeg(int legIndex) {
    final p = plan.value;
    if (p == null || isReadOnly || _saveBlocked) return TripLegEditBlock.readOnly;
    if (p.legs.length < 2) return TripLegEditBlock.onlyLeg;
    if (p.legAt(legIndex) == null) return TripLegEditBlock.edge;
    if (legRunning(legIndex)) return TripLegEditBlock.running;
    return TripLegEditBlock.none;
  }

  TripLegRemoveMode removeLegMode(int legIndex) =>
      _laterLegsHaveBookings(legIndex) ? TripLegRemoveMode.keepLaterDates : TripLegRemoveMode.shift;

  TripLegEditBlock removeLeg(int legIndex, {bool keepBookings = false}) {
    final block = canRemoveLeg(legIndex);
    if (block != TripLegEditBlock.none) return block;
    if (!keepBookings && !legRemoveImpact(legIndex).isEmpty) return TripLegEditBlock.bookings;
    final p = plan.value!;
    final name = p.legAt(legIndex)!.cityName;
    _applyLegChange(_removeLegPlan(p, legIndex, removeLegMode(legIndex)));
    reconcilePlan();
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
    );
  }

  @visibleForTesting
  TripPlan moveLegForTest(TripPlan p, int legIndex, bool up) => _moveLegPlan(p, legIndex, up);

  int maxDaysForLeg(int legIndex) {
    final p = plan.value;
    if (p == null) return 1;
    final m = TripConstants.maxDaysCap - _otherLegDays(p, legIndex);
    return m < 1 ? 1 : m;
  }

  int _pastDaysOf(int legIndex) => legDays(legIndex).where(isDayPast).length;

  EditImpact legDaysImpact(int legIndex, int days) {
    final p = plan.value;
    if (p == null) return const EditImpact();
    final current = p.daysOf(legIndex);
    if (days >= current.length) return const EditImpact();
    return EditImpact(droppedDaysWithBookings: [
      for (final d in current.skip(days < 1 ? 1 : days))
        if (_dayHasBookings(d)) d.day,
    ]);
  }

  TripLegEditBlock setLegDays(int legIndex, int days, {bool keepBookings = false}) {
    final p = plan.value;
    if (p == null || isReadOnly || _saveBlocked) return TripLegEditBlock.readOnly;
    final leg = p.legAt(legIndex);
    if (leg == null || days < 1) return TripLegEditBlock.edge;
    final current = p.legDayCount(legIndex);
    if (days == current) return TripLegEditBlock.none;
    if (days > maxDaysForLeg(legIndex)) return TripLegEditBlock.noDays;
    final running = legRunning(legIndex);
    if (days < minDaysForLeg(legIndex)) return TripLegEditBlock.running;
    if (!keepBookings && !legShrinkImpact(legIndex, days).isEmpty) return TripLegEditBlock.bookings;
    if (p.legSpotCount(legIndex) > 0 && !running) {
      unawaited(_planLegByCity(leg.cityKey, exactDays: days));
      return TripLegEditBlock.none;
    }
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
    reconcilePlan();
    recalculate();
    scheduleSave();
    return TripLegEditBlock.none;
  }

  static final RegExp _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  static final RegExp _phonePattern = RegExp(r'^[6-9]\d{9}$');

  static String? _clip(String? v, int max) {
    final t = v?.trim();
    if (t == null || t.isEmpty) return null;
    return t.length > max ? t.substring(0, max).trim() : t;
  }

  void setOwnTravel(int legIndex, TripTravel t) {
    final p = plan.value;
    final leg = p?.legAt(legIndex);
    final prev = p?.legAt(legIndex - 1);
    if (p == null || leg == null || prev == null || legIndex < 2 || isReadOnly) return;
    if (leg.arrival?.isJourney ?? false) return;
    final phone = t.ownPhone?.replaceAll(RegExp(r'\D'), '');
    final road = t.roadMinutes;
    final leaves = t.leavesAt?.trim();
    final clean = TripTravel.own(
      fromName: prev.cityName,
      how: t.how,
      ownName: _clip(t.ownName, TripConstants.ownTravelNameMax),
      ownPhone: phone != null && _phonePattern.hasMatch(phone) ? phone : null,
      leavesAt: leaves != null && _timePattern.hasMatch(leaves) ? leaves : null,
      roadMinutes: road == TripConstants.travelHalfDayMinutes || road == TripConstants.travelWholeDayMinutes ? road : null,
      note: _clip(t.note, TripConstants.noteMax),
      hubName: _clip(t.hubName, TripConstants.travelHubNameMax),
    );
    final oldRoad = leg.arrival?.roadMinutes;
    plan.value = p.withArrival(legIndex, clean);
    travelGaps.remove(legIndex);
    scheduleSave();
    if (oldRoad != clean.roadMinutes && p.legSpotCount(legIndex) > 0 && canEditLeg(legIndex)) {
      unawaited(_planLegByCity(leg.cityKey, keepDays: true));
    }
  }

  void clearTravel(int legIndex) {
    final p = plan.value;
    final leg = p?.legAt(legIndex);
    if (p == null || leg == null || legIndex < 2 || leg.arrival == null || isReadOnly) return;
    if (leg.arrival!.isJourney) {
      unawaited(removeTravel(legIndex));
      return;
    }
    _setArrival(legIndex, null);
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
    return a != null && a.isJourney && id != null && id.isNotEmpty ? a : null;
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
    return a == null ? const [] : TripTravelRules.liveRowsOf(a.journeyId!, enquiryList);
  }

  TripEnquiryModel? carBooking(int legIndex, int carIndex) =>
      TripTravelRules.carBooking(carIndex, segmentRows(legIndex));

  TripTravelState travelStateOf(int legIndex) {
    final a = legIndex >= 2 ? plan.value?.legAt(legIndex)?.arrival : null;
    final j = segmentJourney(legIndex);
    if (a != null && a.isJourney && j == null && offline.value) return TripTravelState.saved;
    return TripTravelRules.stateOf(
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
    if (offline.value) return TravelFindBlock.offline;
    return TravelFindBlock.none;
  }

  bool hidesLocalTaxi(int day) => isTravelDay(day) && (legOf(day).arrival?.isJourney ?? false);

  bool hasLocalTaxiOn(int day) {
    final t = plan.value?.dayAt(day)?.taxi;
    return (t != null && !t.isSkipped) || taxiEnquiriesForDay(day).any((e) => e.isOpen);
  }

  Future<void> cancelLocalTaxiTravelDay(int day) async {
    final p = plan.value;
    if (p == null || isReadOnly || !canEditDay(day)) return;
    final enq = TripEnquiryController.to;
    var ok = true;
    var kept = false;
    for (final e in taxiEnquiriesForDay(day).where((e) => e.isOpen).toList()) {
      final days = planDaysOf(e);
      final rest = days.where((d) => d != day).toList();
      if (e.isBooked) {
        ok = (rest.isEmpty ? await enq.cancel(e.id) : await _shrinkTaxiBooking(e, days, rest)) && ok;
      } else if (e.isWithdrawable) {
        if (rest.isEmpty) {
          ok = await enq.withdraw(e.id) && ok;
        } else {
          kept = true;
        }
      }
    }
    if (!ok) return;
    _dropLocalTaxiDay(day);
    if (kept) {
      AppToast.warning(TripStringsMcbK1.localTaxiLeadKept);
    } else {
      AppToast.success(TripStringsMcbK1.localTaxiDayRemoved(day));
    }
  }

  Future<bool> _shrinkTaxiBooking(TripEnquiryModel e, List<int> days, List<int> rest) async {
    final t = e.taxi;
    final booking = _localBookingOf(e.listingId);
    final fare = t?.agreedFare ?? booking?.agreedFare;
    if (fare == null) return false;
    final kept = (fare * rest.length ~/ days.length).clamp(TaxiOptionSets.minFare, TaxiOptionSets.maxFare).toInt();
    final place = t?.pickupPlace ?? booking?.pickupPlace ?? settings.pickupPlace;
    final saved = await TripEnquiryController.to.bookTaxi(
      taxiId: e.listingId,
      days: rest,
      agreedFare: kept,
      tollExtra: t?.tollExtra ?? booking?.tollExtra ?? false,
      pickupTime: t?.pickupTime ?? booking?.pickupTime ?? settings.pickupTime ?? TripConstants.defaultPickupTime,
      pickupPlace: place == null || place.trim().isEmpty ? cityNameOf(rest.first) : place,
      closeOthers: false,
    );
    return saved != null;
  }

  TripTaxiBooking? _localBookingOf(String taxiId) {
    for (final d in plan.value?.days ?? const <TripDay>[]) {
      final t = d.taxi;
      if (t != null && t.taxiId == taxiId && t.booking != null) return t.booking;
    }
    return null;
  }

  void _dropLocalTaxiDay(int day) {
    final p = plan.value;
    final t = p?.dayAt(day)?.taxi;
    if (p == null || t == null || t.isSkipped) return;
    final all = t.booking?.days ?? const <int>[];
    _applyChoice([
      for (final d in p.days)
        if (d.day == day)
          d.copyWith(clearTaxi: true)
        else if (all.isNotEmpty && d.taxi?.taxiId == t.taxiId && (d.taxi?.booking?.days.contains(day) ?? false))
          d.copyWith(taxi: _withoutTravelDay(d.taxi!, day))
        else
          d,
    ]);
  }

  TripTaxiChoice _withoutTravelDay(TripTaxiChoice t, int day) {
    final b = t.booking!;
    final rest = b.days.where((x) => x != day).toList();
    final fare = b.days.isEmpty ? b.agreedFare : b.agreedFare * rest.length ~/ b.days.length;
    return t.copyWith(booking: b.copyWith(days: rest, agreedFare: fare));
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
        if (next.steps.of(r).journeyId == j.id) next = next.copyWith(steps: next.steps.withStep(r, const TripStep()));
      }
      for (final l in cur.legs) {
        if (l.index != legIndex && l.index >= 2 && l.arrival?.journeyId == j.id) next = next.withArrival(l.index, null);
      }
      final arrival = TripTravel.journey(
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
      if (deleteOld) unawaited(_deleteJourney(oldId!));
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
    if (!a.isJourney) {
      _setArrival(legIndex, null);
      return true;
    }
    if (travelBusy.contains(legIndex)) return false;
    if (_hasUnavailableLeg) {
      AppToast.warning(TripStrings.cityUnavailable);
      return false;
    }
    final rows = segmentRows(legIndex);
    if (TripTravelRules.impactOf(rows).hasBooked && !cancelBooked) return false;
    final id = a.journeyId!;
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

  Future<TripEnquiryModel?> bookJourneyCar({
    required String journeyId,
    required int legIndex,
    required int carIndex,
    required String taxiId,
    required int agreedFare,
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
    final a = _journeyArrival(legIndex);
    if (isReadOnly) return null;
    if (a == null || a.journeyId != journeyId) {
      AppToast.warning(TripStringsMcbK1.journeyNotInTrip);
      return null;
    }
    final ok = await flushPendingSave();
    final tripId = trip.value?.id;
    if (!ok || tripId == null) {
      AppToast.warning(TripStrings.notSavedCheckConnection);
      return null;
    }
    if (_journeyArrival(legIndex)?.journeyId != journeyId) {
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
      enq.lastErrorMessage = network ? TripStrings.noNetwork : DioErrorMapper.serverMessage(e);
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

  void _markCarBooked(String journeyId, int carIndex, String enquiryId, int fare) {
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
      if (l.index < 2 || a == null || !a.isJourney || id == null) continue;
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
      if (l.index < 2 || a == null || !a.isJourney || id == null) continue;
      final server = saved.plan.legAt(l.index);
      if (server == null || server.cityKey != l.cityKey) continue;
      final sa = server.arrival;
      if (sa != null && sa.isJourney && sa.journeyId == id) continue;
      final mine = next.legAt(l.index);
      if (mine == null || mine.cityKey != l.cityKey || mine.arrival?.journeyId != id) continue;
      next = next.withArrival(l.index, sa);
      _dropLocalJourney(id);
    }
    if (!identical(next, local)) plan.value = next;
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
    final firstDay = days.where((d) => p.dayAt(d) != null).firstOrNull;
    final chosen = {
      for (final d in days)
        if (p.dayAt(d) != null &&
            _sameLeg(p, d, firstDay!) &&
            canEditDay(d) &&
            bookedTaxiEnquiryFor(d) == null)
          d,
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
    final end = _legEndOf(p, day);
    final laterEmpty = p.days.where((d) => d.day > day && d.day <= end).every((d) => d.stay == null);
    final prefill = day == _legStartOf(p, day) || laterEmpty;
    _applyChoice([
      for (final d in p.days)
        if (d.day == day)
          d.copyWith(stay: choice)
        else if (d.day > day &&
            d.day <= end &&
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
    final known = booking.days.where((d) => p.dayAt(d) != null).toSet().toList()..sort();
    if (known.isEmpty) return;
    final valid = known.where((d) => _sameLeg(p, d, known.first)).toList();
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
        else if (d.taxi?.isBooked == true && d.taxi!.taxiId == taxi.id)
          d.copyWith(clearTaxi: true)
        else if (_overlapsBooking(d, valid))
          d.copyWith(taxi: _withoutDays(d.taxi!, valid))
        else
          d,
    ];
    plan.value = p.copyWith(
      days: days,
      settings: p.settings.copyWith(pickupTime: b.pickupTime, pickupPlace: b.pickupPlace),
    );
    scheduleSave();
  }

  // A replaced driver keeps his other days; only the replaced days leave his booking.
  bool _overlapsBooking(TripDay d, List<int> days) => d.taxi?.booking?.days.any(days.contains) ?? false;

  TripTaxiChoice _withoutDays(TripTaxiChoice t, List<int> days) {
    final b = t.booking!;
    return t.copyWith(booking: b.copyWith(days: b.days.where((x) => !days.contains(x)).toList()));
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
    final daysCut = redo && next.maxDays != null && next.maxDays! < dayCount;
    var steps = p.steps;
    if (next.startDateIso != old.startDateIso || daysCut) {
      steps = steps
          .withStep(TripStepRole.gettingThere, steps.gettingThere.copyWith(clearDate: true))
          .withStep(TripStepRole.comingBack, steps.comingBack.copyWith(clearDate: true));
    } else if (redo) {
      steps = steps.withStep(TripStepRole.comingBack, steps.comingBack.copyWith(clearDate: true));
    }
    plan.value = p.copyWith(settings: next, steps: steps);
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
      if (enquiryList.any((e) => e.isTaxi && !e.isSegment && e.listingId == t.taxiId)) continue;
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
    reconcilePlan(freshLeads: freshLeads);
  }

  void reconcilePlan({List<TripEnquiryModel> freshLeads = const []}) {
    final p = plan.value;
    if (p == null || p.days.isEmpty) return;
    final days = [...p.days];
    final spread = _spreadTaxiShortlist(days, freshLeads);
    final taxiChanged = _reconcileTaxis(days);
    final stayChanged = p.settings.hasDates && _reconcileStays(days);
    if (!spread && !taxiChanged && !stayChanged) return;
    plan.value = p.copyWith(days: days);
    scheduleSave();
  }

  bool _spreadTaxiShortlist(List<TripDay> days, List<TripEnquiryModel> leads) {
    if (leads.isEmpty || isReadOnly) return false;
    var changed = false;
    for (final e in leads) {
      final covered = planDaysOf(e, days).toSet();
      if (covered.length < 2) continue;
      TripTaxiShortlistItem? item;
      var itemLeg = 1;
      for (final d in days) {
        if (!covered.contains(d.day)) continue;
        for (final s in d.taxiShortlist) {
          if (s.taxiId == e.listingId) {
            item = s;
            itemLeg = d.leg;
            break;
          }
        }
        if (item != null) break;
      }
      if (item == null) continue;
      for (var i = 0; i < days.length; i++) {
        final d = days[i];
        if (!covered.contains(d.day) || isDayPast(d.day) || d.leg != itemLeg) continue;
        if (d.taxiShortlist.any((s) => s.taxiId == e.listingId)) continue;
        if (d.taxiShortlist.length >= TripConstants.maxShortlist) continue;
        days[i] = d.copyWith(taxiShortlist: [...d.taxiShortlist, item]);
        changed = true;
      }
    }
    return changed;
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
        .where((e) => e.isTaxi && !e.isSegment && (e.isBookedByYou || e.display == TripDisplayStatus.confirmedByBoth))
        .toList()
      ..sort(_newestFirst);
    for (final e in booked) {
      final fare = e.taxi?.agreedFare;
      if (fare == null || e.days.isEmpty) continue;
      final covered = planDaysOf(e, days);
      if (_spansLegs(covered, days) || wrongCityOf(e) != null) continue;
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
      if (!e.isTaxi || e.isSegment || !_taxiTerminal(e.display)) continue;
      for (final day in planDaysOf(e, days)) {
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
        if (e.isTaxi && !e.isSegment && e.isBooked) e.listingId,
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

  static bool _spansLegs(List<int> covered, List<TripDay> days) {
    final legOf = {for (final d in days) d.day: d.leg};
    return {for (final d in covered) legOf[d]}.length > 1;
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
    final p = plan.value;
    for (final e in confirmed) {
      final ci = e.checkIn!;
      final nights = e.nights;
      final total = e.agreedTotal;
      final price = total == null ? null : (total / nights).ceil();
      final home = p == null || !p.isMultiCity ? null : TripEnquiryRules.homeLegIndex(e, p);
      int? firstDay;
      int? firstLeg;
      for (var k = 0; k < nights; k++) {
        final i = indexFor(DateTime(ci.year, ci.month, ci.day + k));
        if (i == null || claimed.contains(i)) continue;
        final d = days[i];
        if (home != null && d.leg != home) {
          final cur = d.stay;
          if (cur != null && !cur.isOwn && !cur.isSkipped && cur.stayId == e.listingId) {
            days[i] = d.copyWith(clearStay: true);
            changed = true;
          }
          continue;
        }
        claimed.add(i);
        if (firstLeg != d.leg) {
          firstDay = null;
          firstLeg = d.leg;
        }
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
      final targetDay = days.where((d) => d.day == same).firstOrNull;
      final target = targetDay?.stay;
      if (target == null || target.stayId != s.stayId || targetDay!.leg != days[i].leg) {
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
      reconcilePlan();
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
    final end = _legEndOf(p, day);
    final laterEmpty = p.days.where((x) => x.day > day && x.day <= end).every((x) => x.stayShortlist.isEmpty);
    final prefill = day == _legStartOf(p, day) || laterEmpty;
    bool follows(TripDay x) =>
        x.stayShortlist.isEmpty ? prefill : x.stayShortlist.every((i) => i.sameAsDay == day);
    _applyChoice([
      for (final x in p.days)
        if (x.day == day)
          x.copyWith(stayShortlist: [...x.stayShortlist, item])
        else if (x.day > day &&
            x.day <= end &&
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

  List<int> enquiryNightsRun(int day, {String? ignoreEnquiryId}) {
    final p = plan.value;
    if (p == null || p.dayAt(day) == null) return const [];
    final run = [day];
    final end = _legEndOf(p, day);
    for (var d = day + 1; d <= end; d++) {
      final stay = p.dayAt(d)?.stay;
      if (!canEditDay(d) ||
          ownStayOf(d) != null ||
          (stay != null && stay.isSkipped) ||
          enquiriesForNight(d).any((e) => e.isBooked && e.id != ignoreEnquiryId)) {
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
    final run = [day];
    final end = _legEndOf(p, day);
    for (var d = day + 1; d <= end; d++) {
      final x = p.dayAt(d);
      if (x == null ||
          !canEditDay(d) ||
          (x.stay != null && !x.stay!.isSameStay) ||
          enquiriesForNight(d).any((e) => e.isBooked)) {
        break;
      }
      run.add(d);
    }
    return run;
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
    if (!_sameLeg(p, day - 1, day)) return false;
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
    final p = plan.value;
    if (p != null && !_sameLeg(p, day - 1, day)) return null;
    final prev = p?.dayAt(day - 1)?.stay;
    if (prev != null) return prev.isSkipped ? null : prev;
    final e = primaryEnquiry(day - 1);
    if (e == null || !e.isBooked || e.isTaxi) return null;
    return TripStayChoice(stayId: e.listingId, name: e.listingName);
  }

  NoStayBlock canSkipNight(int day) {
    final p = plan.value;
    if (p == null || p.dayAt(day) == null || !canEditDay(day)) return NoStayBlock.readOnly;
    if (enquiriesForNight(day).any((e) => e.isOpen)) return NoStayBlock.hasEnquiry;
    return NoStayBlock.none;
  }

  NoStayBlock setSkippedNight(int day) {
    final block = canSkipNight(day);
    if (block != NoStayBlock.none) return block;
    final p = plan.value!;
    _applyChoice([
      for (final x in p.days)
        if (x.day == day)
          x.copyWith(stay: const TripStayChoice.skippedNight(), stayShortlist: const [])
        else if (x.stay?.sameAsDay == day)
          x.copyWith(stay: x.stay!.copyWith(clearSameAsDay: true))
        else
          x,
    ]);
    return NoStayBlock.none;
  }

  void clearSkippedNight(int day) {
    if (plan.value?.dayAt(day)?.stay?.isSkipped ?? false) clearStay(day);
  }

  bool _canSkipTaxiDay(TripDay d) =>
      canEditDay(d.day) && !(d.taxi?.isBooked ?? false) && bookedTaxiEnquiryFor(d.day) == null;

  void setSkippedTaxiDay(int day) {
    final p = plan.value;
    final d = p?.dayAt(day);
    if (p == null || d == null || !_canSkipTaxiDay(d)) return;
    _applyChoice([
      for (final x in p.days)
        x.day == day ? x.copyWith(taxi: const TripTaxiChoice.skippedDay(), taxiShortlist: const []) : x,
    ]);
  }

  void clearSkippedTaxiDay(int day) {
    if (plan.value?.dayAt(day)?.taxi?.isSkipped ?? false) clearTaxi(day);
  }

  void skipRemainingNights() {
    final p = plan.value;
    if (p == null || isReadOnly) return;
    final targets = {
      for (final d in p.days)
        if (canEditDay(d.day) && !_nightSorted(d) && !enquiriesForNight(d.day).any((e) => e.isOpen)) d.day,
    };
    if (targets.isEmpty) return;
    _applyChoice([
      for (final x in p.days)
        targets.contains(x.day) ? x.copyWith(stay: const TripStayChoice.skippedNight(), stayShortlist: const []) : x,
    ]);
  }

  void skipRemainingTaxiDays() {
    final p = plan.value;
    if (p == null || isReadOnly) return;
    final targets = {
      for (final d in p.days)
        if (_canSkipTaxiDay(d) && !_taxiDaySorted(d) && !taxiEnquiriesForDay(d.day).any((e) => e.isOpen)) d.day,
    };
    if (targets.isEmpty) return;
    _applyChoice([
      for (final x in p.days)
        targets.contains(x.day) ? x.copyWith(taxi: const TripTaxiChoice.skippedDay(), taxiShortlist: const []) : x,
    ]);
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
    final tabs = Get.isRegistered<TabConfigController>() ? TabConfigController.to : null;
    taxiTabOff.value = tabs != null && !tabs.isActiveForIndex(AppTabs.taxi);
    stayTabOff.value = tabs != null && !tabs.isActiveForIndex(AppTabs.stays);
    final seq = ++_supplySeq;
    final districtId = p.districtId;
    final recheck = [for (final k in taxiSupplyByLeg.keys) if (k >= 2) k];
    if (districtId == null) {
      cityHasTaxis.value = null;
      taxiSupply.value = trip.value == null ? null : false;
      taxiSupplyByLeg[1] = taxiSupply.value;
      _recheckLegs(recheck);
      return;
    }
    if (taxiTabOff.value) return;
    try {
      final page = await const TaxiBrowseRepository().browseLocal(districtId: districtId, localRate: true, pageSize: 1);
      if (seq != _supplySeq) return;
      cityHasTaxis.value = page.items.isNotEmpty;
      taxiSupply.value = page.items.isNotEmpty;
      taxiSupplyByLeg[1] = page.items.isNotEmpty;
      _supplyByDistrict[districtId] = page.items.isNotEmpty;
    } catch (e) {
      if (seq != _supplySeq) return;
      if (DioErrorMapper.errorType(e) == ApiService.tabInactiveType) taxiTabOff.value = true;
    }
    _recheckLegs(recheck);
  }

  void _recheckLegs(List<int> legs) {
    for (final k in legs) {
      if (taxiSupplyByLeg[k] != null) continue;
      final d = plan.value?.legAt(k)?.districtId;
      if (d != null) _supplyTried.remove(d);
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
      if (l.index < 2 || !(l.arrival?.isJourney ?? false) || id == null || id.isEmpty || links.containsKey(id)) continue;
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
