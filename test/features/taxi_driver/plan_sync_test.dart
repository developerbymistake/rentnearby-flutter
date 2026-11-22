import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/plan/plan_bindings.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/session/owner_plan_sync.dart';
import 'package:bakhli/features/owner_core/session/owner_push_sync.dart';
import 'package:bakhli/features/owner_core/session/owner_session_hooks.dart';
import 'package:bakhli/features/owner_core/sheets/owner_states.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_calendar_controller.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_controller.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_controller.dart';
import 'package:bakhli/features/taxi_driver/plan/taxi_home_plan_card.dart';
import 'package:bakhli/features/taxi_driver/taxi_driver_session.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/owner_fakes.dart';
import 'calendar/taxi_cal_fixtures.dart';
import 'core/taxi_fixtures.dart';

// FT-02 / FT-03 / FT-06 / FT-16: plan change and driver pushes while the app is open.

const _ended = {
  'paymentEnabled': true,
  'limits': {'routes': 1},
  'status': 'Expired',
  'hidden': {'routes': 3},
};
const _plus = {
  'paymentEnabled': true,
  'isPaid': true,
  'limits': {'routes': 5, 'ringWeight': 2, 'calendarEntries': 50, 'monthSummary': true, 'reminders': true},
  'endsAt': '2026-12-21T00:00:00Z',
};

class _Rig {
  _Rig(this.plans, this.home, this.homeApi, this.cal, this.calFake, this.hubCalls);

  final FakePlanRepository plans;
  final TaxiDriverHomeController home;
  final FakeHomeApi homeApi;
  final TaxiCalendarController cal;
  final CalFake calFake;
  final List<int> hubCalls;
}

Future<_Rig> _rig({DateTime Function()? clock}) async {
  final h = TaxiHarness.setUp(homeJson());
  PlanGate.debugPlan = null;
  final plans = FakePlanRepository([_ended]);
  Get.put<PlanRepository>(plans, permanent: true);
  PlanBindings.ensure();
  await pumpEventQueue();
  final calFake = CalFake(months: {'2026-11': monthJson(entries: novEntries(), plus: true)});
  OwnerApi.transport = calFake.transport;
  final cal = Get.put(TaxiCalendarController(clock: clock ?? () => calToday, userIdOf: () => 'user-a'), tag: TaxiCalendarController.tag);
  final hubCalls = <int>[0];
  Get.put(
    TaxiHubController(
      userId: () => 'user-a',
      fetch: () async {
        hubCalls[0]++;
        return {'data': taxiJson()};
      },
    ),
    tag: TaxiHubController.tag,
  );
  TaxiDriverSession.register();
  await pumpEventQueue();
  await cal.open(DateTime(2026, 11));
  await pumpEventQueue();
  return _Rig(plans, h.home, h.api, cal, calFake, hubCalls);
}

