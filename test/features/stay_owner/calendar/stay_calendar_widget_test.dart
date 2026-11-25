import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/look/owner_look.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_calendar_controller.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_calendar_entry_screen.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_calendar_screen.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_day_sheet.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_entry_sheet.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_upcoming_card.dart';
import 'package:bakhli/features/stay_owner/calendar/widgets/stay_calendar_widgets.dart';
import 'package:bakhli/features/stay_owner/plan_visible/stay_plan_visible_screen.dart';
import 'package:bakhli/features/stay_owner/stay_owner_deps.dart';
import 'package:bakhli/features/stay_owner/special_prices/stay_special_price_sheet.dart';
import 'package:bakhli/features/stay_owner/special_prices/stay_special_prices_controller.dart';
import 'package:bakhli/features/stay_owner/special_prices/stay_special_prices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import 'calendar_fixtures.dart';

Future<void> settle(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 400));
}

Finder gateKeys() => find.byWidgetPredicate((w) => w.key is GateKey);

Map<String, dynamic> manyEntries(int n) => monthJson(entries: [
      for (var i = 0; i < n; i++) entryJson('m$i', '2026-11-${(22 + i % 7).toString().padLeft(2, '0')}', '2026-11-${(23 + i % 7).toString().padLeft(2, '0')}', 'Guest $i', auto: i.isEven, finalAmount: 1000 + i, received: 100),
    ]);

