import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/trip_strings_dayplan.dart';
import 'package:bakhli/features/trip/trip_strings_mca_a3.dart';
import 'package:bakhli/features/trip/widgets/trip_leg_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/five_sizes.dart';
import 'support/engine_rig.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

TripPlanController _register(TripPlan plan, {TripPlanLock lock = TripPlanLock.none}) {
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  Get.put<TripPlanController>(c);
  c.plan.value = plan;
  c.trip.value = engineTrip(plan, lock: lock);
  return c;
}

Widget _opener(int legIndex) => Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: TextButton(onPressed: () => TripLegActions.removeCity(ctx, legIndex), child: const Text('open')),
        ),
      ),
    );

Future<void> _open(WidgetTester t) async {
  await pumpAtSize(t, _opener(2), const Size(360, 800));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('too_few_days_text_is_its_own_message', () {
    expect(TripLegActions.blockText(TripLegEditBlock.edge, 'Almora'), TripStringsDayplan.tooFewDays);
    final c = engineRig(enginePlan([[6, 6], [1]]));
    final block = c.canSetLegDays(1, 1);
    expect(block, TripLegEditBlock.edge);
    expect(TripLegActions.blockText(block, 'Nainital'), TripStringsDayplan.tooFewDays);
    expect(TripLegActions.blockText(TripLegEditBlock.readOnly, 'Nainital', locked: true), TripStringsDayplan.lockedShort);
    expect(TripLegActions.blockText(TripLegEditBlock.readOnly, 'Nainital', locked: false), TripStringsMcaA3.readOnlyBlock);
  });

  test('every_block_has_an_arm', () {
    for (final b in TripLegEditBlock.values) {
      expect(() => TripLegActions.blockText(b, 'Almora', locked: false), returnsNormally);
    }
  });

  testWidgets('remove_city_confirm_drops_the_city', (t) async {
    final c = _register(enginePlan([[2], [2]]));
    await _open(t);
    expect(find.text(TripStringsMcaA3.remove), findsOneWidget);
    await t.tap(find.text(TripStringsMcaA3.remove));
    await t.pumpAndSettle();
    expect(c.plan.value!.legCount, 1);
    await t.pump(const Duration(seconds: 10));
  });

  testWidgets('remove_city_keep_changes_nothing', (t) async {
    final c = _register(enginePlan([[2], [2]]));
    await _open(t);
    await t.tap(find.text(TripStringsMcaA3.keep));
    await t.pumpAndSettle();
    expect(c.plan.value!.legCount, 2);
  });

  testWidgets('locked_plan_toasts_and_shows_no_dialog', (t) async {
    final c = _register(enginePlan([[2], [2]]), lock: lockedByRequest);
    await _open(t);
    expect(find.text(TripStringsMcaA3.remove), findsNothing);
    expect(c.plan.value!.legCount, 2);
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
  });

  testWidgets('one_city_plan_shows_no_dialog', (t) async {
    final c = _register(enginePlan([[2]]));
    await pumpAtSize(t, _opener(1), const Size(360, 800));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text(TripStringsMcaA3.remove), findsNothing);
    expect(c.plan.value!.legCount, 1);
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
  });

  testWidgets('second_tap_while_the_dialog_is_open_does_nothing', (t) async {
    _register(enginePlan([[2], [2]]));
    await _open(t);
    TripLegActions.removeCity(t.element(find.byType(Scaffold)), 2);
    await t.pumpAndSettle();
    expect(find.text(TripStringsMcaA3.remove), findsOneWidget);
  });
}
