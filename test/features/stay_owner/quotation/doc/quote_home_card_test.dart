import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay_owner/quotation/widgets/quote_home_card.dart';
import 'package:bakhli/features/stay_owner/stay_owner_deps.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(DS.applyApproved);
  tearDown(() {
    DS.debugReset();
    PlanGate.debugPlan = null;
    StayOwnerDeps.debugReset();
    Get.reset();
  });

  Future<void> pump(WidgetTester t, Widget child) =>
      t.pumpWidget(GetMaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))));

  testWidgets('Q1 not drawn before approval (D-5)', (t) async {
    await pump(t, QuoteHomeCard(approved: () => false));
    expect(find.text('Quotations'), findsNothing);
    expect(find.text('New quotation'), findsNothing);
  });

  testWidgets('Q1 approved: count from /plans/me, no hub call, New quotation button', (t) async {
    PlanGate.debugPlan = const MyPlanModel(paymentEnabled: true, limits: PlanLimitsModel(quotationsPerMonth: 2, quotationsUsed: 1));
    await pump(t, QuoteHomeCard(approved: () => true));
    expect(find.text('Quotations'), findsOneWidget);
    expect(find.text('Make a quotation or proforma as PDF'), findsOneWidget);
    expect(find.textContaining('1 of 2 used'), findsOneWidget);
    expect(find.text('New quotation'), findsOneWidget);
  });

  testWidgets('Q1 never prints "3 of 2": all used line', (t) async {
    PlanGate.debugPlan = const MyPlanModel(paymentEnabled: true, limits: PlanLimitsModel(quotationsPerMonth: 2, quotationsUsed: 3));
    await pump(t, QuoteHomeCard(approved: () => true));
    expect(find.textContaining('All 2 used this month'), findsOneWidget);
  });

  test('the Home hook is empty until the bindings assign it', () {
    StayOwnerDeps.debugReset();
    expect(StayOwnerDeps.quotationsCard(), isA<SizedBox>());
  });
}
