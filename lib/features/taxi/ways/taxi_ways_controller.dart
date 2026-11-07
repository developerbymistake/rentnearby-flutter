import 'package:get/get.dart';
import '../../../models/place_result_model.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../trip/controllers/trip_plan_controller.dart';
import '../../trip/data/trip_segment_geometry_cache.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_repository.dart';
import 'way_actions.dart';

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
    this.fromTrip = false,
    this.fromStep,
  })  : from = Rx<PlaceResult>(from),
        to = Rx<PlaceResult>(to),
        fromMyLocation = (tripLegIndex == null && fromMyLocation).obs,
        datePassed = date != null,
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
  final bool fromTrip;
  final String? fromStep;
  final bool datePassed;

  late final WayActions actions = WayActions(
    tripId: tripId,
    tripRole: tripRole,
    tripLegIndex: tripLegIndex,
    fromStep: fromStep,
    date: () => date.value,
    people: () => people.value,
    chosenOf: chosenOf,
    busy: busyPlans,
  );

  bool get forTrip => actions.forTrip;

  bool get forSegment => actions.forSegment;

  bool get inTrip => fromTrip || forSegment;

  bool get lockedEnds => inTrip;

  bool get lockedDate => inTrip && datePassed;

  bool get lockedPeople => inTrip;

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
  final errorText = ''.obs;
  final isOffline = false.obs;
  final tabOff = false.obs;
  final sort = WaysSort.fewestCars.obs;
  final chosen = <String, Map<int, WayDriver>>{}.obs;
  final busyPlans = <String>{}.obs;

  final _repo = const TaxiWaysRepository();
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
    errorText.value = '';
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
      if (result.value == null) {
        loadFailed.value = true;
        if (!isOffline.value) {
          errorText.value =
              DioErrorMapper.toMessage(e, '', showRawMessageForStatusCodes: const {400, 404, 409, 429});
        }
      }
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
    if (lockedPeople) return;
    final v = n.clamp(1, maxPeople).toInt();
    if (v == people.value) return;
    people.value = v;
    load();
  }

  void setSort(WaysSort s) => sort.value = s;

  WayPlan singlePlan(List<WayDriver> drivers) {
    final r = result.value;
    final f = r?.from ?? _placeOf(from.value);
    final t = r?.to ?? _placeOf(to.value);
    final plan = WayPlan.single(f, t, drivers);
    if (drivers.isNotEmpty) choose(plan.planKey, 1, drivers.first);
    return plan;
  }

  static WayPlace _placeOf(PlaceResult p) =>
      WayPlace(key: '', name: p.name, lat: p.latLng.latitude, lng: p.latLng.longitude, resolved: false);

  JourneyOpenArgs openArgs(WayPlan plan, {bool synthetic = false}) {
    final r = result.value;
    return JourneyOpenArgs(
      plan: plan,
      planKey: plan.planKey,
      from: r != null && r.from.name.isNotEmpty ? r.from : _placeOf(from.value),
      to: r != null && r.to.name.isNotEmpty ? r.to : _placeOf(to.value),
      date: date.value,
      people: people.value,
      tripId: tripId,
      tripRole: tripRole,
      tripLegIndex: tripLegIndex,
      chosen: Map.unmodifiable(chosenOf(plan.planKey)),
      fromStep: fromStep,
      synthetic: synthetic,
      fromMyLocation: fromMyLocation.value,
    );
  }

  Map<int, WayDriver> chosenOf(String planKey) => chosen[planKey] ?? const {};

  WayDriver? chosenFor(String planKey, int legIndex) => chosen[planKey]?[legIndex];

  void choose(String planKey, int legIndex, WayDriver driver) {
    final current = Map<int, WayDriver>.from(chosen[planKey] ?? const {});
    current[legIndex] = driver;
    chosen[planKey] = current;
  }
}
