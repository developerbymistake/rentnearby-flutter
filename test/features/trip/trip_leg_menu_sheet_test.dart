import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_strings_dayplan.dart';
import 'package:bakhli/features/trip/trip_strings_mca_a3.dart';
import 'package:bakhli/features/trip/widgets/trip_leg_menu_sheet.dart';
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

TripPlanController _register(TripPlan plan) {
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  Get.put<TripPlanController>(c);
  c.plan.value = plan;
  c.trip.value = engineTrip(plan);
  return c;
}

Widget _opener(int legIndex) => Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: TextButton(onPressed: () => TripLegMenuSheet.show(ctx, legIndex), child: const Text('open')),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('too_few_days_text_is_its_own_message', () {
    expect(TripLegMenuSheet.blockText(TripLegEditBlock.edge, 'Almora'), TripStringsDayplan.tooFewDays);
    expect(TripLegMenuSheet.blockText(TripLegEditBlock.edge, 'Almora', up: true), TripStringsMcaA3.firstCity);
    expect(TripLegMenuSheet.blockText(TripLegEditBlock.edge, 'Almora', up: false), TripStringsMcaA3.lastCity);
    expect(TripStringsDayplan.tooFewDays, isNot(anyOf(TripStringsMcaA3.firstCity, TripStringsMcaA3.lastCity)));

    final c = engineRig(enginePlan([[6, 6], [1]]));
    final block = c.canSetLegDays(1, 1);
    expect(block, TripLegEditBlock.edge);
    expect(TripLegMenuSheet.blockText(block, 'Nainital'), TripStringsDayplan.tooFewDays);

    expect(TripLegMenuSheet.blockText(TripLegEditBlock.readOnly, 'Nainital', locked: true), TripStringsDayplan.lockedShort);
    expect(TripLegMenuSheet.blockText(TripLegEditBlock.readOnly, 'Nainital', locked: false), TripStringsMcaA3.readOnlyBlock);
  });

  testFiveSizes(
    'leg_menu_sheet_five_sizes',
    () {
      _register(enginePlan([[2, 2], [3, 2, 1], [1]]));
      return _opener(2);
    },
    check: (tester, size) async {
      final c = TripPlanController.to;
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Almora'), findsWidgets);
      expect(find.text(TripStringsMcaA3.changeDays), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(TripStringsMcaA3.changeDays));
      await tester.pumpAndSettle();
      expect(find.text(TripStringsMcaA3.save), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.byIcon(Icons.remove_rounded));
        await tester.tap(find.byIcon(Icons.remove_rounded));
        await tester.pumpAndSettle();
      }
      expect(find.text(TripStringsMcaA3.days(1)), findsOneWidget);
      final p = c.plan.value!;
      c.plan.value = p.copyWith(days: [
        for (final d in p.days) d.day == 5 ? d.copyWith(spots: [...d.spots, engineSpot('x1')]) : d,
      ]);
      await tester.pumpAndSettle();
      expect(find.text(TripStringsDayplan.tooFewDays), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(TripStringsMcaA3.save));
      await tester.tap(find.text(TripStringsMcaA3.save));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(c.plan.value!.legDayCount(2), 3);
      expect(tester.takeException(), isNull);

      c.trip.value = c.trip.value!.copyWith(planLock: lockedByRequest);
      await tester.pumpAndSettle();
      expect(find.text(TripStringsDayplan.lockedShort), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a locked plan does not open the leg menu', (tester) async {
    final plan = enginePlan([[2], [2]]);
    final c = _register(plan);
    c.trip.value = engineTrip(plan, lock: lockedByRequest);
    await pumpAtSize(tester, _opener(1), const Size(360, 800));
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.text(TripStringsMcaA3.changeDays), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });
}
