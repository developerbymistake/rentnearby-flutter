import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/trip_strings_v2_plan.dart';
import 'package:bakhli/features/trip/widgets/trip_undo_snack.dart';
import 'package:bakhli/features/trip/widgets/trip_withdraw_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/real_phone.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Enquiry extends TripEnquiryController {
  final undone = <String>[];

  @override
  Future<bool> undoWithdraw(String enquiryId) async {
    undone.add(enquiryId);
    return true;
  }
}

Future<BuildContext> _pump(WidgetTester tester) async {
  late BuildContext ctx;
  await pumpPhone(tester, Scaffold(body: Builder(builder: (c) {
    ctx = c;
    return const SizedBox.expand();
  })));
  return ctx;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 750));
}

// dismiss() clears in a microtask, then the bar runs its exit animation.
Future<void> _afterDismiss(WidgetTester tester) async {
  await _settle(tester);
  await tester.pump(const Duration(milliseconds: 750));
}

TripPlanController _live() {
  final c = TripPlanController();
  Get.put<TripPlanController>(c, permanent: true);
  return c;
}

void main() {
  setUp(() => Get.put<TabConfigController>(_Tabs()));
  tearDown(Get.reset);

  testWidgets('the bar hides by itself after its duration', (tester) async {
    final ctx = await _pump(tester);
    var undone = 0;
    TripUndoSnack.show(ScaffoldMessenger.of(ctx), 'Gone', onUndo: () => undone++);
    await _settle(tester);
    expect(find.text('Gone'), findsOneWidget);
    await tester.pump(TripUndoSnack.duration + const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.text('Gone'), findsNothing);
    expect(undone, 0);
  });

  testWidgets('Undo runs only while the plan controller is the live one', (tester) async {
    final ctx = await _pump(tester);
    final live = _live();
    final stale = TripPlanController();
    addTearDown(stale.onClose);
    var undone = 0;

    TripUndoSnack.show(ScaffoldMessenger.of(ctx), 'Replaced', plan: stale, onUndo: () => undone++);
    await _settle(tester);
    await tester.tap(find.text(TripStringsV2Plan.undo));
    await _settle(tester);
    expect(undone, 0);

    TripUndoSnack.show(ScaffoldMessenger.of(ctx), 'Live', plan: live, onUndo: () => undone++);
    await _settle(tester);
    await tester.tap(find.text(TripStringsV2Plan.undo));
    await _settle(tester);
    expect(undone, 1);

    TripUndoSnack.show(ScaffoldMessenger.of(ctx), 'Closed', plan: live, onUndo: () => undone++);
    await _settle(tester);
    Get.delete<TripPlanController>(force: true);
    expect(live.isClosed, isTrue);
    await tester.tap(find.text(TripStringsV2Plan.undo));
    await _settle(tester);
    expect(undone, 1);
  });

  testWidgets('dismiss clears only a bar scoped to that plan', (tester) async {
    final ctx = await _pump(tester);
    final a = _live();
    final b = TripPlanController();
    addTearDown(b.onClose);

    TripUndoSnack.show(ScaffoldMessenger.of(ctx), 'Scoped', plan: a, onUndo: () {});
    await _settle(tester);
    TripUndoSnack.dismiss(b);
    await _afterDismiss(tester);
    expect(find.text('Scoped'), findsOneWidget);
    TripUndoSnack.dismiss(a);
    await _afterDismiss(tester);
    expect(find.text('Scoped'), findsNothing);

    TripUndoSnack.show(ScaffoldMessenger.of(ctx), 'Free', onUndo: () {});
    await _settle(tester);
    TripUndoSnack.dismiss(a);
    await _afterDismiss(tester);
    expect(find.text('Free'), findsOneWidget);
  });

  group('withdraw', () {
    TripEnquiryModel row() => TripEnquiryModel(id: 'e1', listingName: 'Hill Stay', undoUntil: DateTime.now().add(const Duration(seconds: 3)));

    testWidgets('onGone fires when the bar times out', (tester) async {
      final ctx = await _pump(tester);
      var gone = 0;
      TripWithdrawSheet.showUndo(ctx, row(), onGone: () => gone++);
      await _settle(tester);
      expect(gone, 0);
      await tester.pump(const Duration(seconds: 4));
      await _settle(tester);
      expect(gone, 1);
    });

    testWidgets('onGone does not fire after Undo', (tester) async {
      final enq = _Enquiry();
      Get.put<TripEnquiryController>(enq);
      final ctx = await _pump(tester);
      var gone = 0;
      TripWithdrawSheet.showUndo(ctx, row(), onGone: () => gone++);
      await _settle(tester);
      await tester.tap(find.text('Undo'));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 4));
      await _settle(tester);
      expect(enq.undone, ['e1']);
      expect(gone, 0);
    });

    testWidgets('a window already over calls onGone without a bar', (tester) async {
      final ctx = await _pump(tester);
      var gone = 0;
      TripWithdrawSheet.showUndo(ctx, TripEnquiryModel(id: 'e2', undoUntil: DateTime.now().subtract(const Duration(seconds: 1))), onGone: () => gone++);
      await _settle(tester);
      expect(gone, 1);
      expect(find.text('Undo'), findsNothing);
    });
  });
}
