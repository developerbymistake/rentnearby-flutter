import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../trip/data/trip_segment_geometry_cache.dart';
import 'change_driver_sheet.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_repository.dart';
import 'taxi_ways_strings.dart';
import 'way_actions.dart';

class JourneyPlanController extends GetxController {
  JourneyPlanController(this.args, {TaxiWaysRepository repo = const TaxiWaysRepository()})
      : _repo = repo,
        plan = Rx<WayPlan>(args.plan),
        chosen = RxMap<int, WayDriver>(filledChosen(args.plan, args.chosen));

  final JourneyOpenArgs args;
  final TaxiWaysRepository _repo;
  final Rx<WayPlan> plan;
  final RxMap<int, WayDriver> chosen;
  final busy = <String>{}.obs;
  final loading = false.obs;
  final offline = false.obs;
  final refreshFailed = false.obs;
  final notFound = false.obs;

  late final WayActions actions = WayActions(
    tripId: args.tripId,
    tripRole: args.tripRole,
    tripLegIndex: args.tripLegIndex,
    date: () => args.date,
    people: () => args.people,
    chosenOf: (_) => Map<int, WayDriver>.from(chosen),
    busy: busy,
  );

  String get planKey => args.planKey;

  bool get isBusy => busy.contains(planKey);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  static Map<int, WayDriver> filledChosen(WayPlan plan, Map<int, WayDriver> current) {
    final out = Map<int, WayDriver>.from(current);
    for (final leg in plan.legs) {
      final all = leg.allDrivers;
      if (all.isEmpty) continue;
      final had = out[leg.index];
      if (had == null) {
        out[leg.index] = all.first;
      } else if (!had.hasContact) {
        final richer = all.firstWhereOrNull((d) => d.taxiId == had.taxiId && d.hasContact);
        if (richer != null) out[leg.index] = richer;
      }
    }
    return out;
  }

  static String carsChip(WayPlan p, Map<int, WayDriver> chosen, int people) {
    final total = p.totalWith(chosen, people: people);
    final cars = p.legs.isEmpty ? p.cars : p.legs.fold(0, (sum, l) => sum + l.carsWith(chosen[l.index], people));
    return cars <= 1 ? TaxiWaysStrings.oneCarTotal(total) : TaxiWaysStrings.carsAbout(cars, total);
  }

  Future<void> load() async {
    if (args.synthetic) return;
    loading.value = true;
    offline.value = false;
    refreshFailed.value = false;
    notFound.value = false;
    try {
      final shownFrom = plan.value.legs.isEmpty ? args.from : plan.value.from;
      final shownTo = plan.value.legs.isEmpty ? args.to : plan.value.to;
      final typedFrom = args.from.name.trim().isNotEmpty ? args.from : shownFrom;
      final typedTo = args.to.name.trim().isNotEmpty ? args.to : shownTo;
      var d = await _repo.plan(planKey,
          people: args.people, date: args.date, fromName: typedFrom.name, toName: typedTo.name);
      if (d.legs.isEmpty) throw StateError('empty plan');
      d = d.withEndNames(typedFrom, typedTo);
      TripSegmentGeometryCache.putPlan(d);
      plan.value = d;
      chosen.assignAll(filledChosen(d, chosen));
    } catch (e) {
      offline.value = DioErrorMapper.isNetworkError(e);
      notFound.value = DioErrorMapper.errorType(e) == 'PlanNotFound';
      refreshFailed.value = !offline.value;
    } finally {
      loading.value = false;
    }
  }

  void choose(int legIndex, WayDriver driver) => chosen[legIndex] = driver;

  void setChosen(Map<int, WayDriver> next) => chosen.assignAll(next);

  JourneyOpenArgs get currentArgs => args.withChosen(Map<int, WayDriver>.from(chosen));

  Future<void> changeDriver(BuildContext context, WayLeg leg) async {
    final picked = await ChangeDriverSheet.show(context, leg: leg, people: args.people, current: chosen[leg.index]);
    if (picked != null) choose(leg.index, picked);
  }

  Future<void> askDrivers(BuildContext context) => actions.askDrivers(context, plan.value);

  Future<void> useForTrip(BuildContext context) => actions.useForTrip(plan.value, context: context);

  Future<void> saveJourney() => actions.saveJourney(plan.value);
}
