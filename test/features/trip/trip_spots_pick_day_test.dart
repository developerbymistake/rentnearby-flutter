import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_spots_controller.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/screens/trip_spots_screen.dart';
import 'package:bakhli/features/trip/trip_strings_spots_x.dart';
import 'package:bakhli/features/trip/trip_strings_v2_create.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

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
      for (var i = 0; i < 6; i++)
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
    return Directory.systemTemp.createTempSync('pick_day_gs').path;
  });
  await GetStorage.init();
}

TripPlanController _rig(TripPlan plan) {
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  c.plan.value = plan;
  c.trip.value = engineTrip(plan);
  Get.put<TripPlanController>(c);
  c.openPages++;
  return c;
}

Map<String, Object?> _args(TripPlanController c, int day) => {
      'city': _city,
      'tripId': c.trip.value?.id,
      'existingIds': c.plan.value!.spotIds,
      'adding': true,
      'legIndex': 1,
      'newLeg': false,
      'pickDay': day,
    };

Future<void> _open(WidgetTester t, TripPlanController c, int day, {bool toastHost = false}) async {
  Get.put<TripSpotsController>(_Spots(1, _seed()), tag: '1');
  await pumpPhone(t, const Scaffold(body: SizedBox()), toastHost: toastHost);
  Get.to<Object?>(() => const TripSpotsScreen(), arguments: _args(c, day));
  await _settle(t);
}

Future<void> _tapAdd(WidgetTester t) async {
  final f = find.text(TripStringsSpotsX.addToTrip).first;
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _settle(t);
}

Future<void> _close(WidgetTester t) async {
  Get.delete<TripPlanController>(force: true);
  await t.pump(const Duration(seconds: 5));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_boot);
  tearDown(Get.reset);

  testWidgets('empty_day_opens_and_adds', (t) async {
    final c = _rig(enginePlan([[1]]));
    c.removeSpot('L1d1s0', keepEmptyDays: true);
    expect(c.plan.value!.dayAt(1), isNotNull);
    expect(c.plan.value!.dayAt(1)!.spots, isEmpty);

    await _open(t, c, 1);
    expect(t.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text(TripStringsV2Create.pickHeading(1, 0)), findsOneWidget);
    expect(find.byType(TripSpotRow), findsWidgets);
    expect(find.text(TripStringsV2Create.dayFullMove), findsNothing);

    await _tapAdd(t);
    expect(t.takeException(), isNull);
    expect(find.byType(TripSpotsScreen), findsNothing);
    expect(c.plan.value!.dayAt(1)!.spots.map((s) => s.id), ['s0']);
    await _close(t);
  });

  testWidgets('full_day_shows_move_bar', (t) async {
    final c = _rig(enginePlan([[6]]));
    await _open(t, c, 1);
    expect(t.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text(TripStringsV2Create.pickHeading(1, 6)), findsOneWidget);
    expect(find.byType(TripSpotRow), findsWidgets);
    expect(find.text(TripStringsV2Create.dayFullMove), findsOneWidget);
    await _close(t);
  });

  testWidgets('day_gone_goes_back', (t) async {
    final c = _rig(enginePlan([[1, 1]]));
    await _open(t, c, 2, toastHost: true);
    expect(find.text(TripStringsV2Create.pickHeading(2, 1)), findsOneWidget);
    c.plan.value = enginePlan([[1]]);
    await t.pump();
    expect(find.text(TripStringsV2Create.dayFullMove), findsNothing);

    await _tapAdd(t);
    // The toast is inserted after the pop finishes.
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(find.text(TripStringsV2Create.dayGone), findsOneWidget);
    expect(find.byType(TripSpotsScreen), findsNothing);
    expect(c.plan.value!.spotCount, 1);
    await _close(t);
  });
}
