import 'package:bakhli/features/owner_core/data/owner_error_types.dart';
import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/features/owner_core/plan/plan_keys.dart';
import 'package:bakhli/features/stay_owner/quotation/widgets/quote_calm_limit_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
