import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/session/owner_session_hooks.dart';
import 'package:bakhli/features/owner_core/sheets/owner_states.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_screen.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_controller.dart';
import 'package:bakhli/features/taxi_driver/taxi_driver_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../features/taxi_driver/core/taxi_fixtures.dart';
import '../support/owner_fakes.dart';
import '../support/real_phone.dart';

// JT-A-LC-1 (taxi half, FT-06): delete taxi from My Taxi -> Home shows the setup entry, never the old dashboard
// and never "Could not load". The stay half lives with FS-06.

void main() {
  setUpAll(() => initTestStorage('taxi_listing_delete_journey'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  for (final plan in const [('Free', OwnerPlans.free), ('Ended', OwnerPlans.free), ('Plus', OwnerPlans.plus)]) {
    testWidgets('delete from the hub in ${plan.$1}: Home becomes the setup entry', (t) async {
      final h = TaxiHarness.setUp(homeJson(taxi: {'newRequests': 2}));
      PlanGate.debugPlan = plan.$2;
      TaxiDriverSession.register();
      var deleted = false;
      h.api.result = () async => deleted
          ? const OwnerRefused<OwnerHomeDto>(type: 'ListingNotFound', statusCode: 404)
          : OwnerOk<OwnerHomeDto>(OwnerHomeDto.fromJson(homeJson(taxi: {'newRequests': 2})));
      final hub = Get.put(
        TaxiHubController(
          userId: () => 'user-a',
          fetch: () async => {'data': deleted ? null : taxiJson(hidden: plan.$1 == 'Ended' ? 3 : 0)},
          deleteTaxiCall: () async {
            deleted = true;
            return OwnerOk<void>(null);
          },
        ),
        tag: TaxiHubController.tag,
      );
      await pumpPhone(t, TaxiDriverHomeScreen(controller: h.home));
      await t.runAsync(() async {
        await h.home.reload(force: true);
        await hub.reload();
      });
      await t.pump();
      expect(find.text('UK 04 TA 2231'), findsWidgets);
      final calls0 = h.api.calls;
      await t.runAsync(() async {
        expect(await hub.deleteTaxi(), isTrue);
        await pumpEventQueue();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(h.api.calls - calls0, greaterThanOrEqualTo(1), reason: 'the delete refreshes Home');
      expect(h.home.load.value, isA<OwnerLoadEmpty<OwnerHomeDto>>());
      expect(find.text('Set up your taxi'), findsOneWidget);
      expect(find.text('No taxi yet'), findsOneWidget);
      expect(find.text('Couldn’t load your taxi'), findsNothing);
      expect(OwnerCache.read('user-a', OwnerCacheKeys.home), isNull);
      await t.pump(const Duration(seconds: 5));
      await OwnerSessionHooks.onLogout(LogoutReason.explicitLogout, 'user-a');
    });
  }

  testWidgets('cold start with an empty cache and a 404: setup entry', (t) async {
    final h = TaxiHarness.setUp(homeJson());
    h.api.result = () async => const OwnerRefused<OwnerHomeDto>(type: 'ListingNotFound', statusCode: 404);
    await t.runAsync(() => h.home.reload(force: true));
    await pumpPhone(t, TaxiDriverHomeScreen(controller: h.home));
    await t.pump();
    expect(find.text('Set up your taxi'), findsOneWidget);
  });
}
