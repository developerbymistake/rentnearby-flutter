import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../models/place_result_model.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../trip/controllers/trip_plan_controller.dart';
import '../../trip/data/trip_segment_geometry_cache.dart';
import '../../trip/models/trip_plan_model.dart';
import '../../trip/trip_strings_steps_a1.dart';
import '../../trip/trip_strings_steps_k3.dart';
import '../../trip/utils/trip_travel_rules.dart';
import '../journeys/journey_models.dart';
import '../journeys/journeys_controller.dart';
import 'ask_drivers_sheet.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_navigation.dart';
import 'taxi_ways_repository.dart';
import 'widgets/travel_confirm_sheet.dart';

enum _SegmentLink { linked, plain, failed }

class TaxiWaysController extends GetxController {
  static const maxPeople = 12;
  static const maxDaysAhead = 365;

  TaxiWaysController({
    required PlaceResult from,
    required PlaceResult to,
    bool fromMyLocation = false,
    DateTime? date,
    int? people,
    this.tripId,
    this.tripRole,
    this.tripLegIndex,
  })  : from = Rx<PlaceResult>(from),
        to = Rx<PlaceResult>(to),
        fromMyLocation = (tripLegIndex == null && fromMyLocation).obs,
        date = Rx<DateTime>(_clampDate(date ?? _today().add(const Duration(days: 1)))),
        people = (people ?? 2).clamp(1, maxPeople).toInt().obs;

  final Rx<PlaceResult> from;
  final Rx<PlaceResult> to;
  final Rx<DateTime> date;
  final RxInt people;
  final RxBool fromMyLocation;
  final String? tripId;
  final String? tripRole;
  final int? tripLegIndex;

  bool get forTrip => tripId != null && TripStepRole.values.any((r) => r.name == tripRole);

  bool get forSegment => tripId != null && tripLegIndex != null;

  bool get lockedEnds => forSegment;

  bool get lockedDate => forSegment;

  TripPlanController? get _tripController =>
      Get.isRegistered<TripPlanController>() && TripPlanController.to.trip.value?.id == tripId ? TripPlanController.to : null;

  int? get segmentDay {
    final k = tripLegIndex;
    if (!forSegment || k == null) return null;
    return _tripController?.plan.value?.legStart(k);
  }

  final result = Rxn<TaxiWaysResult>();
  final isLoading = false.obs;
  final loadFailed = false.obs;
  final isOffline = false.obs;
  final tabOff = false.obs;
  final sort = WaysSort.fewestCars.obs;
  final chosen = <String, Map<int, WayDriver>>{}.obs;
  final busyPlans = <String>{}.obs;

  final _repo = const TaxiWaysRepository();
  final _details = <String, WayPlanDetail>{};
  final _synthetic = <String, WayPlan>{};
  int _gen = 0;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime firstDate() => _today();
  static DateTime lastDate() => _today().add(const Duration(days: maxDaysAhead));

