import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_attention_screen.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_screen.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import 'taxi_fixtures.dart';

void main() {
  setUpAll(() => initTestStorage('taxi_home_render'));
  useOwnerRenderScale();
  setUp(OwnerCache.clearAll);
  tearDown(resetOwnerTestState);

  String confirmBy() => DateTime.now().add(const Duration(minutes: 12, seconds: 40)).toUtc().toIso8601String();
  final chose = att('TravellerChoseYou', 1, {'offerId': 'o1', 'confirmBy': confirmBy()});
  final noToken = att('NoPushToken', 2);
  final eight = [
    chose,
    noToken,
    att('MissedRings', 4, {'count': 3}),
    att('PaymentIssue', 5),
    att('Reports', 7, {'count': 1}),
    att('AddLocalRate', 9),
    att('Festival', 10, {'name': 'Diwali week', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12'}),
  ];
  final nums = {'newRequests': 2, 'nextBookingDate': '2026-11-25', 'ratingAvg': 4.8, 'ratingCount': 72};
  final numsDec = {...nums, 'nextBookingDate': '2026-12-18'};

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() async {
      final c = TaxiHarnessProbe.home;
      await c?.checkNotifications();
    });
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    Get.delete<TaxiDriverHomeController>(force: true);
  }

  final cases = <String, (Map<String, dynamic>, bool, String?)>{
    'o_tx_6': (homeJson(status: 'PendingReview', everApproved: false, switchOn: false), false, null),
    'o_tx_7': (homeJson(status: 'Rejected', everApproved: false, switchOn: false, reason: 'the plate is not clear in the photo.'), false, null),
    'o_tx_8': (homeJson(switchOn: false, attention: [att('GetReady', 8)]), false, null),
    'o_tx_10': (homeJson(badge: 2, taxi: nums, attention: [chose]), false, null),
    'o_tx_11': (homeJson(areaPaused: true, taxi: {...nums, 'newRequests': 0}, attention: [att('MissedRings', 4, {'count': 3})]), false, null),
    'o_tx_12': (homeJson(featured: true, badge: 3, taxi: {...nums, 'newRequests': 3}, routesMeter: {'key': 'Routes', 'used': 5, 'limit': 5}), false, null),
    'o_tx_42_b': (homeJson(status: 'PendingReview', taxi: numsDec, badge: 2), false, 'B'),
    'o_tx_43_a': (homeJson(badge: 2, taxi: nums, attention: [chose, noToken], attentionCount: 8), false, 'A'),
    'o_tx_43_c': (homeJson(status: 'Rejected', takenDown: true, reason: 'travellers reported a different car.', taxi: nums), false, 'C'),
    'o_tx_50_c': (homeJson(areaPaused: true, taxi: numsDec, badge: 2), false, 'C'),
    'o_tx_50_d': (homeJson(plannerOff: true, taxi: numsDec, badge: 2), false, 'D'),
  };

  for (final e in cases.entries) {
    testWidgets('render ${e.key}', (tester) async {
      final h = TaxiHarness.setUp(e.value.$1, denied: e.value.$2);
      TaxiHarnessProbe.home = h.home;
      final id = e.key.split('_').take(3).join('_');
      await renderOwnerFrame(tester, id, const TaxiDriverHomeScreen(), part: e.value.$3, arrange: settle);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  }

  testWidgets('render o_tx_43 B', (tester) async {
    final h = TaxiHarness.setUp(homeJson(taxi: nums, attention: eight, attentionCount: 7), denied: true);
    TaxiHarnessProbe.home = h.home;
    await renderOwnerFrame(tester, 'o_tx_43', const TaxiAttentionScreen(), part: 'B', arrange: settle);
    await finish(tester);
  });

  testWidgets('render o_tx_50 A', (tester) async {
    final h = TaxiHarness.setUp(homeJson(), offline: true);
    TaxiHarnessProbe.home = h.home;
    await renderOwnerFrame(tester, 'o_tx_50', const TaxiDriverHomeScreen(), part: 'A', arrange: settle);
    await finish(tester);
  });
}
