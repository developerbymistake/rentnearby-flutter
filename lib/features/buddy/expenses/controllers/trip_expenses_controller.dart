import 'package:get/get.dart';

import '../../buddy_error_types.dart';
import '../../buddy_live.dart';
import '../../shared/buddy_result.dart';
import '../../shared/models/person_models.dart';
import '../data/expense_list_cache.dart';
import '../data/expenses_api.dart';
import '../expense_deps.dart';
import '../expense_strings.dart';
import '../models/expense_models.dart';

enum ExpenseLoad { loading, ready, failed, gone }

class TripExpensesController extends GetxController {
  TripExpensesController(this.tripId, {this._api, ExpenseList? initial}) {
    if (initial != null) _apply(initial);
  }

  final String tripId;
  final ExpensesApi? _api;
  final Rx<ExpenseList?> list = Rx<ExpenseList?>(null);
  final RxList<ExpenseItem> items = <ExpenseItem>[].obs;
  final Rx<ExpenseLoad> status = ExpenseLoad.loading.obs;
  final RxBool expanded = false.obs;
  final RxBool loadingMore = false.obs;
  final RxInt tab = 0.obs;
  final RxSet<String> skipped = <String>{}.obs;
  final RxBool skipping = false.obs;
  final RxBool fromCache = false.obs;
  bool latePromptHandled = false;
  bool formerHandled = false;
  String? _cursor;
  Worker? _worker;
  Future<void>? _loading;

  ExpensesApi get api => _api ?? ExpenseDeps.api;

  static TripExpensesController? maybeOf(String tripId) =>
      Get.isRegistered<TripExpensesController>(tag: tripId) ? Get.find<TripExpensesController>(tag: tripId) : null;

  @override
  void onInit() {
    super.onInit();
    _worker = ever(BuddyLive.expenses(tripId), (_) => reload());
  }

  @override
  void onClose() {
    _worker?.dispose();
    super.onClose();
  }

  bool get isOwner => list.value?.isOwner ?? false;
  bool get frozen => list.value?.frozen ?? false;
  bool get canAdd => isOwner && !frozen;
  bool get hasMore => _cursor != null;

  List<MoneyPerson> get travellers => list.value?.travellers ?? const [];

  int get currentTravellers => travellers.where((p) => !p.isFormer && !p.isDeleted).length;

  ExpenseSuggestion? get suggestion {
    final l = list.value;
    if (l == null || !canAdd) return null;
    for (final s in l.suggestions) {
      if (!skipped.contains(s.sourceId)) return s;
    }
    return null;
  }

  String headerLine() {
    final l = list.value;
    if (l == null) return '';
    if (!l.isOwner) return ExpenseStrings.headerViewer(l.tripTitle, l.ownerName);
    final end = l.endDate;
    if (l.tripEnded && end != null) return ExpenseStrings.headerEnded(l.tripTitle, end);
    return ExpenseStrings.headerOwner(l.tripTitle, l.dayToday);
  }

  void _apply(ExpenseList value) {
    list.value = value;
    items.assignAll(value.items);
    _cursor = value.nextCursor;
    BuddyLive.seenBalancesVersion(tripId, value.balancesVersion);
    status.value = ExpenseLoad.ready;
  }

  Future<void> reload() => _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    final r = await api.list(tripId);
    if (isClosed) return;
    switch (r) {
      case BuddyOk<ExpenseList>(:final value):
        fromCache.value = false;
        _apply(value);
        if (value.isOwner) ExpenseListCache.save(value);
        if (expanded.value) await _loadRest();
      case BuddyRefused<ExpenseList>(:final type) when type == BuddyErrorTypes.tripNotFound || type == BuddyErrorTypes.notOnTrip:
        status.value = ExpenseLoad.gone;
      case BuddyOffline<ExpenseList>():
        if (list.value == null) {
          final cached = ExpenseListCache.read(tripId);
          if (cached != null) {
            _apply(cached);
            fromCache.value = true;
          } else {
            status.value = ExpenseLoad.failed;
          }
        }
      default:
        if (list.value == null) status.value = ExpenseLoad.failed;
    }
  }

  Future<void> _loadRest() async {
    while (_cursor != null && !isClosed) {
      final r = await api.list(tripId, cursor: _cursor);
      if (r is! BuddyOk<ExpenseList>) return;
      final known = items.map((i) => i.id).toSet();
      items.addAll(r.value.items.where((i) => !known.contains(i.id)));
      _cursor = r.value.nextCursor;
    }
  }

  Future<void> showAll() async {
    expanded.value = true;
    if (_cursor == null || loadingMore.value) return;
    loadingMore.value = true;
    try {
      await _loadRest();
    } finally {
      loadingMore.value = false;
    }
  }

  Future<void> skipSuggestion(ExpenseSuggestion s) async {
    if (skipping.value) return;
    skipping.value = true;
    try {
      final r = await api.skipSuggestion(tripId, kind: s.kind, sourceId: s.sourceId);
      if (isClosed) return;
      switch (r) {
        case BuddyOk<void>():
          skipped.add(s.sourceId);
        case BuddyOffline<void>():
          ExpenseDeps.offline();
        case BuddyRefused<void>(:final type) when type == BuddyErrorTypes.tripExpensesFrozen:
          ExpenseDeps.toast(ExpenseStrings.frozenToast);
          await reload();
        case BuddyRefused<void>(:final rateLimited) when rateLimited:
          ExpenseDeps.toast(ExpenseStrings.tryAgainLater);
        default:
          skipped.add(s.sourceId);
      }
    } finally {
      skipping.value = false;
    }
  }

  Future<bool> keepLate(String userId) async {
    final r = await api.keepLateJoin(tripId, userId);
    if (isClosed) return false;
    switch (r) {
      case BuddyOk<void>():
        await reload();
        return true;
      case BuddyOffline<void>():
        ExpenseDeps.offline();
      case BuddyRefused<void>(:final type) when type == BuddyErrorTypes.tripExpensesFrozen:
        ExpenseDeps.toast(ExpenseStrings.frozenToast);
        await reload();
      default:
        await reload();
    }
    return false;
  }
}
