import 'package:get/get.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/plan_controller.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_api.dart';
import '../../owner_core/data/owner_cache.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_json.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../taxi/models/taxi_owner_model.dart';

class ChooseRouteState {
  const ChooseRouteState({required this.routes, required this.visibleIds, required this.limit, this.paymentEnabled = true, this.limitFromServer = false});

  static const String routesKey = 'Routes';

  final List<TaxiRouteModel> routes;
  final List<String> visibleIds;
  final int limit;
  final bool paymentEnabled;
  final bool limitFromServer;

  int get target => routes.length < limit ? routes.length : limit;
  bool get somethingHidden => routes.length > visibleIds.length;

  // The answer carries the plan meters (doc 6.6 rule 4); the local plan is only a fallback for an old server.
  factory ChooseRouteState.fromJson(Map<String, dynamic> j, {required int limit, bool paymentOn = true}) {
    final served = Meter.maybe(j['routesMeter'])?.limit ?? Meter.find(Meter.listOf(j['meters']), routesKey)?.limit;
    final payment = OwnerJson.boolOrNull(j['paymentEnabled']) ?? paymentOn;
    final l = served ?? limit;
    final visible = OwnerJson.list(j['routes'], TaxiRouteModel.fromJson).where((r) => r.id.isNotEmpty).toList()
      ..sort((a, b) => a.routeIndex.compareTo(b.routeIndex));
    final hidden = OwnerJson.list(j['hiddenRoutes'], TaxiRouteModel.fromJson).where((r) => r.id.isNotEmpty).toList()
      ..sort((a, b) => a.routeIndex.compareTo(b.routeIndex));
    final seen = <String>{};
    final all = [for (final r in [...visible, ...hidden]) if (seen.add(r.id)) r];
    return ChooseRouteState(
      routes: all,
      visibleIds: [for (final r in visible) r.id],
      limit: l < 1 ? 1 : l,
      paymentEnabled: payment,
      limitFromServer: served != null,
    );
  }
}

class ChooseRouteApi {
  const ChooseRouteApi();

  Future<OwnerResult<Map<String, dynamic>>> load() => OwnerApi.get('/taxis/me', (j) => j);

  Future<OwnerResult<Map<String, dynamic>>> save(List<String> routeIds) => OwnerApi.put('/taxis/me/plan-visible', {'routeIds': routeIds}, (j) => j);
}

enum ChooseRouteSave { done, nothingToSave, limit, invalid, notNeeded, offline, failed, rateLimited }

class ChooseRouteController extends GetxController {
  ChooseRouteController({this.api = const ChooseRouteApi(), String? Function()? userId}) : _userId = userId; // ignore: prefer_initializing_formals

  static const String tag = 'taxi-plan-visible';

  final ChooseRouteApi api;
  final String? Function()? _userId;
  final load = Rx<OwnerLoad<ChooseRouteState>>(const OwnerLoadLoading());
  final selected = <String>[].obs;
  final limitLine = RxnString();
  bool paymentOff = false;
  final LatestOnly _latest = LatestOnly();
  final SingleFlight<OwnerResult<Map<String, dynamic>>> _save = SingleFlight();
  List<String> _start = const [];

  String? get _uid => _userId != null ? _userId() : (Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null);

  ChooseRouteState? get state => load.value.valueOrNull;
  bool get stale => switch (load.value) {
        OwnerLoadData(:final stale) => stale,
        _ => false,
      };

  bool get dirty => selected.join(',') != _start.join(',');

  bool get ready {
    final s = state;
    return s != null && !stale && s.routes.isNotEmpty && selected.length == s.target;
  }

  int get _limit => PlanGate.limit(PlanKey.routes);

