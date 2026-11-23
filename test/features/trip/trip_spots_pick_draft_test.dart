import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_spots_controller.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/screens/trip_spots_screen.dart';
import 'package:bakhli/features/trip/trip_strings_pick_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';
import 'support/engine_rig.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Spots extends TripSpotsController {
  _Spots(super.cityKey, this.seed);
  final List<TripSpotModel> seed;
  @override
  Future<void> load() async {
    items.assignAll(seed);
    total.value = seed.length;
  }
}

const _city = TripCityModel(cityKey: 1, name: 'Nainital', latitude: 29.38, longitude: 79.45);

List<TripSpotModel> _seed() => [
      for (var i = 0; i < 9; i++)
        TripSpotModel(
          id: 's$i',
          source: 'osm',
          name: 'Place $i',
          latitude: 29.38,
          longitude: 79.45,
          category: 'lake',
          visitMinutes: 60,
          rank: 1,
        ),
    ];

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

Future<void> _boot() async {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    return Directory.systemTemp.createTempSync('pd_gs').path;
  });
  await GetStorage.init();
}

Map<String, Object> _args({int dayCount = 2, Set<String> existing = const {'s0', 's1'}}) => {
      'city': _city,
      'pickForDraft': true,
      'dayNumber': 3,
      'dayCount': dayCount,
      'existingIds': existing,
    };

Future<Future<Object?>> _open(WidgetTester t, {Size size = phoneSize, Map<String, Object>? args}) async {
  Get.put<TabConfigController>(_Tabs());
  Get.put<TripSpotsController>(_Spots(1, _seed()), tag: '1');
  await pumpPhone(t, const Scaffold(body: SizedBox()), size: size);
  final result = Get.to<Object?>(() => const TripSpotsScreen(), arguments: args ?? _args());
  await _settle(t);
  return result as Future<Object?>;
}

Future<void> _tapPlus(WidgetTester t, int i) async {
  for (var n = 0; n < 10 && find.byIcon(Icons.circle_outlined).evaluate().length <= i; n++) {
    await t.drag(find.byType(ListView).first, const Offset(0, -200));
    await t.pump();
  }
  final f = find.byIcon(Icons.circle_outlined).at(i);
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _settle(t);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_boot);
  tearDown(Get.reset);

  testWidgets('picks_returned', (t) async {
    final result = await _open(t);
    expect(find.text(TripStringsPickDraft.title(3)), findsOneWidget);
    expect(find.text(TripStringsPickDraft.subtitle('Nainital', 2)), findsOneWidget);
    await _tapPlus(t, 0);
    Get.find<TripSpotsController>(tag: '1').toggle('s3');
    await t.pump();
    expect(find.text(TripStringsPickDraft.summary(3, 4)), findsOneWidget);
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    await t.tap(find.text(TripStringsPickDraft.add(2)));
    await _settle(t);
    await t.pump(const Duration(milliseconds: 500));
    final picks = await result.timeout(const Duration(seconds: 3)) as List<TripSpotModel>;
    expect(picks.map((s) => s.id), ['s2', 's3']);
    expect(t.takeException(), isNull);
  });

  testWidgets('plan_unchanged', (t) async {
    final plan = enginePlan([[2, 2]]);
    Get.put<TabConfigController>(_Tabs());
    final c = TripPlanController();
    Get.put<TripPlanController>(c);
    c.plan.value = plan;
    c.openPages++;
    final before = plan.toJson().toString();
    final spotsBefore = c.plan.value!.spotCount;
    final result = await _open(t);
    await _tapPlus(t, 0);
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    await t.tap(find.text(TripStringsPickDraft.add(1)));
    await _settle(t);
    await t.pump(const Duration(milliseconds: 500));
    await result.timeout(const Duration(seconds: 3));
    expect(identical(c.plan.value, plan), isTrue);
    expect(c.plan.value!.spotCount, spotsBefore);
    expect(c.plan.value!.toJson().toString(), before);
  });

  testWidgets('cap_disables_more_picks', (t) async {
    final result = await _open(t, args: _args(dayCount: 5, existing: {'s0'}));
    final ctrl = Get.find<TripSpotsController>(tag: '1');
    expect(ctrl.limit.value, 1);
    await _tapPlus(t, 0);
    expect(ctrl.selected.toList(), ['s1']);
    expect(ctrl.toggle('s2'), isFalse);
    await t.pump();
    expect(ctrl.selected.length, 1);
    expect(find.text(TripStringsPickDraft.summary(3, 6)), findsOneWidget);
    await t.pump(const Duration(milliseconds: 500));
    Get.back();
    await _settle(t);
    expect(await result, isNull);
  });

  testWidgets('Added rows not selectable', (t) async {
    await _open(t);
    final ctrl = Get.find<TripSpotsController>(tag: '1');
    expect(find.text('Added'), findsWidgets);
    await t.tap(find.text('Added').first);
    await t.pump();
    expect(ctrl.selected, isEmpty);
    expect(find.text(TripStringsPickDraft.pickHint), findsOneWidget);
  });

  testFiveSizes('pick_draft_five_sizes', () {
    Get.put<TabConfigController>(_Tabs());
    Get.put<TripSpotsController>(_Spots(1, _seed()), tag: '1');
    return Builder(builder: (ctx) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Get.currentRoute == '/') Get.to(() => const TripSpotsScreen(), arguments: _args());
      });
      return const Scaffold(body: SizedBox());
    });
  }, check: (t, size) async {
    await _settle(t);
    expect(find.text(TripStringsPickDraft.title(3)), findsOneWidget);
    Get.find<TripSpotsController>(tag: '1').toggle('s2');
    await t.pump();
    expect(find.text(TripStringsPickDraft.add(1)), findsOneWidget);
    await t.pump(const Duration(milliseconds: 500));
  });
}
