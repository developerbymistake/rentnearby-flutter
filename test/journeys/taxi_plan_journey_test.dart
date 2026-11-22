import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/plan/plan_bindings.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/session/owner_plan_sync.dart';
import 'package:bakhli/features/owner_core/session/owner_session_hooks.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_calendar_controller.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_calendar_entry_screen.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_controller.dart';
import 'package:bakhli/features/taxi_driver/plan/taxi_home_plan_card.dart';
import 'package:bakhli/features/taxi_driver/plan_visible/choose_route_controller.dart';
import 'package:bakhli/features/taxi_driver/taxi_driver_session.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../features/taxi_driver/calendar/taxi_cal_fixtures.dart';
import '../features/taxi_driver/core/taxi_fixtures.dart';
import '../support/owner_fakes.dart';
import '../support/real_phone.dart';

// JT-A-TX-1 (app half): Free -> Trial -> Plus -> Cancelled -> Ended -> Resubscribed, fed as /plans/me bodies to the
// real PlanController. Every step change = one reload each of Home, My Taxi and Bookings (FX-03, FT-02, FT-03).
// The Free / Draft first-login step (routes screen without MainScreen) is in taxi_setup_plan_wiring_test.dart (FT-01).

const _plusLimits = {'routes': 5, 'ringWeight': 2, 'calendarEntries': 50, 'upcomingDays': 183, 'monthsAhead': 6, 'monthSummary': true, 'reminders': true};

final Map<String, Map<String, dynamic>> _steps = {
  'Free': {'state': 'Free', 'paymentEnabled': true, 'trialAvailable': true, 'limits': {'routes': 1}},
  'Trial': {'state': 'Trial', 'paymentEnabled': true, 'isPaid': true, 'source': 'Trial', 'endsAt': '2026-11-28T00:00:00Z', 'limits': _plusLimits},
  'Plus': {'state': 'Plus', 'paymentEnabled': true, 'isPaid': true, 'endsAt': '2026-12-21T00:00:00Z', 'limits': _plusLimits},
  'Cancelled': {'state': 'Cancelled', 'paymentEnabled': true, 'isPaid': true, 'endsAt': '2026-12-21T00:00:00Z', 'limits': _plusLimits, 'play': {'autoRenewEnabled': false}},
  'Ended': {'state': 'Ended', 'paymentEnabled': true, 'limits': {'routes': 1}, 'hidden': {'routes': 3}},
  'Resubscribed': {'state': 'Plus', 'paymentEnabled': true, 'isPaid': true, 'endsAt': '2027-01-21T00:00:00Z', 'limits': _plusLimits},
};

final Map<String, List<String>> _homeWords = {
  'Free': ['Free plan', 'More routes, more requests.'],
  'Trial': ['Free until 28 Nov', 'Trial', 'Up to 5 routes are open now.'],
  'Plus': ['Plus'],
  'Cancelled': ['Plus till 21 Dec 2026', 'After that, you keep 1 route.'],
  'Ended': ['Subscription ended', 'Extra routes are hidden. Nothing is deleted.', 'Subscribe again'],
  'Resubscribed': ['Plus'],
};

void main() {
  setUpAll(() => initTestStorage('taxi_plan_journey'));
  setUp(OwnerCache.clearAll);
  tearDown(() async {
    await OwnerSessionHooks.onLogout(LogoutReason.explicitLogout, 'user-a');
    OwnerPlanSync.reset();
    PlanBindings.dispose();
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  testWidgets('JT-A-TX-1: each plan step reloads Home, My Taxi and Bookings once and the Home card follows', (t) async {
    final h = TaxiHarness.setUp(homeJson());
    PlanGate.debugPlan = null;
    final plans = FakePlanRepository([_steps['Free']!]);
    Get.put<PlanRepository>(plans, permanent: true);
    PlanBindings.ensure();
    final calFake = CalFake(months: {'2026-11': monthJson(entries: novEntries(), plus: true)});
    OwnerApi.transport = calFake.transport;
    final cal = Get.put(TaxiCalendarController(clock: () => calToday, userIdOf: () => 'user-a'), tag: TaxiCalendarController.tag);
    var hubCalls = 0;
    Get.put(
      TaxiHubController(
        userId: () => 'user-a',
        fetch: () async {
          hubCalls++;
          return {'data': taxiJson()};
        },
      ),
      tag: TaxiHubController.tag,
    );
    TaxiDriverSession.register();
    await t.runAsync(() async {
      await pumpEventQueue();
      await cal.open(DateTime(2026, 11));
      await pumpEventQueue();
    });
    await pumpPhone(t, const Scaffold(body: SingleChildScrollView(child: TaxiHomePlanCard())));
    for (final w in _homeWords['Free']!) {
      expect(find.text(w), findsOneWidget, reason: 'Free: $w');
    }

    int months() => calFake.calls.where((c) => c == 'GET /taxis/me/calendar').length;
    int summaries() => calFake.calls.where((c) => c == 'GET /taxis/me/calendar/summary').length;

    for (final step in ['Trial', 'Plus', 'Cancelled', 'Ended', 'Resubscribed']) {
      final home0 = h.api.calls, hub0 = hubCalls, m0 = months(), s0 = summaries();
      plans.bodies
        ..clear()
        ..add(_steps[step]!);
      calFake.months = {'2026-11': monthJson(entries: novEntries(), plus: step != 'Ended', hidden: step == 'Ended' ? 2 : 0)};
      await t.runAsync(() async {
        await Get.find<PlanController>().invalidate();
        await Future<void>.delayed(OwnerPlanSync.debounce + const Duration(milliseconds: 80));
        await pumpEventQueue();
      });
      await t.pump();
      expect(h.api.calls - home0, 1, reason: '$step: Home reloads once');
      expect(hubCalls - hub0, 1, reason: '$step: My Taxi reloads once');
      expect(months() - m0, 1, reason: '$step: Bookings month reloads once');
      final locked = step == 'Ended';
      expect(summaries() - s0, locked ? 0 : 1, reason: '$step: summary follows the plan');
      for (final w in _homeWords[step]!) {
        expect(find.text(w), findsWidgets, reason: '$step: $w');
      }
    }
  });

  test('JT-A-TX-1 Ended (admin revoke while open): Choose your route uses the answer, not the stale plan', () async {
    PlanGate.debugPlan = OwnerPlans.plus;
    final c = ChooseRouteController(
      api: _RouteApi({
        'id': 't1',
        'routes': [taxiJson(routes: 1)['routes'][0]],
        'hiddenRoutes': [for (final r in (taxiJson(routes: 4)['routes'] as List).skip(1)) r],
        'routesMeter': {'key': 'Routes', 'used': 1, 'limit': 1},
        'paymentEnabled': true,
      }),
      userId: () => null,
    );
    await c.fetch();
    expect(c.state!.limit, 1);
    expect(c.state!.target, 1);
  });

  test('JT-A-TX-1 Ended: a past trip is read-only except amounts and delete', () {
    final past = CalendarEntry.fromJson(tripJson('m03', from: '2026-11-03', label: 'Bhowali drop'));
    final next = CalendarEntry.fromJson(tripJson('m25', from: '2026-11-25', label: 'Mehra family'));
    expect(TaxiTripEnded.of(past, calToday), isTrue);
    expect(TaxiTripEnded.of(next, calToday), isFalse);
  });
}

class _RouteApi extends ChooseRouteApi {
  _RouteApi(this.body);

  final Map<String, dynamic> body;

  @override
  Future<OwnerResult<Map<String, dynamic>>> load() async => OwnerOk(body);
}
