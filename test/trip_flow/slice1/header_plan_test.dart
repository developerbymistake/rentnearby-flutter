import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_bar.dart';
import 'package:bakhli/features/trip/widgets/trip_plan_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/real_phone.dart';

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

TripPlan _plan() => TripPlan(
      legs: [
        for (var k = 1; k <= 2; k++)
          TripCityLeg(index: k, cityKey: k, cityName: k == 1 ? 'Almora' : 'Nainital', latitude: 29.4 + k / 10, longitude: 79.4),
      ],
      days: [for (var k = 1; k <= 4; k++) TripDay(day: k, leg: k <= 2 ? 1 : 2, spots: [_spot('s$k'), _spot('t$k')])],
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
      steps: const TripSteps(startFrom: TripStartFrom(name: 'Kamalwaganja', lat: 29.21, lon: 79.45)),
    );

Future<TripPlanController> _rig(WidgetTester t, {double scale = 1, Size size = const Size(360, 800), bool guide = true}) async {
  final sl = TripShortlistController(repo: _Repo(), tripId: () async => 't1', offline: () => false, warn: (_) {});
  Get.put<TripShortlistController>(sl);
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  c.plan.value = _plan();
  Get.put<TripPlanController>(c, permanent: true);
  c.planStep.value = 2;
  await pumpPhone(t, const TripPlanScreen(), size: size, textScale: scale);
  await settlePhone(t);
  if (guide) {
    c.guideState.on.value = true;
    await settlePhone(t);
  }
  return c;
}

String _sz(Size s) => '${s.width.toInt()}x${s.height.toInt()}';

Future<void> _checkAt(WidgetTester t, Size size, double scale) async {
  await _rig(t, size: size, scale: scale);
  final z = '${_sz(size)}_x${scale.toString().replaceAll('.', '')}';
  final header = t.getRect(find.byType(TripPlanHeader));
  final map = t.getRect(find.byTooltip('Map'));
  final title = t.getRect(find.text('Almora, Nainital trip'));
  expect(title.right, lessThanOrEqualTo(map.left + 0.5), reason: 'title runs under Map at $z');
  expect(map.right, lessThanOrEqualTo(size.width));
  expect(header.top, 0);
  expect(title.top, greaterThanOrEqualTo(28), reason: 'title under status bar at $z');
  final guide = find.byType(SingleChildScrollView).last;
  final scrollable = t.state<ScrollableState>(find.descendant(of: guide, matching: find.byType(Scrollable)).first);
  final max = scrollable.position.maxScrollExtent;
  for (final off in [0.0, 120.0, 400.0, max]) {
    scrollable.position.jumpTo(off.clamp(0, max).toDouble());
    await t.pump();
    expect(t.getRect(find.byType(TripPlanHeader)), header, reason: 'header moved at offset $off, $z');
  }
  await settlePhone(t);
  final bar = t.getRect(find.byType(TripGuideBar));
  final skip = t.getRect(find.text('Skip this'));
  expect(skip.bottom, lessThanOrEqualTo(bar.top), reason: 'last option behind bar at $z');
  expect(bar.bottom, closeTo(size.height - 22 - phoneBottomInset, 0.5));
  await shot(t, 'C_plan_guide_${z}_end');
  scrollable.position.jumpTo(0);
  await settlePhone(t);
  await shot(t, 'C_plan_guide_${z}_top');
  expect(t.takeException(), isNull);
}

void main() {
  setUpAll(loadRealFonts);
  tearDown(Get.reset);

  for (final s in const [Size(360, 800), Size(300, 640)]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets('plan header and guide ${_sz(s)} x$scale', (t) => _checkAt(t, s, scale));
    }
  }
}
