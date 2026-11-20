import '../expenses/data/expense_write_gateway.dart';
import '../expenses/models/expense_draft.dart';
import '../expenses/models/expense_models.dart';
import 'expense_queue_service.dart';

class QueuedExpenseGateway implements ExpenseWriteGateway {
  QueuedExpenseGateway(this.queue);

  final ExpenseQueueService queue;

  static bool _offline(ExpenseWriteOutcome r) => r is ExpenseWriteFailed && r.isOffline;

  @override
  Future<ExpenseWriteOutcome> save(ExpenseDraft draft) async {
    if (queue.offline.value) return queue.enqueueSave(draft);
    final r = await queue.online.save(draft);
    return _offline(r) ? queue.enqueueSave(draft) : r;
  }

  @override
  Future<ExpenseWriteOutcome> delete({
    required String tripId,
    required String expenseId,
    required int baseVersion,
    required String opId,
    bool paymentsAcknowledged = false,
    required ExpenseItem shown,
  }) async {
    ExpenseQueued enqueue() => queue.enqueueDelete(
          tripId: tripId,
          expenseId: expenseId,
          baseVersion: baseVersion,
          opId: opId,
          paymentsAcknowledged: paymentsAcknowledged,
          shown: shown,
        );
    if (queue.offline.value) return enqueue();
    final r = await queue.online.delete(
      tripId: tripId,
      expenseId: expenseId,
      baseVersion: baseVersion,
      opId: opId,
      paymentsAcknowledged: paymentsAcknowledged,
      shown: shown,
    );
    return _offline(r) ? enqueue() : r;
  }
}
