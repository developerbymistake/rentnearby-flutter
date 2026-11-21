import 'package:get/get.dart';

import '../../../controllers/auth_controller.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_cache.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../calendar/data/stay_calendar_apis.dart';
import '../calendar/models/stay_calendar_models.dart';
import '../home/stay_owner_home_controller.dart';
import '../stay_owner_deps.dart';

abstract final class StaySpecialPriceMemory {
  static int? lastPercent;

  static void reset() => lastPercent = null;
}

class StaySpecialPricesController extends GetxController {
  StaySpecialPricesController({this.api = const StaySpecialPriceApi(), DateTime Function()? clock, this.userIdOf, this.listingNameOf})
      : _clock = clock ?? DateTime.now;

  static const String tag = 'stay-special-prices';
  static const String meterKey = 'SpecialPrices';
  static const int festivalDays = 180;

  final StaySpecialPriceApi api;
  final DateTime Function() _clock;
  final String? Function()? userIdOf;
  final String Function()? listingNameOf;

  final load = Rx<OwnerLoad<StaySpecialPricesPage>>(const OwnerLoadLoading());
  final festivals = <FestivalRow>[].obs;
  final busyIds = <String>{}.obs;

  final LatestOnly _latest = LatestOnly();
  final SingleFlight<OwnerResult<Map<String, dynamic>>> _save = SingleFlight();

  DateTime get today => OwnerDates.only(_clock());

  String? get userId {
    final f = userIdOf;
    if (f != null) return f();
    return Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null;
  }

  String get listingName {
    final f = listingNameOf;
    if (f != null) return f();
    return StayOwnerHomeController.maybe?.data?.listing.name ?? '';
  }

  StaySpecialPricesPage? get page => load.value.valueOrNull;

  List<SpecialPriceBand> get rules => page?.items ?? const [];

  Meter? get meter => page == null ? null : Meter.find(page?.meters ?? const [], meterKey);

  bool get plus => PlanGate.paymentOn && !PlanGate.canUpgrade;

  bool get needsG12 {
    final m = meter;
    if (m == null || m.limit <= 0) return PlanGate.locks(PlanKey.specialPrices, rules.length);
    return PlanGate.canUpgrade && m.full;
  }

  DateTime? get soonestEnd {
    DateTime? best;
    for (final r in rules) {
      final t = r.dateTo;
      if (t == null || t.isBefore(today)) continue;
      if (best == null || t.isBefore(best)) best = t;
    }
    return best;
  }

  @override
  void onInit() {
    super.onInit();
    final raw = OwnerCache.read(userId, OwnerCacheKeys.specialPrices);
    if (raw != null) load.value = OwnerLoadData(StaySpecialPricesPage.fromJson(raw), stale: true);
  }

  Future<void> fetch() async {
    final id = _latest.next();
    if (page == null) load.value = const OwnerLoadLoading();
    final r = await api.list();
    if (isClosed || !_latest.isLatest(id)) return;
    if (r is OwnerOk<StaySpecialPricesPage>) {
      load.value = OwnerLoadData(r.value);
      OwnerCache.write(userId, OwnerCacheKeys.specialPrices, r.value.raw);
      _festivals(r.value.stateName);
      return;
    }
    load.value = OwnerLoads.from<StaySpecialPricesPage>(r, saved: page);
  }

  Future<void> _festivals(String? stateName) async {
    final t = today;
    final rows = await api.festivals(userId: userId, stateName: stateName, from: t, to: OwnerDates.addDays(t, festivalDays));
    if (isClosed) return;
    festivals.assignAll(rows.where((f) {
      final end = f.dateTo;
      final start = f.dateFrom;
      return end != null && start != null && !end.isBefore(t) && !start.isAfter(OwnerDates.addDays(t, festivalDays));
    }));
  }

  SpecialPriceBand? ruleFor(DateTime from, DateTime to) {
    for (final r in rules) {
      final f = r.dateFrom;
      final t = r.dateTo;
      if (f != null && t != null && OwnerDates.sameDay(f, from) && OwnerDates.sameDay(t, to)) return r;
    }
    return null;
  }

  SpecialPriceBand? overlapping(DateTime from, DateTime to, {String? exceptId}) {
    for (final r in rules) {
      if (r.id == exceptId) continue;
      final f = r.dateFrom;
      final t = r.dateTo;
      if (f == null || t == null) continue;
      if (!f.isAfter(to) && !t.isBefore(from)) return r;
    }
    return null;
  }

  Future<OwnerResult<Map<String, dynamic>>> save(StaySpecialPriceDraft d, {required bool edit}) async {
    final r = await _save.run(() => edit ? api.update(d) : api.create(d));
    if (isClosed) return r;
    if (r is OwnerOk<Map<String, dynamic>>) {
      StaySpecialPriceMemory.lastPercent = d.percent;
      await fetch();
      StayOwnerDeps.refreshHome();
    }
    return r;
  }

  Future<OwnerResult<dynamic>> toggle(SpecialPriceBand r) async {
    if (busyIds.contains(r.id)) return const OwnerOk<void>(null);
    busyIds.add(r.id);
    try {
      final res = r.pausedByPlan ? await api.live(r.id, version: r.version) : await api.pause(r.id, paused: !r.isPaused, version: r.version);
      if (isClosed) return res;
      await fetch();
      return res;
    } finally {
      if (!isClosed) busyIds.remove(r.id);
    }
  }

  Future<OwnerResult<void>> delete(SpecialPriceBand r) async {
    busyIds.add(r.id);
    try {
      final res = await api.delete(r.id);
      if (isClosed) return res;
      if (res is OwnerOk<void>) {
        await fetch();
        StayOwnerDeps.refreshHome();
      }
      return res;
    } finally {
      if (!isClosed) busyIds.remove(r.id);
    }
  }

  @override
  void onClose() {
    _latest.cancel();
    super.onClose();
  }
}
