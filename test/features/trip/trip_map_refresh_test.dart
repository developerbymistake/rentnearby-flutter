import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_leg_draft.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../journeys/fake_api.dart';
import 'support/engine_rig.dart';

TripLegDraft _draft(TripPlanController c, int legIndex) {
  final p = c.plan.value!;
  return TripLegDraft.from(
    p,
    legIndex,
    frozenDays: 0,
    otherLegsDayCount: p.days.length - p.legDayCount(legIndex),
    otherLegsSpotCount: p.spotCount - p.legSpotCount(legIndex),
  );
}

// The fake planner draws each day as a line through its spots, so equal geometry means equal places in order.
FakeTripAdapter _planner() => installFakeApi([
      FakeRoute('POST', '/trips/plan', (o) {
        final body = o.data as Map;
        return {
          'days': [
            for (final d in (body['days'] as List? ?? const []))
              {
                'day': (d as Map)['day'],
                'spotIds': [for (final s in d['spots'] as List) (s as Map)['id']],
                'visitMinutes': 60,
                'totalMinutes': 90,
                'routeGeoJson': {
                  'type': 'LineString',
                  'spots': [for (final s in d['spots'] as List) (s as Map)['id']],
                },
              },
          ],
          'osrmAvailable': true,
          'dayLimitMinutes': 300,
        };
      }),
      FakeRoute('PUT', '/trips/{id}', (o) {
        final body = o.data as Map;
        return engineTripJson(TripPlan.fromJson(Map<String, dynamic>.from(body['plan'] as Map)));
      }),
    ]);

int _planCalls(FakeTripAdapter api, int cityKey) =>
    api.calls('POST', '/trips/plan').where((o) => (o.data as Map)['cityKey'] == cityKey).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('map_refresh_gs').path);
    await GetStorage.init();
  });
  tearDown(Get.reset);

  test('redraw_signature_changes_after_apply', () {
    _planner();
    final c = engineRig(enginePlan([[2, 2], [2]]));
    final before = c.mapRedrawSignature(c.plan.value!);

    final unchanged = _draft(c, 1);
    expect(c.applyLegDraft(1, unchanged), TripLegApplyBlock.none);
    expect(c.mapRedrawSignature(c.plan.value!), before);

    final d = _draft(c, 1);
    expect(d.move('L1d1s0', 1, 0), TripDraftBlock.none);
    expect(c.applyLegDraft(1, d), TripLegApplyBlock.none);
    final moved = c.mapRedrawSignature(c.plan.value!);
    expect(moved, isNot(before));

    final grow = _draft(c, 1);
    expect(grow.addDay(), TripDraftBlock.none);
    expect(grow.move('L1d1s0', 2, 0), TripDraftBlock.none);
    expect(c.applyLegDraft(1, grow), TripLegApplyBlock.none);
    expect(c.plan.value!.days.length, 4);
    expect(c.mapRedrawSignature(c.plan.value!), isNot(moved));
  });

  test('map_screen_redraws_on_the_tested_signature', () {
    String read(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');
    final screen = read('lib/features/trip/screens/trip_map_screen.dart');
    if (screen.contains('_plan.mapRedrawSignature(') && !screen.contains('String _signature(TripPlan')) return;
    final controller = read('lib/features/trip/controllers/trip_plan_controller.dart');
    String body(String src, String head) {
      final start = src.indexOf(head);
      expect(start, isNot(-1), reason: head);
      final end = src.indexOf('\n  }\n', start);
      expect(end, isNot(-1), reason: head);
      return src.substring(start + head.length, end).replaceAll('_plan.', '').replaceAll(RegExp(r'\s+'), '');
    }

    expect(
      body(screen, 'String _signature(TripPlan p) {'),
      body(controller, 'String mapRedrawSignature(TripPlan p) {'),
      reason: 'TripMapScreen must redraw on TripPlanController.mapRedrawSignature',
    );
  });

  test('other_cities_routes_stay', () async {
    final api = _planner();
    final c = engineRig(enginePlan([[2, 2], [2, 1]]));
    await c.recalculate();
    final leg2 = [for (final d in c.plan.value!.daysOf(2)) d.day];
    expect(leg2, [3, 4]);
    final routes = {for (final d in leg2) d: c.routeFor(d)};
    expect(routes.values.every((r) => r != null), isTrue);
    final leg2Calls = _planCalls(api, 2);

    final d = _draft(c, 1);
    expect(d.move('L1d1s1', 0, 0), TripDraftBlock.none);
    expect(c.applyLegDraft(1, d), TripLegApplyBlock.none);
    for (final day in leg2) {
      expect(identical(c.routeFor(day), routes[day]), isTrue, reason: 'day $day before the redraw');
    }
    await c.recalculate();
    expect(_planCalls(api, 2), leg2Calls);
    for (final day in leg2) {
      expect(identical(c.routeFor(day), routes[day]), isTrue, reason: 'day $day after the redraw');
    }
    expect((c.routeFor(1)!['spots'] as List).first, 'L1d1s1');

    final grow = _draft(c, 1);
    expect(grow.addDay(), TripDraftBlock.none);
    expect(grow.move('L1d2s0', 2, 0), TripDraftBlock.none);
    expect(c.applyLegDraft(1, grow), TripLegApplyBlock.none);
    await c.recalculate();
    final moved = [for (final x in c.plan.value!.daysOf(2)) x.day];
    expect(moved, [4, 5]);
    for (var i = 0; i < leg2.length; i++) {
      expect(jsonEncode(c.routeFor(moved[i])), jsonEncode(routes[leg2[i]]), reason: 'city 2 day ${i + 1}');
    }
  });
}
