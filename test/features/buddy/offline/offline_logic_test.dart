import 'dart:async';
import 'dart:io';

import 'package:bakhli/features/buddy/buddy_error_types.dart';
import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/expenses/data/expense_write_gateway.dart';
import 'package:bakhli/features/buddy/offline/expense_op.dart';
import 'package:bakhli/features/buddy/offline/expense_queue_service.dart';
import 'package:bakhli/features/buddy/offline/expense_queue_store.dart';
import 'package:bakhli/features/buddy/offline/offline_strings.dart';
import 'package:bakhli/features/buddy/offline/queue_rules.dart';
import 'package:bakhli/features/buddy/offline/queued_expense_gateway.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'offline_fakes.dart';

ExpenseOp op(OpKind kind, {String opId = 'o1', String? failType, List<String> sharers = const [rahulId, amanId], OpState state = OpState.notSaved}) => ExpenseOp(
      opId: opId,
      kind: kind,
      tripId: tripId,
      expenseId: 'e1',
      baseVersion: kind == OpKind.create ? 0 : 1,
      body: kind == OpKind.delete ? null : draft(opId, 'e1', sharers: sharers).body,
      shown: shownItem('e1'),
      state: state,
      failType: failType,
      createdAt: DateTime.utc(2026, 5, 19),
    );

