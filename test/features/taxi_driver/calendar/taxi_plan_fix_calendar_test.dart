import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/owner_inactive.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_bookings_tab.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_upcoming_screen.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_gate_strings_calendar.dart';
import 'package:bakhli/features/taxi_driver/taxi_driver_deps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import 'taxi_cal_fixtures.dart';

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _drain(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(seconds: 4));
  }
}

const _line = ValueKey('taxi_plus_full_line');

void main() {
  setUpAll(() => initTestStorage('taxi_plan_fix_cal'));
  tearDown(calTearDown);

  test('Plus full copy', () {
    expect(TaxiGateStringsCalendar.plusFull(50), 'You can keep up to 50 trips you add.');
  });

  testWidgets('bookings tab Plus 50 of 50: calm grey line under Add', (t) async {
    final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(), plus: true, used: 50, limit: 50)}), plan: OwnerPlans.plus);
    await pumpPhone(t, TaxiBookingsTab(root: true, controller: c));
    await _settle(t);
    await t.scrollUntilVisible(find.byKey(_line), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('You can keep up to 50 trips you add.'), findsOneWidget);
  });

  testWidgets('bookings tab Plus 14 of 50: no line', (t) async {
    final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(), plus: true, used: 14)}), plan: OwnerPlans.plus);
    await pumpPhone(t, TaxiBookingsTab(root: true, controller: c));
    await _settle(t);
    expect(find.byKey(_line), findsNothing);
  });

  testWidgets('bookings tab Free 4 of 4 can upgrade: no line (Add opens the gate)', (t) async {
    final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(), used: 4)}));
    await pumpPhone(t, TaxiBookingsTab(root: true, controller: c));
    await _settle(t);
    expect(find.byKey(_line), findsNothing);
  });

  testWidgets('upcoming: an inactive trip is greyed with Delete only, no open', (t) async {
    final opened = <String>[];
    final fake = CalFake(upcoming: {
      null: {
        'items': [
          tripJson('m25', from: '2026-11-25', time: '09:30', label: 'Mehra family'),
          {...tripJson('m29', from: '2027-01-29', time: '07:00', label: 'January drop'), 'inactiveByPlan': true},
        ],
      },
    });
    final c = calSetUp(fake);
    TaxiDriverDeps.openEntry = opened.add;
    await pumpPhone(t, TaxiUpcomingScreen(controller: c, windowEnd: DateTime(2026, 12, 6)));
    await _settle(t);
    final inactive = find.byKey(GateKeys.inactiveRow);
    expect(inactive, findsOneWidget);
    expect(find.descendant(of: inactive, matching: find.text('January drop')), findsOneWidget);
    expect(find.descendant(of: inactive, matching: find.text(TaxiGateStringsCalendar.entryInactive(TaxiGateStringsCalendar.freeEntries))), findsOneWidget);
    expect(find.byType(OwnerInactive), findsOneWidget);
    await t.tap(find.text('January drop'), warnIfMissed: false);
    await _settle(t);
    expect(opened, isEmpty);
    await t.tap(find.text('Mehra family'));
    await _settle(t);
    expect(opened, ['m25']);
    await t.tap(find.descendant(of: inactive, matching: find.text('Delete')));
    await _settle(t);
    await t.tap(find.text('Delete').last);
    await _settle(t);
    expect(fake.count('DELETE /taxis/me/calendar/entries/m29'), 1);
    await _drain(t);
  });
}
