import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/sheets/owner_states.dart';
import 'package:bakhli/features/taxi_driver/plan_visible/choose_route_controller.dart';
import 'package:bakhli/features/taxi_driver/plan_visible/taxi_plan_visible_screen.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/owner_fakes.dart';
import '../../support/owner_sizes.dart';
import '../../support/real_phone.dart';
import 'plans_harness.dart';

Map<String, dynamic> _route(String id, int index, String to, int fare, {String type = 'OneWay'}) =>
    {'id': id, 'routeIndex': index, 'fromName': 'Haldwani', 'toName': to, 'fare': fare, 'tripType': type};

Map<String, dynamic> _taxi({int total = 4, int visible = 1}) {
  const to = ['Nainital', 'Ranikhet', 'Mukteshwar', 'Kausani', 'Almora', 'Bhimtal', 'Ramnagar', 'Pithoragarh', 'Munsiyari', 'Binsar'];
  const fares = [1800, 3000, 2600, 3800, 2900, 1500, 2200, 6000, 7000, 3300];
  final all = [for (var i = 0; i < total; i++) _route('r$i', i + 1, to[i % to.length], fares[i % fares.length])];
  return {'id': 't1', 'routes': all.take(visible).toList(), 'hiddenRoutes': all.skip(visible).toList()};
}

class FakeRouteApi extends ChooseRouteApi {
  FakeRouteApi(this.loadResult, {this.saveResult});

  OwnerResult<Map<String, dynamic>> loadResult;
  OwnerResult<Map<String, dynamic>>? saveResult;
  final List<List<String>> saves = [];
  int loads = 0;

  @override
  Future<OwnerResult<Map<String, dynamic>>> load() async {
    loads++;
    return loadResult;
  }

  @override
  Future<OwnerResult<Map<String, dynamic>>> save(List<String> routeIds) async {
    saves.add(routeIds);
    return saveResult ?? OwnerOk(const <String, dynamic>{});
  }
}

const _freeOn = MyPlanModel(paymentEnabled: true, limits: PlanLimitsModel(routes: 1), featureKey: 'Taxi');

ChooseRouteController _ctrl(FakeRouteApi api) => ChooseRouteController(api: api, userId: () => null);

