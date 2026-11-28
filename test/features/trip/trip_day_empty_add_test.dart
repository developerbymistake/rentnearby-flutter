import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_strings_v2_plan.dart';
import 'package:bakhli/features/trip/widgets/trip_day_spot_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/real_phone.dart';
import 'support/engine_rig.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

Future<TripPlanController> _pumpDay(WidgetTester t, TripPlan plan, {TripPlanLock lock = TripPlanLock.none, bool edit = false}) async {
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  c.plan.value = plan;
  c.trip.value = engineTrip(plan, lock: lock);
  Get.put<TripPlanController>(c, permanent: true);
  await pumpPhone(t, const Scaffold(body: SingleChildScrollView(child: TripDaySpotList(1))));
  if (edit) {
    c.editMode.value = true;
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }
  return c;
}

void main() {
  tearDown(Get.reset);

  testWidgets('view mode: an empty day shows No places this day and one Add a place', (t) async {
    await _pumpDay(t, enginePlan([[0, 1]]));
    expect(t.takeException(), isNull);
    expect(find.text(TripStringsV2Plan.noPlacesThisDay), findsOneWidget);
    expect(find.text(TripStringsV2Plan.addPlace), findsOneWidget);
  });

  testWidgets('edit mode: only the footer Add a place, no second one in the body', (t) async {
    await _pumpDay(t, enginePlan([[0, 1]]), edit: true);
    expect(t.takeException(), isNull);
    expect(find.text(TripStringsV2Plan.noPlacesThisDay), findsOneWidget);
    expect(find.text(TripStringsV2Plan.addPlace), findsOneWidget);
  });

  testWidgets('a rest day shows no Add a place in view mode', (t) async {
    await _pumpDay(t, enginePlan([[0, 1]], restDays: {1}));
    expect(find.text(TripStringsV2Plan.restDay), findsOneWidget);
    expect(find.text(TripStringsV2Plan.addPlace), findsNothing);
  });

  testWidgets('a past day shows no Add a place', (t) async {
    await _pumpDay(t, enginePlan([[0, 1, 1]], start: daysFromToday(-1)));
    expect(find.text(TripStringsV2Plan.noPlacesThisDay), findsOneWidget);
    expect(find.text(TripStringsV2Plan.addPlace), findsNothing);
  });

  testWidgets('a locked plan shows no Add a place', (t) async {
    await _pumpDay(t, enginePlan([[0, 1]]), lock: lockedByRequest);
    expect(find.text(TripStringsV2Plan.noPlacesThisDay), findsOneWidget);
    expect(find.text(TripStringsV2Plan.addPlace), findsNothing);
  });
}
