import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/social/c/plus/seeker_plan_keys.dart';
import 'package:bakhli/features/social/c/social_strings_c.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_trip_card.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/widgets/plan_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'plus_fakes.dart';
import 'social_c_test_kit.dart';

TripSummaryModel _trip({bool inactive = false}) => TripSummaryModel(
      id: 't1',
      title: 'Hills week',
      status: 'draft',
      cityName: 'Nainital',
      dayCount: 3,
      spotCount: 4,
      category: 'attraction',
      updatedAt: DateTime(2026, 11, 20),
      inactiveByPlan: inactive,
    );

void main() {
  useBuddyRenderScale();
  tearDown(Get.reset);

  void plan(String? state, {bool paid = false, String featureKey = 'Seeker', int? daysLeft}) {
    final plans = FakePlanController(paid: paid);
    plans.myPlan.value = MyPlanModel(
      paymentEnabled: true,
      featureKey: featureKey,
      isPaid: paid,
      isDefault: !paid,
      endsAt: DateTime(2026, 12, 26),
      daysLeft: daysLeft,
      state: state,
    );
    Get.put<PlanController>(plans);
  }

  group('Settings Plus row line', () {
    test('free seeker keeps the old Free line', () {
      plan('Free');
      expect(SeekerPlanKeys.statusLine(), isNull);
    });

    test('Plus, grace, on hold and ended read the owner plan words', () {
      plan('Plus', paid: true, daysLeft: 30);
      expect(SeekerPlanKeys.statusLine(), '30 days left');
      Get.reset();
      plan('Grace', paid: true);
      expect(SeekerPlanKeys.statusLine(), PlanWords.paymentIssue);
      Get.reset();
      plan('OnHold');
      expect(SeekerPlanKeys.statusLine(), PlanWords.paymentOnHold);
      Get.reset();
      plan('Ended');
      expect(SeekerPlanKeys.statusLine(), PlanWords.subscriptionEnded);
    });

    test('another feature key is not read as a seeker plan', () {
      plan('Plus', paid: true, featureKey: 'Stay');
      expect(SeekerPlanKeys.statusLine(), isNull);
    });
  });

  group('inactive trip card', () {
    for (final w in socialWidths) {
      for (final s in socialScales) {
        testWidgets('shows the reason line instead of the Make it easy body (${w.toInt()} x$s)', (t) async {
          Get.put<SocialMeController>(FakeSocialMeController(freeLimits()));
          await pumpSocial(t, HubTripCard(trip: _trip(inactive: true), onOpen: () {}, onAction: () {}, onDelete: () {}), width: w, scale: s);
          expect(find.byKey(const ValueKey('hub-card-inactive')), findsOneWidget);
          expect(find.text(SocialStringsC.inactiveTrip(1)), findsOneWidget);
          expect(t.takeException(), isNull);
          await disposeSocial(t);
        });
      }
    }

    test('the summary reads inactiveByPlan from the server', () {
      final m = TripSummaryModel.fromJson({'id': 't', 'updatedAt': '2026-11-20T00:00:00Z', 'inactiveByPlan': true});
      expect(m.inactiveByPlan, isTrue);
      expect(m.withMuted(null).inactiveByPlan, isTrue);
      expect(TripSummaryModel.fromJson({'id': 't'}).inactiveByPlan, isFalse);
    });
  });

  test('social limits read the paused counts', () {
    final l = SocialLimits.fromJson({'inactiveTrips': 2, 'pausedPosts': 1});
    expect((l.inactiveTrips, l.pausedPosts, l.pausedTotal), (2, 1, 3));
    expect(freeLimits().pausedTotal, 0);
  });

  test('the TripModel reads inactiveByPlan and isPublic from the server', () {
    final m = TripModel.fromJson({
      'id': 't',
      'cityKey': 1,
      'plan': <String, dynamic>{},
      'inactiveByPlan': true,
      'isPublic': true,
    });
    expect(m.inactiveByPlan, isTrue);
    expect(m.isPublic, isTrue);
    expect(m.copyWith(title: 'x').inactiveByPlan, isTrue);
    final plain = TripModel.fromJson({'id': 't', 'cityKey': 1, 'plan': <String, dynamic>{}});
    expect((plain.inactiveByPlan, plain.isPublic), (false, false));
  });

  testWidgets('a hub card with no limits loaded yet shows the plain inactive line, no invented number', (t) async {
    await pumpSocial(t, HubTripCard(trip: _trip(inactive: true), onOpen: () {}, onAction: () {}, onDelete: () {}));
    expect(find.text(SocialStringsC.inactiveTripPlain), findsOneWidget);
    await disposeSocial(t);
  });
}