void main() {
  setUp(() => PlanGate.debugPlan = _freeOn);
  tearDown(() {
    OwnerApi.debugReset();
    resetPlans();
  });

  group('controller', () {
    test('visible first, server set pre-selected, single pick swaps', () async {
      final c = _ctrl(FakeRouteApi(OwnerOk(_taxi())));
      await c.fetch();
      expect(c.state!.routes.map((r) => r.toName), ['Nainital', 'Ranikhet', 'Mukteshwar', 'Kausani']);
      expect(c.selected, ['r0']);
      expect(c.ready, isTrue);
      expect(c.dirty, isFalse);
      c.toggle('r2');
      expect(c.selected, ['r2']);
      expect(c.dirty, isTrue);
    });

    test('same set: no write', () async {
      final api = FakeRouteApi(OwnerOk(_taxi()));
      final c = _ctrl(api);
      await c.fetch();
      expect(await c.save(), ChooseRouteSave.nothingToSave);
      expect(api.saves, isEmpty);
    });

    test('save sends the ids and applies the answer', () async {
      final api = FakeRouteApi(OwnerOk(_taxi()), saveResult: OwnerOk({'routes': [_route('r1', 2, 'Ranikhet', 3000)], 'hiddenRoutes': [_route('r0', 1, 'Nainital', 1800)]}));
      final c = _ctrl(api);
      await c.fetch();
      c.toggle('r1');
      expect(await c.save(), ChooseRouteSave.done);
      expect(api.saves.single, ['r1']);
      expect(c.selected, ['r1']);
      expect(c.dirty, isFalse);
    });

    test('409 PlanVisibleLimit keeps the server line', () async {
      final api = FakeRouteApi(OwnerOk(_taxi()),
          saveResult: const OwnerRefused(type: 'PlanVisibleLimit', statusCode: 409, message: 'You can change this 3 times a day.'));
      final c = _ctrl(api);
      await c.fetch();
      c.toggle('r3');
      expect(await c.save(), ChooseRouteSave.limit);
      expect(c.limitLine.value, 'You can change this 3 times a day.');
    });

    test('400 PlanVisibleInvalid reloads', () async {
      final api = FakeRouteApi(OwnerOk(_taxi()), saveResult: const OwnerRefused(type: 'PlanVisibleInvalid', statusCode: 400));
      final c = _ctrl(api);
      await c.fetch();
      c.toggle('r3');
      expect(await c.save(), ChooseRouteSave.invalid);
      expect(api.loads, 2);
    });

    test('409 PlanVisibleNotNeeded empties', () async {
      final api = FakeRouteApi(OwnerOk(_taxi()), saveResult: const OwnerRefused(type: 'PlanVisibleNotNeeded', statusCode: 409));
      final c = _ctrl(api);
      await c.fetch();
      c.toggle('r3');
      expect(await c.save(), ChooseRouteSave.notNeeded);
      expect(c.load.value, isA<OwnerLoadEmpty<ChooseRouteState>>());
    });

    test('nothing hidden: empty (screen pops)', () async {
      final c = _ctrl(FakeRouteApi(OwnerOk(_taxi(total: 1))));
      await c.fetch();
      expect(c.load.value, isA<OwnerLoadEmpty<ChooseRouteState>>());
    });

    test('limit 5 of 8 routes: pick up to 5, Save only at 5', () async {
      PlanGate.debugPlan = const MyPlanModel(paymentEnabled: true, limits: PlanLimitsModel(routes: 5));
      final c = _ctrl(FakeRouteApi(OwnerOk(_taxi(total: 8, visible: 5))));
      await c.fetch();
      expect(c.selected.length, 5);
      c.toggle('r0');
      expect(c.ready, isFalse);
      c.toggle('r7');
      expect(c.ready, isTrue);
      c.toggle('r6');
      expect(c.selected.length, 5);
    });

    test('offline with nothing saved: offline state', () async {
      final c = _ctrl(FakeRouteApi(const OwnerOffline()));
      await c.fetch();
      expect(c.load.value, isA<OwnerLoadOffline<ChooseRouteState>>());
    });

    test('FT-04: the answer meter wins over a stale plan (admin revoke while open)', () async {
      PlanGate.debugPlan = const MyPlanModel(paymentEnabled: true, limits: PlanLimitsModel(routes: 5));
      final data = {..._taxi(), 'routesMeter': {'key': 'Routes', 'used': 1, 'limit': 1}, 'paymentEnabled': true};
      final c = _ctrl(FakeRouteApi(OwnerOk(data)));
      await c.fetch();
      expect(c.state!.limit, 1);
      expect(c.state!.target, 1);
      expect(c.selected.length, 1);
      expect(c.ready, isTrue);
    });

    test('FT-04: meters list also carries the limit; payment flag from the answer', () async {
      final data = {..._taxi(total: 6, visible: 1), 'meters': [{'key': 'Routes', 'used': 1, 'limit': 3}], 'paymentEnabled': true};
      final c = _ctrl(FakeRouteApi(OwnerOk(data)));
      await c.fetch();
      expect(c.state!.target, 3);
      final off = _ctrl(FakeRouteApi(OwnerOk({..._taxi(), 'paymentEnabled': false})));
      await off.fetch();
      expect(off.load.value, isA<OwnerLoadEmpty<ChooseRouteState>>());
      expect(off.paymentOff, isTrue);
    });

    test('every wrong shape parses without a throw', () {
      for (final v in jsonVariants(_taxi())) {
        ChooseRouteState.fromJson(v, limit: 1);
      }
    });
  });

  group('screen', () {
    Future<FakeRouteApi> pump(WidgetTester t, Map<String, dynamic> data, {Size size = const Size(392, 800)}) async {
      final api = FakeRouteApi(OwnerOk(data));
      final c = Get.put(_ctrl(api), tag: ChooseRouteController.tag);
      await pumpPhone(t, TaxiPlanVisibleScreen(controller: c), size: size);
      await settlePhone(t);
      return api;
    }

    testWidgets('o_tx_45 B strings', (t) async {
      await pump(t, _taxi());
      for (final s in [
        'Choose your route', 'Free rings on 1 route', 'Haldwani to Nainital', 'One way · ₹1,800', 'Haldwani to Ranikhet', 'One way · ₹3,000',
        'Haldwani to Mukteshwar', 'One way · ₹2,600', 'Haldwani to Kausani', 'One way · ₹3,800',
        'Hidden routes are kept. They ring again as soon as you are on Plus.', 'You can change this 3 times a day.', 'Save', 'See Plus',
      ]) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.byKey(GateKeys.seePlus), findsOneWidget);
    });

    testWidgets('tap another row and save', (t) async {
      final api = await pump(t, _taxi());
      await t.tap(find.text('Haldwani to Mukteshwar'));
      await t.pump();
      await t.tap(find.text('Save'));
      await settlePhone(t);
      expect(api.saves.single, ['r2']);
    });

    testWidgets('FT-04: header from the answer even with a stale plan', (t) async {
      PlanGate.debugPlan = const MyPlanModel(paymentEnabled: true, limits: PlanLimitsModel(routes: 5));
      await pump(t, {..._taxi(), 'routesMeter': {'key': 'Routes', 'used': 1, 'limit': 1}, 'paymentEnabled': true});
      expect(find.text('Free rings on 1 route'), findsOneWidget);
      expect(find.text('Free rings on 5 routes'), findsNothing);
    });

    testWidgets('FT-04: PlanVisibleInvalid shows the changed-on-another-phone line', (t) async {
      final api = FakeRouteApi(OwnerOk(_taxi()), saveResult: const OwnerRefused(type: 'PlanVisibleInvalid', statusCode: 400));
      final c = Get.put(_ctrl(api), tag: ChooseRouteController.tag);
      await pumpPhone(t, TaxiPlanVisibleScreen(controller: c), size: const Size(392, 800), toastHost: true);
      await settlePhone(t);
      await t.tap(find.text('Haldwani to Mukteshwar'));
      await t.pump();
      await t.tap(find.text('Save'));
      await settlePhone(t);
      expect(api.loads, 2, reason: 'refetched before the line is shown');
      expect(find.byType(TaxiPlanVisibleScreen), findsOneWidget, reason: 'stays open on the fresh list');
      await t.pump(const Duration(seconds: 6));
    });

    testWidgets('payment OFF: no gate key and the screen leaves', (t) async {
      PlanGate.debugPlan = const MyPlanModel(paymentEnabled: false, limits: PlanLimitsModel(routes: 5));
      final api = await pump(t, _taxi());
      expect(api.loads, 1, reason: 'the answer decides, not the cached plan (FT-04)');
      expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
    });

    testWidgets('dispose removes the owned controller', (t) async {
      OwnerApi.transport = FakeTransport((m, p, b) async => {'data': _taxi()});
      await pumpPhone(t, const TaxiPlanVisibleScreen(), size: const Size(392, 800));
      await t.pump();
      expect(Get.isRegistered<ChooseRouteController>(tag: ChooseRouteController.tag), isTrue);
      await t.pumpWidget(const SizedBox.shrink());
      expect(Get.isRegistered<ChooseRouteController>(tag: ChooseRouteController.tag), isFalse);
    });

    for (final n in [1, 4, 10]) {
      testOwnerSizes(
        'choose route $n rows',
        () => TaxiPlanVisibleScreen(controller: Get.find<ChooseRouteController>(tag: ChooseRouteController.tag)),
        setUpEach: () {
          PlanGate.debugPlan = _freeOn;
          Get.put(_ctrl(FakeRouteApi(OwnerOk(_taxi(total: n == 1 ? 2 : n)))), tag: ChooseRouteController.tag);
        },
        arrange: settlePhone,
      );
    }
  });
}
