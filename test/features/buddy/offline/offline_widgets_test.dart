@Timeout(Duration(seconds: 120))
library;

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/buddy/buddy_error_types.dart';
import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/expenses/data/expense_write_gateway.dart';
import 'package:bakhli/features/buddy/expenses/expense_deps.dart';
import 'package:bakhli/features/buddy/expenses/screens/trip_expenses_screen.dart';
import 'package:bakhli/features/buddy/expenses/widgets/expense_sheet.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/offline/expense_op.dart';
import 'package:bakhli/features/buddy/offline/expense_queue_service.dart';
import 'package:bakhli/features/buddy/offline/logout_guard.dart';
import 'package:bakhli/features/buddy/offline/offline_registration.dart';
import 'package:bakhli/features/buddy/offline/offline_strings.dart';
import 'package:bakhli/features/buddy/offline/widgets/expense_sync_banner.dart';
import 'package:bakhli/features/buddy/offline/widgets/lost_changes_banner.dart';
import 'package:bakhli/features/buddy/offline/widgets/pending_row_extras.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/real_phone.dart';
import '../expenses/expenses_fixtures.dart' as ef;
import 'offline_fakes.dart';

ExpenseOp _w(String id, {int day = 4}) =>
    makeOp(opId: id, title: 'Rafting in Rishikesh', amount: 2400, day: day, sharers: const [rahulId, amanId], myShare: 0, payer: rahulId);

ExpenseOp _n(String id, String fail, OpAction action, {String title = 'Lunch at Laxman Jhula'}) => makeOp(
      opId: id,
      title: title,
      amount: 900,
      day: 4,
      sharers: const [rahulId, amanId, priyaId],
      myShare: 300,
      payer: rahulId,
      state: OpState.notSaved,
      failType: fail,
      action: action,
    );

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

class _Rows extends StatelessWidget {
  const _Rows();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Obx(() {
          final q = ExpenseQueueService.maybe!;
          q.version.value;
          return ListView(children: [
            ExpenseSyncBanner(tripId: tripId),
            for (final p in q.forTrip(tripId))
              GestureDetector(
                onTap: () => PendingRowExtras.onTap(context, p),
                child: Column(children: [Text(p.shown.title), ?PendingRowExtras.of(context, p)]),
              ),
          ]);
        }),
      );
}

class _Guard extends StatefulWidget {
  const _Guard();

  static bool? result;

  @override
  State<_Guard> createState() => _GuardState();
}

class _GuardState extends State<_Guard> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(onPressed: () async => _Guard.result = await LogoutGuard.check(context), child: const Text('Logout')),
        ),
      );
}