  Future<void> fetch() async {
    final id = _latest.next();
    final r = await api.load();
    if (isClosed || !_latest.isLatest(id)) return;
    if (r is OwnerOk<Map<String, dynamic>>) {
      OwnerCache.write(_uid, OwnerCacheKeys.listing, r.value);
      final s = ChooseRouteState.fromJson(r.value, limit: _limit, paymentOn: PlanGate.paymentOn);
      if (s.limitFromServer && s.limit != _limit && Get.isRegistered<PlanController>()) Get.find<PlanController>().invalidate().ignore();
      _apply(s);
      return;
    }
    final raw = OwnerCache.read(_uid, OwnerCacheKeys.listing);
    final saved = raw == null ? null : ChooseRouteState.fromJson(raw, limit: _limit, paymentOn: PlanGate.paymentOn);
    if (saved != null && saved.somethingHidden && r is OwnerOffline<Map<String, dynamic>>) {
      _start = _ordered(saved, saved.visibleIds);
      selected.assignAll(_start);
      load.value = OwnerLoadData(saved, stale: true);
      return;
    }
    load.value = OwnerLoads.from<ChooseRouteState>(switch (r) {
      OwnerRefused() => r.cast<ChooseRouteState>(),
      OwnerOffline() => OwnerOffline<ChooseRouteState>(),
      OwnerFailed(:final message) => OwnerFailed<ChooseRouteState>(message: message),
      OwnerOk() => OwnerFailed<ChooseRouteState>(message: ''),
    });
  }

  void _apply(ChooseRouteState s) {
    paymentOff = !s.paymentEnabled;
    if (!s.somethingHidden || paymentOff) {
      load.value = const OwnerLoadEmpty();
      return;
    }
    _start = _ordered(s, s.visibleIds.take(s.target).toList());
    selected.assignAll(_start);
    load.value = OwnerLoadData(s);
  }

  List<String> _ordered(ChooseRouteState s, List<String> ids) {
    final order = [for (final r in s.routes) r.id];
    return ids.where(order.contains).toList()..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
  }

  void toggle(String id) {
    final s = state;
    if (s == null || stale) return;
    if (s.target <= 1) {
      selected.assignAll([id]);
      return;
    }
    if (selected.contains(id)) {
      selected.remove(id);
    } else if (selected.length < s.target) {
      selected.assignAll(_ordered(s, [...selected, id]));
    }
  }

  Future<ChooseRouteSave> save() async {
    final s = state;
    if (s == null || !ready) return ChooseRouteSave.failed;
    if (!dirty) return ChooseRouteSave.nothingToSave;
    limitLine.value = null;
    final r = await _save.run(() => api.save(selected.toList()));
    if (isClosed) return ChooseRouteSave.failed;
    switch (r) {
      case OwnerOk<Map<String, dynamic>>(:final value):
        if (value.containsKey('routes') || value.containsKey('hiddenRoutes')) {
          final next = ChooseRouteState.fromJson(value, limit: s.limit, paymentOn: s.paymentEnabled);
          _start = _ordered(next, next.visibleIds);
          selected.assignAll(_start);
          load.value = OwnerLoadData(next);
        } else {
          _start = selected.toList();
        }
        return ChooseRouteSave.done;
      case OwnerRefused<Map<String, dynamic>>():
        if (r.rateLimited) return ChooseRouteSave.rateLimited;
        switch (r.type) {
          case OwnerErrorTypes.planVisibleLimit:
            limitLine.value = r.message ?? '';
            return ChooseRouteSave.limit;
          case OwnerErrorTypes.planVisibleNotNeeded:
            load.value = const OwnerLoadEmpty();
            return ChooseRouteSave.notNeeded;
          case OwnerErrorTypes.planVisibleInvalid:
            await fetch();
            return ChooseRouteSave.invalid;
        }
        return ChooseRouteSave.failed;
      case OwnerOffline<Map<String, dynamic>>():
        return ChooseRouteSave.offline;
      case OwnerFailed<Map<String, dynamic>>():
        return ChooseRouteSave.failed;
    }
  }

  @override
  void onClose() {
    _latest.cancel();
    super.onClose();
  }
}
