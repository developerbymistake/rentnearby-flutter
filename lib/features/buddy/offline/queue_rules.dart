import '../buddy_error_types.dart';
import '../expenses/data/expense_write_gateway.dart';
import '../expenses/models/expense_models.dart';
import '../shared/models/person_models.dart';
import 'expense_op.dart';
import 'offline_strings.dart';

enum OutcomeKind { done, notSaved, tripGone, retry }

class QueueOutcome {
  const QueueOutcome(this.kind, {this.action, this.retryAfterSeconds});

  final OutcomeKind kind;
  final OpAction? action;
  final int? retryAfterSeconds;

  static const done = QueueOutcome(OutcomeKind.done);
  static const tripGone = QueueOutcome(OutcomeKind.tripGone);
  static const retry = QueueOutcome(OutcomeKind.retry);
}

class PendingTotals {
  const PendingTotals({this.spent = 0, this.myShare = 0, this.days = const {}});

  final int spent;
  final int myShare;
  final Map<int, int> days;

  int day(int dayNumber) => days[dayNumber] ?? 0;
}

abstract final class QueueRules {
  static QueueOutcome outcome(OpKind kind, {required int statusCode, String? type, int? retryAfterSeconds}) {
    if (statusCode == 429) return QueueOutcome(OutcomeKind.retry, retryAfterSeconds: retryAfterSeconds);
    if (statusCode >= 500 || statusCode == 401) return QueueOutcome.retry;
    if (type == BuddyErrorTypes.tripNotFound || type == BuddyErrorTypes.notTripOwner) return QueueOutcome.tripGone;
    if (type == BuddyErrorTypes.expenseNotFound) {
      return kind == OpKind.delete ? QueueOutcome.done : const QueueOutcome(OutcomeKind.notSaved, action: OpAction.remove);
    }
    final action = switch (type) {
      BuddyErrorTypes.expenseVersionConflict => OpAction.refresh,
      BuddyErrorTypes.sharerNotTraveller || BuddyErrorTypes.payerNotTraveller => OpAction.edit,
      BuddyErrorTypes.expenseLimitReached || BuddyErrorTypes.tripExpensesFrozen => OpAction.remove,
      _ => OpAction.edit,
    };
    return QueueOutcome(OutcomeKind.notSaved, action: kind == OpKind.delete && action == OpAction.edit ? OpAction.remove : action);
  }

  static bool isFrozen(ExpenseOp op) => op.notSaved && op.failType == BuddyErrorTypes.tripExpensesFrozen;

  static String line(ExpenseOp op, {List<MoneyPerson> travellers = const []}) => switch (op.failType) {
        BuddyErrorTypes.expenseVersionConflict => OfflineStrings.lineConflict,
        BuddyErrorTypes.sharerNotTraveller || BuddyErrorTypes.payerNotTraveller => OfflineStrings.lineNotTraveller(goneName(op, travellers)),
        BuddyErrorTypes.expenseLimitReached => OfflineStrings.lineLimit,
        BuddyErrorTypes.tripExpensesFrozen => OfflineStrings.lineFrozen,
        BuddyErrorTypes.paymentsNotAcknowledged => op.kind == OpKind.delete ? OfflineStrings.linePaymentsDelete : OfflineStrings.linePayments,
        BuddyErrorTypes.expenseNotFound => OfflineStrings.lineDeleted,
        _ => _nonEmpty(op.failMessage) ?? OfflineStrings.lineOther,
      };

  static String? _nonEmpty(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

  static String goneName(ExpenseOp op, List<MoneyPerson> travellers) {
    final byId = {for (final p in travellers) p.userId: p};
    for (final id in op.peopleIds) {
      final p = byId[id];
      if (p != null && (p.isFormer || p.isDeleted) && p.name.isNotEmpty) return p.name;
    }
    return OfflineStrings.someone;
  }

  static PendingAction pendingAction(OpAction a) => switch (a) {
        OpAction.refresh => PendingAction.refresh,
        OpAction.edit => PendingAction.edit,
        OpAction.remove => PendingAction.remove,
      };

  static PendingKind pendingKind(OpKind k) => switch (k) {
        OpKind.create => PendingKind.create,
        OpKind.edit => PendingKind.edit,
        OpKind.delete => PendingKind.delete,
      };

  static PendingTotals totals(Iterable<PendingExpense> pending, List<ExpenseItem> serverItems) {
    final server = {for (final i in serverItems) i.id: i};
    var spent = 0;
    var mine = 0;
    final days = <int, int>{};
    for (final p in pending) {
      if (p.kind == PendingKind.create) {
        days[p.shown.dayNumber] = (days[p.shown.dayNumber] ?? 0) + p.shown.amount;
      }
      if (p.state != PendingState.waiting) continue;
      if (p.kind == PendingKind.create) {
        spent += p.shown.amount;
        mine += p.shown.myShare;
      } else if (p.kind == PendingKind.edit) {
        final old = server[p.expenseId];
        if (old == null) continue;
        spent += p.shown.amount - old.amount;
        mine += p.shown.myShare - old.myShare;
      }
    }
    return PendingTotals(spent: spent, myShare: mine, days: days);
  }
}
