import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_usage_view.dart';
import 'package:bakhli/features/stay_owner/quotation/widgets/quote_usage_line.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final resets = DateTime(2026, 12, 1, 0, 0);
  final ends = DateTime(2026, 12, 21);

  QuoteUsageView v(PlanCardState s, int used, int limit) => QuoteUsageView.of(state: s, used: used, limit: limit, resetsAt: resets, endsAt: ends);

  group('Q16 usage line table (ARCH 10.4)', () {
    test('free', () {
      final x = v(PlanCardState.free, 1, 2);
      expect(x.line1, 'Free plan · 1 of 2 used');
      expect(x.line2, 'Resets on 1 Dec · Preview is always free');
      expect(x.seePlus, isFalse);
    });

    test('plus, grace and admin grant', () {
      for (final s in [PlanCardState.plus, PlanCardState.grace, PlanCardState.adminGrant]) {
        final x = v(s, 7, 30);
        expect(x.line1, 'Plus · 7 of 30 used', reason: s.name);
        expect(x.line2, '30 quotations a month · Plus till 21 Dec 2026', reason: s.name);
      }
    });

    test('cancelled, still in the paid period', () {
      final x = v(PlanCardState.cancelled, 7, 30);
      expect(x.line1, 'Plus · 7 of 30 used');
      expect(x.line2, '30 quotations a month · Plus ends on 21 Dec 2026');
    });

    test('ended, on hold: Plus ended line, free numbers, See Plus', () {
      for (final s in [PlanCardState.ended, PlanCardState.onHold]) {
        final x = v(s, 0, 2);
        expect(x.top, 'Plus ended on 21 Dec 2026', reason: s.name);
        expect(x.line1, 'Free plan · 0 of 2 used', reason: s.name);
        expect(x.seePlus, isTrue, reason: s.name);
      }
    });

    test('payment OFF: no plan word, no upsell', () {
      final x = v(PlanCardState.paymentOff, 3, 30);
      expect(x.line1, '3 of 30 used this month');
      expect(x.line2, isNull);
      expect(x.seePlus, isFalse);
    });

    test('used >= limit never prints "7 of 2"', () {
      expect(v(PlanCardState.ended, 7, 2).line1, 'Free plan · All 2 used this month');
      expect(v(PlanCardState.free, 2, 2).line1, 'Free plan · All 2 used this month');
      expect(v(PlanCardState.plus, 30, 30).line1, 'Plus · All 30 used this month');
      expect(v(PlanCardState.paymentOff, 31, 30).line1, 'All 30 used this month');
      expect(v(PlanCardState.free, 7, 2).fraction, 1);
    });
  });

  group('B1 / m1 / m8', () {
    tearDown(() => PlanGate.debugPlan = null);

    test('m1 the reset month is read in IST, whatever the phone zone (1st 00:00 IST = last day 18:30 UTC)', () {
      final x = QuoteUsageView.of(state: PlanCardState.free, used: 1, limit: 2, resetsAt: DateTime.utc(2026, 11, 30, 18, 30));
      expect(x.line2, 'Resets on 1 Dec · Preview is always free');
    });

    test('m8 Plus with all used: the reset line replaces the plan line', () {
      final x = QuoteUsageView.of(state: PlanCardState.plus, used: 30, limit: 30, resetsAt: DateTime.utc(2026, 11, 30, 18, 30), endsAt: ends);
      expect(x.line2, 'Resets on 1 Dec · Preview still works');
    });

    test('reconcile: a hub saved before /plans/me loaded with another limit is dropped; a fresher hub wins', () {
      const hub = QuoteUsage(used: 7, limit: 30);
      final saved = DateTime.utc(2026, 11, 20);
      expect(QuoteUsageSource.reconcile(hub, 2, hubSavedAt: saved, planLoadedAt: saved.add(const Duration(minutes: 1))), isNull);
      expect(QuoteUsageSource.reconcile(hub, 2, hubSavedAt: saved, planLoadedAt: saved.subtract(const Duration(minutes: 1))), same(hub));
      expect(QuoteUsageSource.reconcile(hub, 30, hubSavedAt: saved, planLoadedAt: saved.add(const Duration(minutes: 1))), same(hub));
    });

    test('B1 after a lapse, a stale hub limit 30 prints Free plan · x of 2', () {
      PlanGate.debugPlan = MyPlanModel(
        paymentEnabled: true,
        endsAt: DateTime.utc(2026, 11, 20),
        limits: const PlanLimitsModel(quotationsPerMonth: 2, quotationsUsed: 1),
      );
      final saved = DateTime.utc(2026, 11, 21);
      final v = QuoteUsageSource.view(
        hub: const QuoteUsage(used: 1, limit: 30),
        hubSavedAt: saved,
        planLoadedAt: saved.add(const Duration(hours: 1)),
        now: DateTime.utc(2026, 11, 22),
      );
      expect(v.limit, 2);
      expect(v.line1, startsWith('Free plan · '));
      expect(v.line1, contains('1 of 2 used'));
    });
  });
}
