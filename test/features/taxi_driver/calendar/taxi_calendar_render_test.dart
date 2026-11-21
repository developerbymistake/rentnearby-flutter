import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/sheets/owner_states.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_balance_due_screen.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_bookings_tab.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_calendar_entry_screen.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_money_summary_screen.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_past_screen.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_trip_sheet.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_upcoming_card.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_upcoming_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import 'taxi_cal_fixtures.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 120));
  }
}

CalendarEntry entryOf(Map<String, dynamic> j) => CalendarEntry.fromJson(j);

List<Map<String, dynamic>> downgradedEntries() => [
      tripJson('g23', from: '2026-11-23', time: '06:00', fromPlace: 'Haldwani', label: 'Corbett day trip', finalAmount: 1000, received: 0),
      tripJson('g25', from: '2026-11-25', time: '09:30', fromPlace: 'Haldwani', toPlace: 'Mukteshwar', label: 'Mehra family', finalAmount: 2200, received: 500),
      tripJson('g28', from: '2026-11-28', time: '10:00', fromPlace: 'Haldwani', label: 'Bhimtal round trip'),
      tripJson('g02', from: '2026-12-02', time: '14:00', fromPlace: 'Haldwani', toPlace: 'Nainital', label: 'Family trip'),
    ];

void main() {
  setUpAll(() => initTestStorage('taxi_cal_render'));
  useOwnerRenderScale();
  tearDown(calTearDown);

  testWidgets('render o_tx_23', (tester) async {
    final rows = [
      entryOf(tripJson('a23', kind: 'Auto', from: '2026-11-23', fromPlace: 'Kathgodam', toPlace: 'Nainital', label: 'Priya Rawat')),
      entryOf(tripJson('m25', from: '2026-11-25', time: '09:30', fromPlace: 'Haldwani', toPlace: 'Mukteshwar', label: 'Mehra family', finalAmount: 2200)),
      entryOf(tripJson('m28', from: '2026-11-28', time: '10:00', fromPlace: 'Haldwani', label: 'Bhimtal round trip', finalAmount: 1800)),
      entryOf(tripJson('a28', kind: 'Auto', from: '2026-11-28', fromPlace: 'Pantnagar airport', toPlace: 'Haldwani', label: 'Vikram Singh')),
    ];
    calSetUp(CalFake());
    final up = OwnerUpcoming(rows: rows, moreInWindowCount: 1, beyondWindowAppCount: 1, window: CalendarWindow(upcomingTo: DateTime(2026, 12, 6)));
    await renderOwnerFrame(
      tester,
      'o_tx_23',
      Scaffold(backgroundColor: ListingPalette.coral.page, body: SafeArea(child: SingleChildScrollView(child: TaxiUpcomingCardView(load: OwnerLoadData(up))))),
      arrange: settle,
    );
  });

  testWidgets('render o_tx_33', (tester) async {
    final rows = [
      entryOf(tripJson('m25', from: '2026-11-25', time: '09:30', fromPlace: 'Haldwani', toPlace: 'Mukteshwar', label: 'Mehra family', finalAmount: 2200)),
      entryOf(tripJson('a28', kind: 'Auto', from: '2026-11-28', fromPlace: 'Pantnagar airport', toPlace: 'Haldwani', label: 'Vikram Singh')),
    ];
    calSetUp(CalFake());
    await renderOwnerFrame(
      tester,
      'o_tx_33',
      Scaffold(
        backgroundColor: ListingPalette.coral.page,
        body: SafeArea(child: SingleChildScrollView(child: TaxiUpcomingCardView(load: OwnerLoadData(OwnerUpcoming(rows: rows, window: CalendarWindow(upcomingTo: DateTime(2026, 12, 6))))))),
      ),
      arrange: settle,
    );
  });

  testWidgets('render o_tx_24', (tester) async {
    final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
    await renderOwnerFrame(tester, 'o_tx_24', TaxiBookingsTab(root: true, controller: c), arrange: settle);
  });

  testWidgets('render o_tx_31', (tester) async {
    final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
    await renderOwnerFrame(tester, 'o_tx_31', TaxiBookingsTab(root: true, controller: c), arrange: (t) async {
      await settle(t);
      await t.drag(find.byType(ListView).first, const Offset(0, -620));
      await settle(t);
    });
  });

  testWidgets('render o_tx_29', (tester) async {
    final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(paidExtras: true), plus: true, used: 14)}), plan: OwnerPlans.plus);
    await renderOwnerFrame(tester, 'o_tx_29', TaxiBookingsTab(root: true, controller: c), arrange: settle);
  });

  testWidgets('render o_tx_30', (tester) async {
    final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(paidExtras: true), plus: true, used: 14)}), plan: OwnerPlans.plus);
    await renderOwnerFrame(tester, 'o_tx_30', TaxiMoneySummaryScreen(controller: c), arrange: settle);
  });

  testWidgets('render o_tx_32', (tester) async {
    final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(paidExtras: true), plus: true, used: 14)}), plan: OwnerPlans.plus);
    await renderOwnerFrame(tester, 'o_tx_32', TaxiBalanceDueScreen(controller: c), arrange: settle);
  });

  testWidgets('render o_tx_25', (tester) async {
    final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
    await renderOwnerFrame(tester, 'o_tx_25', TaxiBookingsTab(root: true, controller: c), arrange: (t) async {
      await settle(t);
      await t.tap(find.text('28').first);
      await settle(t);
    });
  });

  testWidgets('render o_tx_26', (tester) async {
    final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
    final draft = entryOf(tripJson('new', from: '2026-11-25', time: '09:30', fromPlace: 'Haldwani', toPlace: 'Mukteshwar', label: 'Mehra family', finalAmount: 2200, received: 0, note: 'Pickup at hotel gate'));
    await renderOwnerFrame(tester, 'o_tx_26', TaxiBookingsTab(root: true, controller: c), arrange: (t) async {
      await settle(t);
      TaxiTripSheet.show(t.element(find.byType(TaxiBookingsTab)), controller: c, editing: draft);
      await settle(t);
    });
  });

  testWidgets('render o_tx_28', (tester) async {
    final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(), used: 4)}));
    await renderOwnerFrame(tester, 'o_tx_28', TaxiBookingsTab(root: true, controller: c), arrange: (t) async {
      await settle(t);
      TaxiTripSheet.show(t.element(find.byType(TaxiBookingsTab)), controller: c);
      await settle(t);
      await t.enterText(find.byType(TextField).first, 'Airport drop');
      await t.tap(find.text('Save trip'));
      await settle(t);
    });
  });

  testWidgets('render o_tx_27', (tester) async {
    final c = calSetUp(CalFake(entries: {
      'a23': tripJson('a23', kind: 'Auto', from: '2026-11-23', fromPlace: 'Kathgodam', toPlace: 'Nainital', label: 'Priya Rawat', guests: 3, finalAmount: 1800, paid: true),
    }));
    await renderOwnerFrame(tester, 'o_tx_27', TaxiCalendarEntryScreen(args: const {'id': 'a23'}, controller: c), arrange: settle);
  });

  testWidgets('render o_tx_46 A', (tester) async {
    final c = calSetUp(CalFake(months: {'2026-12': monthJson(entries: decEntries(), plus: true, used: 14, monthFrom: '2026-11-01', festivals: const [])}), plan: OwnerPlans.plus);
    c.month.value = DateTime(2026, 12);
    await renderOwnerFrame(tester, 'o_tx_46', TaxiBookingsTab(root: true, controller: c), part: 'A', arrange: settle);
  });

  for (final e in {
    'B': tripJson('d18', kind: 'Auto', from: '2026-12-18', to: '2026-12-26', fromPlace: 'Kathgodam hub', toPlace: 'Kathgodam hub', label: 'Aarav Sharma', seats: 4, places: const ['Nainital', 'Ranikhet', 'Kausani', 'Almora', 'Binsar']),
    'C': tripJson('j02', kind: 'Auto', from: '2027-01-02', fromPlace: 'Pantnagar airport', label: 'Seema Joshi', cancelled: true, cancelledBy: 'Traveller', cancelledOn: '2026-12-28', finalAmount: 2000, received: 500),
    'D': tripJson('m25', from: '2026-11-25', time: '09:30', fromPlace: 'Haldwani', toPlace: 'Mukteshwar', label: 'Mehra family', note: '2 bags, pick up at the gate', finalAmount: 2200, received: 500),
  }.entries) {
    testWidgets('render o_tx_46 ${e.key}', (tester) async {
      final id = e.value['id'] as String;
      final c = calSetUp(CalFake(entries: {id: e.value}));
      await renderOwnerFrame(tester, 'o_tx_46', TaxiCalendarEntryScreen(args: {'id': id}, controller: c), part: e.key, arrange: (t) async {
        await settle(t);
        if (e.key == 'D') {
          await t.tap(find.text('Delete').last);
          await settle(t);
        }
      });
    });
  }

  testWidgets('render o_tx_47 A', (tester) async {
    final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: downgradedEntries(), used: 4, hidden: 6)}));
    await renderOwnerFrame(tester, 'o_tx_47', TaxiBookingsTab(root: true, controller: c), part: 'A', arrange: (t) async {
      await settle(t);
      await t.scrollUntilVisible(find.text('4 of 4 shown'), 300, scrollable: find.byType(Scrollable).first);
      await t.drag(find.byType(ListView).first, const Offset(0, -120));
      await settle(t);
    });
  });

  testWidgets('render o_tx_47 C', (tester) async {
    final c = calSetUp(CalFake(months: {'2026-12': monthJson(entries: decEntries(), plus: true, used: 14, festivals: const [])}), plan: OwnerPlans.plus);
    c.month.value = DateTime(2026, 12);
    final draft = entryOf(tripJson('new', from: '2026-12-20', time: '05:00', fromPlace: 'Haldwani', toPlace: 'Pantnagar', label: 'Airport drop, Mehra ji'));
    await renderOwnerFrame(tester, 'o_tx_47', TaxiBookingsTab(root: true, controller: c), part: 'C', arrange: (t) async {
      await settle(t);
      TaxiTripSheet.show(t.element(find.byType(TaxiBookingsTab)), controller: c, editing: draft);
      await settle(t);
    });
  });

  testWidgets('render o_tx_48', (tester) async {
    final c = calSetUp(CalFake(upcoming: {
      null: {
        'items': [
          tripJson('a23', kind: 'Auto', from: '2026-11-23', fromPlace: 'Kathgodam', toPlace: 'Nainital', label: 'Priya Rawat'),
          tripJson('m25', from: '2026-11-25', time: '09:30', fromPlace: 'Haldwani', toPlace: 'Mukteshwar', label: 'Mehra family', finalAmount: 2200, received: 500),
          tripJson('m28', from: '2026-11-28', time: '10:00', fromPlace: 'Haldwani', label: 'Bhimtal round trip', finalAmount: 1800, paid: true),
          tripJson('d05', from: '2026-12-05', time: '06:00', fromPlace: 'Haldwani', label: 'Corbett day trip'),
          tripJson('d18', kind: 'Auto', from: '2026-12-18', to: '2026-12-26', fromPlace: 'Kathgodam', label: 'Aarav Sharma'),
          tripJson('d20', from: '2026-12-20', time: '05:00', fromPlace: 'Haldwani', toPlace: 'Pantnagar', label: 'Airport drop, Mehra ji'),
          tripJson('j02', kind: 'Auto', from: '2027-01-02', fromPlace: 'Pantnagar airport', label: 'Seema Joshi'),
        ],
        'nextCursor': 'c2',
      },
    }), plan: OwnerPlans.plus);
    await renderOwnerFrame(tester, 'o_tx_48', TaxiUpcomingScreen(controller: c, windowEnd: DateTime(2027, 5, 21)), arrange: settle);
  });

  testWidgets('render o_tx_34', (tester) async {
    final c = calSetUp(CalFake(past: {
      null: {
        'items': [
          tripJson('p19', from: '2026-11-19', time: '06:00', fromPlace: 'Haldwani', label: 'Corbett day trip', finalAmount: 2400, paid: true),
          tripJson('p16', kind: 'Auto', from: '2026-11-16', fromPlace: 'Kathgodam', toPlace: 'Bhimtal', label: 'Rahul Das', finalAmount: 1500, paid: true),
          tripJson('p12', from: '2026-11-12', time: '14:00', fromPlace: 'Haldwani', toPlace: 'Nainital', label: 'Family trip, Nainital', finalAmount: 1800, received: 1000),
          tripJson('p30', kind: 'Auto', from: '2026-10-30', fromPlace: 'Pantnagar airport', label: 'Seema Joshi', finalAmount: 1200, paid: true),
          tripJson('p11', from: '2026-10-11', time: '09:00', fromPlace: 'Haldwani', label: 'Ranikhet round trip', finalAmount: 2600, paid: true),
          tripJson('p21', kind: 'Auto', from: '2026-09-21', fromPlace: 'Kathgodam', toPlace: 'Nainital', label: 'Arjun Bisht', finalAmount: 1800, paid: true),
        ],
      },
    }));
    await renderOwnerFrame(tester, 'o_tx_34', TaxiPastScreen(controller: c, plate: 'UK 04 TA 2231'), arrange: settle);
  });
}