void main() {
  int logouts = 0;
  final edits = <PendingExpense>[];

  setUp(() {
    Get.reset();
    BuddyLive.reset();
    OfflineHooks.debugReset();
    logouts = 0;
    edits.clear();
    _Guard.result = null;
    OfflineHooks.logout = () async => logouts++;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    OfflineHooks.debugReset();
    Get.reset();
  });

  group('ExpenseSyncBanner + rows', () {
    testWidgets('4.13 offline with one waiting: amber line, Waiting to sync tag, tap toast', (t) async {
      putQueue(user: rahulId, offline: true, ops: [_w('a')]);
      await pumpPhone(t, const _Rows(), toastHost: true);
      await _settle(t);
      expect(find.text('You are offline. 1 expense will sync when you are back online.'), findsOneWidget);
      expect(find.text('Waiting to sync'), findsOneWidget);
      await t.tap(find.text('Rafting in Rishikesh'));
      await _settle(t);
      expect(find.text('Waiting to sync'), findsNWidgets(2));
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('offline with two waiting and with nothing waiting', (t) async {
      final q = putQueue(user: rahulId, offline: true, ops: [_w('a'), _w('b')]);
      await pumpPhone(t, const _Rows());
      await _settle(t);
      expect(find.text('You are offline. 2 expenses will sync when you are back online.'), findsOneWidget);
      await q.drop('a');
      await q.drop('b');
      await _settle(t);
      expect(find.text('You are offline.'), findsOneWidget);
    });

    testWidgets('online with only waiting ops: no banner, rows keep the tag', (t) async {
      putQueue(user: rahulId, ops: [_w('a')]);
      await pumpPhone(t, const _Rows());
      await _settle(t);
      expect(find.textContaining('You are offline'), findsNothing);
      expect(find.text('Waiting to sync'), findsOneWidget);
    });

    testWidgets('4.13a three not saved: red count, one line and one button each; Refresh, Edit, Remove', (t) async {
      final q = putQueue(user: rahulId, ops: [
        _n('a', BuddyErrorTypes.expenseVersionConflict, OpAction.refresh, title: 'Rafting in Rishikesh'),
        _n('b', BuddyErrorTypes.sharerNotTraveller, OpAction.edit),
        _n('c', BuddyErrorTypes.expenseLimitReached, OpAction.remove, title: 'Cafe by the river'),
      ]);
      OfflineHooks.travellers = (_) => const [];
      OfflineHooks.openEdit = (ctx, p) async {
        edits.add(p);
        return true;
      };
      await pumpPhone(t, const _Rows());
      await _settle(t);
      expect(find.text('3 expenses could not be saved.'), findsOneWidget);
      expect(find.text('Not saved'), findsNWidgets(3));
      expect(find.text('Updated on another device'), findsOneWidget);
      expect(find.text('Someone is no longer on this trip. Edit and save again.'), findsOneWidget);
      expect(find.text('This trip has 500 expenses. Delete one to add more.'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      final tick = BuddyLive.expenses(tripId).value;
      await t.tap(find.byKey(PendingRowExtras.actionKey('a')));
      await _settle(t);
      expect(q.byId('a'), isNull);
      expect(BuddyLive.expenses(tripId).value, tick + 1);
      expect(find.text('2 expenses could not be saved.'), findsOneWidget);

      await t.tap(find.byKey(PendingRowExtras.actionKey('b')));
      await _settle(t);
      expect(edits.single.opId, 'b');
      expect(edits.single.draft!.opId, isNot('b'));
      expect(q.byId('b'), isNull);

      await t.tap(find.byKey(PendingRowExtras.actionKey('c')));
      await _settle(t);
      expect(q.count, 0);
      expect(find.text('Not saved'), findsNothing);
    });

    testWidgets('Edit closed without saving keeps the op (never lost quietly)', (t) async {
      final q = putQueue(user: rahulId, ops: [_n('b', BuddyErrorTypes.payerNotTraveller, OpAction.edit)]);
      OfflineHooks.openEdit = (ctx, p) async => false;
      await pumpPhone(t, const _Rows());
      await _settle(t);
      expect(find.text('1 expense could not be saved.'), findsOneWidget);
      await t.tap(find.byKey(PendingRowExtras.actionKey('b')));
      await _settle(t);
      expect(q.byId('b'), isNotNull);
    });

    testWidgets('4.13b trip closed: locked banner, line and Remove', (t) async {
      final q = putQueue(user: rahulId, ops: [_n('a', BuddyErrorTypes.tripExpensesFrozen, OpAction.remove, title: 'Breakfast at Dehradun')]);
      await pumpPhone(t, const _Rows());
      await _settle(t);
      expect(find.text('1 change could not be saved. This trip is closed for changes.'), findsOneWidget);
      expect(find.text('This trip is closed for changes.'), findsOneWidget);
      await t.tap(find.byKey(PendingRowExtras.actionKey('a')));
      await _settle(t);
      expect(q.count, 0);
    });

    testWidgets('back online: the queue sends by itself and the tag goes', (t) async {
      final server = FakeServer();
      final q = putQueue(user: rahulId, offline: true, ops: [_w('a')], server: server);
      await pumpPhone(t, const _Rows());
      await _settle(t);
      expect(find.text('Waiting to sync'), findsOneWidget);
      q.offline.value = false;
      q.sync();
      await _settle(t);
      expect(find.text('Waiting to sync'), findsNothing);
      expect(server.sentOpIds, ['a']);
      expect(server.expensesCreated, 1);
    });
  });

  group('real Expenses screen', () {
    tearDown(ef.resetExpenseFakes);

    ExpenseOp op(String id, {OpState state = OpState.waiting, String? fail, OpAction? action}) => makeOp(
          opId: id,
          title: 'Rafting in Rishikesh',
          amount: 2400,
          day: 4,
          sharers: const [ef.rahul, ef.aman],
          myShare: 1200,
          payer: ef.rahul,
          trip: ef.tripId,
          state: state,
          failType: fail,
          action: action,
        );

    Widget screen() {
      final l = ef.ownerList({
        'totals': {'spent': 20000, 'expenseCount': 1, 'myShare': 6168, 'myPaid': 20000},
        'days': [
          {'day': 3, 'date': '2026-05-18', 'total': 18500, 'count': 1}
        ],
        'items': [ef.item(ef.e4, 'Taxi, Suresh (Dzire), full trip', 'Taxi', 18500, 3, ef.rahul, 3, 6168)],
        'suggestions': <Object>[],
      });
      return TripExpensesScreen(tripId: ef.tripId, initial: l);
    }

    testWidgets('waiting row: day header with date, total counted once, hero includes it, tap is a toast only', (t) async {
      final fakes = ef.registerFakes(list: const BuddyOffline());
      final opened = <String>[];
      ExpenseDeps.openExpense = (trip, id) {
        opened.add(id);
        return null;
      };
      putQueue(user: ef.rahul, offline: true, ops: [op('a')]);
      await pumpPhone(t, screen(), toastHost: true);
      await _settle(t);
      expect(find.text('DAY 4 · 19 MAY'), findsOneWidget);
      expect(find.text('₹2,400'), findsNWidgets(2));
      expect(find.text('₹4,800'), findsNothing);
      expect(find.text('₹22,400'), findsOneWidget);
      await t.tap(find.text('Rafting in Rishikesh'));
      await _settle(t);
      expect(opened, isEmpty);
      expect(find.text('Waiting to sync'), findsNWidgets(2));
      expect(fakes.gateway.drafts, isEmpty);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('not saved row: tap opens nothing; Edit opens the sheet filled from the op, Save makes a new op and drops the old one', (t) async {
      final fakes = ef.registerFakes(list: const BuddyOffline());
      final opened = <String>[];
      ExpenseDeps.openExpense = (trip, id) {
        opened.add(id);
        return null;
      };
      OfflineHooks.openEdit = openPendingEdit;
      final q = putQueue(user: ef.rahul, ops: [op('b', state: OpState.notSaved, fail: BuddyErrorTypes.invalidAmount, action: OpAction.edit)]);
      await pumpPhone(t, screen(), toastHost: true);
      await _settle(t);
      await t.tap(find.text('Rafting in Rishikesh'));
      await _settle(t);
      expect(opened, isEmpty);
      await t.tap(find.byKey(PendingRowExtras.actionKey('b')));
      await _settle(t);
      final c = ExpenseSheet.debugLast!;
      expect(c.title.value, 'Rafting in Rishikesh');
      expect(c.amountDigits.value, '2400');
      expect(c.day.value, 4);
      expect(c.chosen.toSet(), {ef.rahul, ef.aman});
      expect(c.expenseId, isNot('x-b'));
      await t.ensureVisible(find.byKey(ExpenseSheet.saveKey));
      await t.tap(find.byKey(ExpenseSheet.saveKey));
      await _settle(t);
      final sent = fakes.gateway.drafts.single;
      expect(sent.opId, isNot('b'));
      expect(sent.isCreate, isTrue);
      expect(sent.body.amount, 2400);
      expect(q.byId('b'), isNull);
      expect(find.text('Not saved'), findsNothing);
      await t.pump(const Duration(seconds: 5));
    });
  });

  group('LostChangesBanner (4.13c)', () {
    testWidgets('shows the count once and clears when My trips is left', (t) async {
      final q = putQueue(user: rahulId, lost: 2);
      await pumpPhone(t, const Scaffold(body: Column(children: [LostChangesBanner()])));
      await _settle(t);
      expect(find.text('2 changes could not be saved. The trip is no longer yours.'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      await _settle(t);
      expect(q.lost.value, 0);
    });

    testWidgets('one change', (t) async {
      putQueue(user: rahulId, lost: 1);
      await pumpPhone(t, const Scaffold(body: Column(children: [LostChangesBanner()])));
      await _settle(t);
      expect(find.text('1 change could not be saved. The trip is no longer yours.'), findsOneWidget);
    });

    testWidgets('nothing lost: no banner', (t) async {
      putQueue(user: rahulId);
      await pumpPhone(t, const Scaffold(body: Column(children: [LostChangesBanner()])));
      await _settle(t);
      expect(find.textContaining('could not be saved'), findsNothing);
    });
  });

  group('LogoutGuard (4.13d, 4.13e)', () {
    Future<void> open(WidgetTester t) async {
      await t.tap(find.text('Logout'));
      await _settle(t);
    }

    testWidgets('empty queue: true at once, no box', (t) async {
      putQueue(user: rahulId);
      await pumpPhone(t, const _Guard());
      await open(t);
      expect(_Guard.result, isTrue);
      expect(find.text(OfflineStrings.logOutAnyway), findsNothing);
    });

    testWidgets('box 1 strings; tap outside closes without logout', (t) async {
      putQueue(user: rahulId, ops: [_w('a'), _w('b')]);
      await pumpPhone(t, const _Guard());
      await open(t);
      expect(find.text('2 expenses are not saved yet'), findsOneWidget);
      expect(find.text('They are only on this phone. Sync them before you log out.'), findsOneWidget);
      expect(find.text('Log out anyway'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
      await t.tapAt(const Offset(10, 10));
      await _settle(t);
      expect(_Guard.result, isFalse);
      expect(logouts, 0);
    });

    testWidgets('one expense title', (t) async {
      putQueue(user: rahulId, ops: [_w('a')]);
      await pumpPhone(t, const _Guard());
      await open(t);
      expect(find.text('1 expense is not saved yet'), findsOneWidget);
    });

    testWidgets('Sync now, still offline: the box stays with the red line', (t) async {
      final q = putQueue(user: rahulId, ops: [_w('a')]);
      await pumpPhone(t, const _Guard());
      await open(t);
      await t.tap(find.byKey(LogoutGuard.syncNowKey));
      await _settle(t);
      expect(find.text('Could not sync. Check your network.'), findsOneWidget);
      expect(q.count, 1);
      expect(_Guard.result, isNull);
    });

    testWidgets('Sync now, all saved: box closes, toast Expenses saved, no logout', (t) async {
      final server = FakeServer()..down = true;
      putQueue(user: rahulId, ops: [_w('a')], server: server);
      await pumpPhone(t, const _Guard(), toastHost: true);
      await open(t);
      server.down = false;
      await t.tap(find.byKey(LogoutGuard.syncNowKey));
      await _settle(t);
      expect(find.text('Expenses saved'), findsOneWidget);
      expect(find.text('Sync now'), findsNothing);
      expect(_Guard.result, isFalse);
      expect(logouts, 0);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('Log out anyway -> box 2 strings; Cancel keeps everything', (t) async {
      final q = putQueue(user: rahulId, ops: [_w('a'), _w('b')]);
      await pumpPhone(t, const _Guard());
      await open(t);
      await t.tap(find.byKey(LogoutGuard.anywayKey));
      await _settle(t);
      expect(find.text('Log out anyway?'), findsOneWidget);
      expect(find.text('2 expenses will be lost. They never reached the trip.'), findsOneWidget);
      expect(find.text('Sync them first if you can.'), findsOneWidget);
      await t.tap(find.byKey(LogoutGuard.cancelKey));
      await _settle(t);
      expect(_Guard.result, isFalse);
      expect(q.count, 2);
      expect(logouts, 0);
    });

    testWidgets('box 2 one expense; Log out deletes the queue and logs out with no further box', (t) async {
      final q = putQueue(user: rahulId, ops: [_w('a')]);
      await pumpPhone(t, const _Guard());
      await open(t);
      await t.tap(find.byKey(LogoutGuard.anywayKey));
      await _settle(t);
      expect(find.text('1 expense will be lost. It never reached the trip.'), findsOneWidget);
      await t.tap(find.byKey(LogoutGuard.logOutKey));
      await _settle(t);
      expect(q.count, 0);
      expect(q.storedCount(rahulId), 0);
      expect(logouts, 1);
      expect(_Guard.result, isFalse);
    });
  });

  group('SessionEndedNotice (4.13f)', () {
    testWidgets('forced logout with expenses: box once, Log in continues, queue kept', (t) async {
      final q = putQueue(user: rahulId, ops: [_w('a'), _w('b')]);
      await pumpPhone(t, const Scaffold(body: SizedBox()));
      var done = false;
      SessionEndedNotice.onLogout(LogoutReason.sessionExpired, rahulId).then((_) => done = true);
      await _settle(t);
      expect(find.text('Please log in again'), findsOneWidget);
      expect(find.text('2 expenses are saved on this phone. They sync after you log in.'), findsOneWidget);
      expect(done, isFalse);
      await t.tap(find.text('Log in'));
      await _settle(t);
      expect(done, isTrue);
      expect(q.storedCount(rahulId), 2);
    });

    testWidgets('one expense line; role change too', (t) async {
      putQueue(user: rahulId, ops: [_w('a')]);
      await pumpPhone(t, const Scaffold(body: SizedBox()));
      SessionEndedNotice.onLogout(LogoutReason.roleChanged, rahulId);
      await _settle(t);
      expect(find.text('1 expense is saved on this phone. It syncs after you log in.'), findsOneWidget);
    });

    testWidgets('empty queue or explicit logout: no box; account deleted wipes the queue', (t) async {
      final q = putQueue(user: rahulId, ops: [_w('a')]);
      await pumpPhone(t, const Scaffold(body: SizedBox()));
      await SessionEndedNotice.onLogout(LogoutReason.explicitLogout, rahulId);
      await SessionEndedNotice.onLogout(LogoutReason.sessionExpired, priyaId);
      await _settle(t);
      expect(find.text('Please log in again'), findsNothing);
      await SessionEndedNotice.onLogout(LogoutReason.accountDeleted, rahulId);
      expect(q.storedCount(rahulId), 0);
    });
  });
}
