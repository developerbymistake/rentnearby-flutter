import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/look/owner_look.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_balance_due_screen.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_calendar_entry_screen.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_calendar_screen.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_day_sheet.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_entry_sheet.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_past_screen.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_upcoming_card.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_upcoming_screen.dart';
import 'package:bakhli/features/stay_owner/plan_visible/stay_plan_visible_screen.dart';
import 'package:bakhli/features/stay_owner/special_prices/stay_special_price_sheet.dart';
import 'package:bakhli/features/stay_owner/special_prices/stay_special_prices_controller.dart';
import 'package:bakhli/features/stay_owner/special_prices/stay_special_prices_screen.dart';
import 'package:bakhli/features/stay_owner/strings/stay_gate_strings_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import 'calendar_fixtures.dart';

Future<void> settle(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 400));
}

BuildContext ctxOf(WidgetTester t, Type type) => t.element(find.byType(type));

Map<String, dynamic> upcomingPage({bool plus = true, bool cancelled = false}) => {
      'items': cancelled
          ? [
              entryJson('neha', '2026-11-22', '2026-11-23', 'Neha Joshi', auto: true, roomNames: 'Family Room'),
              entryJson('rs', '2026-11-24', '2026-11-26', 'Rohit Sharma', auto: true, roomNames: 'Deluxe Room', received: 1000, cancelled: true),
              entryJson('kapoor', '2026-11-24', '2026-11-25', 'Kapoor couple', finalAmount: 2800, received: 800),
              entryJson('rohit', '2026-11-28', '2026-11-30', 'Rohit Verma', auto: true, roomNames: 'Deluxe Room'),
            ]
          : [
              entryJson('neha', '2026-11-22', '2026-11-23', 'Neha Joshi', auto: true, roomNames: 'Family Room'),
              entryJson('kapoor', '2026-11-24', '2026-11-25', 'Kapoor couple'),
              entryJson('gupta', '2026-11-25', '2026-11-27', 'Gupta ji, 2 rooms'),
              entryJson('rohit', '2026-11-27', '2026-11-29', 'Rohit Verma', auto: true, roomNames: 'Deluxe Room'),
              entryJson('office', '2026-12-04', '2026-12-05', 'Office group, 6 people'),
              entryJson('ankit', '2026-12-12', '2026-12-14', 'Ankit Joshi', auto: true, roomNames: 'Family Room'),
              entryJson('arora', '2026-12-24', '2026-12-27', 'Arora family', auto: true, roomNames: 'Whole stay'),
              entryJson('mehra', '2026-12-28', '2026-12-31', 'Mehra group'),
              entryJson('sneha', '2027-01-02', '2027-01-04', 'Sneha Sen', auto: true, roomNames: 'Deluxe Room'),
              entryJson('bisht', '2027-01-14', '2027-01-15', 'Bisht family'),
            ],
      'nextCursor': plus && !cancelled ? 'c2' : null,
      'hiddenCount': 0,
      'beyondWindowAppCount': plus ? 0 : 1,
      'beyondWindowFirstDate': '2026-12-08',
    };

