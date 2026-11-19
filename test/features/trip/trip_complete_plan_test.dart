import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_trip_card.dart';
import 'package:bakhli/features/trip/widgets/trip_lifecycle_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../journeys/fake_api.dart';
import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';
import 'support/engine_rig.dart';

class _Trips extends MyTripsController {
  int loads = 0;
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> load({bool refresh = false}) async => loads++;
}

class _Plan extends TripPlanController {
  final List<String> calls = [];
  @override
  Future<bool> flushPendingSave() async {
    calls.add('flush');
    return true;
  }

  @override
  Future<void> reloadFromServer() async => calls.add('reload');
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

TripSummaryModel _summary({TripRowState taxi = TripRowState.todo, TripRowState stay = TripRowState.todo}) => TripSummaryModel(
      id: 't1',
      title: 'Hills',
      status: 'Planned',
      cityName: 'Nainital',
      dayCount: 3,
      spotCount: 6,
      category: 'trip',
      updatedAt: DateTime(2026, 11, 1),
      progress: TripProgress(rows: [
        TripEasyRowModel(key: const TripEasyRowKey(TripEasyRowKind.stay, 1), state: stay),
        TripEasyRowModel(key: const TripEasyRowKey(TripEasyRowKind.taxi), state: taxi),
      ]),
    );

Widget _card({VoidCallback? onCompletePlan}) => Scaffold(
      body: ListView(children: [
        HubTripCard(
          trip: _summary(),
          onOpen: () {},
          onAction: () {},
          onShare: () {},
          onDelete: () {},
          onCompletePlan: onCompletePlan,
        ),
      ]),
    );

class _ConfirmHost extends StatelessWidget {
  const _ConfirmHost({required this.taxi, required this.stay, required this.result});
  final bool taxi;
  final bool stay;
  final List<bool> result;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey('open'),
            onPressed: () async => result.add(await TripLifecycleActions.confirmCompletePlan(context, taxi: taxi, stay: stay)),
            child: const Text('open'),
          ),
        ),
      );
}

Future<void> _openMenu(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('hub-card-menu')));
  await t.pumpAndSettle();
}

void main() {
  testFiveSizes('menu shows Complete my plan between Share and Delete', () => _card(onCompletePlan: () {}), check: (t, _) async {
    await _openMenu(t);
    expect(t.takeException(), isNull);
    final share = t.getTopLeft(find.text('Share')).dy;
    final plan = t.getTopLeft(find.text('Complete my plan')).dy;
    final delete = t.getTopLeft(find.text('Delete')).dy;
    expect(share < plan && plan < delete, isTrue);
  });

  testWidgets('menu hides the item without a callback', (t) async {
    await pumpAtSize(t, _card(), phoneSize);
    await _openMenu(t);
    expect(find.text('Complete my plan'), findsNothing);
  });

  testWidgets('menu item calls back once per tap', (t) async {
    var n = 0;
    await pumpAtSize(t, _card(onCompletePlan: () => n++), phoneSize);
    await _openMenu(t);
    await t.tap(find.text('Complete my plan'));
    await t.pumpAndSettle();
    expect(n, 1);
  });

  group('confirm box names the missing parts', () {
    final cases = <String, (bool, bool, String)>{
      'both': (true, true, 'Complete this plan without taxi and stay? You can still add them any time.'),
      'taxi': (true, false, 'Complete this plan without a taxi? You can still add one any time.'),
      'stay': (false, true, 'Complete this plan without a stay? You can still add one any time.'),
    };
    for (final e in cases.entries) {
      testFiveSizes('${e.key} text', () => _ConfirmHost(taxi: e.value.$1, stay: e.value.$2, result: []), check: (t, _) async {
        await t.tap(find.byKey(const ValueKey('open')));
        await t.pumpAndSettle();
        expect(find.text('Complete this plan?'), findsOneWidget);
        expect(find.text(e.value.$3), findsOneWidget);
        expect(find.byKey(const ValueKey('complete-plan-yes')), findsOneWidget);
        expect(find.byKey(const ValueKey('complete-plan-back')), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('complete-plan-back')));
        await t.pumpAndSettle();
      });
    }

    testWidgets('Go back answers false, Complete answers true', (t) async {
      final result = <bool>[];
      await pumpAtSize(t, _ConfirmHost(taxi: true, stay: true, result: result), phoneSize);
      await t.tap(find.byKey(const ValueKey('open')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('complete-plan-back')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('open')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('complete-plan-yes')));
      await t.pumpAndSettle();
      expect(result, [false, true]);
    });
  });

  group('controller', () {
    tearDown(Get.reset);

    test('posts complete-plan once and reloads the list', () async {
      final plan = TripPlan.singleCity(cityKey: 1, cityName: 'Nainital', days: [TripDay(day: 1, spots: const [])]);
      final api = installFakeApi([FakeRoute.value('POST', '/trips/{id}/complete-plan', engineTripJson(plan))]);
      final c = _Trips();
      expect(await c.completePlan('t1'), isTrue);
      expect(api.calls('POST', '/trips/t1/complete-plan'), hasLength(1));
      expect(c.loads, 1);
    });

    test('a held plan is flushed before and reloaded after the call', () async {
      final plan = TripPlan.singleCity(cityKey: 1, cityName: 'Nainital', days: [TripDay(day: 1, spots: const [])]);
      final api = installFakeApi([FakeRoute.value('POST', '/trips/{id}/complete-plan', engineTripJson(plan))]);
      Get.put<TabConfigController>(_Tabs());
      final p = Get.put<TripPlanController>(_Plan()) as _Plan;
      p.trip.value = TripModel.fromJson(engineTripJson(plan));
      final id = p.trip.value!.id;
      expect(await _Trips().completePlan(id), isTrue);
      expect(api.calls('POST', '/trips/$id/complete-plan'), hasLength(1));
      expect(p.calls, ['flush', 'reload']);
      expect(await _Trips().completePlan('other'), isTrue);
      expect(p.calls, ['flush', 'reload']);
    });

    test('a failed call answers false and does not reload', () async {
      final api = installFakeApi([FakeRoute.value('POST', '/trips/{id}/complete-plan', null, code: 409, errorType: 'TripCompleted')]);
      final c = _Trips();
      expect(await c.completePlan('t1'), isFalse);
      expect(api.calls('POST', '/trips/t1/complete-plan'), hasLength(1));
      expect(c.loads, 0);
    });
  });
}
