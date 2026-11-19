import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/real_phone.dart';

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
      const MarkBookedResult(closedEnquiries: 1, closedShortlist: 1);
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

TripSpotRef _spot(String id) =>
    TripSpotRef(id: id, name: id, latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60);

TripPlan _plan(int days) => TripPlan(
      legs: [TripCityLeg(index: 1, cityKey: 1, cityName: 'Almora', latitude: 29.5, longitude: 79.4)],
      days: [for (var k = 1; k <= days; k++) TripDay(day: k, leg: 1, spots: [_spot('s$k'), _spot('t$k')])],
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
    );

Future<void> _rig(WidgetTester t, Size size, int days) async {
  Get.put<TripShortlistController>(TripShortlistController(repo: _Repo(), tripId: () async => 't1', offline: () => false, warn: (_) {}));
  Get.put<TabConfigController>(_Tabs());
  TripCityCatalog.to.seedForTest(const [TripCityModel(cityKey: 901, name: 'Bhimtal', stateName: 'Uttarakhand', latitude: 29.35, longitude: 79.56)]);
  final c = TripPlanController();
  c.plan.value = _plan(days);
  Get.put<TripPlanController>(c, permanent: true);
  c.planStep.value = 1;
  await pumpPhone(t, const TripPlanScreen(), size: size);
  await settlePhone(t);
  c.guideState.on.value = false;
  c.planStep.value = 1;
  await settlePhone(t);
}

void main() {
  setUpAll(loadRealFonts);
  tearDown(Get.reset);

  for (final size in const [Size(360, 800), Size(300, 640)]) {
    for (final days in const [1, 6]) {
      testWidgets('Save trip stays pinned at the bottom ${size.width.toInt()}x${size.height.toInt()}, $days days', (t) async {
        await _rig(t, size, days);
        final next = find.text('Save trip');
        expect(next, findsOneWidget);
        expect(find.ancestor(of: next, matching: find.byType(Scrollable)), findsNothing, reason: 'Save trip must not live inside the scrolling body');
        final before = t.getRect(next);
        expect(before.bottom, greaterThan(size.height * 0.8), reason: 'Save trip must sit at the bottom of the screen');
        final list = find.byType(Scrollable).first;
        await t.drag(list, const Offset(0, -300));
        await t.pump();
        expect(t.getRect(next), before, reason: 'Save trip must not move when the body scrolls');
        expect(t.takeException(), isNull);
      });
    }
  }
}
