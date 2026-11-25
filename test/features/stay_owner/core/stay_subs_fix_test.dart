import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_error_types.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/plan/plan_keys.dart';
import 'package:bakhli/features/stay/setup/stay_rooms_screen.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_list_controller.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_upcoming_screen.dart';
import 'package:bakhli/features/stay_owner/stay_owner_session.dart';
import 'package:bakhli/features/stay_owner/strings/stay_gate_strings_calendar.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import '../calendar/calendar_fixtures.dart';
import 'stay_setup_fixtures.dart';

class _TrialRepo extends FakePlanRepository {
  _TrialRepo(super.bodies);

  @override
  Future<MyPlanModel> startTrial(String planId) async => MyPlanModel.fromJson(const {
        'paymentEnabled': true,
        'paymentProvider': 'Razorpay',
        'isPaid': true,
        'source': 'Trial',
        'limits': {'photos': 8, 'roomTypes': 6},
      });
}

const _freeMe = {
  'paymentEnabled': true,
  'paymentProvider': 'Razorpay',
  'limits': {'photos': 2, 'roomTypes': 2},
};

Future<void> _settle(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _dropToasts(WidgetTester t) async {
  await t.pump(const Duration(seconds: 6));
  toastification.dismissAll(delayForAnimation: false);
  await t.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() => initTestStorage('stay_subs_fix'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  group('S1 rooms page cold start', () {
    testWidgets('loads the saved rooms before showing the form', (t) async {
      setupFor(null, stayStatus: 'Approved');
      FakeStayRepo.last!.model = stayModel(draftJson(step1: true, rooms: true, rules: true, status: 'Approved'));
      await pumpPhone(t, const StayRoomsScreen(manage: true), size: const Size(360, 1400), toastHost: true);
      await _settle(t);
      expect(find.text('ROOM 1'), findsOneWidget);
      expect(find.text('ROOM 2'), findsOneWidget);
      expect(find.text('Room Type'), findsNothing);
      expect(find.text('Save'), findsNothing);
      await _dropToasts(t);
    });

    testWidgets('Save with no stay loaded never sends a partial room list', (t) async {
      setupFor(null, stayStatus: 'Approved', loadError: Exception('offline'));
      final repo = FakeStayRepo.last!;
      await pumpPhone(t, const StayRoomsScreen(manage: true), size: const Size(360, 1400), toastHost: true);
      await _settle(t);
      repo
        ..loadError = null
        ..model = stayModel(draftJson(step1: true, rooms: true, rules: true, status: 'Approved'));
      await t.tap(find.text('Save'));
      await _settle(t);
      expect(repo.calls.contains('rooms'), isFalse);
      expect(find.text('ROOM 1'), findsOneWidget);
      expect(find.text('ROOM 2'), findsOneWidget);
      await _dropToasts(t);
    });
  });

  group('S2 plan change without the hub', () {
    test('reloads the setup stay and the Upcoming list', () async {
      final c = setupFor(stayModel(draftJson(step1: true, rooms: true, status: 'Approved')), stayStatus: 'Approved');
      FakeStayRepo.last!.model = stayModel({...draftJson(step1: true, rooms: true, status: 'Approved'), 'name': 'After plan change'});
      var pages = 0;
      Get.put(
        StayListController(loader: (_) async {
          pages++;
          return const OwnerOk<Map<String, dynamic>>({'items': [], 'nextCursor': null});
        }),
        tag: StayUpcomingScreen.listTag,
      );
      StayOwnerSession.onPlanChanged();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.stay.value?.name, 'After plan change');
      expect(pages, 1);
    });
  });

  group('S4 shared plan files', () {
    testWidgets('handleInactive asks /plans/me again', (t) async {
      final repo = FakePlanRepository([_freeMe]);
      Get.put<PlanRepository>(repo, permanent: true);
      Get.put(PlanController());
      await pumpPhone(t, const Scaffold(body: Text('page')), toastHost: true);
      await _settle(t);
      final before = repo.meCalls;
      expect(PlanGate.handleInactive(const OwnerRefused<void>(type: 'StaleEdit', statusCode: 409)), isFalse);
      expect(repo.meCalls, before);
      expect(PlanGate.handleInactive(const OwnerRefused<void>(type: OwnerErrorTypes.planRowInactive, statusCode: 409)), isTrue);
      await _settle(t);
      expect(repo.meCalls, before + 1);
      await _dropToasts(t);
    });

    testWidgets('startTrial stores the plan and bumps planVersion', (t) async {
      Get.put<PlanRepository>(_TrialRepo([_freeMe]), permanent: true);
      final c = Get.put(PlanController());
      await pumpPhone(t, const Scaffold(body: Text('page')), toastHost: true);
      await _settle(t);
      final v = c.planVersion.value;
      late bool ok;
      await t.runAsync(() async => ok = await c.startTrial('plus'));
      await t.pump();
      expect(ok, isTrue);
      expect(c.planVersion.value, v + 1);
      expect(c.loaded.value, isTrue);
      expect(c.myPlan.value.isPaid, isTrue);
      await _dropToasts(t);
    });
  });

  group('S6 Upcoming inactive rows', () {
    testWidgets('an inactive manual row shows Delete only and deletes', (t) async {
      final h = CalendarHarness.setUp(
        registerCalendar: false,
        extra: (p) => p.endsWith('/upcoming')
            ? {
                'items': [
                  entryJson('neha', '2026-11-22', '2026-11-23', 'Neha Joshi', auto: true, roomNames: 'Family Room'),
                  {...entryJson('late', '2027-01-10', '2027-01-11', 'Late group'), 'inactiveByPlan': true},
                ],
                'nextCursor': null,
                'hiddenCount': 0,
                'beyondWindowAppCount': 0,
              }
            : null,
      );
      await pumpPhone(t, StayUpcomingScreen(clock: calClock), size: const Size(392, 1600), toastHost: true);
      await _settle(t);
      expect(find.byKey(GateKeys.inactiveRow), findsOneWidget);
      expect(find.text(StayGateStringsCalendar.entryInactive(PlanGate.limit(PlanKey.calendarEntries))), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      await t.tap(find.text('Delete'));
      await _settle(t);
      expect(find.text('Delete this booking?'), findsOneWidget);
      await t.tap(find.text('Delete').last);
      await _settle(t);
      expect(h.transport.calls, contains('DELETE /stays/me/calendar/entries/late'));
      await _dropToasts(t);
    });
  });
}
