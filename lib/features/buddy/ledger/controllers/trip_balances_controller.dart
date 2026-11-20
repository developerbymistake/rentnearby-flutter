import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../buddy_live.dart';
import '../../shared/buddy_result.dart';
import '../ledger_deps.dart';
import '../ledger_rules.dart';
import '../models/ledger_models.dart';

enum LedgerLoad { loading, ready, failed, gone }

class TripBalancesController extends GetxController with WidgetsBindingObserver {
  TripBalancesController(this.tripId);

  final String tripId;
  final Rx<TripBalances?> balances = Rx<TripBalances?>(null);
  final Rx<LedgerLoad> status = LedgerLoad.loading.obs;
  final RxBool offline = false.obs;
  final RxSet<String> changed = <String>{}.obs;
  final Rx<LedgerRace> race = LedgerRace.none.obs;
  final RxSet<String> busy = <String>{}.obs;
  final RxSet<String> reminded = <String>{}.obs;
  final Map<String, String> _opIds = {};
  Future<void>? _loading;
  bool _keepMarks = false;
  Worker? _live;

  static final Map<String, int> _users = {};

  static TripBalancesController of(String tripId) =>
      Get.isRegistered<TripBalancesController>(tag: tripId) ? Get.find<TripBalancesController>(tag: tripId) : Get.put(TripBalancesController(tripId), tag: tripId);

  static TripBalancesController? maybeOf(String tripId) =>
      Get.isRegistered<TripBalancesController>(tag: tripId) ? Get.find<TripBalancesController>(tag: tripId) : null;

  static TripBalancesController acquire(String tripId) {
    _users[tripId] = (_users[tripId] ?? 0) + 1;
    return of(tripId);
  }

  static void release(String tripId) {
    final n = (_users[tripId] ?? 1) - 1;
    if (n > 0) {
      _users[tripId] = n;
      return;
    }
    _users.remove(tripId);
    if (Get.isRegistered<TripBalancesController>(tag: tripId)) Get.delete<TripBalancesController>(tag: tripId);
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _live = ever(BuddyLive.expenses(tripId), (_) => reload());
    reload();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _live?.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  Future<void> reload() => _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> reloadFresh() async {
    final running = _loading;
    if (running != null) {
      final keep = _keepMarks;
      await running;
      _keepMarks = keep;
    }
    return reload();
  }

  Future<void> _load() async {
    if (balances.value == null) status.value = LedgerLoad.loading;
    final r = await LedgerDeps.api.balances(tripId);
    if (isClosed) return;
    switch (r) {
      case BuddyOk(:final value):
        balances.value = value;
        BuddyLive.seenBalancesVersion(tripId, value.balancesVersion);
        offline.value = false;
        status.value = LedgerLoad.ready;
        if (_keepMarks) {
          _keepMarks = false;
        } else {
          changed.clear();
          race.value = LedgerRace.none;
        }
      case BuddyRefused(:final statusCode):
        if (statusCode == 404 || statusCode == 403) {
          status.value = LedgerLoad.gone;
        } else if (balances.value == null) {
          status.value = LedgerLoad.failed;
        }
      case BuddyOffline():
        offline.value = true;
        if (balances.value == null) status.value = LedgerLoad.failed;
      case BuddyFailed():
        if (balances.value == null) status.value = LedgerLoad.failed;
    }
  }

  bool begin(String key) {
    if (busy.contains(key)) return false;
    busy.add(key);
    return true;
  }

  void end(String key) => busy.remove(key);

  bool isBusy(PaymentRow r) => busy.contains(LedgerRules.rowKey(r));

  String opIdFor(PaymentRow r) => _opIds.putIfAbsent('${LedgerRules.rowKey(r)}#${r.amount}', LedgerDeps.newOpId);

  void dropOpId(PaymentRow r) => _opIds.remove('${LedgerRules.rowKey(r)}#${r.amount}');

  void markChanged(PaymentRow r) {
    changed.add(LedgerRules.rowKey(r));
    _keepMarks = true;
  }

  void markRace(LedgerRace value) {
    race.value = value;
    _keepMarks = true;
  }

  void clearMarks() {
    changed.clear();
    race.value = LedgerRace.none;
  }

  bool reminderOff(PaymentRow r) => r.reminderSentToday || reminded.contains(LedgerRules.rowKey(r));
}
