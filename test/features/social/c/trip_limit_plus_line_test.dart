import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/buddy/triplimit/trip_limit_models.dart';
import 'package:bakhli/features/buddy/triplimit/trip_limit_sheet.dart';
import 'package:bakhli/features/buddy/triplimit/trip_limit_strings.dart';
import 'package:bakhli/features/social/c/social_strings_c.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'plus_fakes.dart';
import 'social_c_test_kit.dart';

TripSlots _slots() => TripSlots.fromRefusal({
      'limit': 1,
      'count': 1,
      'trips': [
        {'id': 't1', 'title': 'Manali trip', 'role': 'Owner', 'startDate': null, 'endDate': null},
      ],
    });

Widget _opener() => Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: TextButton(onPressed: () => TripLimitSheet.show(ctx, _slots(), reason: TripLimitReason.plan), child: const Text('open')),
        ),
      ),
    );

Future<void> _open(WidgetTester t) async {
  await pumpSocial(t, _opener());
  await t.tap(find.text('open'));
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  useBuddyRenderScale();
  tearDown(Get.reset);

  testWidgets('a free seeker at the trip limit sees the Plus line with the Plus trip count from the catalog', (t) async {
    Get.put<PlanController>(FakePlanController());
    Get.put<SocialMeController>(FakeSocialMeController(freeLimits()));
    await _open(t);
    expect(find.byKey(const ValueKey('trip_limit_plus')), findsOneWidget);
    expect(find.text(SocialStringsC.tripLimitPlus(10)), findsOneWidget);
    expect(find.text(TripLimitStrings.body(TripLimitReason.plan, 1)), findsOneWidget);
    await disposeSocial(t);
  });

  testWidgets('a Plus member at the limit gets no Plus line', (t) async {
    Get.put<PlanController>(FakePlanController(paid: true));
    Get.put<SocialMeController>(FakeSocialMeController(plusLimits()));
    await _open(t);
    expect(find.byKey(const ValueKey('trip_limit_plus')), findsNothing);
    await disposeSocial(t);
  });
}
