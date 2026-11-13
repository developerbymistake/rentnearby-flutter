import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/trip_strings_guide.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_bar.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../ui_golden/golden_support.dart';

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

TripSpotRef _spot(String id) =>
    TripSpotRef(id: id, name: id, latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  testWidgets('360dp x1.3: every option scrolls clear of the pinned buttons', (t) async {
    final sl = TripShortlistController(repo: _Repo(), tripId: () async => 't1', offline: () => false, warn: (_) {});
    Get.put<TripShortlistController>(sl);
    final c = TripPlanController();
    c.plan.value = TripPlan(
      legs: [TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29.4, longitude: 79.4)],
      days: [TripDay(day: 1, leg: 1, spots: [_spot('s1')])],
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
    );
    setGoldenView(t, const Size(360, 640));
    await t.pumpWidget(GetMaterialApp(
      theme: ThemeData(fontFamily: 'WorkSans'),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(1.3), disableAnimations: true),
        child: Scaffold(body: TripGuideView(controller: c, shortlist: sl)),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    final barTop = t.getTopLeft(find.byType(TripGuideBar)).dy;
    for (final label in [TripStringsGuide.optFind, TripStringsGuide.optOwn, TripStringsGuide.optSkip]) {
      expect(find.text(label), findsOneWidget);
      await t.ensureVisible(find.text(label));
      await t.pump();
      expect(t.getRect(find.text(label)).bottom, lessThanOrEqualTo(barTop), reason: label);
    }
    expect(t.takeException(), isNull);
    c.onClose();
  });
}
