import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../utils/app_toast.dart';
import '../../buddy_error_types.dart';
import '../../buddy_live.dart';
import '../../expenses/data/expenses_api.dart';
import '../../expenses/models/expense_models.dart';
import '../../ledger/data/ledger_api.dart';
import '../../ledger/models/ledger_models.dart';
import '../../shared/buddy_result.dart';
import '../../shared/models/person_models.dart';
import '../../shared/strings_shared.dart';
import '../viewer_deps.dart';

enum FormerShareState { loading, ready, gone, failed }

class FormerShareController extends GetxController {
  FormerShareController(this.tripId, {ExpensesApi? expenses, LedgerApi? ledger})
      : _expenses = expenses ?? ViewerDeps.expenses,
        _ledger = ledger ?? ViewerDeps.ledger;

  final String tripId;
  final ExpensesApi _expenses;
  final LedgerApi _ledger;

  final state = FormerShareState.loading.obs;
  final list = Rxn<ExpenseList>();
  final balances = Rxn<TripBalances>();
  final busy = <String>{}.obs;
  int _seq = 0;
  Worker? _worker;

  @override
  void onInit() {
    super.onInit();
    _worker = ever<int>(BuddyLive.expenses(tripId), (_) => load());
    load();
  }

  @override
  void onClose() {
    _worker?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final seq = ++_seq;
    if (list.value == null) state.value = FormerShareState.loading;
    final results = await Future.wait<BuddyResult<Object?>>([_expenses.list(tripId), _ledger.balances(tripId)]);
    if (seq != _seq || isClosed) return;
    final e = results[0];
    final b = results[1];
    if (_gone(e) || _gone(b)) {
      state.value = FormerShareState.gone;
      return;
    }
    if (e is BuddyOk<Object?> && b is BuddyOk<Object?>) {
      list.value = e.value as ExpenseList;
      final bal = b.value as TripBalances;
      balances.value = bal;
      BuddyLive.seenBalancesVersion(tripId, bal.balancesVersion);
      state.value = FormerShareState.ready;
    } else if (list.value == null) {
      state.value = FormerShareState.failed;
    }
  }

  static bool _gone(BuddyResult<Object?> r) =>
      r is BuddyRefused<Object?> && (r.type == BuddyErrorTypes.tripNotFound || r.statusCode == 404);

  MoneyPerson? person(String userId) {
    final b = balances.value?.person(userId);
    if (b != null) return b;
    for (final p in list.value?.travellers ?? const <MoneyPerson>[]) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  String? get myId {
    for (final p in balances.value?.people ?? const <BalancePerson>[]) {
      if (p.person.isMe) return p.person.userId;
    }
    for (final p in list.value?.travellers ?? const <MoneyPerson>[]) {
      if (p.isMe) return p.userId;
    }
    return null;
  }

  List<PaymentRow> get myRows {
    final me = myId;
    return [for (final p in balances.value?.payments ?? const <PaymentRow>[]) if (p.fromUserId == me || p.toUserId == me) p];
  }

  static String rowKey(PaymentRow r) => r.paymentId ?? '${r.fromUserId}>${r.toUserId}';

  Future<bool> sayPaid(PaymentRow row) => _write(row, () => _ledger.saidPaid(tripId, opId: const Uuid().v4(), toUserId: row.toUserId, amount: row.amount));

  Future<bool> withdraw(PaymentRow row) {
    final id = row.paymentId;
    if (id == null) return Future.value(false);
    return _write(row, () => _ledger.withdraw(tripId, id));
  }

  Future<bool> _write(PaymentRow row, Future<BuddyResult<PaymentWriteResponse>> Function() call) async {
    final key = rowKey(row);
    if (busy.contains(key)) return false;
    busy.add(key);
    try {
      final r = await call();
      if (isClosed) return false;
      switch (r) {
        case BuddyOk(:final value):
          BuddyLive.seenBalancesVersion(tripId, value.balancesVersion);
          await load();
          return true;
        case BuddyRefused(:final message, :final type):
          if (type == BuddyErrorTypes.tripNotFound) {
            state.value = FormerShareState.gone;
          } else {
            AppToast.error(message ?? BuddySharedStrings.somethingWrong);
            await load();
          }
          return false;
        default:
          ViewerDeps.toastError(r);
          return false;
      }
    } finally {
      busy.remove(key);
    }
  }
}
