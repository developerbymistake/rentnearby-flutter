import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/calendar/month_pager.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/money/money_summary_card.dart';
import 'package:bakhli/features/owner_core/look/owner_look.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/plan/plan_keys.dart';
import 'package:bakhli/features/owner_core/plan/soft_lock.dart';
import 'package:bakhli/features/owner_core/strings/owner_shared_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';

const _spec = GateSpec(
  id: 'g10',
  title: 'You have 4 active entries',
  body: 'Free keeps 4 bookings you add yourself. Plus keeps 50.',
  taxi: false,
  rows: [GateRow(label: 'Free', value: '4 bookings you add'), GateRow(label: 'Plus', value: '50 bookings you add', highlight: true)],
  tip: 'A slot frees up when a booking date passes, or delete one you do not need.',
);

const _words = MoneySummaryWords(
  title: 'This month',
  sub: 'Booked, received, to collect',
  booked: 'Booked',
  received: 'Received',
  toCollect: 'To collect',
  lockedLine: 'Plus adds up the amounts you write on each booking. Writing them stays free.',
  hiddenAmount: '₹ ●●,●●●',
);

Widget _locks() => Scaffold(
      body: Builder(
        builder: (context) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const PlusChip(),
            SoftLock.row(text: '8 more bookings are hidden.', unlocked: const Text('unlocked row')),
            SoftLock.card(child: const SizedBox(height: 80, child: Text('card body')), lockedTitle: 'This month'),
            MonthPager(
              month: DateTime(2026, 11),
              window: CalendarWindow(monthFrom: DateTime(2026, 11, 1), monthTo: DateTime(2026, 11, 30), locked: true),
              today: DateTime(2026, 11, 21),
              onMonth: (_) {},
            ),
            MoneySummaryCard(words: _words, look: OwnerLook.stay, allowed: false),
            ElevatedButton(onPressed: () => PlanGate.showLimit(context, _spec), child: const Text('open gate')),
          ],
        ),
      ),
    );

void main() {
  tearDown(() {
    PlanGate.debugPlan = null;
    PlanGate.debugTrialDays = null;
  });

  group('rules', () {
    test('payment OFF: no upgrade, limits are the server numbers', () {
      PlanGate.debugPlan = OwnerPlans.paymentOff;
      expect(PlanGate.paymentOn, isFalse);
      expect(PlanGate.canUpgrade, isFalse);
      expect(PlanGate.limit(PlanKey.calendarEntries), 50);
      expect(PlanGate.locks(PlanKey.calendarEntries, 50), isFalse);
    });

    test('Free: locks at the limit; Plus never locks', () {
      PlanGate.debugPlan = OwnerPlans.free;
      expect(PlanGate.limit(PlanKey.photos), 2);
      expect(PlanGate.locks(PlanKey.photos, 1), isFalse);
      expect(PlanGate.locks(PlanKey.photos, 2), isTrue);
      expect(PlanGate.on(PlanKey.monthSummary), isFalse);
      PlanGate.debugPlan = OwnerPlans.plus;
      expect(PlanGate.canUpgrade, isFalse);
      expect(PlanGate.locks(PlanKey.photos, 8), isFalse);
      expect(PlanGate.on(PlanKey.reminders), isTrue);
    });

    test('price line: Play prices, no trial words while no plan carries a trial (2026-11-27)', () {
      PlanGate.debugPlan = OwnerPlans.free;
      expect(PlanGate.priceLine(taxi: false), '₹500 / month');
      expect(PlanGate.priceLine(taxi: true), '₹300 / month');
      PlanGate.debugTrialDays = 0;
      expect(PlanGate.priceLine(taxi: false), '₹500 / month');
      expect(PlanGate.trialDays(), isNull);
    });

    test('trial machinery: words only while the catalog has a trial and it is unused', () {
      PlanGate.debugTrialDays = 7;
      PlanGate.debugPlan = OwnerPlans.free;
      expect(PlanGate.priceLine(taxi: false), '₹500 / month · 7 days free');
      expect(PlanGate.priceLine(taxi: true), '₹300 / month · 7 days free');
      PlanGate.debugPlan = OwnerPlans.freeNoTrial;
      expect(PlanGate.priceLine(taxi: false), '₹500 / month');
    });

    test('fromRefusal: gate only for a limit type that can upgrade', () {
      PlanGate.debugPlan = OwnerPlans.free;
      const limit = BuddyRefused<void>(
          type: 'CalendarEntryLimit', statusCode: 409, data: {'key': 'CalendarEntries', 'limit': 4, 'used': 4, 'canUpgrade': true});
      expect(PlanGate.fromRefusal(limit, (k, l) => _spec), isNotNull);
      const atCap = BuddyRefused<void>(
          type: 'CalendarEntryLimit', statusCode: 409, data: {'key': 'CalendarEntries', 'limit': 50, 'used': 50, 'canUpgrade': false});
      expect(PlanGate.fromRefusal(atCap, (k, l) => _spec), isNull);
      const other = BuddyRefused<void>(type: 'StaleEdit', statusCode: 409);
      expect(PlanGate.fromRefusal(other, (k, l) => _spec), isNull);
      PlanGate.debugPlan = OwnerPlans.paymentOff;
      expect(PlanGate.fromRefusal(limit, (k, l) => _spec), isNull);
    });
  });

  group('payment OFF shows no gate key anywhere', () {
    testOwnerSizes(
      'locks with payment OFF',
      _locks,
      setUpEach: () => PlanGate.debugPlan = OwnerPlans.paymentOff,
      check: (tester, size, scale) async {
        expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
        expect(find.text('unlocked row'), findsOneWidget);
        expect(find.textContaining(OwnerSharedStrings.seePlus), findsNothing);
        await tester.tap(find.text('open gate'));
        await tester.pumpAndSettle();
        expect(find.byKey(GateKeys.sheet), findsNothing);
      },
    );
  });

  group('Free shows the locks and the gate sheet', () {
    testOwnerSizes(
      'locks on Free',
      _locks,
      setUpEach: () => PlanGate.debugPlan = OwnerPlans.free,
      check: (tester, size, scale) async {
        expect(find.byKey(GateKeys.plusChip), findsWidgets);
        expect(find.byKey(GateKeys.softRow), findsOneWidget);
        expect(find.byKey(GateKeys.softArrow), findsOneWidget);
        await tester.tap(find.text('open gate'));
        await tester.pumpAndSettle();
        expect(find.byKey(GateKeys.sheet), findsOneWidget);
        expect(find.text('You have 4 active entries'), findsOneWidget);
        expect(find.text('₹500 / month'), findsOneWidget);
        expect(find.textContaining('days free'), findsNothing);
        expect(find.text(_spec.tip!), findsOneWidget);
        await tester.tap(find.text(OwnerSharedStrings.notNow));
        await tester.pumpAndSettle();
        expect(find.byKey(GateKeys.sheet), findsNothing);
        expect(find.text('open gate'), findsOneWidget);
      },
    );
  });
}
