import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../buddy_error_types.dart';
import '../../buddy_live.dart';
import '../../shared/buddy_result.dart';
import '../../shared/models/person_models.dart';
import '../../shared/strings_shared.dart';
import '../data/expense_list_cache.dart';
import '../data/expense_write_gateway.dart';
import '../data/expenses_api.dart';
import '../expense_deps.dart';
import '../models/expense_models.dart';
import 'trip_expenses_controller.dart';

enum DetailLoad { loading, ready, gone, failed }

enum DeleteEnd { none, deleted, queued, needsAck, conflict, frozen, gone }

class ExpenseDetailController extends GetxController {
  ExpenseDetailController(this.tripId, this.expenseId, {this._api, this._gateway, ExpenseDetailPage? initial, ExpenseList? context}) {
    if (initial != null) {
      page.value = initial;
      status.value = DetailLoad.ready;
    }
    if (context != null) trip.value = context;
  }

  final String tripId;
  final String expenseId;
  final ExpensesApi? _api;
  final ExpenseWriteGateway? _gateway;
  final Rx<ExpenseDetailPage?> page = Rx<ExpenseDetailPage?>(null);
  final Rx<ExpenseList?> trip = Rx<ExpenseList?>(null);
  final Rx<DetailLoad> status = DetailLoad.loading.obs;
  final RxBool deleting = false.obs;
  Worker? _worker;
  Future<void>? _loading;

  ExpensesApi get api => _api ?? ExpenseDeps.api;
  ExpenseWriteGateway get gateway => _gateway ?? ExpenseWriteGateway.to;

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

  bool get frozen => trip.value?.frozen ?? false;
  bool get deleted => page.value?.expense.deleted ?? false;
  bool get canEdit => (page.value?.canEdit ?? false) && !frozen && !deleted;
  bool get canDelete => (page.value?.canDelete ?? false) && !frozen && !deleted;

  List<MoneyPerson> get people {
    final p = page.value?.people ?? const <MoneyPerson>[];
    final t = trip.value?.travellers ?? const <MoneyPerson>[];
    final known = t.map((x) => x.userId).toSet();
    return [...t, ...p.where((x) => !known.contains(x.userId))];
  }

  MoneyPerson? person(String? id) {
    for (final p in people) {
      if (p.userId == id) return p;
    }
    return null;
  }

  Future<void> reload() => _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    final results = await Future.wait<Object>([api.detail(tripId, expenseId), _context()]);
    if (isClosed) return;
    final r = results.first as BuddyResult<ExpenseDetailPage>;
    switch (r) {
      case BuddyOk<ExpenseDetailPage>(:final value):
        page.value = value;
        status.value = DetailLoad.ready;
      case BuddyRefused<ExpenseDetailPage>(:final type)
          when type == BuddyErrorTypes.expenseNotFound || type == BuddyErrorTypes.tripNotFound || type == BuddyErrorTypes.notOnTrip:
        status.value = DetailLoad.gone;
      default:
        if (page.value == null) status.value = DetailLoad.failed;
    }
  }

  Future<Object> _context() async {
    final known = TripExpensesController.maybeOf(tripId)?.list.value ?? trip.value;
    if (known != null) {
      trip.value = known;
      return known;
    }
    final cached = ExpenseListCache.read(tripId);
    if (cached != null) trip.value = cached;
    final r = await api.list(tripId, limit: 1);
    if (r is BuddyOk<ExpenseList> && !isClosed) trip.value = r.value;
    return r;
  }

  ExpenseItem _shown(ExpenseDetail e) => ExpenseItem(
        id: e.id,
        title: e.title,
        category: e.category,
        amount: e.amount,
        dayNumber: e.dayNumber,
        paidByUserId: e.paidByUserId,
        sharedBy: e.shares.length,
        myShare: e.shares.where((s) => person(s.userId)?.isMe ?? false).fold(0, (a, s) => a + s.share),
        version: e.version,
        edited: e.editedTimes > 0,
        linkKind: e.link?.kind,
        linkId: e.link?.id,
      );

  Future<DeleteEnd> delete({required bool ack}) async {
    final p = page.value;
    if (p == null || deleting.value) return DeleteEnd.none;
    deleting.value = true;
    try {
      final e = p.expense;
      final out = await gateway.delete(
        tripId: tripId,
        expenseId: expenseId,
        baseVersion: e.version,
        opId: const Uuid().v4(),
        paymentsAcknowledged: ack,
        shown: _shown(e),
      );
      if (isClosed) return DeleteEnd.none;
      switch (out) {
        case ExpenseDeleted() || ExpenseSaved():
          BuddyLive.expenses(tripId).value++;
          return DeleteEnd.deleted;
        case ExpenseQueued():
          return DeleteEnd.queued;
        case ExpenseWriteFailed(:final isOffline):
          isOffline ? ExpenseDeps.offline() : ExpenseDeps.toast(BuddySharedStrings.somethingWrong);
          return DeleteEnd.none;
        case ExpenseRefused(:final error):
          if (error.rateLimited) {
            ExpenseDeps.toast(BuddySharedStrings.tooManyTries);
            return DeleteEnd.none;
          }
          switch (error.type) {
            case BuddyErrorTypes.paymentsNotAcknowledged:
              return DeleteEnd.needsAck;
            case BuddyErrorTypes.expenseVersionConflict:
              return DeleteEnd.conflict;
            case BuddyErrorTypes.tripExpensesFrozen:
              return DeleteEnd.frozen;
            case BuddyErrorTypes.expenseNotFound:
              BuddyLive.expenses(tripId).value++;
              return DeleteEnd.gone;
            default:
              ExpenseDeps.toast(error.message ?? BuddySharedStrings.somethingWrong);
              return DeleteEnd.none;
          }
      }
    } finally {
      if (!isClosed) deleting.value = false;
    }
  }
}
