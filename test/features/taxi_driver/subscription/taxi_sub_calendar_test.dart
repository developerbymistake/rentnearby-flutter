import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/owner_inactive.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_bookings_tab.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_calendar_controller.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_trip_sheet.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_gate_strings_calendar.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import '../calendar/taxi_cal_fixtures.dart';

// Matrix L1-L16 for the Taxi Bookings tab (calendar entries): Add trip per plan state, inactive rows, expire and re-buy.

const _paid = MyPlanModel(paymentEnabled: true, isPaid: true, isDefault: false, limits: OwnerPlans.plusLimits);
const _cancelled = MyPlanModel(paymentEnabled: true, isPaid: true, isDefault: false, limits: OwnerPlans.plusLimits, state: 'Cancelled');
const _grace = MyPlanModel(paymentEnabled: true, isPaid: true, isDefault: false, limits: OwnerPlans.plusLimits, state: 'Grace');
const _onHold = MyPlanModel(paymentEnabled: true, state: 'OnHold');
const _ended = MyPlanModel(paymentEnabled: true, state: 'Ended');

const _line = ValueKey('taxi_plus_full_line');

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

Finder get _addBtn => find.widgetWithText(PrimaryButton, '+ Add');

Future<PrimaryButton> _add(WidgetTester t) async {
  await t.scrollUntilVisible(_addBtn, 200, scrollable: find.byType(Scrollable).first);
  await t.pump();
  return t.widget<PrimaryButton>(_addBtn);
}

Future<void> _openTab(WidgetTester t, CalFake fake, MyPlanModel plan) async {
  final c = calSetUp(fake, plan: plan);
  await pumpPhone(t, TaxiBookingsTab(root: true, controller: c), toastHost: true);
  await _settle(t);
}

Map<String, dynamic> _month({required bool plus, required int used, required int limit, List<Map<String, dynamic>>? entries, int hidden = 0}) =>
    monthJson(entries: entries ?? novEntries(), plus: plus, used: used, limit: limit, hidden: hidden);