Future<void> flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QueueRules outcome table', () {
    QueueOutcome o(OpKind k, int s, String t) => QueueRules.outcome(k, statusCode: s, type: t);

    test('409 ExpenseVersionConflict -> Not saved, Refresh', () {
      final r = o(OpKind.edit, 409, BuddyErrorTypes.expenseVersionConflict);
      expect((r.kind, r.action), (OutcomeKind.notSaved, OpAction.refresh));
      expect(QueueRules.line(op(OpKind.edit, failType: BuddyErrorTypes.expenseVersionConflict)), 'Updated on another device');
    });

    test('422 SharerNotTraveller / PayerNotTraveller -> Edit with the name', () {
      for (final t in [BuddyErrorTypes.sharerNotTraveller, BuddyErrorTypes.payerNotTraveller]) {
        final r = o(OpKind.create, 422, t);
        expect((r.kind, r.action), (OutcomeKind.notSaved, OpAction.edit));
      }
      const aman = MoneyPerson(userId: amanId, name: 'Aman', last4: '8275', initial: 'A', isMe: false, status: MoneyPersonStatus.left);
      final x = op(OpKind.create, failType: BuddyErrorTypes.sharerNotTraveller);
      expect(QueueRules.line(x, travellers: const [aman]), 'Aman is no longer on this trip. Edit and save again.');
      expect(QueueRules.line(x), 'Someone is no longer on this trip. Edit and save again.');
    });

    test('409 ExpenseLimitReached -> Remove', () {
      final r = o(OpKind.create, 409, BuddyErrorTypes.expenseLimitReached);
      expect((r.kind, r.action), (OutcomeKind.notSaved, OpAction.remove));
      expect(QueueRules.line(op(OpKind.create, failType: BuddyErrorTypes.expenseLimitReached)), 'This trip has 500 expenses. Delete one to add more.');
    });

    test('409 TripExpensesFrozen -> Remove, frozen', () {
      final r = o(OpKind.create, 409, BuddyErrorTypes.tripExpensesFrozen);
      expect((r.kind, r.action), (OutcomeKind.notSaved, OpAction.remove));
      final x = op(OpKind.create, failType: BuddyErrorTypes.tripExpensesFrozen);
      expect(QueueRules.isFrozen(x), isTrue);
      expect(QueueRules.line(x), 'This trip is closed for changes.');
    });

    test('409 PaymentsNotAcknowledged -> Edit', () {
      final r = o(OpKind.edit, 409, BuddyErrorTypes.paymentsNotAcknowledged);
      expect((r.kind, r.action), (OutcomeKind.notSaved, OpAction.edit));
      expect(QueueRules.line(op(OpKind.edit, failType: BuddyErrorTypes.paymentsNotAcknowledged)), 'Payments are already made. Edit and save again.');
      expect(o(OpKind.delete, 409, BuddyErrorTypes.paymentsNotAcknowledged).action, OpAction.remove);
    });

    test('404 ExpenseNotFound: edit -> Remove, delete -> done', () {
      final e = o(OpKind.edit, 404, BuddyErrorTypes.expenseNotFound);
      expect((e.kind, e.action), (OutcomeKind.notSaved, OpAction.remove));
      expect(QueueRules.line(op(OpKind.edit, failType: BuddyErrorTypes.expenseNotFound)), 'This expense was deleted.');
      expect(o(OpKind.delete, 404, BuddyErrorTypes.expenseNotFound).kind, OutcomeKind.done);
    });

    test('404 TripNotFound / 403 NotTripOwner -> trip gone', () {
      expect(o(OpKind.create, 404, BuddyErrorTypes.tripNotFound).kind, OutcomeKind.tripGone);
      expect(o(OpKind.delete, 403, BuddyErrorTypes.notTripOwner).kind, OutcomeKind.tripGone);
    });

    test('any other 4xx -> Edit with the server message', () {
      final r = o(OpKind.create, 400, BuddyErrorTypes.invalidAmount);
      expect((r.kind, r.action), (OutcomeKind.notSaved, OpAction.edit));
      final x = op(OpKind.create, failType: BuddyErrorTypes.invalidAmount).copyWith(failMessage: 'Amount must be 1 to 500000.');
      expect(QueueRules.line(x), 'Amount must be 1 to 500000.');
    });

    test('429 and 5xx keep the op waiting', () {
      final r = QueueRules.outcome(OpKind.create, statusCode: 429, type: 'TooManyRequests', retryAfterSeconds: 7);
      expect((r.kind, r.retryAfterSeconds), (OutcomeKind.retry, 7));
      expect(QueueRules.outcome(OpKind.create, statusCode: 503).kind, OutcomeKind.retry);
      expect(QueueRules.outcome(OpKind.create, statusCode: 401).kind, OutcomeKind.retry);
    });

    test('totals: waiting creates and edit differences; not saved adds nothing to the hero', () {
      final pending = [
        PendingExpense(opId: 'a', tripId: tripId, expenseId: 'n1', kind: PendingKind.create, state: PendingState.waiting, shown: shownItem('n1', amount: 2400, myShare: 0, day: 4)),
        PendingExpense(opId: 'b', tripId: tripId, expenseId: 'n2', kind: PendingKind.create, state: PendingState.notSaved, shown: shownItem('n2', amount: 900, myShare: 300, day: 4)),
        PendingExpense(opId: 'c', tripId: tripId, expenseId: 'x', kind: PendingKind.edit, state: PendingState.waiting, shown: shownItem('x', amount: 1500, myShare: 500, day: 3)),
      ];
      final t = QueueRules.totals(pending, [shownItem('x', amount: 1200, myShare: 400, day: 3)]);
      expect(t.spent, 2400 + 300);
      expect(t.myShare, 0 + 100);
      expect(t.day(4), 3300);
      expect(t.day(3), 0);
    });
  });

  test('ExpenseOp json round trip keeps the op id', () {
    final x = op(OpKind.create, failType: BuddyErrorTypes.expenseLimitReached).copyWith(failAction: OpAction.remove, attempts: 2);
    final y = ExpenseOp.fromJson(x.toJson());
    expect(y.opId, x.opId);
    expect(y.body!.opId, x.opId);
    expect((y.kind, y.state, y.failAction, y.attempts, y.shown.title), (OpKind.create, OpState.notSaved, OpAction.remove, 2, 'Rafting in Rishikesh'));
  });

  group('store', () {
    test('per account, prune of other accounts after 30 days', () async {
      var now = DateTime.utc(2026, 5, 1);
      final box = MemoryQueueBox();
      final s = ExpenseQueueStore(box: box, now: () => now);
      await s.save(rahulId, [op(OpKind.create, state: OpState.waiting)]);
      await s.save(priyaId, [op(OpKind.create, opId: 'p1', state: OpState.waiting)]);
      expect(s.load(rahulId).single.opId, 'o1');
      expect(s.load(priyaId).single.opId, 'p1');
      expect(s.load(amanId), isEmpty);
      await s.addLost(rahulId, 2);
      expect(s.lost(rahulId), 2);
      expect(s.lost(priyaId), 0);
      now = now.add(const Duration(days: 29));
      await s.touchAndPrune(rahulId);
      expect(s.load(priyaId), isNotEmpty);
      now = now.add(const Duration(days: 2));
      await s.touchAndPrune(rahulId);
      expect(s.load(priyaId), isEmpty);
      expect(s.load(rahulId), isNotEmpty);
      await s.clear(rahulId);
      expect(s.load(rahulId), isEmpty);
      expect(s.lost(rahulId), 0);
    });

    test('named box survives StorageService.clearAll()', () async {
      final dir = Directory.systemTemp.createTempSync('offline_q');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
      await GetStorage.init();
      final s = ExpenseQueueStore();
      await s.init();
      expect(GetStorageQueueBox.name, 'buddy_expense_queue_v1');
      await s.save(rahulId, [op(OpKind.create, state: OpState.waiting)]);
      await StorageService.clearAll();
      expect(s.load(rahulId).single.opId, 'o1');
      expect(s.load(priyaId), isEmpty);
    });
  });

  group('service', () {
    late FakeServer server;
    late Rx<String?> user;
    late Net net;
    late MemoryQueueBox box;
    late ExpenseQueueService q;
    final gone = <String>[];

    Future<ExpenseQueueService> start() async {
      final s = makeQueue(server: server, user: user, box: box, net: net);
      s.onInit();
      await s.ready;
      await flush();
      return s;
    }

    setUp(() async {
      Get.reset();
      BuddyLive.reset();
      OfflineHooks.debugReset();
      gone.clear();
      OfflineHooks.onTripGone = gone.add;
      server = FakeServer();
      user = Rx<String?>(rahulId);
      net = Net();
      box = MemoryQueueBox();
      q = await start();
    });

    tearDown(() => q.onClose());

    test('online save goes straight to the server, nothing queued', () async {
      final g = QueuedExpenseGateway(q);
      final r = await g.save(draft('op1', 'e1'));
      expect(r, isA<ExpenseSaved>());
      expect(q.count, 0);
    });

    test('offline save is queued as Waiting to sync and syncs once when back online, never doubled', () async {
      final g = QueuedExpenseGateway(q);
      net.changes.add(false);
      await flush();
      final r = await g.save(draft('op1', 'e1'));
      expect(r, isA<ExpenseQueued>());
      expect((r as ExpenseQueued).opId, 'op1');
      await g.save(draft('op1', 'e1'));
      expect(q.count, 1);
      final p = q.forTrip(tripId).single;
      expect((p.state, p.kind, p.shown.myShare), (PendingState.waiting, PendingKind.create, 1200));
      expect(server.sentOpIds, isEmpty);
      final tick = BuddyLive.expenses(tripId).value;
      net.changes.add(true);
      await flush();
      expect(q.count, 0);
      expect(server.sentOpIds, ['op1']);
      expect(server.expensesCreated, 1);
      expect(BuddyLive.expenses(tripId).value, greaterThan(tick));
    });

    test('a network error keeps the op waiting; the retry sends the SAME op id; a replay does not double', () async {
      server.down = true;
      final g = QueuedExpenseGateway(q);
      final r = await g.save(draft('op1', 'e1'));
      expect(r, isA<ExpenseQueued>());
      await flush();
      expect(q.ops.single.waiting, isTrue);
      expect(await q.sync(), isFalse);
      server.down = false;
      server.applied.add('op1');
      expect(await q.sync(), isTrue);
      expect(server.sentOpIds.toSet(), {'op1'});
      expect(server.expensesCreated, 0);
      expect(q.count, 0);
    });

    test('sync is single flight and keeps the order', () async {
      net.changes.add(false);
      await flush();
      q.enqueueSave(draft('a', 'e1'));
      q.enqueueSave(draft('b', 'e2'));
      q.enqueueDelete(tripId: tripId, expenseId: 'e9', baseVersion: 3, opId: 'c', shown: shownItem('e9'));
      net.online = true;
      q.offline.value = false;
      server.gate = Completer<void>();
      final f1 = q.sync();
      final f2 = q.sync();
      expect(identical(f1, f2), isTrue);
      server.gate!.complete();
      server.gate = null;
      expect(await f1, isTrue);
      expect(server.sentOpIds, ['a', 'b', 'c']);
    });

    test('a refusal turns ONE op into Not saved, the rest still sync', () async {
      net.changes.add(false);
      await flush();
      q.enqueueSave(draft('a', 'e1'));
      q.enqueueSave(draft('b', 'e2'));
      server.answers['a'] = refused(409, BuddyErrorTypes.expenseLimitReached);
      net.changes.add(true);
      await flush();
      expect(q.count, 1);
      final p = q.forTrip(tripId).single;
      expect((p.opId, p.state, p.action, p.line), ('a', PendingState.notSaved, PendingAction.remove, OfflineStrings.lineLimit));
      expect(server.sentOpIds, ['a', 'b']);
      await q.sync();
      expect(server.sentOpIds, ['a', 'b']);
      await q.drop('a');
      expect(q.count, 0);
      expect(box.data.containsKey(ExpenseQueueStore.queueKey(rahulId)), isFalse);
    });

    test('Refresh drops the op and reloads E1', () async {
      server.down = true;
      q.enqueueSave(draft('a', 'e1', baseVersion: 2));
      await flush();
      server.down = false;
      server.answers['a'] = refused(409, BuddyErrorTypes.expenseVersionConflict);
      await q.sync();
      expect(q.forTrip(tripId).single.action, PendingAction.refresh);
      final tick = BuddyLive.expenses(tripId).value;
      await q.refresh('a');
      expect(q.count, 0);
      expect(BuddyLive.expenses(tripId).value, tick + 1);
    });

    test('Edit offers a draft with a NEW op id (and a new expense id for a create)', () async {
      server.down = true;
      q.enqueueSave(draft('a', 'e1'));
      await flush();
      server.down = false;
      server.answers['a'] = refused(422, BuddyErrorTypes.sharerNotTraveller);
      await q.sync();
      final p = q.forTrip(tripId).single;
      expect(p.action, PendingAction.edit);
      expect(p.draft, isNotNull);
      expect(p.draft!.opId, isNot('a'));
      expect(p.draft!.expenseId, isNot('e1'));
      expect(p.draft!.isCreate, isTrue);
    });

    test('trip gone drops every op of that trip, counts them once and closes Expenses', () async {
      net.changes.add(false);
      await flush();
      q.enqueueSave(draft('a', 'e1'));
      q.enqueueSave(draft('b', 'e2'));
      q.enqueueSave(draft('c', 'e3', trip: otherTrip));
      server.answers['a'] = refused(404, BuddyErrorTypes.tripNotFound);
      net.changes.add(true);
      await flush();
      expect(q.forTrip(tripId), isEmpty);
      expect(q.count, 0);
      expect(q.lost.value, 2);
      expect(gone, [tripId]);
      expect(server.sentOpIds, ['a', 'c']);
      expect(box.data[ExpenseQueueStore.lostKey(rahulId)], 2);
      await q.clearLost();
      expect(q.lost.value, 0);
    });

    test('429 waits and keeps the op', () async {
      server.down = true;
      q.enqueueSave(draft('a', 'e1'));
      await flush();
      server.down = false;
      server.answers['a'] = refused(429, 'TooManyRequests', retryAfter: 60);
      expect(await q.sync(), isFalse);
      expect(q.ops.single.waiting, isTrue);
    });

    test('per account: another account never sees the queue; the same account gets it back and syncs', () async {
      server.down = true;
      q.enqueueSave(draft('a', 'e1'));
      await flush();
      user.value = null;
      await flush();
      expect(q.count, 0);
      user.value = priyaId;
      await flush();
      expect(q.count, 0);
      expect(q.forTrip(tripId), isEmpty);
      user.value = null;
      await flush();
      server.down = false;
      user.value = rahulId;
      await flush();
      expect(q.count, 0);
      expect(server.sentOpIds.last, 'a');
      expect(server.expensesCreated, 1);
    });

    test('forced logout keeps the queue; clearAccount deletes it', () async {
      server.down = true;
      q.enqueueSave(draft('a', 'e1'));
      await flush();
      user.value = null;
      await flush();
      expect(q.storedCount(rahulId), 1);
      await q.clearAccount(rahulId);
      expect(q.storedCount(rahulId), 0);
    });
  });
}