  static DateTime _clampDate(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    if (day.isBefore(firstDate())) return firstDate();
    if (day.isAfter(lastDate())) return lastDate();
    return day;
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  List<Object> get rows {
    final r = result.value;
    return r == null ? const [] : sortedRows(r, sort.value, people: people.value);
  }

  Future<void> load() async {
    final myGen = ++_gen;
    isLoading.value = true;
    loadFailed.value = false;
    isOffline.value = false;
    tabOff.value = false;
    try {
      final f = from.value;
      final t = to.value;
      final r = await _repo.ways(
        fromLat: f.latLng.latitude,
        fromLng: f.latLng.longitude,
        toLat: t.latLng.latitude,
        toLng: t.latLng.longitude,
        date: date.value,
        people: people.value,
        fromMyLocation: fromMyLocation.value,
        fromName: _cut(f.name),
        toName: _cut(t.name),
      );
      if (myGen != _gen) return;
      _details.clear();
      _synthetic.clear();
      chosen.clear();
      result.value = r;
      for (final p in r.plans) {
        TripSegmentGeometryCache.putPlan(p);
      }
      _syncGap(r);
    } catch (e) {
      if (myGen != _gen) return;
      if (DioErrorMapper.isNetworkError(e)) {
        isOffline.value = true;
      } else if (DioErrorMapper.errorType(e) == 'TabInactive') {
        tabOff.value = true;
      }
      if (result.value == null) loadFailed.value = true;
    } finally {
      if (myGen == _gen) isLoading.value = false;
    }
  }

  String get gapHub {
    final r = result.value;
    final hub = r?.reachFirstPlace?.name;
    if (hub != null && hub.isNotEmpty) return hub;
    final to = r?.to.name;
    return to != null && to.isNotEmpty ? to : this.to.value.name;
  }

  void _syncGap(TaxiWaysResult r) {
    final t = forSegment ? _tripController : null;
    final k = tripLegIndex;
    if (t == null || k == null) return;
    if (r.hasWays) {
      t.clearTravelGap(k);
    } else {
      t.markTravelGap(k, gapHub);
    }
  }

  static String? _cut(String name) {
    final t = name.trim();
    if (t.isEmpty) return null;
    return t.length > 80 ? t.substring(0, 80) : t;
  }

  void retry() => load();

  Future<void> pullRefresh() => load();

  void setDate(DateTime d) {
    if (lockedDate) return;
    final v = _clampDate(d);
    if (v == date.value) return;
    date.value = v;
    load();
  }

  void setPeople(int n) {
    final v = n.clamp(1, maxPeople).toInt();
    if (v == people.value) return;
    people.value = v;
    load();
  }

  void setSort(WaysSort s) => sort.value = s;

  WayPlan? planByKey(String planKey) {
    final d = _details[planKey];
    if (d != null) return d;
    final s = _synthetic[planKey];
    if (s != null) return s;
    for (final p in result.value?.plans ?? const <WayPlan>[]) {
      if (p.planKey == planKey) return p;
    }
    return null;
  }

  bool isSynthetic(String planKey) => _synthetic.containsKey(planKey);

  WayPlan singlePlan(List<WayDriver> drivers) {
    final r = result.value;
    final f = r?.from ?? _placeOf(from.value);
    final t = r?.to ?? _placeOf(to.value);
    final plan = WayPlan.single(f, t, drivers);
    _synthetic[plan.planKey] = plan;
    if (drivers.isNotEmpty) choose(plan.planKey, 1, drivers.first);
    return plan;
  }

  static WayPlace _placeOf(PlaceResult p) =>
      WayPlace(key: '', name: p.name, lat: p.latLng.latitude, lng: p.latLng.longitude, resolved: false);

  Future<WayPlanDetail?> openPlan(String planKey) async {
    final cached = _details[planKey];
    if (cached != null) {
      _fillChosen(cached);
      return cached;
    }
    final base = planByKey(planKey);
    if (base != null) _fillChosen(base);
    try {
      final d = await _repo.plan(planKey, people: people.value, date: date.value);
      if (d.legs.isEmpty) throw StateError('empty plan');
      _details[planKey] = d;
      TripSegmentGeometryCache.putPlan(d);
      _fillChosen(d);
      return d;
    } catch (e) {
      final s = _synthetic[planKey];
      if (s != null) return s;
      if (DioErrorMapper.errorType(e) == 'PlanNotFound') load();
      rethrow;
    }
  }

  void _fillChosen(WayPlan plan) {
    final current = Map<int, WayDriver>.from(chosen[plan.planKey] ?? const {});
    for (final leg in plan.legs) {
      final all = leg.allDrivers;
      if (all.isEmpty) continue;
      final had = current[leg.index];
      if (had == null) {
        current[leg.index] = all.first;
      } else if (!had.hasContact) {
        final richer = all.firstWhereOrNull((d) => d.taxiId == had.taxiId && d.hasContact);
        if (richer != null) current[leg.index] = richer;
      }
    }
    chosen[plan.planKey] = current;
  }

  Map<int, WayDriver> chosenOf(String planKey) => chosen[planKey] ?? const {};

  WayDriver? chosenFor(String planKey, int legIndex) => chosen[planKey]?[legIndex];

  void choose(String planKey, int legIndex, WayDriver driver) {
    final current = Map<int, WayDriver>.from(chosen[planKey] ?? const {});
    current[legIndex] = driver;
    chosen[planKey] = current;
  }

  Future<SavedJourney?> saveIfNeeded(WayPlan plan, {bool quiet = false}) => JourneysController.ensure().saveIfNeeded(
        quiet: quiet,
        plan: plan,
        chosen: chosenOf(plan.planKey),
        date: date.value,
        people: people.value,
        fromName: plan.from.name,
        fromLat: plan.from.lat,
        fromLng: plan.from.lng,
        toName: plan.to.name,
        toLat: plan.to.lat,
        toLng: plan.to.lng,
        forTripId: forTrip || forSegment ? tripId : null,
        forTripLegIndex: forSegment && _tripController != null ? tripLegIndex : null,
      );

  int? roadMinutesOf(WayPlan plan) {
    var total = 0;
    for (final leg in plan.legs) {
      final m = leg.driverFor(chosenFor(plan.planKey, leg.index))?.minutes;
      if (m == null || m <= 0) return null;
      total += m;
    }
    return plan.legs.isEmpty ? null : total;
  }

  Future<({bool go, bool replaceBooked})> _segmentGate(BuildContext? context, WayPlan plan) async {
    final c = _tripController;
    final k = tripLegIndex;
    if (c == null || k == null) return (go: true, replaceBooked: false);
    final block = await c.prepareSegmentLink(k);
    if (block != null) {
      AppToast.warning(block);
      return (go: false, replaceBooked: false);
    }
    final booked = c.travelImpact(k).bookedRows;
    if (booked == 0 || c.travelMatches(k, plan.planKey, date.value, people.value)) {
      return (go: true, replaceBooked: false);
    }
    if (context == null || !context.mounted) return (go: false, replaceBooked: false);
    final ok = await TravelConfirmSheet.replaceTravel(context, booked);
    return (go: ok, replaceBooked: ok);
  }

  Future<void> _releaseUnsaved(WayPlan plan) async {
    final c = _tripController;
    final j = JourneysController.ensure().findByPlan(plan.planKey, date.value, people: people.value, forTripId: tripId);
    if (c != null && j != null && j.tripId == tripId) await c.releaseJourneyLink(j.id);
  }

  Future<void> saveJourney(WayPlan plan) async {
    if (busyPlans.contains(plan.planKey)) return;
    busyPlans.add(plan.planKey);
    try {
      final saved = await saveIfNeeded(plan);
      if (saved != null) TaxiWaysNavigation.openSavedJourney(saved.id);
    } finally {
      busyPlans.remove(plan.planKey);
    }
  }

  Future<bool> _linkToTrip(SavedJourney saved) async {
    final role = TripStepRole.values.firstWhereOrNull((r) => r.name == tripRole);
    if (role != null && Get.isRegistered<TripPlanController>() && TripPlanController.to.trip.value?.id == tripId) {
      final c = TripPlanController.to;
      c.linkJourney(role, saved);
      if (c.stepOf(role).journeyId == saved.id) {
        if (await c.flushPendingSave()) {
          AppToast.success(TripStringsStepsA1.savedToTrip);
        } else {
          AppToast.warning(TripStringsStepsK3.notSavedToTrip);
        }
        return true;
      }
    }
    AppToast.success(TripStringsStepsA1.savedToJourneys);
    return false;
  }

  Future<_SegmentLink> _linkSegment(
    BuildContext? context,
    SavedJourney saved,
    WayPlan plan, {
    bool replaceBooked = false,
  }) async {
    final c = _tripController;
    final k = tripLegIndex;
    if (c == null || k == null) {
      AppToast.success(TripStringsStepsA1.savedToJourneys);
      return _SegmentLink.plain;
    }
    final minutes = roadMinutesOf(plan);
    var r = await c.linkSegmentJourney(k, saved, replaceBooked: replaceBooked, roadMinutes: minutes);
    if (r == TripLinkResult.needsConfirm && context != null && context.mounted) {
      final booked = c.travelImpact(k).bookedRows;
      if (await TravelConfirmSheet.replaceTravel(context, booked)) {
        r = await c.linkSegmentJourney(k, saved, replaceBooked: true, roadMinutes: minutes);
      }
    }
    switch (r) {
      case TripLinkResult.saved:
        AppToast.success(TripStringsStepsA1.savedToTrip);
        return _SegmentLink.linked;
      case TripLinkResult.notSaved:
        AppToast.warning(TripStringsStepsK3.notSavedToTrip);
        await c.releaseJourneyLink(saved.id);
        return _SegmentLink.failed;
      case TripLinkResult.needsConfirm:
        await c.releaseJourneyLink(saved.id);
        return _SegmentLink.failed;
    }
  }

  Future<void> arrangedMyself() async {
    if (Get.isRegistered<TripPlanController>()) await TripPlanController.to.flushPendingSave();
    backToPlan();
  }

  void backToPlan() => Get.until((r) => r.settings.name == AppRoutes.tripPlan || r.isFirst);

  Future<void> useForTrip(WayPlan plan, {BuildContext? context}) async {
    if (busyPlans.contains(plan.planKey)) return;
    busyPlans.add(plan.planKey);
    try {
      var replaceBooked = false;
      if (forSegment) {
        final gate = await _segmentGate(context, plan);
        if (!gate.go) return;
        replaceBooked = gate.replaceBooked;
      }
      final saved = await saveIfNeeded(plan, quiet: true);
      if (saved == null) {
        if (forSegment) await _releaseUnsaved(plan);
        return;
      }
      if (forSegment) {
        final link = await _linkSegment(context, saved, plan, replaceBooked: replaceBooked);
        if (link == _SegmentLink.linked) {
          backToPlan();
        } else if (link == _SegmentLink.plain) {
          TaxiWaysNavigation.openSavedJourney(saved.id);
        }
        return;
      }
      if (await _linkToTrip(saved)) {
        backToPlan();
      } else {
        TaxiWaysNavigation.openSavedJourney(saved.id);
      }
    } finally {
      busyPlans.remove(plan.planKey);
    }
  }

  Future<void> askDrivers(BuildContext context, WayPlan plan) async {
    if (busyPlans.contains(plan.planKey)) return;
    busyPlans.add(plan.planKey);
    try {
      var replaceBooked = false;
      if (forSegment) {
        final gate = await _segmentGate(context, plan);
        if (!gate.go) return;
        replaceBooked = gate.replaceBooked;
      }
      final journey = await saveIfNeeded(plan, quiet: forTrip || forSegment);
      if (journey == null) {
        if (forSegment) await _releaseUnsaved(plan);
        return;
      }
      final bool linked;
      if (forSegment) {
        if (!context.mounted) {
          await _tripController?.releaseJourneyLink(journey.id);
          return;
        }
        final link = await _linkSegment(context, journey, plan, replaceBooked: replaceBooked);
        if (link == _SegmentLink.failed) return;
        linked = link == _SegmentLink.linked;
      } else {
        linked = forTrip && await _linkToTrip(journey);
      }
      if (!context.mounted) return;
      final res = await AskDriversSheet.show(
        context,
        plan: plan,
        chosen: chosenOf(plan.planKey),
        date: date.value,
        people: people.value,
        journeyId: journey.id,
        fromName: plan.from.name,
        toName: plan.to.name,
      );
      if (res == null) return;
      JourneysController.ensure().recordAsk(journey.id, res);
      if (linked) {
        final t = forSegment ? _tripController : null;
        if (t != null) unawaited(t.refreshEnquiries());
        backToPlan();
      } else {
        TaxiWaysNavigation.openSavedJourney(journey.id);
      }
    } finally {
      busyPlans.remove(plan.planKey);
    }
  }
}