void main() {
  setUpAll(() => initTestStorage('stay_calendar_widget'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    StaySpecialPriceMemory.reset();
    resetOwnerTestState();
  });

  group('calendar screen sizes', () {
    for (final rows in [0, 1, 50]) {
      testOwnerSizes(
        'Free month with $rows entries',
        () {
          final h = CalendarHarness.setUp(month: rows == 0 ? monthJson(entries: const []) : manyEntries(rows));
          return StayCalendarScreen(controller: h.calendar);
        },
        arrange: settle,
        check: (t, size, scale) async {
          expect(find.text('Calendar'), findsOneWidget);
          expect(find.text('November 2026'), findsOneWidget);
        },
      );
    }
    testOwnerSizes(
      'Plus December',
      () {
        final h = CalendarHarness.setUp(plan: OwnerPlans.plus, month: monthJson(plus: true), december: decMonthJson());
        return StayCalendarScreen(controller: h.calendar, args: const {'date': '2026-12-05'});
      },
      arrange: settle,
      check: (t, size, scale) async => expect(find.text('December 2026'), findsOneWidget),
    );
    testOwnerSizes(
      'after Plus ends',
      () {
        final h = CalendarHarness.setUp(month: monthJson(hiddenCount: 8, entriesUsed: 4));
        return StayCalendarScreen(controller: h.calendar);
      },
      arrange: settle,
    );
  });

  testWidgets('Free month: locked arrow, locked summary, window line; numbers hidden', (t) async {
    final h = CalendarHarness.setUp();
    await pumpPhone(t, StayCalendarScreen(controller: h.calendar));
    await settle(t);
    expect(find.byKey(GateKeys.softArrow), findsOneWidget);
    expect(find.byKey(GateKeys.softCard), findsOneWidget);
    expect(find.text('₹29,500'), findsNothing);
    expect(find.text('3 of 4'), findsOneWidget);
    expect(find.text('1 of 1'), findsOneWidget);
    expect(find.text('Diwali week · 6 to 12 Nov'), findsOneWidget);
    expect(find.text('Your price was 20% higher · removed 30 days after it ends'), findsOneWidget);
  });

  testWidgets('payment OFF: no gate key anywhere, meters without a limit', (t) async {
    final h = CalendarHarness.setUp(plan: OwnerPlans.paymentOff, month: monthJson(paymentEnabled: false));
    await pumpPhone(t, StayCalendarScreen(controller: h.calendar));
    await settle(t);
    expect(gateKeys(), findsNothing);
    expect(find.text('3 bookings you added'), findsOneWidget);
    expect(find.textContaining('See Plus'), findsNothing);
  });

  testWidgets('Block days at 1 of 1 opens G11 before any call; Not now closes', (t) async {
    final h = CalendarHarness.setUp();
    await pumpPhone(t, StayCalendarScreen(controller: h.calendar));
    await settle(t);
    await t.tap(find.text('Block days'));
    await settle(t);
    expect(find.text('Free allows 1 blocked range'), findsOneWidget);
    expect(h.transport.calls.where((c) => c.startsWith('POST')), isEmpty);
    await t.tap(find.text('Not now'));
    await settle(t);
    expect(find.text('Free allows 1 blocked range'), findsNothing);
  });

  testWidgets('Add booking at 4 of 4 on Free opens G10 before the form', (t) async {
    final h = CalendarHarness.setUp(month: monthJson(entriesUsed: 4));
    await pumpPhone(t, StayCalendarScreen(controller: h.calendar));
    await settle(t);
    await t.tap(find.text('+ Add booking'));
    await settle(t);
    expect(find.byKey(GateKeys.sheet), findsOneWidget);
    expect(find.text('You have 4 active entries'), findsOneWidget);
    expect(find.text('Save booking'), findsNothing);
    expect(h.transport.calls.where((c) => c.startsWith('POST')), isEmpty);
    await t.tap(find.text('Not now'));
    await settle(t);
    expect(find.byKey(GateKeys.sheet), findsNothing);
  });

  testWidgets('Plus full: Add booking and Block days are greyed', (t) async {
    final month = monthJson(plus: true)..['meters'] = [meter('CalendarEntries', 50, 50), meter('BlockedRanges', 10, 10)];
    final h = CalendarHarness.setUp(plan: OwnerPlans.plus, month: month);
    await pumpPhone(t, StayCalendarScreen(controller: h.calendar));
    await settle(t);
    final bar = t.widget<StayCalBar>(find.byType(StayCalBar));
    expect(bar.onPrimary, isNull);
    expect(bar.onSecondary, isNull);
  });

  testWidgets('Free under the limit: Add booking and Block days stay enabled', (t) async {
    final h = CalendarHarness.setUp(month: monthJson(blocksUsed: 0));
    await pumpPhone(t, StayCalendarScreen(controller: h.calendar));
    await settle(t);
    final bar = t.widget<StayCalBar>(find.byType(StayCalBar));
    expect(bar.onPrimary, isNotNull);
    expect(bar.onSecondary, isNotNull);
  });

  testWidgets('after Plus: an inactive own booking is greyed with the reason and Delete', (t) async {
    final month = monthJson(entries: [
      ...novEntries(),
      {...entryJson('old1', '2026-11-25', '2026-11-26', 'Older booking'), 'inactiveByPlan': true},
    ]);
    final h = CalendarHarness.setUp(month: month);
    await pumpPhone(t, StayCalendarScreen(controller: h.calendar), size: const Size(360, 4000));
    await settle(t);
    expect(find.byKey(GateKeys.inactiveRow), findsOneWidget);
    expect(find.text('Inactive: the Free plan keeps 4 bookings you add.'), findsOneWidget);
    expect(find.descendant(of: find.byKey(GateKeys.inactiveRow), matching: find.text('Delete')), findsOneWidget);
    expect(h.calendar.ownActive.where((e) => e.id == 'old1'), isEmpty);
  });

  testWidgets('add booking: name needed, phone guard, received above final', (t) async {
    final h = CalendarHarness.setUp();
    await pumpPhone(t, StayCalendarScreen(controller: h.calendar));
    await settle(t);
    StayEntrySheet.add(t.element(find.byType(StayCalendarScreen)), h.calendar, from: DateTime(2026, 11, 27), to: DateTime(2026, 11, 28));
    await settle(t);
    await t.tap(find.text('Save booking'));
    await settle(t);
    expect(find.text('Add a name for this booking.'), findsOneWidget);
    final f = find.byType(EditableText);
    await t.enterText(f.at(0), 'Negi ji');
    await t.enterText(f.at(3), 'Call Ravi 98765 43210');
    await settle(t);
    expect(find.text('Do not add phone numbers.'), findsOneWidget);
    await t.enterText(f.at(3), '');
    await t.enterText(f.at(1), '4000');
    await t.enterText(f.at(2), '5000');
    await settle(t);
    expect(find.textContaining('cannot be more than the final amount'), findsOneWidget);
    expect(h.transport.calls.where((c) => c.startsWith('POST')), isEmpty);
  });

  testWidgets('save posts once with the same client id and closes', (t) async {
    final h = CalendarHarness.setUp(override: (m, p, b) async {
      if (m == 'POST' && p == '/stays/me/calendar/entries') return {'data': {'entry': b, 'meters': [], 'overlap': {'bookings': 0, 'blocked': 0}}};
      return const {};
    });
    await pumpPhone(t, StayCalendarScreen(controller: h.calendar));
    await settle(t);
    StayEntrySheet.add(t.element(find.byType(StayCalendarScreen)), h.calendar, from: DateTime(2026, 11, 27), to: DateTime(2026, 11, 28));
    await settle(t);
    await t.enterText(find.byType(EditableText).first, 'Sharma family');
    await settle(t);
    await t.tap(find.text('Save booking'));
    await t.tap(find.text('Save booking'), warnIfMissed: false);
    await settle(t);
    expect(h.transport.calls.where((c) => c == 'POST /stays/me/calendar/entries'), hasLength(1));
    expect(find.text('Add booking'), findsNothing);
  });

  testWidgets('offline save keeps the sheet open', (t) async {
    final h = CalendarHarness.setUp(override: (m, p, b) async {
      if (m == 'POST') throw offline();
      return const {};
    });
    await pumpPhone(t, StayCalendarScreen(controller: h.calendar), toastHost: true);
    await settle(t);
    StayEntrySheet.add(t.element(find.byType(StayCalendarScreen)), h.calendar, from: DateTime(2026, 11, 27), to: DateTime(2026, 11, 28));
    await settle(t);
    await t.enterText(find.byType(EditableText).first, 'Sharma family');
    await t.tap(find.text('Save booking'));
    await settle(t);
    expect(find.text('Add booking'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('block needs confirm: dialog, Block anyway resends with confirm=true', (t) async {
    final h = CalendarHarness.setUp(plan: OwnerPlans.plus, override: (m, p, b) async {
      if (m == 'POST' && p == '/stays/me/blocked-ranges') throw refusal(409, 'BlockedRangeNeedsConfirm', data: {'confirmedInside': 1, 'openEnquiriesInside': 2});
      if (m == 'POST' && p == '/stays/me/blocked-ranges?confirm=true') return {'data': {'block': b}};
      return const {};
    });
    await pumpPhone(t, StayCalendarScreen(controller: h.calendar));
    await settle(t);
    StayEntrySheet.block(t.element(find.byType(StayCalendarScreen)), h.calendar, day: DateTime(2026, 11, 27));
    await settle(t);
    await t.tap(find.text('Block these days').last);
    await settle(t);
    expect(find.text('1 confirmed booking is inside these days'), findsOneWidget);
    expect(find.text('It stays confirmed. 2 open enquiries are for these days.'), findsOneWidget);
    await t.tap(find.text('Block anyway'));
    await settle(t);
    expect(h.transport.calls, contains('POST /stays/me/blocked-ranges?confirm=true'));
  });

  testWidgets('day sheet: IN and OUT tiles, base price band, buttons', (t) async {
    final h = CalendarHarness.setUp();
    await pumpPhone(t, StayCalendarScreen(controller: h.calendar));
    await settle(t);
    StayDaySheet.show(t.element(find.byType(StayCalendarScreen)), h.calendar, DateTime(2026, 11, 27), onAdd: (_) {}, onBlock: (_) {});
    await settle(t);
    expect(find.text('Fri, 27 Nov'), findsOneWidget);
    expect(find.text('2 bookings on this day'), findsOneWidget);
    expect(find.text('IN'), findsOneWidget);
    expect(find.text('OUT'), findsOneWidget);
    expect(find.text('Check-in · 27 – 29 Nov · Deluxe Room'), findsOneWidget);
    expect(find.text('No special price on these dates yet'), findsOneWidget);
    expect(find.text('Set a price for these days'), findsOneWidget);
  });

  testWidgets('entry detail: cancelled app booking and enquiry gone', (t) async {
    final h = CalendarHarness.setUp(extra: (p) => p.endsWith('/entries/rs')
        ? (entryJson('rs', '2026-11-24', '2026-11-26', 'Rohit Sharma', auto: true, roomNames: 'Deluxe Room', listed: 6000, finalAmount: 6000, received: 1000, cancelled: true, cancelledBy: 'Rohit', cancelledOn: '2026-11-21')
          ..['sourceAvailable'] = false)
        : null);
    await pumpPhone(t, StayCalendarEntryScreen(args: const {'id': 'rs'}, controller: h.calendar), toastHost: true);
    await settle(t);
    expect(find.text('From the app · cancelled'), findsOneWidget);
    expect(find.text('By Rohit on 21 Nov'), findsOneWidget);
    expect(find.text('Kept so you remember the ₹1,000 you received. Not counted in Booked or To collect.'), findsOneWidget);
    expect(find.text('Removed automatically on 24 Feb, 90 days after this date.'), findsOneWidget);
    var opened = false;
    StayOwnerDeps.openEnquiry = (_) => opened = true;
    await t.tap(find.text('Open enquiry'));
    await settle(t);
    await t.pump(const Duration(seconds: 1));
    expect(opened, isFalse);
    expect(find.textContaining('no longer available', findRichText: true), findsOneWidget);
    StayOwnerDeps.debugReset();
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('entry detail: delete asks first and calls delete once', (t) async {
    final h = CalendarHarness.setUp(extra: (p) => p.endsWith('/entries/gupta') ? novEntries()[4] : null);
    await pumpPhone(t, StayCalendarEntryScreen(args: const {'id': 'gupta'}, controller: h.calendar));
    await settle(t);
    expect(find.text('Deletes on 25 Feb 2027'), findsOneWidget);
    await t.tap(find.text('Delete'));
    await settle(t);
    expect(find.text('Delete this booking?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(h.transport.calls.where((c) => c.startsWith('DELETE')), isEmpty);
    await t.tap(find.text('Delete'));
    await settle(t);
    await t.tap(find.text('Delete').last);
    await settle(t);
    expect(h.transport.calls.where((c) => c == 'DELETE /stays/me/calendar/entries/gupta'), hasLength(1));
  });

  testWidgets('entry screen with a missing id shows the error card, never crashes', (t) async {
    final h = CalendarHarness.setUp();
    await pumpPhone(t, StayCalendarEntryScreen(controller: h.calendar));
    await settle(t);
    expect(find.text("Couldn't load"), findsOneWidget);
  });

  testWidgets('calendar controller is gone after the screen leaves', (t) async {
    CalendarHarness.setUp(registerCalendar: false);
    await pumpPhone(t, const StayCalendarScreen());
    await settle(t);
    expect(Get.isRegistered<StayCalendarController>(tag: StayCalendarController.tag), isTrue);
    await t.pumpWidget(const SizedBox.shrink());
    expect(Get.isRegistered<StayCalendarController>(tag: StayCalendarController.tag), isFalse);
    expect(t.takeException(), isNull);
  });

  group('upcoming card', () {
    OwnerUpcoming u({int rows = 3, int more = 2, int beyond = 1, int? days = 15}) => OwnerUpcoming.fromJson({
          'rows': [for (var i = 0; i < rows; i++) entryJson('e$i', '2026-11-2${2 + i}', '2026-11-2${3 + i}', 'Guest $i', auto: i.isEven, roomNames: 'Family Room')],
          'moreInWindowCount': more,
          'windowLabelDays': days,
          'beyondWindowAppCount': beyond,
          'window': {'upcomingTo': '2026-12-06', 'locked': days == 15},
        });
    Widget host(OwnerUpcoming x) => Scaffold(backgroundColor: OwnerLook.stay.page, body: SingleChildScrollView(child: StayUpcomingCard(upcoming: x)));

    testWidgets('Free: 3 rows, heading with See all, no more strip, amber row or buttons', (t) async {
      CalendarHarness.setUp(registerCalendar: false);
      await pumpPhone(t, host(u()));
      expect(find.text('Upcoming bookings'), findsOneWidget);
      expect(find.text('Next 15 days'), findsOneWidget);
      expect(find.text('See all ›'), findsOneWidget);
      expect(find.text('From app'), findsNWidgets(2));
      expect(find.text('Added by you'), findsOneWidget);
      expect(find.textContaining('more in the'), findsNothing);
      expect(find.textContaining('Plus shows 6 months ahead'), findsNothing);
      for (final gone in ['View calendar', 'Past', 'Add booking']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
    });
    testWidgets('Plus: 6 months, no amber line; zero more hides the line', (t) async {
      CalendarHarness.setUp(registerCalendar: false, plan: OwnerPlans.plus);
      await pumpPhone(t, host(u(more: 0, days: 183)));
      expect(find.text('Next 6 months'), findsOneWidget);
      expect(find.textContaining('more in the'), findsNothing);
      expect(gateKeys(), findsNothing);
    });
    testWidgets('payment OFF: no See Plus', (t) async {
      CalendarHarness.setUp(registerCalendar: false, plan: OwnerPlans.paymentOff);
      await pumpPhone(t, host(u()));
      expect(gateKeys(), findsNothing);
    });
    testOwnerSizes('card 0 rows', () {
      CalendarHarness.setUp(registerCalendar: false);
      return host(u(rows: 0, more: 0, beyond: 0));
    });
  });

  group('special prices', () {
    StaySpecialPricesController put() => Get.put(
          StaySpecialPricesController(clock: calClock, userIdOf: () => 'user-a', listingNameOf: () => 'Deodar Heights'),
          tag: StaySpecialPricesController.tag,
        );

    testWidgets('Free 1 of 1: add opens G12 before any call with the end date', (t) async {
      final h = CalendarHarness.setUp(registerCalendar: false);
      final sp = put();
      await pumpPhone(t, StaySpecialPricesScreen(controller: sp));
      await settle(t);
      expect(find.text('Deluxe ₹3,000 → ₹3,600 · Family ₹4,500 → ₹5,400'), findsOneWidget);
      await t.tap(find.text('+ Add special price'));
      await settle(t);
      expect(find.text('Plus keeps 5 at a time. Your current one ends on 12 Nov. You can change or remove it now.'), findsNothing);
      expect(find.text('1 special price on Free'), findsOneWidget);
      expect(h.transport.calls.where((c) => c.startsWith('POST')), isEmpty);
    });

    testWidgets('Free: plan strip on top; a rule paused by the plan has no Edit and a reason line', (t) async {
      CalendarHarness.setUp(registerCalendar: false, special: specialJson(items: [
        {'id': 'sp1', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12', 'nights': 7, 'direction': 'Higher', 'percent': 20, 'label': 'Diwali week', 'live': true, 'version': 1},
        {'id': 'sp2', 'dateFrom': '2026-12-24', 'dateTo': '2027-01-01', 'nights': 9, 'direction': 'Higher', 'percent': 25, 'label': 'Christmas and New Year', 'pausedByPlan': true, 'version': 1},
      ]));
      final sp = put();
      await pumpPhone(t, StaySpecialPricesScreen(controller: sp), size: const Size(360, 1600));
      await settle(t);
      expect(find.byKey(GateKeys.planStrip), findsOneWidget);
      expect(find.text('Free plan: 1 special price. Plus gives up to 5.'), findsOneWidget);
      expect(find.byKey(GateKeys.softRow), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsNWidgets(2));
      expect(find.text('Inactive: the Free plan allows 1 special price.'), findsOneWidget);
    });

    testWidgets('Plus full 5 of 5: Add is greyed, no strip', (t) async {
      CalendarHarness.setUp(registerCalendar: false, plan: OwnerPlans.plus, special: specialJson(plus: true, items: [
        ...plusRules(),
        {'id': 'sp5', 'dateFrom': '2027-03-01', 'dateTo': '2027-03-03', 'nights': 3, 'direction': 'Higher', 'percent': 10, 'live': true, 'version': 1},
      ]));
      final sp = put();
      await pumpPhone(t, StaySpecialPricesScreen(controller: sp));
      await settle(t);
      expect(find.byKey(GateKeys.planStrip), findsNothing);
      expect(t.widget<StayCalBar>(find.byType(StayCalBar)).onPrimary, isNull);
    });

    testWidgets('payment OFF: no locked row, no gate key', (t) async {
      CalendarHarness.setUp(registerCalendar: false, plan: OwnerPlans.paymentOff);
      final sp = put();
      await pumpPhone(t, StaySpecialPricesScreen(controller: sp));
      await settle(t);
      expect(gateKeys(), findsNothing);
      expect(find.text('Plus keeps 5 at a time'), findsNothing);
    });

    testWidgets('overlap refusal shows the frame lines and keeps Save off until the dates change', (t) async {
      CalendarHarness.setUp(registerCalendar: false, plan: OwnerPlans.plus, override: (m, p, b) async {
        if (m == 'POST') throw refusal(409, 'SpecialPriceOverlap', data: {'id': 'sp1', 'label': 'Diwali week', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12'});
        return const {};
      });
      final sp = put();
      await pumpPhone(t, StaySpecialPricesScreen(controller: sp));
      await settle(t);
      StaySpecialPriceSheet.open(t.element(find.byType(StaySpecialPricesScreen)), sp, from: DateTime(2026, 12, 10), to: DateTime(2026, 12, 14));
      await settle(t);
      await t.tap(find.text('Save').last);
      await settle(t);
      expect(find.text('These dates already have a special price.'), findsOneWidget);
      expect(find.text('Diwali week (6 to 12 Nov) covers part of these dates. Change the dates, or edit that price.'), findsOneWidget);
      expect(find.text('Edit Diwali week'), findsOneWidget);
      await t.tap(find.text('Save').last, warnIfMissed: false);
      await settle(t);
      expect(sp.load.value.valueOrNull, isNotNull);
    });

    testWidgets('saves limit line', (t) async {
      CalendarHarness.setUp(registerCalendar: false, plan: OwnerPlans.plus, override: (m, p, b) async {
        if (m == 'POST') throw refusal(409, 'SpecialPriceSavesLimit');
        return const {};
      });
      final sp = put();
      await pumpPhone(t, StaySpecialPricesScreen(controller: sp));
      await settle(t);
      StaySpecialPriceSheet.open(t.element(find.byType(StaySpecialPricesScreen)), sp, from: DateTime(2026, 12, 10), to: DateTime(2026, 12, 14));
      await settle(t);
      await t.tap(find.text('Save').last);
      await settle(t);
      expect(find.text('You can change special prices 3 times a day. Try again tomorrow.'), findsOneWidget);
    });

    testWidgets('delete asks first', (t) async {
      final h = CalendarHarness.setUp(registerCalendar: false);
      final sp = put();
      await pumpPhone(t, StaySpecialPricesScreen(controller: sp));
      await settle(t);
      await t.tap(find.text('Delete'));
      await settle(t);
      expect(find.text('Delete this special price?'), findsOneWidget);
      await t.tap(find.text('Delete').last);
      await settle(t);
      expect(h.transport.calls, contains('DELETE /stays/me/special-prices/sp1'));
    });

    testOwnerSizes('Plus list with 4 rules', () {
      CalendarHarness.setUp(registerCalendar: false, plan: OwnerPlans.plus, special: specialJson(plus: true, items: plusRules()));
      return StaySpecialPricesScreen(controller: put());
    }, arrange: settle);
    testOwnerSizes('empty list', () {
      CalendarHarness.setUp(registerCalendar: false, special: specialJson(items: const []));
      return StaySpecialPricesScreen(controller: put());
    }, arrange: settle);
  });

  group('choose what stays', () {
    Map<String, dynamic> me({int hidden = 4}) => {
          'photos': [{'id': 'p1', 'url': '', 'photoOrder': 0}, {'id': 'p2', 'url': '', 'photoOrder': 1}],
          'hiddenPhotos': [for (var i = 0; i < hidden; i++) {'id': 'h$i', 'url': '', 'photoOrder': 50 + i}],
          'rooms': [{'id': 'r1', 'roomName': 'Deluxe Room', 'pricePerNight': 3000, 'roomIndex': 1}, {'id': 'r2', 'roomName': 'Family Room', 'pricePerNight': 4500, 'roomIndex': 2}],
          'hiddenRooms': [{'id': 'r3', 'roomName': 'Suite', 'pricePerNight': 5500, 'roomIndex': 101}],
          'meters': [meter('Photos', 2, 2), meter('RoomTypes', 2, 2)],
        };

    testWidgets('exact counts: Save needs 2 and 2, a third tap adds nothing', (t) async {
      final h = CalendarHarness.setUp(registerCalendar: false, extra: (p) => p == '/stays/me' ? me() : null, override: (m, p, b) async {
        if (m == 'PUT' && p == '/stays/me/plan-visible') return {'data': <String, dynamic>{}};
        return const {};
      });
      await pumpPhone(t, const StayPlanVisibleScreen());
      await settle(t);
      expect(find.text('2 of 2 chosen'), findsNWidgets(2));
      final c = Get.find<StayPlanVisibleController>(tag: StayPlanVisibleController.tag);
      c.togglePhoto('h0');
      expect(c.photoIds, ['p1', 'p2']);
      c.togglePhoto('p2');
      c.togglePhoto('h0');
      expect(c.photoIds, ['p1', 'h0']);
      expect(c.ready, isTrue);
      c.toggleRoom('r1');
      expect(c.ready, isFalse);
      c.toggleRoom('r3');
      await t.pump();
      await t.tap(find.text('Save'));
      await settle(t);
      expect(h.transport.calls, contains('PUT /stays/me/plan-visible'));
    });

    testWidgets('nothing hidden shows the Nothing is hidden state', (t) async {
      CalendarHarness.setUp(registerCalendar: false, extra: (p) => p == '/stays/me' ? (me(hidden: 0)..['hiddenRooms'] = []) : null);
      await pumpPhone(t, const StayPlanVisibleScreen());
      await settle(t);
      expect(find.text('Nothing is hidden.'), findsOneWidget);
    });

    testOwnerSizes('8 photos and 6 rooms', () {
      CalendarHarness.setUp(registerCalendar: false, extra: (p) => p == '/stays/me' ? me(hidden: 6) : null);
      return const StayPlanVisibleScreen();
    }, arrange: settle);
  });
}