void main() {
  setUpAll(() => initTestStorage('stay_calendar_render'));
  useOwnerRenderScale();
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  testWidgets('render o_st_24', (tester) async {
    CalendarHarness.setUp(registerCalendar: false);
    final u = OwnerUpcoming.fromJson({
      'rows': [
        entryJson('neha', '2026-11-22', '2026-11-23', 'Neha Joshi', auto: true, roomNames: 'Family Room'),
        entryJson('kapoor', '2026-11-24', '2026-11-25', 'Kapoor couple'),
        entryJson('gupta', '2026-11-25', '2026-11-27', 'Gupta ji, 2 rooms'),
      ],
      'moreInWindowCount': 2,
      'windowLabelDays': 15,
      'beyondWindowAppCount': 1,
      'beyondWindowFirstDate': '2026-12-08',
      'window': {'upcomingTo': '2026-12-06', 'locked': true},
    });
    await renderOwnerFrame(
      tester,
      'o_st_24',
      Scaffold(backgroundColor: OwnerLook.stay.page, body: SingleChildScrollView(child: StayUpcomingCard(upcoming: u))),
    );
  });

  testWidgets('render o_st_25', (tester) async {
    final h = CalendarHarness.setUp();
    await renderOwnerFrame(tester, 'o_st_25', StayCalendarScreen(controller: h.calendar), arrange: settle);
  });

  testWidgets('render o_st_26', (tester) async {
    final h = CalendarHarness.setUp();
    await renderOwnerFrame(tester, 'o_st_26', StayCalendarScreen(controller: h.calendar), arrange: (t) async {
      await settle(t);
      StayDaySheet.show(ctxOf(t, StayCalendarScreen), h.calendar, DateTime(2026, 11, 27), onAdd: (_) {}, onBlock: (_) {});
      await settle(t);
    });
  });

  testWidgets('render o_st_27', (tester) async {
    final h = CalendarHarness.setUp();
    await renderOwnerFrame(tester, 'o_st_27', StayCalendarScreen(controller: h.calendar), arrange: (t) async {
      await settle(t);
      StayEntrySheet.add(ctxOf(t, StayCalendarScreen), h.calendar, from: DateTime(2026, 11, 25), to: DateTime(2026, 11, 27));
      await settle(t);
      final fields = find.byType(EditableText);
      await t.enterText(fields.at(0), 'Gupta ji, 2 rooms');
      await t.enterText(fields.at(1), '9000');
      await t.enterText(fields.at(2), '3000');
      await t.enterText(fields.at(3), 'Family room + deluxe, 4 guests');
      await settle(t);
    });
  });

  testWidgets('render o_st_28', (tester) async {
    final h = CalendarHarness.setUp(month: monthJson(blocksUsed: 0, blocks: const []));
    await renderOwnerFrame(tester, 'o_st_28', StayCalendarScreen(controller: h.calendar), arrange: (t) async {
      await settle(t);
      StayEntrySheet.block(ctxOf(t, StayCalendarScreen), h.calendar, day: DateTime(2026, 11, 30));
      await settle(t);
      await t.enterText(find.byType(EditableText).first, 'Water tank repair');
      await settle(t);
    });
  });

  for (final c in [('o_st_29', 'neha', null), ('o_st_30', 'gupta', null), ('o_st_58', 'rs', 'A')]) {
    testWidgets('render ${c.$1}${c.$3 ?? ''}', (tester) async {
      final h = CalendarHarness.setUp(extra: (path) {
        if (path.endsWith('/entries/neha')) return novEntries()[2];
        if (path.endsWith('/entries/gupta')) return novEntries()[4];
        if (path.endsWith('/entries/rs')) {
          return entryJson('rs', '2026-11-24', '2026-11-26', 'Rohit Sharma',
              auto: true, roomNames: 'Deluxe Room', listed: 6000, finalAmount: 6000, received: 1000, cancelled: true, cancelledBy: 'Rohit', cancelledOn: '2026-11-21');
        }
        return null;
      });
      await renderOwnerFrame(tester, c.$1, StayCalendarEntryScreen(args: {'id': c.$2}, controller: h.calendar), part: c.$3, arrange: settle);
    });
  }

  testWidgets('render o_st_31', (tester) async {
    final h = CalendarHarness.setUp(month: monthJson(entriesUsed: 4));
    await renderOwnerFrame(tester, 'o_st_31', StayCalendarScreen(controller: h.calendar), arrange: (t) async {
      await settle(t);
      PlanGate.showLimit(ctxOf(t, StayCalendarScreen), StayGateStringsCalendar.g10(used: 4));
      await settle(t);
    });
  });

  testWidgets('render o_st_32', (tester) async {
    final h = CalendarHarness.setUp();
    await renderOwnerFrame(tester, 'o_st_32', StayCalendarScreen(controller: h.calendar), arrange: (t) async {
      await settle(t);
      StayEntrySheet.block(ctxOf(t, StayCalendarScreen), h.calendar);
      await settle(t);
    });
  });

  testWidgets('render o_st_33', (tester) async {
    final h = CalendarHarness.setUp(plan: OwnerPlans.plus, month: monthJson(plus: true), december: decMonthJson());
    await renderOwnerFrame(tester, 'o_st_33', StayCalendarScreen(controller: h.calendar, args: const {'date': '2026-12-01'}), arrange: settle);
  });

  testWidgets('render o_st_34', (tester) async {
    CalendarHarness.setUp(plan: OwnerPlans.plus, extra: (p) => p.endsWith('/upcoming') ? upcomingPage() : null);
    await renderOwnerFrame(tester, 'o_st_34', StayUpcomingScreen(clock: calClock), arrange: settle);
  });

  testWidgets('render o_st_58 B', (tester) async {
    CalendarHarness.setUp(extra: (p) => p.endsWith('/upcoming') ? upcomingPage(plus: false, cancelled: true) : null);
    await renderOwnerFrame(tester, 'o_st_58', StayUpcomingScreen(clock: calClock), part: 'B', arrange: settle);
  });

  for (final c in [('o_st_35', true), ('o_st_36', false)]) {
    testWidgets('render ${c.$1}', (tester) async {
      final h = CalendarHarness.setUp(plan: c.$2 ? OwnerPlans.plus : OwnerPlans.free, month: monthJson(plus: c.$2));
      await renderOwnerFrame(tester, c.$1, StayCalendarScreen(controller: h.calendar, args: const {'summary': true}), arrange: (t) async {
        await settle(t);
        await t.drag(find.byType(CustomScrollView), const Offset(0, -560));
        await settle(t);
      });
    });
  }

  testWidgets('render o_st_37', (tester) async {
    CalendarHarness.setUp(plan: OwnerPlans.plus, month: monthJson(plus: true), extra: (p) {
      if (p.endsWith('/balance-due')) return {'items': (summaryJson()['top'] as List), 'nextCursor': null};
      return null;
    });
    await renderOwnerFrame(tester, 'o_st_37', StayBalanceDueScreen(clock: calClock, args: const {'month': '2026-11'}), arrange: settle);
  });

  for (final c in [('o_st_41', false), ('o_st_46', true)]) {
    testWidgets('render ${c.$1}', (tester) async {
      CalendarHarness.setUp(plan: c.$2 ? OwnerPlans.plus : OwnerPlans.free, special: specialJson(plus: c.$2, items: c.$2 ? plusRules() : null), registerCalendar: false);
      final sp = Get.put(StaySpecialPricesController(clock: calClock, userIdOf: () => 'user-a', listingNameOf: () => 'Deodar Heights'), tag: StaySpecialPricesController.tag);
      await renderOwnerFrame(tester, c.$1, StaySpecialPricesScreen(controller: sp), arrange: settle);
    });
  }

  for (final c in ['o_st_42', 'o_st_43', 'o_st_44', 'o_st_45']) {
    testWidgets('render $c', (tester) async {
      CalendarHarness.setUp(
        special: specialJson(),
        registerCalendar: false,
        override: (m, p, b) async {
          if (c == 'o_st_44' && m == 'POST') throw refusal(409, 'SpecialPriceOverlap', data: {'id': 'sp1', 'label': 'Diwali week', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12'});
          return const {};
        },
      );
      final early = c == 'o_st_42' || c == 'o_st_44';
      final sp = Get.put(
        StaySpecialPricesController(clock: early ? () => DateTime(2026, 10, 15) : calClock, userIdOf: () => 'user-a', listingNameOf: () => 'Deodar Heights'),
        tag: StaySpecialPricesController.tag,
      );
      if (c != 'o_st_45') PlanGate.debugPlan = OwnerPlans.plus;
      await renderOwnerFrame(tester, c, StaySpecialPricesScreen(controller: sp), arrange: (t) async {
        await settle(t);
        final ctx = ctxOf(t, StaySpecialPricesScreen);
        if (c == 'o_st_45') {
          StaySpecialPriceSheet.open(ctx, sp);
        } else if (c == 'o_st_42') {
          StaySpecialPriceSheet.open(ctx, sp, from: DateTime(2026, 11, 6), to: DateTime(2026, 11, 12), festivalId: 'f1');
        } else if (c == 'o_st_43') {
          StaySpecialPriceMemory.lastPercent = 15;
          StaySpecialPriceSheet.open(ctx, sp, from: DateTime(2027, 6, 10), to: DateTime(2027, 6, 20));
        } else {
          StaySpecialPriceMemory.lastPercent = 10;
          StaySpecialPriceSheet.open(ctx, sp, from: DateTime(2026, 11, 10), to: DateTime(2026, 11, 14));
        }
        await settle(t);
        if (c == 'o_st_43') {
          await t.tap(find.text('Lower price'));
          await settle(t);
        }
        if (c == 'o_st_44') {
          await t.tap(find.text('Save').last);
          await settle(t);
        }
      });
      StaySpecialPriceMemory.reset();
    });
  }

  testWidgets('render o_st_47', (tester) async {
    final m = monthJson(plus: true, entries: [
      entryJson('bisht', '2026-11-07', '2026-11-09', 'Bisht family', finalAmount: 6000, received: 2000),
      entryJson('sanjay', '2026-11-09', '2026-11-11', 'Sanjay Rao', auto: true),
    ])
      ..['today'] = '2026-10-15';
    final h = CalendarHarness.setUp(plan: OwnerPlans.plus, month: m);
    await renderOwnerFrame(tester, 'o_st_47', StayCalendarScreen(controller: h.calendar), arrange: (t) async {
      await settle(t);
      h.calendar.selectDay(DateTime(2026, 11, 8));
      StayDaySheet.show(ctxOf(t, StayCalendarScreen), h.calendar, DateTime(2026, 11, 8), onAdd: (_) {}, onBlock: (_) {});
      await settle(t);
    });
  });

  testWidgets('render o_st_51', (tester) async {
    CalendarHarness.setUp(extra: (p) {
      if (!p.endsWith('/past')) return null;
      return {
        'items': [
          entryJson('walk', '2026-11-17', '2026-11-18', 'Walk-in couple', finalAmount: 2400, paid: true),
          entryJson('sanjay', '2026-11-09', '2026-11-10', 'Sanjay Rao', auto: true, roomNames: 'Family Room', finalAmount: 3600, paid: true),
          entryJson('bisht', '2026-11-07', '2026-11-09', 'Bisht family', finalAmount: 6000, received: 2000),
          entryJson('ankit', '2026-10-24', '2026-10-26', 'Ankit Mehra', auto: true, roomNames: 'Deluxe Room', finalAmount: 6000, paid: true),
          entryJson('office', '2026-10-03', '2026-10-05', 'Office group, 3 rooms', finalAmount: 9000, paid: true),
          entryJson('kavya', '2026-09-12', '2026-09-14', 'Kavya Iyer', auto: true, roomNames: 'Deluxe Room', finalAmount: 6000, paid: true),
          entryJson('negi', '2026-08-28', '2026-08-30', 'Negi ji', finalAmount: 5000, paid: true),
        ],
        'nextCursor': null,
      };
    });
    await renderOwnerFrame(tester, 'o_st_51', StayPastScreen(clock: calClock), arrange: settle);
  });

  testWidgets('render o_st_59 A', (tester) async {
    final h = CalendarHarness.setUp(extra: (p) {
      if (p == '/stays/me/blocked-ranges') {
        return {
          'items': [{'id': 'b1', 'dateFrom': '2026-11-30', 'dateTo': '2026-12-02', 'reason': 'Water tank repair', 'version': 1}],
          'meters': [meter('BlockedRanges', 1, 1)],
        };
      }
      return null;
    });
    await renderOwnerFrame(tester, 'o_st_59', StayCalendarEntryScreen(args: const {'id': 'b1', 'kind': 'block'}, controller: h.calendar), part: 'A', arrange: settle);
  });

  for (final part in ['B', 'C']) {
    testWidgets('render o_st_59 $part', (tester) async {
      final h = CalendarHarness.setUp(
        plan: OwnerPlans.plus,
        month: monthJson(blocks: const []),
        override: (m, p, b) async {
          if (m == 'POST' && p.startsWith('/stays/me/blocked-ranges')) {
            if (part == 'B') throw refusal(409, 'BlockedRangeNeedsConfirm', data: {'confirmedInside': 1, 'openEnquiriesInside': 2});
            throw refusal(409, 'BlockedRangeOverlap');
          }
          return const {};
        },
      );
      await renderOwnerFrame(tester, 'o_st_59', StayCalendarScreen(controller: h.calendar), part: part, arrange: (t) async {
        await settle(t);
        final ctx = ctxOf(t, StayCalendarScreen);
        StayEntrySheet.add(ctx, h.calendar, from: part == 'B' ? DateTime(2026, 11, 27) : DateTime(2026, 12, 1), to: part == 'B' ? DateTime(2026, 11, 30) : DateTime(2026, 12, 5));
        await settle(t);
        await t.enterText(find.byType(EditableText).first, part == 'B' ? 'Family function' : 'Painting');
        await t.ensureVisible(find.text('Block these days').first);
        await t.tap(find.text('Block these days').first);
        await settle(t);
        await t.tap(find.text('Save block'));
        await settle(t);
      });
    });
  }

  for (final part in ['A', 'B', 'C']) {
    testWidgets('render o_st_60 $part', (tester) async {
      final h = CalendarHarness.setUp();
      await renderOwnerFrame(tester, 'o_st_60', StayCalendarScreen(controller: h.calendar), part: part, arrange: (t) async {
        await settle(t);
        StayEntrySheet.add(ctxOf(t, StayCalendarScreen), h.calendar, from: DateTime(2026, 11, 27), to: DateTime(2026, 11, 28));
        await settle(t);
        final f = find.byType(EditableText);
        if (part == 'A') await t.enterText(f.at(0), 'Sharma family');
        if (part == 'B') {
          await t.enterText(f.at(0), 'Negi ji, 1 room');
          await t.enterText(f.at(1), '4000');
          await t.enterText(f.at(2), '5000');
          await t.enterText(f.at(3), 'Call Ravi 98765 43210');
        }
        if (part == 'C') {
          await t.enterText(f.at(0), 'Office group');
          await t.tap(find.text('Paid in full'));
        }
        await settle(t);
      });
    });
  }

  testWidgets('render o_st_61 B', (tester) async {
    CalendarHarness.setUp(registerCalendar: false, extra: (p) {
      if (p != '/stays/me') return null;
      return {
        'photos': [
          {'id': 'p1', 'url': '', 'photoOrder': 0},
          {'id': 'p2', 'url': '', 'photoOrder': 1},
        ],
        'hiddenPhotos': [for (var i = 3; i <= 6; i++) {'id': 'p$i', 'url': '', 'photoOrder': 50 + i}],
        'rooms': [
          {'id': 'r1', 'roomName': 'Deluxe Room', 'pricePerNight': 3000, 'roomIndex': 1},
          {'id': 'r2', 'roomName': 'Family Room', 'pricePerNight': 4500, 'roomIndex': 2},
        ],
        'hiddenRooms': [
          {'id': 'r3', 'roomName': 'Suite', 'pricePerNight': 5500, 'roomIndex': 101},
          {'id': 'r4', 'roomName': 'Dormitory', 'pricePerNight': 900, 'roomIndex': 102},
        ],
        'meters': [meter('Photos', 2, 2), meter('RoomTypes', 2, 2)],
      };
    });
    await renderOwnerFrame(tester, 'o_st_61', const StayPlanVisibleScreen(), part: 'B', arrange: settle);
  });

  testWidgets('render o_st_62', (tester) async {
    final m = monthJson(
      entriesUsed: 4,
      hiddenCount: 8,
      entries: [
        ...novEntries().take(2),
        entryJson('neha', '2026-11-22', '2026-11-23', 'Neha Joshi', auto: true),
        entryJson('kapoor', '2026-11-24', '2026-11-25', 'Kapoor couple', finalAmount: 2800, received: 800),
        entryJson('gupta', '2026-11-25', '2026-11-27', 'Gupta ji, 2 rooms', finalAmount: 9000, received: 3000),
        entryJson('rohit', '2026-11-27', '2026-11-29', 'Rohit Verma', auto: true),
        entryJson('office', '2026-12-02', '2026-12-04', 'Office group'),
        entryJson('bisht', '2026-12-05', '2026-12-06', 'Bisht family'),
      ],
      specialPrices: [
        {'id': 'sp9', 'dateFrom': '2027-01-25', 'dateTo': '2027-01-27', 'direction': 'Higher', 'percent': 10, 'pausedByPlan': true, 'version': 1},
      ],
    );
    final h = CalendarHarness.setUp(
      month: m,
      special: specialJson(items: [
        {'id': 'sp2', 'dateFrom': '2026-12-24', 'dateTo': '2027-01-01', 'direction': 'Higher', 'percent': 25, 'label': 'Christmas and New Year', 'live': true, 'version': 1},
        {'id': 'sp3', 'dateFrom': '2027-01-25', 'dateTo': '2027-01-27', 'direction': 'Higher', 'percent': 10, 'pausedByPlan': true, 'version': 1},
        {'id': 'sp4', 'dateFrom': '2027-02-08', 'dateTo': '2027-02-18', 'direction': 'Lower', 'percent': 15, 'pausedByPlan': true, 'version': 1},
      ]),
      extra: (p) => p == '/stays/me/blocked-ranges'
          ? {
              'items': [
                {'id': 'b1', 'dateFrom': '2026-11-30', 'dateTo': '2026-12-02', 'reason': 'Water tank repair', 'version': 1},
                {'id': 'b2', 'dateFrom': '2026-12-18', 'dateTo': '2026-12-20', 'reason': 'Family visit', 'version': 1},
              ],
            }
          : null,
    );
    await renderOwnerFrame(tester, 'o_st_62', StayCalendarScreen(controller: h.calendar), arrange: settle);
  });

  testWidgets('render o_st_67 D', (tester) async {
    final h = CalendarHarness.setUp(override: (m, p, b) async {
      if (m == 'PUT' && p.contains('/entries/')) throw refusal(409, 'StaleEdit');
      return const {};
    });
    await renderOwnerFrame(tester, 'o_st_67', StayCalendarScreen(controller: h.calendar), part: 'D', arrange: (t) async {
      await settle(t);
      final e = h.calendar.current!.entries.firstWhere((e) => e.id == 'gupta');
      StayEntrySheet.edit(ctxOf(t, StayCalendarScreen), h.calendar, e);
      await settle(t);
      await t.tap(find.text('Save booking'));
      await settle(t);
    });
  });
}
