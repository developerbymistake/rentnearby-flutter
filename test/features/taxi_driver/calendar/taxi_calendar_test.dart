import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/money/money_note_math.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/sheets/owner_states.dart';
import 'package:bakhli/features/taxi_driver/calendar/models/taxi_calendar_models.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_balance_due_screen.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_bookings_tab.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_calendar_controller.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_calendar_entry_screen.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_money_summary_screen.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_past_screen.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_trip_sheet.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_trip_text.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_upcoming_card.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_upcoming_screen.dart';
import 'package:bakhli/features/taxi_driver/taxi_driver_deps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import 'taxi_cal_fixtures.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 120));
  }
}

Future<void> drain(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(seconds: 4));
  }
}

CalendarEntry entryOf(Map<String, dynamic> j) => CalendarEntry.fromJson(j);

Finder gateKeys() => find.byWidgetPredicate((w) => w.key is GateKey);

List<Map<String, dynamic>> manyManual(int n) => [
      for (var i = 0; i < n; i++)
        tripJson('x$i', from: '2026-11-${(i % 9) + 22}', time: '08:00', fromPlace: 'Haldwani with a very long pickup name', toPlace: 'Mukteshwar', label: 'Long family trip name number $i', finalAmount: 2200, received: 100),
    ];

void main() {
  setUpAll(() => initTestStorage('taxi_cal_test'));
  tearDown(calTearDown);

  group('models and text', () {
    test('month view adds up to the frame numbers (o_tx_29, o_tx_30, o_tx_32)', () {
      final data = CalendarMonth.fromJson(monthJson(entries: novEntries(paidExtras: true), plus: true));
      final v = TaxiMonthView.build(DateTime(2026, 11), data, today: calToday);
      expect(TaxiCalendarController.sumBooked(v.monthRows), 17100);
      expect(TaxiCalendarController.sumReceived(v.monthRows), 11100);
      expect(TaxiCalendarController.sumToCollect(v.monthRows), 6000);
      expect(v.tripCount, 9);
      expect(v.balanceRows.map((e) => e.label), ['Mehra family', 'Sharma family, Ranikhet', 'Vikram Singh', 'Bhimtal round trip']);
      expect(v.paidRows.length, 5);
      expect(v.paidRows.first.id, 'a23');
      expect(v.festival?.name, 'Diwali week');
    });

    test('free month counts (o_tx_24): app trips this month and active own trips', () {
      final v = TaxiMonthView.build(DateTime(2026, 11), CalendarMonth.fromJson(monthJson(entries: novEntries())), today: calToday);
      expect(v.appCount, 3);
      expect(v.ownActive, 3);
    });

    test('cancelled entry leaves booked and to collect', () {
      final rows = [entryOf(tripJson('c', kind: 'Auto', from: '2026-11-25', label: 'A', cancelled: true, finalAmount: 2000, received: 500))];
      expect(TaxiCalendarController.sumBooked(rows), 0);
      expect(TaxiCalendarController.sumToCollect(rows), 0);
      expect(TaxiTripText.chip(rows.first), MoneyChip.received);
    });

    test('app rows never print a time or a fare; own rows print time and route', () {
      final auto = entryOf(tripJson('a', kind: 'Auto', from: '2026-11-23', time: '09:00', fromPlace: 'Kathgodam', toPlace: 'Nainital', label: 'Priya Rawat'));
      expect(TaxiTripText.upcomingLine(auto), '23 Nov, all day · Priya Rawat');
      expect(TaxiTripText.title(auto), 'Kathgodam to Nainital');
      expect(TaxiTripText.timeTile(auto), (top: 'All', bottom: 'DAY'));
      final multi = entryOf(tripJson('m', kind: 'Auto', from: '2026-12-18', to: '2026-12-26', fromPlace: 'Kathgodam', label: 'Aarav Sharma'));
      expect(TaxiTripText.upcomingLine(multi), '18 to 26 Dec · 9 days · Aarav Sharma');
      expect(TaxiTripText.title(multi), 'Kathgodam pickup');
      final own = entryOf(tripJson('o', from: '2026-11-25', time: '09:30', fromPlace: 'Haldwani', toPlace: 'Mukteshwar', label: 'Mehra family', finalAmount: 2200));
      expect(TaxiTripText.upcomingLine(own), '9:30 am · Haldwani to Mukteshwar');
      expect(TaxiTripText.monthLine(own), '9:30 am · ₹2,200');
      expect(TaxiTripText.pastLine(own), 'Haldwani to Mukteshwar · 9:30 am');
      expect(TaxiTripText.timeTile(own), (top: '9:30', bottom: 'AM'));
      final removed = entryOf({...tripJson('r', kind: 'Auto', from: '2026-11-23', label: ''), 'travellerRemoved': true});
      expect(TaxiTripText.traveller(removed), 'Traveller removed');
    });

    test('entry parse never throws on broken data', () {
      for (final v in jsonVariants(tripJson('a', kind: 'Auto', from: '2026-11-23', fromPlace: 'K', label: 'P', places: const ['A', 'B']))) {
        final e = CalendarEntry.fromJson(v);
        TaxiTripText.title(e);
        TaxiTripText.upcomingLine(e);
        TaxiTripText.pastLine(e);
        TaxiTripText.collectLine(e);
        TaxiEntryBody.head(e);
      }
    });

    test('manual trip days seam returns only own dates inside the range', () async {
      final fake = CalFake(months: {'2026-12': monthJson(entries: decEntries(), plus: true, monthFrom: '2026-11-01')});
      final c = calSetUp(fake, plan: OwnerPlans.plus);
      await c.open(DateTime(2026, 12));
      expect(c.manualDays(DateTime(2026, 12, 18), DateTime(2026, 12, 26)), [DateTime(2026, 12, 25)]);
      expect(c.manualDays(DateTime(2026, 12, 13), DateTime(2026, 12, 17)), isEmpty);
    });
  });

  group('bookings tab', () {
    testWidgets('free (o_tx_24): meters, locked summary and reminder, soft lock arrow', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      expect(find.text('3 of 4'), findsOneWidget);
      expect(find.text('From the app this month'), findsOneWidget);
      expect(find.text('Diwali week · 6 to 12 Nov'), findsOneWidget);
      expect(find.text('Festival in Uttarakhand · fares unchanged'), findsOneWidget);
      expect(find.text('₹ ●●,●●●'), findsNWidgets(3));
      expect(find.byKey(GateKeys.softArrow), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Today’s trips at 7:00 am · Plus'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Today’s trips at 7:00 am · Plus'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('no Past button in the header; Past trips link sits in the list', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      expect(find.text('Past'), findsNothing);
      await tester.scrollUntilVisible(find.text('Past trips ›'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Past trips ›'), findsOneWidget);
    });

    testWidgets('Add trip at 4 of 4 on Free opens the gate sheet before the form', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(), used: 4)}));
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      final add = find.text('+ Add');
      await tester.scrollUntilVisible(add, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(add);
      await settle(tester);
      await tester.tap(find.text('A trip you got by phone or WhatsApp'));
      await settle(tester);
      expect(find.byKey(GateKeys.sheet), findsOneWidget);
      expect(find.text('Save trip'), findsNothing);
    });

    testWidgets('Add trip at 50 of 50 on Plus is disabled', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(), plus: true, used: 50, limit: 50)}), plan: OwnerPlans.plus);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      final add = find.text('+ Add');
      await tester.scrollUntilVisible(add, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(add, warnIfMissed: false);
      await settle(tester);
      expect(find.text('Save trip'), findsNothing);
      expect(find.byKey(GateKeys.sheet), findsNothing);
    });

    testWidgets('plus (o_tx_29): chips, open card, switch, months ahead', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries(paidExtras: true), plus: true, used: 14)});
      final c = calSetUp(fake, plan: OwnerPlans.plus);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      expect(find.text('Nov'), findsOneWidget);
      expect(find.text('Dec'), findsOneWidget);
      expect(find.text('₹17,100'), findsOneWidget);
      expect(find.text('To collect ›'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('14 of 50'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('14 of 50'), findsOneWidget);
      expect(find.text('6 months'), findsOneWidget);
      expect(find.byKey(GateKeys.softCard), findsNothing);
      expect(find.byKey(GateKeys.softArrow), findsNothing);
      await tester.scrollUntilVisible(find.byType(Switch), -200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byType(Switch));
      await settle(tester);
      expect(fake.count('PUT /taxis/me/calendar/reminder'), 1);
      expect(fake.bodies.last?['on'], false);
      expect(c.reminderOn.value, false);
    });

    testWidgets('payment off: no gate widget anywhere, summary open', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(), plus: true)}), plan: OwnerPlans.paymentOff);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      expect(gateKeys(), findsNothing);
      expect(find.text('See Plus'), findsNothing);
      expect(find.text('Plus'), findsNothing);
      expect(find.text('₹ ●●,●●●'), findsNothing);
    });

    testWidgets('failed load shows Could not load bookings + Try again, no spinner', (tester) async {
      final c = calSetUp(CalFake());
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await drain(tester);
      expect(find.text('Could not load bookings'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('downgraded (o_tx_47 A): hidden line and shield note', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(), used: 4, hidden: 6)}));
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Nothing is deleted. App bookings are never hidden.'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('6 more trips are hidden. They show as dates pass.'), findsOneWidget);
      expect(find.text('3 of 3 shown'), findsOneWidget);
    });

    testWidgets('app bookings seam is mounted below', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: const [])}));
      TaxiDriverDeps.appBookings = () => const Text('APP CARDS');
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('APP CARDS'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('APP CARDS'), findsOneWidget);
    });

    testWidgets('owned controller is released on dispose', (tester) async {
      calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      Get.delete<TaxiCalendarController>(tag: TaxiCalendarController.tag, force: true);
      await pumpPhone(tester, const TaxiBookingsTab(root: false));
      await settle(tester);
      expect(TaxiCalendarController.maybe, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(TaxiCalendarController.maybe, isNull);
    });

    for (final rows in [0, 1, 50]) {
      testOwnerSizes(
        'free tab with $rows own rows',
        () => TaxiBookingsTab(root: true, controller: TaxiCalendarController.maybe),
        setUpEach: () => calSetUp(CalFake(months: {'2026-11': monthJson(entries: manyManual(rows), used: rows.clamp(0, 4))})),
        arrange: settle,
      );
      testOwnerSizes(
        'plus tab with $rows own rows',
        () => TaxiBookingsTab(root: true, controller: TaxiCalendarController.maybe),
        setUpEach: () => calSetUp(CalFake(months: {'2026-11': monthJson(entries: manyManual(rows), plus: true, used: rows)}), plan: OwnerPlans.plus),
        arrange: settle,
      );
    }
  });

  group('trip sheet', () {
    Future<TaxiCalendarController> openSheet(WidgetTester tester, CalFake fake, {plan = OwnerPlans.free}) async {
      final c = calSetUp(fake, plan: plan);
      await c.open(DateTime(2026, 11));
      await pumpPhone(tester, Scaffold(body: Builder(builder: (ctx) => TextButton(onPressed: () => TaxiTripSheet.show(ctx, controller: c), child: const Text('open')))), toastHost: true);
      await tester.tap(find.text('open'));
      await settle(tester);
      return c;
    }

    testWidgets('empty label shows the frame line, nothing sent', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries())});
      await openSheet(tester, fake);
      await tester.tap(find.text('Save trip'));
      await settle(tester);
      expect(find.text('Add a name for this trip.'), findsOneWidget);
      expect(fake.count('POST'), 0);
    });

    testWidgets('phone digits in a text field are refused', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries())});
      await openSheet(tester, fake);
      await tester.enterText(find.byType(TextField).at(0), 'Call 98765 43210');
      await tester.tap(find.text('Save trip'));
      await settle(tester);
      expect(find.text('Do not add phone numbers.'), findsOneWidget);
      expect(fake.count('POST'), 0);
    });

    testWidgets('G10 at 4 of 4 on Free opens before the form, Not now leaves no form', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries(), used: 4)});
      await openSheet(tester, fake);
      expect(find.byKey(GateKeys.sheet), findsOneWidget);
      expect(find.text('Save trip'), findsNothing);
      expect(find.text('You have 4 active entries'), findsOneWidget);
      expect(find.text('Free keeps 4 trips you add yourself. Plus keeps 50.'), findsOneWidget);
      expect(find.text('₹300 / month'), findsOneWidget);
      expect(find.textContaining('days free'), findsNothing);
      await tester.tap(find.text('Not now'));
      await settle(tester);
      expect(find.text('Save trip'), findsNothing);
      expect(fake.count('POST'), 0);
    });

    testWidgets('no trial: price line without 7 days free', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries(), used: 4)});
      await openSheet(tester, fake, plan: OwnerPlans.freeNoTrial);
      expect(find.text('₹300 / month'), findsOneWidget);
    });

    testWidgets('payment off at the cap: no gate, server refusal is a toast and the sheet stays', (tester) async {
      final fake = CalFake(
        months: {'2026-11': monthJson(entries: novEntries(), used: 50, limit: 50)},
        writeRefusal: {
          'status': 409,
          'body': {
            'error': {'type': 'CalendarEntryLimit', 'message': 'You can add up to 50 entries.'},
            'data': {'key': 'CalendarEntries', 'limit': 50, 'used': 50, 'canUpgrade': false},
          },
        },
      );
      await openSheet(tester, fake, plan: OwnerPlans.paymentOff);
      await tester.enterText(find.byType(TextField).at(0), 'Airport drop');
      await tester.tap(find.text('Save trip'));
      await settle(tester);
      expect(gateKeys(), findsNothing);
      expect(fake.count('POST'), 1);
      expect(find.text('Airport drop'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('double tap on Save sends one POST and closes', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries())});
      await openSheet(tester, fake);
      await tester.enterText(find.byType(TextField).at(0), 'Airport drop');
      await tester.tap(find.text('Save trip'));
      await tester.tap(find.text('Save trip'), warnIfMissed: false);
      await settle(tester);
      expect(fake.count('POST /taxis/me/calendar/entries'), 1);
      expect(find.text('Add trip'), findsNothing);
      final body = fake.bodies.whereType<Map<String, dynamic>>().firstWhere((b) => b.containsKey('label'));
      expect(body['label'], 'Airport drop');
      expect(body['dateFrom'], body['dateTo']);
    });

    testWidgets('offline keeps the sheet and the typed values', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries())}, writeOffline: true);
      await openSheet(tester, fake);
      await tester.enterText(find.byType(TextField).at(0), 'Airport drop');
      await tester.tap(find.text('Save trip'));
      await settle(tester);
      expect(find.text('Airport drop'), findsOneWidget);
      expect(find.text('Save trip'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('own trip on a day with an app booking shows the grey line (o_tx_47 C)', (tester) async {
      final fake = CalFake(months: {'2026-12': monthJson(entries: decEntries(), plus: true, monthFrom: '2026-11-01')});
      final c = calSetUp(fake, plan: OwnerPlans.plus);
      await c.open(DateTime(2026, 12));
      final draft = entryOf(tripJson('n', from: '2026-12-20', fromPlace: 'Haldwani', label: 'Airport drop, Mehra ji'));
      await pumpPhone(tester, Scaffold(body: Builder(builder: (ctx) => TextButton(onPressed: () => TaxiTripSheet.show(ctx, controller: c, editing: draft), child: const Text('open')))));
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.text('You already have 1 booking on this day.'), findsOneWidget);
    });

    testWidgets('edit at 4 of 4 is never gated', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries(), used: 4)});
      final c = calSetUp(fake);
      await c.open(DateTime(2026, 11));
      final e = c.current!.entries.firstWhere((x) => x.id == 'm25');
      await pumpPhone(tester, Scaffold(body: Builder(builder: (ctx) => TextButton(onPressed: () => TaxiTripSheet.show(ctx, controller: c, editing: e), child: const Text('open')))));
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.tap(find.text('Save trip'));
      await settle(tester);
      expect(gateKeys(), findsNothing);
      expect(fake.count('PUT /taxis/me/calendar/entries/m25'), 1);
    });
  });

  group('entry detail', () {
    testWidgets('app booking with money (o_tx_27)', (tester) async {
      final c = calSetUp(CalFake(entries: {
        'a23': tripJson('a23', kind: 'Auto', from: '2026-11-23', fromPlace: 'Kathgodam', toPlace: 'Nainital', label: 'Priya Rawat', guests: 3, finalAmount: 1800, paid: true),
      }));
      await pumpPhone(tester, TaxiCalendarEntryScreen(args: const {'id': 'a23'}, controller: c));
      await settle(tester);
      for (final t in ['23 Nov · all day', 'Kathgodam to Nainital', 'Confirmed', 'Priya Rawat', '3 travellers', 'Paid in full', 'Open booking', 'Edit amounts',
        'Date and places come from the confirmed request. Changes happen there. Money notes are yours to write.']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining(RegExp(r'\d (am|pm)')), findsNothing);
    });

    testWidgets('dates-only booking (o_tx_46 B) shows dashes and Add amounts', (tester) async {
      final c = calSetUp(CalFake(entries: {
        'd18': tripJson('d18', kind: 'Auto', from: '2026-12-18', to: '2026-12-26', fromPlace: 'Kathgodam hub', toPlace: 'Kathgodam hub', label: 'Aarav Sharma', seats: 4, places: const ['Nainital', 'Ranikhet', 'Kausani', 'Almora', 'Binsar']),
      }));
      await pumpPhone(tester, TaxiCalendarEntryScreen(args: const {'id': 'd18'}, controller: c));
      await settle(tester);
      expect(find.text('18 to 26 Dec'), findsOneWidget);
      expect(find.text('9 days · all day'), findsOneWidget);
      expect(find.text('4 seater'), findsOneWidget);
      expect(find.text('Nainital, Ranikhet, Kausani +2'), findsOneWidget);
      expect(find.text('–'), findsNWidgets(3));
      expect(find.text('Add amounts'), findsOneWidget);
      expect(find.text('Removed automatically 90 days after 26 Dec.'), findsOneWidget);
    });

    testWidgets('cancelled booking (o_tx_46 C)', (tester) async {
      final c = calSetUp(CalFake(entries: {
        'j02': tripJson('j02', kind: 'Auto', from: '2027-01-02', fromPlace: 'Pantnagar airport', label: 'Seema Joshi', cancelled: true, cancelledBy: 'Traveller', cancelledOn: '2026-12-28', finalAmount: 2000, received: 500),
      }));
      await pumpPhone(tester, TaxiCalendarEntryScreen(args: const {'id': 'j02'}, controller: c));
      await settle(tester);
      expect(find.text('From the app · cancelled'), findsOneWidget);
      expect(find.text('By Seema on 28 Dec'), findsOneWidget);
      expect(find.text('₹500 received'), findsOneWidget);
      expect(find.text('Your dates are free again. Notes stay until 2 Apr.'), findsOneWidget);
    });

    testWidgets('own trip (o_tx_46 D): Keep does nothing, Delete sends one DELETE', (tester) async {
      final fake = CalFake(entries: {
        'm25': tripJson('m25', from: '2026-11-25', time: '09:30', fromPlace: 'Haldwani', toPlace: 'Mukteshwar', label: 'Mehra family', note: '2 bags, pick up at the gate', finalAmount: 2200, received: 500),
      });
      final c = calSetUp(fake);
      await pumpPhone(tester, TaxiCalendarEntryScreen(args: const {'id': 'm25'}, controller: c));
      await settle(tester);
      expect(find.text('25 Nov · 9:30 am'), findsOneWidget);
      expect(find.text('₹1,700 to collect'), findsOneWidget);
      expect(find.text('Open booking'), findsNothing);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(find.text('Delete this trip?'), findsOneWidget);
      expect(find.text('Its money notes go with it.'), findsOneWidget);
      await tester.tap(find.text('Keep'));
      await settle(tester);
      expect(fake.count('DELETE'), 0);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.tap(find.text('Delete').last);
      await settle(tester);
      expect(fake.count('DELETE /taxis/me/calendar/entries/m25'), 1);
      await drain(tester);
    });

    testWidgets('missing id or unknown entry never crashes', (tester) async {
      final c = calSetUp(CalFake());
      await pumpPhone(tester, TaxiCalendarEntryScreen(args: const {'id': 7}, controller: c));
      await settle(tester);
      expect(find.text("Couldn't load"), findsOneWidget);
      await pumpPhone(tester, TaxiCalendarEntryScreen(key: const ValueKey('gone'), args: const {'id': 'gone'}, controller: c));
      await settle(tester);
      expect(find.text('This booking is no longer available.'), findsOneWidget);
    });

    testWidgets('open booking goes through the seam', (tester) async {
      String? opened;
      final c = calSetUp(CalFake(entries: {'a23': tripJson('a23', kind: 'Auto', from: '2026-11-23', fromPlace: 'K', label: 'P', sourceId: 'bk9')}));
      TaxiDriverDeps.openBooking = (id) => opened = id;
      await pumpPhone(tester, TaxiCalendarEntryScreen(args: const {'id': 'a23'}, controller: c));
      await settle(tester);
      await tester.tap(find.text('Open booking'));
      expect(opened, 'bk9');
    });
  });

  group('lists', () {
    testWidgets('upcoming (o_tx_48): month groups with counts and Show more paging', (tester) async {
      final fake = CalFake(upcoming: {
        null: {
          'items': [
            tripJson('a23', kind: 'Auto', from: '2026-11-23', fromPlace: 'K', toPlace: 'N', label: 'Priya Rawat'),
            tripJson('m25', from: '2026-11-25', time: '09:30', label: 'Mehra family'),
            tripJson('d05', from: '2026-12-05', time: '06:00', label: 'Corbett day trip'),
          ],
          'nextCursor': 'c2',
        },
        'c2': {
          'items': [tripJson('f01', from: '2027-02-01', label: 'Feb trip')],
        },
      });
      final c = calSetUp(fake, plan: OwnerPlans.plus);
      await pumpPhone(tester, TaxiUpcomingScreen(controller: c, windowEnd: DateTime(2027, 5, 21)));
      await settle(tester);
      expect(find.text('Next 6 months, until 21 May 2027'), findsOneWidget);
      expect(find.text('NOVEMBER 2026'), findsOneWidget);
      expect(find.text('DECEMBER 2026'), findsOneWidget);
      await tester.tap(find.text('Show more'));
      await settle(tester);
      expect(find.text('FEBRUARY 2027'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
    });

    testWidgets('upcoming reloads its list after a calendar write', (tester) async {
      final fake = CalFake(upcoming: {
        null: {
          'items': [tripJson('m25', from: '2026-11-25', time: '09:30', label: 'Mehra family')],
        },
      });
      final c = calSetUp(fake, plan: OwnerPlans.plus);
      await pumpPhone(tester, TaxiUpcomingScreen(controller: c, windowEnd: DateTime(2027, 5, 21)));
      await settle(tester);
      expect(find.text('Mehra family'), findsOneWidget);
      fake.upcoming = {
        null: {'items': const <Map<String, dynamic>>[]},
      };
      await tester.runAsync(() => c.delete('m25'));
      await settle(tester);
      expect(fake.count('DELETE'), 1);
      expect(find.text('Mehra family'), findsNothing);
    });

    testWidgets('upcoming on Free shows the after-window lock line', (tester) async {
      final fake = CalFake(upcoming: {
        null: {
          'items': [tripJson('a23', kind: 'Auto', from: '2026-11-23', fromPlace: 'K', label: 'Priya Rawat')],
          'beyondWindowAppCount': 1,
        },
      });
      final c = calSetUp(fake);
      await pumpPhone(tester, TaxiUpcomingScreen(controller: c, windowEnd: DateTime(2026, 12, 6)));
      await settle(tester);
      expect(find.text('After 6 Dec: 1 booking from the app (see Bookings). Plus shows 6 months ahead.'), findsOneWidget);
    });

    testWidgets('past (o_tx_34): month names, footer, no gate', (tester) async {
      final c = calSetUp(CalFake(past: {
        null: {
          'items': [
            tripJson('p19', from: '2026-11-19', time: '06:00', fromPlace: 'Haldwani', label: 'Corbett day trip', finalAmount: 2400, paid: true),
            tripJson('p30', kind: 'Auto', from: '2026-10-30', fromPlace: 'Pantnagar airport', label: 'Seema Joshi', finalAmount: 1200, paid: true),
          ],
        },
      }));
      await pumpPhone(tester, TaxiPastScreen(controller: c, plate: 'UK 04 TA 2231'));
      await settle(tester);
      expect(find.text('UK 04 TA 2231 · 22 Aug to 20 Nov'), findsOneWidget);
      expect(find.text('NOVEMBER'), findsOneWidget);
      expect(find.text('OCTOBER'), findsOneWidget);
      expect(find.text('Haldwani · 6:00 am'), findsOneWidget);
      expect(find.text('All day · Seema Joshi'), findsOneWidget);
      expect(find.text('Older entries are removed automatically after 3 months.'), findsOneWidget);
      expect(gateKeys(), findsNothing);
    });

    testWidgets('past empty shows only the footer line; error shows Try again', (tester) async {
      final c = calSetUp(CalFake());
      await pumpPhone(tester, TaxiPastScreen(controller: c));
      await settle(tester);
      expect(find.text('Older entries are removed automatically after 3 months.'), findsOneWidget);
      final c2 = calSetUp(CalFake(offline: true));
      await pumpPhone(tester, TaxiPastScreen(key: const ValueKey('c2'), controller: c2));
      await drain(tester);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('money summary (o_tx_30): short list and Balance due (4)', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(paidExtras: true), plus: true, used: 14)}), plan: OwnerPlans.plus);
      await pumpPhone(tester, TaxiMoneySummaryScreen(controller: c));
      await settle(tester);
      expect(find.text('Balance due (4)'), findsOneWidget);
      expect(find.text('₹2,200 to collect'), findsOneWidget);
      expect(find.text('25 Nov · Added by you'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('money summary nothing to collect', (tester) async {
      final c = calSetUp(
        CalFake(months: {'2026-11': monthJson(entries: [tripJson('p', from: '2026-11-25', label: 'X', finalAmount: 100, paid: true)], plus: true)}, summary: const {'month': '2026-11', 'finalTotal': 0, 'receivedTotal': 0, 'balanceTotal': 0, 'entryCount': 1, 'dueCount': 0, 'topBalances': [], 'paymentEnabled': true}),
        plan: OwnerPlans.plus,
      );
      await pumpPhone(tester, TaxiMoneySummaryScreen(controller: c));
      await settle(tester);
      expect(find.text('Nothing to collect'), findsOneWidget);
    });

    testWidgets('free never calls the summary endpoint', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries())});
      final c = calSetUp(fake);
      await pumpPhone(tester, TaxiMoneySummaryScreen(controller: c));
      await settle(tester);
      expect(fake.count('GET /taxis/me/calendar/summary'), 0);
      expect(find.byKey(GateKeys.softCard), findsOneWidget);
    });

    testWidgets('balance due (o_tx_32): sections, counts, mark paid asks first then one PUT', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries(paidExtras: true), plus: true, used: 14)});
      final c = calSetUp(fake, plan: OwnerPlans.plus);
      await pumpPhone(tester, TaxiBalanceDueScreen(controller: c));
      await settle(tester);
      expect(find.text('November 2026 · ₹6,000 to collect'), findsOneWidget);
      expect(find.text('STILL TO COLLECT'), findsOneWidget);
      expect(find.text('Haldwani to Mukteshwar · of ₹2,200'), findsOneWidget);
      expect(find.text('To Haldwani · of ₹1,200'), findsOneWidget);
      await tester.tap(find.text('Mark paid').first);
      await settle(tester);
      expect(find.text('Mark paid?'), findsOneWidget);
      await tester.tap(find.text('Keep'));
      await settle(tester);
      expect(fake.count('PUT'), 0);
      await tester.tap(find.text('Mark paid').first);
      await settle(tester);
      await tester.tap(find.text('Mark paid').last);
      await settle(tester);
      expect(fake.count('PUT /taxis/me/calendar/entries/m25/money'), 1);
      await tester.scrollUntilVisible(find.text('Show 3 more paid trips'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Show 3 more paid trips'));
      await settle(tester);
      expect(find.text('Show 3 more paid trips'), findsNothing);
    });

    for (final screen in <String, Widget Function()>{
      'upcoming': () => TaxiUpcomingScreen(controller: TaxiCalendarController.maybe),
      'past': () => TaxiPastScreen(controller: TaxiCalendarController.maybe),
      'balance due': () => TaxiBalanceDueScreen(controller: TaxiCalendarController.maybe),
      'summary': () => TaxiMoneySummaryScreen(controller: TaxiCalendarController.maybe),
    }.entries) {
      testOwnerSizes(
        '${screen.key} with many rows',
        screen.value,
        setUpEach: () => calSetUp(
          CalFake(
            months: {'2026-11': monthJson(entries: [...novEntries(paidExtras: true), ...manyManual(25)], plus: true, used: 34)},
            upcoming: {null: {'items': manyManual(25), 'nextCursor': 'x'}},
            past: {null: {'items': manyManual(25)}},
          ),
          plan: OwnerPlans.plus,
        ),
        arrange: settle,
      );
    }

    testWidgets('a request that never answers leaves no spinner stuck in the error path', (tester) async {
      final c = calSetUp(CalFake(hang: true));
      await pumpPhone(tester, TaxiPastScreen(controller: c));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('upcoming card', () {
    Widget card(OwnerUpcoming up) => Scaffold(body: SingleChildScrollView(child: TaxiUpcomingCardView(load: OwnerLoadData(up))));

    final rows = [
      entryOf(tripJson('a23', kind: 'Auto', from: '2026-11-23', fromPlace: 'Kathgodam', toPlace: 'Nainital', label: 'Priya Rawat')),
      entryOf(tripJson('m25', from: '2026-11-25', time: '09:30', fromPlace: 'Haldwani', toPlace: 'Mukteshwar', label: 'Mehra family', finalAmount: 2200)),
    ];

    testWidgets('free (o_tx_23): Upcoming bookings heading with See all, rows, lock line, no button row', (tester) async {
      calSetUp(CalFake());
      await pumpPhone(tester, card(OwnerUpcoming(rows: rows, moreInWindowCount: 1, beyondWindowAppCount: 1, window: CalendarWindow(upcomingTo: DateTime(2026, 12, 6)))));
      expect(find.text('Upcoming bookings'), findsOneWidget);
      expect(find.text('See all ›'), findsOneWidget);
      expect(find.text('Next 15 days'), findsOneWidget);
      expect(find.text('23 Nov, all day · Priya Rawat'), findsOneWidget);
      expect(find.text('₹2,200'), findsOneWidget);
      expect(find.text('1 more in the next 15 days'), findsNothing);
      expect(find.text('After 6 Dec: 1 booking from the app (see Bookings). Plus shows 6 months ahead.'), findsOneWidget);
      for (final t in ['View calendar', 'Past', '+ Add trip']) {
        expect(find.text(t), findsNothing);
      }
    });

    testWidgets('plus and payment off: no lock line, months window', (tester) async {
      for (final plan in [OwnerPlans.plus, OwnerPlans.paymentOff]) {
        calSetUp(CalFake(), plan: plan);
        await pumpPhone(tester, card(OwnerUpcoming(rows: rows, beyondWindowAppCount: 1, window: CalendarWindow(upcomingTo: DateTime(2027, 5, 21)))));
        expect(find.text('Next 6 months'), findsOneWidget);
        expect(find.textContaining('After '), findsNothing);
        expect(gateKeys(), findsNothing);
      }
    });

    testWidgets('empty and loading states', (tester) async {
      calSetUp(CalFake());
      await pumpPhone(tester, card(const OwnerUpcoming()));
      expect(find.text('Upcoming bookings'), findsNothing);
      expect(find.text('See all ›'), findsNothing);
      await pumpPhone(tester, const Scaffold(body: SingleChildScrollView(child: TaxiUpcomingCardView(load: OwnerLoadLoading()))));
      expect(find.text('Upcoming bookings'), findsOneWidget);
    });

    testWidgets('row tap opens the entry seam', (tester) async {
      calSetUp(CalFake());
      String? opened;
      TaxiDriverDeps.openEntry = (id) => opened = id;
      await pumpPhone(tester, card(OwnerUpcoming(rows: rows)));
      await tester.tap(find.text('Mehra family'));
      expect(opened, 'm25');
    });

    for (final n in [0, 1, 3]) {
      testOwnerSizes(
        'card with $n rows',
        () => card(OwnerUpcoming(rows: [for (var i = 0; i < n; i++) entryOf(manyManual(3)[i])], moreInWindowCount: n, beyondWindowAppCount: 1, window: CalendarWindow(upcomingTo: DateTime(2026, 12, 6)))),
        setUpEach: () => calSetUp(CalFake()),
      );
    }
  });
}
