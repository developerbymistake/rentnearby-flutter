import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../journeys/fake_api.dart';
import '../../ui_golden/golden_support.dart';

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

Future<TripPlanController> _open(WidgetTester t, TripPlan plan, Map<String, dynamic> args, double w, double scale) async {
  Get.reset();
  Get.put<TripShortlistController>(TripShortlistController(repo: _Repo(), tripId: () async => 't1', offline: () => false, warn: (_) {}));
  Get.put<TripEnquiryController>(TripEnquiryController());
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  Get.put<TripPlanController>(c);
  c.plan.value = plan;
  t.view.physicalSize = Size(w, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(GetMaterialApp(
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child!,
    ),
    home: Builder(builder: (ctx) => TextButton(onPressed: () => Get.to(() => const TripPlanScreen(), arguments: args), child: const Text('go'))),
  ));
  await t.tap(find.text('go'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 800));
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadGoldenFonts);
  tearDown(Get.reset);
  final start = TripClock.today().add(const Duration(days: 10));

  for (final w in [300.0, 360.0, 412.0, 560.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('final push deep link opens the stay step with the booking nudge at ${w.toInt()} dp x$scale', (t) async {
        final plan = journeyPlan([2, 2], start: start).withGuide(const TripGuide(choices: {'gettingThere': TripGuideChoice.skip}));
        final c = await _open(t, plan, {'step': 'stay:2', 'nudge': true, 'name': 'Hill View'}, w, scale);
        expect(c.guideState.keyNow, 'stay:2');
        expect(c.guideState.nudgeStep.value, 'stay:2');
        expect(find.text('Did you book Hill View?'), findsOneWidget);
        expect(find.text('Mark as booked'), findsOneWidget);
        expect(find.text('Choose new options'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pump(const Duration(seconds: 5));
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      });
    }
  }

  testWidgets('an old plan without any guide data opens the plan screen without error', (t) async {
    final plan = journeyPlan([2, 2], start: start);
    expect(plan.guide, isNull);
    final c = await _open(t, plan, {'tripId': null}, 360, 1);
    expect(c.plan.value, isNotNull);
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 5));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
