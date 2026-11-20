@Timeout(Duration(seconds: 120))
library;

import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/buddy/buddies/controllers/buddy_summary_controller.dart';
import 'package:bakhli/features/buddy/buddies/models/buddy_models.dart';
import 'package:bakhli/features/buddy/buddy_error_types.dart';
import 'package:bakhli/features/buddy/expenses/models/expense_models.dart';
import 'package:bakhli/features/buddy/expenses/screens/trip_expenses_screen.dart';
import 'package:bakhli/features/buddy/offline/expense_op.dart';
import 'package:bakhli/features/buddy/offline/expense_queue_service.dart';
import 'package:bakhli/features/buddy/offline/logout_guard.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/screens/my_trips_screen.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../buddies/buddies_fakes.dart' as bf;
import '../expenses/expenses_fixtures.dart' as ef;
import '../viewer/viewer_fixtures.dart' as vf;
import 'offline_fakes.dart';

Future<void> _render(WidgetTester t, String id, Widget screen, {Future<void> Function(WidgetTester)? arrange}) async {
  final f = await renderFrame(t, id, screen, arrange: arrange);
  expect(t.takeException(), isNull);
  expect(f.existsSync(), isTrue);
  await t.pump(const Duration(seconds: 6));
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

const _three = [ef.rahul, ef.aman, ef.priya];
const _two = [ef.rahul, ef.aman];

ExpenseOp _op(String opId, String title, String cat, int amount, int day, List<String> sharers, int myShare,
        {OpState state = OpState.waiting, String? fail, OpAction? action}) =>
    makeOp(
      opId: opId,
      title: title,
      category: cat,
      amount: amount,
      day: day,
      sharers: sharers,
      myShare: myShare,
      payer: ef.rahul,
      state: state,
      failType: fail,
      action: action,
      trip: ef.tripId,
    );

Map<String, dynamic> _day(int day, String date, int total, int count) => {'day': day, 'date': date, 'total': total, 'count': count};

ExpenseList _list({required int spent, required List<Map<String, dynamic>> days, required List<Map<String, dynamic>> items, Map<String, dynamic> over = const {}}) =>
    ef.ownerList({
      'totals': {'spent': spent, 'expenseCount': items.length, 'myShare': 11618, 'myPaid': 20000},
      'days': days,
      'items': items,
      'suggestions': <Object>[],
      ...over,
    });

final _taxi = ef.item(ef.e4, 'Taxi, Suresh (Dzire), full trip', 'Taxi', 18500, 3, ef.rahul, 3, 6168);
final _dinner = ef.item(ef.e5, 'Dinner by the Ganga', 'Food', 1500, 3, ef.priya, 3, 500);
final _boat = ef.item(ef.e3, 'Naini Lake boating', 'Tickets', 900, 2, ef.rahul, 2, 450);
final _rafting = ef.item(ef.e2, 'Rafting in Rishikesh', 'Other', 2400, 4, ef.rahul, 2, 0);

Widget _expenses(ExpenseList l) {
  ef.registerFakes(list: const BuddyOffline());
  return TripExpensesScreen(tripId: ef.tripId, initial: l);
}

void main() {
  useBuddyRenderScale();
  setUp(() {
    Get.reset();
    OfflineHooks.debugReset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });
  tearDown(() {
    OfflineHooks.debugReset();
    ef.resetExpenseFakes();
    TripClock.resetClock();
  });

  testWidgets('4.13 offline, waiting to sync', (t) async {
    final l = _list(spent: 29900, days: [_day(3, '2026-05-18', 20000, 2), _day(2, '2026-05-17', 900, 1)], items: [_taxi, _dinner, _boat]);
    final screen = _expenses(l);
    putQueue(user: ef.rahul, offline: true, ops: [_op('o1', 'Rafting in Rishikesh', 'Other', 2400, 4, _two, 0)]);
    await _render(t, '4.13', screen);
  });

  testWidgets('4.13a not saved', (t) async {
    final l = _list(spent: 29900, days: [_day(3, '2026-05-18', 20000, 1)], items: [_taxi]);
    final screen = _expenses(l);
    OfflineHooks.travellers = (_) => const [
          MoneyPerson(userId: ef.aman, name: 'Aman', last4: '8275', initial: 'A', isMe: false, status: MoneyPersonStatus.left),
        ];
    putQueue(user: ef.rahul, ops: [
      _op('o1', 'Rafting in Rishikesh', 'Other', 2400, 4, _two, 0,
          state: OpState.notSaved, fail: BuddyErrorTypes.expenseVersionConflict, action: OpAction.refresh),
      _op('o2', 'Lunch at Laxman Jhula', 'Food', 900, 4, _three, 300,
          state: OpState.notSaved, fail: BuddyErrorTypes.sharerNotTraveller, action: OpAction.edit),
      _op('o3', 'Cafe by the river', 'Other', 300, 4, _three, 100,
          state: OpState.notSaved, fail: BuddyErrorTypes.expenseLimitReached, action: OpAction.remove),
    ]);
    await _render(t, '4.13a', screen);
  });

  testWidgets('4.13b not saved, trip closed', (t) async {
    final l = _list(
      spent: 32300,
      days: [_day(4, '2026-05-19', 2400, 1)],
      items: [_rafting],
      over: {'dayToday': 7, 'tripEnded': true, 'frozen': true, 'endDate': '2026-05-22', 'dayCount': 7},
    );
    final screen = _expenses(l);
    putQueue(user: ef.rahul, ops: [
      _op('o1', 'Breakfast at Dehradun', 'Food', 600, 7, _three, 200,
          state: OpState.notSaved, fail: BuddyErrorTypes.tripExpensesFrozen, action: OpAction.remove),
    ]);
    await _render(t, '4.13b', screen);
  });

  testWidgets('4.13c not saved, trip gone', (t) async {
    TripClock.clockUtc = () => DateTime.utc(2026, 5, 10, 6);
    vf.useMemoryCache();
    Get.put<MyTripsController>(vf.FakeMyTrips(), permanent: true);
    vf.registerViewerFakes(api: vf.FakeViewerApi(sharedResult: BuddyOk(vf.sharedTrips())));
    putQueue(user: ef.rahul, lost: 1);
    await _render(t, '4.13c', const MyTripsScreen());
  });

  Future<void> profile(WidgetTester t, {required int waiting}) async {
    bf.putMe();
    final p = Get.put(PlanController());
    p.myPlan.value = MyPlanModel(paymentEnabled: false);
    Get.put(BuddySummaryController(api: bf.FakeBuddiesApi()..summaryResult = const BuddyOk(BuddySummary(buddies: 2))), permanent: true);
    putQueue(user: bf.rahulId, ops: [
      for (var i = 0; i < waiting; i++) _op('o$i', 'Lunch $i', 'Food', 900, 4, _three, 300),
    ]);
  }

  Future<void> openLogout(WidgetTester t) async {
    await t.scrollUntilVisible(find.text('Logout'), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Logout').last);
    await _settle(t);
  }

  testWidgets('4.13d logout, expenses not saved', (t) async {
    await profile(t, waiting: 2);
    await _render(t, '4.13d', const ProfileScreen(), arrange: openLogout);
  });

  testWidgets('4.13e log out anyway', (t) async {
    await profile(t, waiting: 2);
    await _render(t, '4.13e', const ProfileScreen(), arrange: (t) async {
      await openLogout(t);
      await t.tap(find.byKey(LogoutGuard.anywayKey));
      await _settle(t);
    });
  });

  testWidgets('4.13f session ended, expenses kept', (t) async {
    final l = _list(spent: 28700, days: [_day(3, '2026-05-18', 20000, 1)], items: [_taxi]);
    final screen = _expenses(l);
    putQueue(user: ef.rahul, ops: [
      _op('o1', 'Rafting in Rishikesh', 'Other', 2400, 4, _two, 0),
      _op('o2', 'Lunch at the ghat', 'Food', 1200, 4, _three, 400),
    ]);
    await _render(t, '4.13f', screen, arrange: (t) async {
      SessionEndedNotice.show(t.element(find.byType(TripExpensesScreen)), 2);
      await _settle(t);
    });
  });
}