void main() {
  setUpAll(() => initTestStorage('taxi_sub_calendar'));
  tearDown(calTearDown);

  for (final (name, plan, plus, used, limit, enabled, line) in <(String, MyPlanModel, bool, int, int, bool, bool)>[
    ('L1 Free 3 of 4', OwnerPlans.free, false, 3, 4, true, false),
    ('L2 Free 4 of 4', OwnerPlans.free, false, 4, 4, true, false),
    ('L3 Plus after buy 4 of 50', _paid, true, 4, 50, true, false),
    ('L4 Plus 50 of 50', _paid, true, 50, 50, false, true),
    ('L5 Cancelled but running, 20 of 50', _cancelled, true, 20, 50, true, false),
    ('L5 Cancelled but running, 50 of 50', _cancelled, true, 50, 50, false, true),
    ('L7 Grace, 20 of 50', _grace, true, 20, 50, true, false),
    ('L7 Grace, 50 of 50', _grace, true, 50, 50, false, true),
    ('L8 On hold (as Free) 4 of 4', _onHold, false, 4, 4, true, false),
    ('L6 Expired (as Free) 4 of 4', _ended, false, 4, 4, true, false),
    ('L11 Trial 10 of 50', OwnerPlans.trial, true, 10, 50, true, false),
    ('L14 Payment OFF 10 of 50', OwnerPlans.paymentOff, true, 10, 50, true, false),
    ('L14 Payment OFF 50 of 50', OwnerPlans.paymentOff, true, 50, 50, false, true),
  ]) {
    testWidgets('Add trip: $name -> ${enabled ? 'enabled' : 'greyed'}, calm line ${line ? 'shown' : 'hidden'}', (t) async {
      await _openTab(t, CalFake(months: {'2026-11': _month(plus: plus, used: used, limit: limit)}), plan);
      final b = await _add(t);
      expect(b.onPressed != null, enabled);
      expect(find.byKey(_line), line ? findsOneWidget : findsNothing);
      if (line) expect(find.text(TaxiGateStringsCalendar.plusFull(limit)), findsOneWidget);
      await _drain(t);
    });
  }

  testWidgets('L2 Free 4 of 4: Add, then Booked opens the Plus sheet, no form', (t) async {
    await _openTab(t, CalFake(months: {'2026-11': _month(plus: false, used: 4, limit: 4)}), OwnerPlans.free);
    await _add(t);
    await t.tap(_addBtn);
    await _settle(t);
    await t.tap(find.text('A trip you got by phone or WhatsApp'));
    await _settle(t);
    expect(find.byKey(GateKeys.sheet), findsOneWidget);
    expect(find.text('Save trip'), findsNothing);
    await _drain(t);
  });

  testWidgets('L4 Plus 50 of 50: tapping the greyed Add does nothing', (t) async {
    await _openTab(t, CalFake(months: {'2026-11': _month(plus: true, used: 50, limit: 50)}), _paid);
    await _add(t);
    await t.tap(_addBtn, warnIfMissed: false);
    await _settle(t);
    expect(find.byKey(GateKeys.sheet), findsNothing);
    expect(find.text('Save trip'), findsNothing);
    await _drain(t);
  });

  testWidgets('L1/L3 Add below the limit, then Booked opens the trip form and sends no Plus sheet', (t) async {
    await _openTab(t, CalFake(months: {'2026-11': _month(plus: true, used: 4, limit: 50)}), _paid);
    await _add(t);
    await t.tap(_addBtn);
    await _settle(t);
    await t.tap(find.text('A trip you got by phone or WhatsApp'));
    await _settle(t);
    expect(find.byKey(GateKeys.sheet), findsNothing);
    expect(find.text('Save trip'), findsOneWidget);
    await _drain(t);
  });

  testWidgets('L6 expire then L9 re-buy: inactive trip is greyed with Delete, then active again with nothing lost', (t) async {
    final inactive = {...tripJson('m29', from: '2026-11-29', time: '07:00', label: 'January drop'), 'inactiveByPlan': true};
    final fake = CalFake(months: {'2026-11': _month(plus: false, used: 4, limit: 4, entries: [...novEntries(), inactive])});
    await _openTab(t, fake, _ended);
    await t.scrollUntilVisible(find.byKey(GateKeys.inactiveRow), 200, scrollable: find.byType(Scrollable).first);
    expect(find.descendant(of: find.byKey(GateKeys.inactiveRow), matching: find.text(TaxiGateStringsCalendar.entryInactive(4))), findsOneWidget);
    expect(find.descendant(of: find.byKey(GateKeys.inactiveRow), matching: find.text('Delete')), findsOneWidget);
    expect(find.byType(OwnerInactive), findsOneWidget);

    final c = TaxiCalendarController.maybe!;
    PlanGate.debugPlan = _paid;
    fake.months = {'2026-11': _month(plus: true, used: 5, limit: 50, entries: [...novEntries(), tripJson('m29', from: '2026-11-29', time: '07:00', label: 'January drop')])};
    await c.reload();
    await _settle(t);
    expect(find.byKey(GateKeys.inactiveRow), findsNothing);
    expect(find.byType(OwnerInactive), findsNothing);
    expect(c.view.value.monthRows.where((e) => e.id == 'm29' && !e.inactiveByPlan), isNotEmpty, reason: 'the trip is active again, nothing lost');
    expect(c.entriesFull, isFalse);
    await _drain(t);
  });

  testWidgets('L6 expire while Add is open: a stale edit of an inactive trip answers PlanRowInactive, sheet closes and the month reloads', (t) async {
    final fake = CalFake(
      months: {'2026-11': _month(plus: false, used: 4, limit: 4)},
      writeRefusal: {
        'status': 409,
        'body': {
          'error': {'type': 'PlanRowInactive', 'message': 'This trip is inactive. Delete it or get Plus.'},
        },
      },
    );
    final c = calSetUp(fake, plan: _ended);
    await c.open(DateTime(2026, 11));
    final entry = CalendarEntry.fromJson(tripJson('m25', from: '2026-11-25', time: '09:30', label: 'Mehra family'));
    await pumpPhone(
      t,
      Scaffold(body: Builder(builder: (ctx) => TextButton(onPressed: () => TaxiTripSheet.show(ctx, controller: c, editing: entry), child: const Text('open')))),
      toastHost: true,
    );
    await t.tap(find.text('open'));
    await _settle(t);
    expect(find.text('Save trip'), findsOneWidget);
    final months0 = fake.calls.where((e) => e == 'GET /taxis/me/calendar').length;
    await t.tap(find.text('Save trip'));
    await _settle(t);
    expect(fake.count('PUT'), 1);
    expect(find.text('Save trip'), findsNothing, reason: 'sheet closed');
    expect(fake.calls.where((e) => e == 'GET /taxis/me/calendar').length, months0 + 1, reason: 'month reloaded');
    await _drain(t);
  });

  test('entry copy follows the plan numbers', () {
    expect(TaxiGateStringsCalendar.entryInactive(4), 'Inactive on Free. Free keeps 4 trips you add. Delete it or get Plus.');
    expect(TaxiGateStringsCalendar.plusFull(50), 'You can keep up to 50 trips you add.');
    expect(TaxiGateStringsCalendar.title(4), 'You have 4 active entries');
    expect(TaxiGateStringsCalendar.body(4, 50), 'Free keeps 4 trips you add yourself. Plus keeps 50.');
  });
}
