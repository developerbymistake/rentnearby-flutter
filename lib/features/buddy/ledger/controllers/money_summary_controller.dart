import 'package:get/get.dart';

import '../../buddy_live.dart';
import '../../shared/buddy_result.dart';
import '../ledger_deps.dart';
import '../models/ledger_models.dart';
import 'trip_balances_controller.dart';

class MoneySummaryController extends GetxController {
  MoneySummaryController(this.tripId);

  final String tripId;
  final Rx<ExpenseSummary?> summary = Rx<ExpenseSummary?>(null);
  final Rx<LedgerLoad> status = LedgerLoad.loading.obs;
  Future<void>? _loading;
  Worker? _live;

  static final Map<String, int> _users = {};

  static String _tag(String tripId) => 'summary:$tripId';

  static MoneySummaryController of(String tripId) => Get.isRegistered<MoneySummaryController>(tag: _tag(tripId))
      ? Get.find<MoneySummaryController>(tag: _tag(tripId))
      : Get.put(MoneySummaryController(tripId), tag: _tag(tripId));

  static MoneySummaryController acquire(String tripId) {
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
    if (Get.isRegistered<MoneySummaryController>(tag: _tag(tripId))) Get.delete<MoneySummaryController>(tag: _tag(tripId));
  }

  @override
  void onInit() {
    super.onInit();
    _live = ever(BuddyLive.expenses(tripId), (_) => reload());
    reload();
  }

  @override
  void onClose() {
    _live?.dispose();
    super.onClose();
  }

  Future<void> reload() => _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    if (summary.value == null) status.value = LedgerLoad.loading;
    final r = await LedgerDeps.api.summary(tripId);
    if (isClosed) return;
    switch (r) {
      case BuddyOk(:final value):
        summary.value = value;
        status.value = LedgerLoad.ready;
      case BuddyRefused(:final statusCode) when statusCode == 404 || statusCode == 403:
        status.value = LedgerLoad.gone;
      default:
        if (summary.value == null) status.value = LedgerLoad.failed;
    }
  }
}