void main() {
  setUpAll(() => initTestStorage('taxi_plan_sync'));
  tearDown(() async {
    await OwnerSessionHooks.onLogout(LogoutReason.explicitLogout, 'user-a');
    OwnerPlanSync.reset();
    PlanBindings.dispose();
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  test('Ended -> Plus: one Home reload, one hub reload, one calendar month + summary reload', () async {
    final r = await _rig();
    final home0 = r.homeApi.calls;
    final hub0 = r.hubCalls[0];
    int months() => r.calFake.calls.where((c) => c == 'GET /taxis/me/calendar').length;
    final month0 = months();
    final sum0 = r.calFake.count('GET /taxis/me/calendar/summary');
    r.plans.bodies
      ..clear()
      ..add(_plus);
    await Get.find<PlanController>().invalidate();
    expect(Get.find<PlanController>().planVersion.value, 1);
    await Future<void>.delayed(OwnerPlanSync.debounce + const Duration(milliseconds: 50));
    await pumpEventQueue();
    expect(r.homeApi.calls - home0, 1);
    expect(r.hubCalls[0] - hub0, 1);
    expect(months() - month0, 1);
    expect(r.calFake.count('GET /taxis/me/calendar/summary') - sum0, 1);
  });

  test('same /plans/me answer twice: no reload', () async {
    final r = await _rig();
    final home0 = r.homeApi.calls;
    await Get.find<PlanController>().invalidate();
    await Future<void>.delayed(OwnerPlanSync.debounce + const Duration(milliseconds: 50));
    expect(r.homeApi.calls, home0);
  });

  test('a taxi_selected push reloads Home once; five pushes in 300 ms = one load', () async {
    final r = await _rig();
    final home0 = r.homeApi.calls;
    OwnerPushSync.onPush('taxi_selected', null, const {'offerId': 'o1'});
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(r.homeApi.calls - home0, 1);
    for (var i = 0; i < 5; i++) {
      OwnerPushSync.onPush('taxi_selected', null, const {});
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(r.homeApi.calls - home0, 2);
  });

  test('FT-16: only booking cancelled, trip ended and booked reload the calendar month', () async {
    final r = await _rig();
    int months() => r.calFake.calls.where((c) => c == 'GET /taxis/me/calendar').length;
    final m0 = months();
    for (final t in ['taxi_request_ring', 'taxi_request_ring_ended', 'taxi_not_selected', 'taxi_rings_missed', 'festival_reminder']) {
      OwnerPushSync.onPush(t, null, const {});
    }
    await pumpEventQueue();
    expect(months(), m0);
    OwnerPushSync.onPush('taxi_booking_cancelled', null, const {});
    await pumpEventQueue();
    expect(months(), m0 + 1);
    expect(TaxiDriverSession.reloadsCalendar('taxi_trip_ended'), isTrue);
    expect(TaxiDriverSession.reloadsCalendar('plan_limits_changed'), isFalse, reason: 'D-01: plan pushes go through OwnerPlanSync');
    expect(TaxiDriverSession.reloadsHome('plan_limits_changed'), isFalse);
  });

  test('FT-03: calendar tab revisit after 31 s loads once; after 5 s loads nothing', () async {
    var now = DateTime(2026, 11, 21, 10);
    final r = await _rig(clock: () => now);
    final auth = Get.find<AuthController>();
    int months() => r.calFake.calls.where((c) => c == 'GET /taxis/me/calendar').length;
    auth.tabIndex.value = AppTabs.home;
    final m0 = months();
    now = now.add(const Duration(seconds: 5));
    auth.tabIndex.value = AppTabs.fourth;
    await pumpEventQueue();
    expect(months(), m0);
    auth.tabIndex.value = AppTabs.home;
    now = now.add(const Duration(seconds: 31));
    auth.tabIndex.value = AppTabs.fourth;
    await pumpEventQueue();
    expect(months(), m0 + 1);
  });

  test('FT-02.3: the feed plan card is used only when it is newer than the last plan change', () {
    final t0 = DateTime(2026, 11, 21, 10);
    expect(TaxiHomePlanCard.feedCardFresh(t0, true, null), isTrue);
    expect(TaxiHomePlanCard.feedCardFresh(t0, true, t0.add(const Duration(seconds: 1))), isFalse);
    expect(TaxiHomePlanCard.feedCardFresh(t0.add(const Duration(seconds: 2)), true, t0), isTrue);
    expect(TaxiHomePlanCard.feedCardFresh(null, true, t0), isFalse);
    expect(TaxiHomePlanCard.feedCardFresh(t0, false, null), isFalse);
  });

  test('FT-06: 404 ListingNotFound after data drops the dashboard and the cache (Empty)', () async {
    final h = TaxiHarness.setUp(homeJson());
    await h.home.reload();
    expect(h.home.load.value, isA<OwnerLoadData<OwnerHomeDto>>());
    expect(OwnerCache.read('user-a', OwnerCacheKeys.home), isNotNull);
    h.api.result = () async => const OwnerRefused<OwnerHomeDto>(type: 'ListingNotFound', statusCode: 404);
    await h.home.reload();
    expect(h.home.load.value, isA<OwnerLoadEmpty<OwnerHomeDto>>());
    expect(OwnerCache.read('user-a', OwnerCacheKeys.home), isNull);
  });

  test('FT-06: other refusals keep the last dashboard (stale)', () async {
    final h = TaxiHarness.setUp(homeJson());
    await h.home.reload();
    h.api.result = () async => const OwnerRefused<OwnerHomeDto>(type: 'Boom', statusCode: 500);
    await h.home.reload();
    final v = h.home.load.value;
    expect(v, isA<OwnerLoadData<OwnerHomeDto>>());
    expect((v as OwnerLoadData<OwnerHomeDto>).stale, isTrue);
  });

  test('forced reload while a load is in flight runs one more load after it', () async {
    final h = TaxiHarness.setUp(homeJson());
    await pumpEventQueue();
    final c0 = h.api.calls;
    final a = h.home.reload();
    final b = h.home.reload(force: true);
    final c = h.home.reload(force: true);
    await Future.wait([a, b, c]);
    expect(h.api.calls - c0, 2);
  });
}
