import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/trip_strings_v2_plan.dart';
import 'package:bakhli/features/trip/widgets/trip_undo_snack.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../journeys/fake_api.dart';
import '../../support/real_phone.dart';
import 'support/engine_rig.dart';

class _Repo implements TripShortlistRepository {
  @override
  Future<TripShortlist> list(String tripId) async => const TripShortlist(items: []);
  @override
  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async => [item];
  @override
  Future<void> remove(String tripId, String stepKey, String listingId) async {}
  @override
  Future<void> close(String tripId, String stepKey, {required String reason}) async {}
  @override
  Future<MarkBookedResult> markBooked(String tripId, String stepKey, {String? listingId}) async =>
      const MarkBookedResult(closedEnquiries: 0, closedShortlist: 0);
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

TripPlan _empty() {
  final p = journeyPlan(const [2, 1]);
  return TripPlan(legs: p.legs, days: [for (final d in p.days) TripDay(day: d.day, leg: d.leg, spots: const [])], settings: p.settings);
}

TripPlan _noDays() {
  final p = journeyPlan(const [2, 1]);
  return TripPlan(legs: p.legs, days: const [], settings: p.settings);
}

TripPlanController _rig(TripPlan plan, {bool saved = false, bool newUnsaved = false}) {
  Get.put<TripShortlistController>(TripShortlistController(repo: _Repo(), tripId: () async => 't1', offline: () => false, warn: (_) {}));
  Get.put<TripEnquiryController>(TripEnquiryController());
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  Get.put<TripPlanController>(c, permanent: true);
  c.plan.value = plan;
  if (saved) c.trip.value = engineTrip(plan, status: TripStatuses.draft);
  if (newUnsaved) c.markNewUnsavedForTest();
  return c;
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

GradientPillButton _next(WidgetTester t) => t.widget<GradientPillButton>(find.byKey(TripPlanScreen.saveTripKey));

void main() {
  setUpAll(() async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return Directory.systemTemp.createTempSync('tp_empty').path;
    });
    await GetStorage.init();
  });
  tearDown(Get.reset);

  testWidgets('saved trip with 0 places can go back to overview', (t) async {
    _rig(_empty(), saved: true);
    await pumpPhone(t, const TripPlanScreen());
    await _settle(t);
    expect(_next(t).onTap, isNotNull);
    expect(find.text(TripStringsV2Plan.nextHintNoPlaces), findsNothing);
    t.takeException();
  });

  testWidgets('new unsaved trip with 0 places is blocked with the hint', (t) async {
    _rig(_empty(), newUnsaved: true);
    await pumpPhone(t, const TripPlanScreen());
    await _settle(t);
    expect(_next(t).onTap, isNull);
    expect(find.text(TripStringsV2Plan.nextHintNoPlaces), findsOneWidget);
    t.takeException();
  });

  testWidgets('empty days show only the day card, no plan card', (t) async {
    _rig(_empty());
    await pumpPhone(t, const TripPlanScreen());
    await _settle(t);
    expect(find.text(TripStringsV2Plan.noPlanTitle), findsNothing);
    expect(find.text(TripStringsV2Plan.noPlacesThisDay), findsWidgets);
    t.takeException();
  });

  testWidgets('no days shows the plan card', (t) async {
    _rig(_noDays());
    await pumpPhone(t, const TripPlanScreen());
    await _settle(t);
    expect(find.text(TripStringsV2Plan.noPlanTitle), findsOneWidget);
    t.takeException();
  });

  testWidgets('undo bar is dismissed when the plan screen closes', (t) async {
    final c = _rig(_empty());
    await pumpPhone(t, const Scaffold(body: SizedBox()));
    Get.to(() => const TripPlanScreen());
    await _settle(t);
    TripUndoSnack.show(ScaffoldMessenger.maybeOf(t.element(find.byType(TripPlanScreen))), TripStringsV2Plan.placeRemoved, plan: c, onUndo: () {});
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(TripStringsV2Plan.placeRemoved), findsOneWidget);
    Get.back();
    await _settle(t);
    // dispose() clears the bar; its exit animation needs more frames.
    await _settle(t);
    expect(find.byType(TripPlanScreen), findsNothing);
    expect(find.text(TripStringsV2Plan.placeRemoved), findsNothing);
    // Closing saves the plan; with no server the save-failed toast holds a 4 s timer.
    await t.pump(const Duration(seconds: 5));
    t.takeException();
  });
}
