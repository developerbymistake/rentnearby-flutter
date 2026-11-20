import 'dart:async';
import 'dart:convert';

import 'package:bakhli/features/buddy/expenses/data/expense_write_gateway.dart';
import 'package:bakhli/features/buddy/expenses/models/expense_draft.dart';
import 'package:bakhli/features/buddy/expenses/models/expense_models.dart';
import 'package:bakhli/features/buddy/offline/expense_op.dart';
import 'package:bakhli/features/buddy/offline/expense_queue_service.dart';
import 'package:bakhli/features/buddy/offline/expense_queue_store.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:get/get.dart';

const String rahulId = '11111111-1111-1111-1111-111111111111';
const String priyaId = '22222222-2222-2222-2222-222222222222';
const String amanId = '33333333-3333-3333-3333-333333333333';
const String tripId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const String otherTrip = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

ExpenseRefused refused(int status, String type, {String? message, int? retryAfter}) =>
    ExpenseRefused(error: BuddyRefused<Object?>(type: type, statusCode: status, message: message, retryAfterSeconds: retryAfter));

const ExpenseWriteFailed offlineFail = ExpenseWriteFailed(message: ExpenseWriteFailed.offline);

class FakeServer implements ExpenseWriteGateway {
  final Set<String> applied = {};
  final List<String> sentOpIds = [];
  final Map<String, ExpenseWriteOutcome> answers = {};
  bool down = false;
  int expensesCreated = 0;
  Completer<void>? gate;

  ExpenseWriteOutcome _ok(String expenseId) => ExpenseSaved(expense: ExpenseDetail.fromJson({'id': expenseId}), balancesVersion: 1);

  @override
  Future<ExpenseWriteOutcome> save(ExpenseDraft draft) async {
    sentOpIds.add(draft.opId);
    final g = gate;
    if (g != null) await g.future;
    if (down) return offlineFail;
    final a = answers[draft.opId];
    if (a != null) return a;
    if (applied.add(draft.opId) && draft.isCreate) expensesCreated++;
    return _ok(draft.expenseId);
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
    sentOpIds.add(opId);
    if (down) return offlineFail;
    final a = answers[opId];
    if (a != null) return a;
    applied.add(opId);
    return const ExpenseDeleted(balancesVersion: 2);
  }
}

class Net {
  final StreamController<bool> changes = StreamController<bool>.broadcast();
  bool online = true;
}

ExpenseQueueService makeQueue({
  required FakeServer server,
  required Rx<String?> user,
  QueueBox? box,
  Net? net,
}) {
  final n = net ?? Net();
  return ExpenseQueueService(
    store: ExpenseQueueStore(box: box ?? MemoryQueueBox()),
    onlineOverride: server,
    onlineChanges: n.changes.stream,
    isOnlineCheck: () async => n.online,
    userSource: user,
  );
}

ExpenseItem shownItem(String id, {String title = 'Rafting in Rishikesh', int amount = 2400, int day = 4, int sharedBy = 2, int myShare = 0, String category = 'Tickets', String paidBy = rahulId}) =>
    ExpenseItem(
      id: id,
      title: title,
      category: category,
      amount: amount,
      dayNumber: day,
      paidByUserId: paidBy,
      sharedBy: sharedBy,
      myShare: myShare,
      version: 1,
      edited: false,
    );

ExpenseDraft draft(String opId, String expenseId, {int baseVersion = 0, String trip = tripId, List<String> sharers = const [rahulId, priyaId], int amount = 2400, ExpenseItem? shown}) =>
    ExpenseDraft(
      tripId: trip,
      expenseId: expenseId,
      body: ExpenseWriteRequest(
        opId: opId,
        baseVersion: baseVersion,
        amount: amount,
        title: shown?.title ?? 'Rafting in Rishikesh',
        category: shown?.category ?? 'Tickets',
        dayNumber: shown?.dayNumber ?? 4,
        paidByUserId: rahulId,
        splitMode: 'Chosen',
        sharers: sharers,
      ),
      shown: shown,
    );

ExpenseQueueService putQueue({
  required String user,
  List<ExpenseOp> ops = const [],
  bool offline = false,
  FakeServer? server,
  int lost = 0,
}) {
  final box = MemoryQueueBox();
  if (ops.isNotEmpty) box.data[ExpenseQueueStore.queueKey(user)] = jsonEncode([for (final o in ops) o.toJson()]);
  if (lost > 0) box.data[ExpenseQueueStore.lostKey(user)] = lost;
  final net = Net()..online = !offline;
  final q = makeQueue(server: server ?? (FakeServer()..down = true), user: Rx<String?>(user), box: box, net: net);
  q.offline.value = offline;
  Get.put<ExpenseQueueService>(q);
  Get.put<ExpensePendingSource>(q);
  return q;
}

ExpenseOp makeOp({
  required String opId,
  required String title,
  required int amount,
  required int day,
  required List<String> sharers,
  required int myShare,
  required String payer,
  String category = 'Food',
  OpKind kind = OpKind.create,
  OpState state = OpState.waiting,
  String? failType,
  OpAction? action,
  String trip = tripId,
  String? expenseId,
}) {
  final id = expenseId ?? 'x-$opId';
  return ExpenseOp(
    opId: opId,
    kind: kind,
    tripId: trip,
    expenseId: id,
    baseVersion: kind == OpKind.create ? 0 : 1,
    body: kind == OpKind.delete
        ? null
        : ExpenseWriteRequest(
            opId: opId,
            baseVersion: kind == OpKind.create ? 0 : 1,
            amount: amount,
            title: title,
            category: category,
            dayNumber: day,
            paidByUserId: payer,
            splitMode: 'Chosen',
            sharers: sharers,
          ),
    shown: ExpenseItem(
      id: id,
      title: title,
      category: category,
      amount: amount,
      dayNumber: day,
      paidByUserId: payer,
      sharedBy: sharers.length,
      myShare: myShare,
      version: 1,
      edited: false,
    ),
    state: state,
    failType: failType,
    failAction: action,
    createdAt: DateTime.utc(2026, 5, 19, 10),
  );
}
