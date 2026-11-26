import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_days_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/engine_rig.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  TripPlan posted(int legs, int? maxDays) {
    final p = enginePlan([for (var i = 0; i < legs; i++) <int>[]]);
    return p.copyWith(settings: p.settings.copyWith(maxDays: maxDays));
  }

  test('a trip posted with no days gets the posted days, so the first place can be added', () {
    final c = engineRig(posted(1, 4));
    expect(c.plan.value!.days, isEmpty);
    expect(TripDaysRules.canAddOnDay(c.plan.value!, 1), isFalse);
    expect(c.layOutPostedDays(), isTrue);
    final p = c.plan.value!;
    expect(p.days.map((d) => d.day), [1, 2, 3, 4]);
    expect(TripDaysRules.canAddOnDay(p, 1), isTrue);
    expect(c.layOutPostedDays(), isFalse);
  });

  test('posted days are spread over the cities in order, at least one day each', () {
    final c = engineRig(posted(2, 5));
    c.layOutPostedDays();
    final p = c.plan.value!;
    expect(p.daysOf(1), hasLength(3));
    expect(p.daysOf(2), hasLength(2));
    expect(p.days.first.leg, 1);
  });

  test('ten plus days or no posted count still gives one day per city', () {
    final c = engineRig(posted(3, null));
    c.layOutPostedDays();
    expect(c.plan.value!.days, hasLength(3));
  });
}
