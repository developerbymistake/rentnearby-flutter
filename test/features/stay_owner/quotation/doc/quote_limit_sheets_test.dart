import 'package:bakhli/features/owner_core/data/owner_error_types.dart';
import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/features/owner_core/plan/plan_keys.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay_owner/quotation/widgets/quote_calm_limit_sheet.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  group('Q15 limit sheets, numbers from the plan values', () {
    test('Plus sheet spec: title, body and rows from the catalog values (Plus 30)', () {
      const values = PlanValues(freeFeatures: {'StayQuotationsPerMonth': 2}, plusFeatures: {'StayQuotationsPerMonth': 30});
      final g = QuoteLimitSheets.gate(used: 2, limit: 2, resetsAt: DateTime(2026, 12, 1), values: values);
      expect(g.id, 'quotations');
      expect(g.taxi, isFalse);
      expect(g.title, '2 of 2 quotations used');
      expect(g.body, 'The Free plan makes 2 quotations a month. Plus makes 30 quotations a month.');
      expect(g.rows.map((r) => '${r.label}=${r.value}').toList(), ['Free plan=2 a month', 'Plus=30 a month']);
      expect(g.rows.last.highlight, isTrue);
      expect(g.tip, 'Preview always works. Your count resets on 1 Dec.');
    });

    test('catalog missing: the seed values (Free 2, Plus 30)', () {
      final g = QuoteLimitSheets.gate(used: 2, limit: 2, values: const PlanValues());
      expect(g.body, contains('Free plan makes ${PlanKeys.freeSeed[PlanKey.quotationsPerMonth]}'));
      expect(g.body, contains('Plus makes ${PlanKeys.plusSeed[PlanKey.quotationsPerMonth]}'));
    });

    test('plan plumbing: wire name, seeds, refusal type is a limit type', () {
      expect(PlanKey.quotationsPerMonth.wire, 'StayQuotationsPerMonth');
      expect(PlanKeys.fromWire('StayQuotationsPerMonth'), PlanKey.quotationsPerMonth);
      expect(PlanKeys.freeSeed[PlanKey.quotationsPerMonth], 2);
      expect(PlanKeys.plusSeed[PlanKey.quotationsPerMonth], 30);
      expect(OwnerErrorTypes.limitTypes, contains('QuotationMonthLimit'));
    });
  });

  test('I3 never "7 of 2": used above the limit reads All N used this month', () {
    final g = QuoteLimitSheets.gate(used: 7, limit: 2, values: const PlanValues());
    expect(g.title, 'All 2 used this month');
    expect(QuoteLimitSheets.gate(used: 2, limit: 2, values: const PlanValues()).title, '2 of 2 quotations used');
  });

  test('m1 the reset month on the sheet is read in IST', () {
    final g = QuoteLimitSheets.gate(used: 2, limit: 2, resetsAt: DateTime.utc(2026, 11, 30, 18, 30), values: const PlanValues());
    expect(g.tip, 'Preview always works. Your count resets on 1 Dec.');
  });

  group('calm sheet branch', () {
    setUp(DS.applyApproved);
    tearDown(() {
      DS.debugReset();
      Get.reset();
    });

    testWidgets('canUpgrade false opens the calm sheet: OK only, no Plus, never 7 of 2', (t) async {
      await t.pumpWidget(GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => Center(
              child: ElevatedButton(
                onPressed: () => QuoteLimitSheets.show(c, used: 7, limit: 2, canUpgrade: false, resetsAt: DateTime.utc(2026, 11, 30, 18, 30)),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.text(StayQuoteStrings.allUsed(2)), findsOneWidget);
      expect(find.text(StayQuoteStrings.calmNote), findsOneWidget);
      expect(find.text(StayQuoteStrings.ok), findsOneWidget);
      expect(find.textContaining('December'), findsOneWidget);
      expect(find.textContaining('7 of 2'), findsNothing);
      await t.tap(find.text(StayQuoteStrings.ok));
      await t.pumpAndSettle();
      expect(find.text(StayQuoteStrings.calmNote), findsNothing);
    });
  });
}
