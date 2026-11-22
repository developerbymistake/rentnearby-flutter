import 'dart:io';

import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/json/owner_dates.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/pricing/special_price_math.dart';
import 'package:bakhli/features/stay_owner/calendar/models/stay_calendar_models.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_entry_sheet.dart';
import 'package:bakhli/features/stay_owner/special_prices/stay_special_price_sheet.dart';
import 'package:bakhli/features/stay_owner/strings/stay_calendar_strings.dart';
import 'package:bakhli/features/stay_owner/strings/stay_gate_strings_calendar.dart';
import 'package:bakhli/features/stay_owner/strings/stay_special_price_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import 'calendar_fixtures.dart';

void main() {
  setUpAll(() => initTestStorage('stay_calendar_logic'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  group('models never throw', () {
    final samples = <String, void Function(Map<String, dynamic>)>{
      'block write': (j) => StayBlockWrite.fromJson(j),
      'block list': (j) => StayBlockList.fromJson(j),
      'price room': (j) => StayPriceRoom.fromJson(j),
      'special page': (j) => StaySpecialPricesPage.fromJson(j),
      'overlap': (j) => SpecialPriceOverlapInfo.maybe(j),
      'plan visible': (j) => StayPlanVisibleState.fromJson(j, photoLimit: 2, roomLimit: 2),
    };
    final data = <String, Map<String, dynamic>>{
      'block write': {
        'block': {'id': 'b', 'dateFrom': '2026-11-30', 'dateTo': '2026-12-02', 'reason': 'x', 'version': 1},
        'confirmedInside': 1,
        'openEnquiriesInside': 2,
        'meters': [meter('BlockedRanges', 1, 1)],
      },
      'block list': {'items': [{'id': 'b', 'dateFrom': '2026-11-30', 'dateTo': '2026-12-02'}], 'meters': [meter('BlockedRanges', 1, 1)]},
      'price room': {'id': 'r', 'roomName': 'Deluxe Room', 'basePrice': 3000},
      'special page': specialJson(),
      'overlap': {'id': 'sp1', 'label': 'Diwali week', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12'},
      'plan visible': {
        'photos': [{'id': 'p1', 'url': '', 'photoOrder': 0}],
        'hiddenPhotos': [{'id': 'p2', 'url': '', 'photoOrder': 9}],
        'rooms': [{'id': 'r1', 'roomName': 'Deluxe Room', 'pricePerNight': 3000, 'roomIndex': 1}],
        'hiddenRooms': [{'id': 'r2', 'roomName': 'Suite', 'pricePerNight': 5500, 'roomIndex': 101}],
        'meters': [meter('Photos', 1, 2)],
      },
    };
    for (final e in samples.entries) {
      test(e.key, () {
        for (final v in jsonVariants(data[e.key]!)) {
          expect(() => e.value(v), returnsNormally);
        }
      });
    }

    test('unknown direction keeps the rule with no price line, rooms without price are dropped', () {
      final p = StaySpecialPricesPage.fromJson({
        'items': [{'id': 'a', 'dateFrom': '2026-12-01', 'dateTo': '2026-12-02', 'direction': 'Sideways', 'percent': 10}],
        'rooms': [{'id': 'r', 'roomName': 'Deluxe Room', 'basePrice': 0}],
      });
      expect(p.items.single.direction.name, 'unknown');
      expect(p.rooms, isEmpty);
    });
  });

  group('booking and block rules', () {
    final t = calToday;
    test('stay nights 1..60', () {
      expect(StayEntryRules.nightsOk(t, t), isFalse);
      expect(StayEntryRules.nightsOk(t, OwnerDates.addDays(t, 1)), isTrue);
      expect(StayEntryRules.nightsOk(t, OwnerDates.addDays(t, 60)), isTrue);
      expect(StayEntryRules.nightsOk(t, OwnerDates.addDays(t, 61)), isFalse);
    });
    test('block 1..90 nights inclusive, start today..+180', () {
      expect(StayEntryRules.blockOk(t, t, t), isTrue);
      expect(StayEntryRules.blockOk(t, OwnerDates.addDays(t, 89), t), isTrue);
      expect(StayEntryRules.blockOk(t, OwnerDates.addDays(t, 90), t), isFalse);
      expect(StayEntryRules.blockOk(OwnerDates.addDays(t, 180), OwnerDates.addDays(t, 180), t), isTrue);
      expect(StayEntryRules.blockOk(OwnerDates.addDays(t, 181), OwnerDates.addDays(t, 181), t), isFalse);
      expect(StayEntryRules.blockOk(OwnerDates.addDays(t, -1), t, t), isFalse);
    });
    test('ids are unique uuid-shaped strings', () {
      final a = StayIds.next();
      expect(a, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(StayIds.next(), isNot(a));
    });
  });

  group('special price rules', () {
    test('percent clamp by direction and step', () {
      expect(SpecialPriceRules.clamp(60, true), 50);
      expect(SpecialPriceRules.clamp(60, false), 60);
      expect(SpecialPriceRules.clamp(0, false), 5);
      expect(SpecialPriceRules.clamp(105, false), 100);
    });
    test('nights inclusive, 60 / 61, +180 / +181', () {
      expect(SpecialPriceRules.nights(DateTime(2027, 6, 10), DateTime(2027, 6, 20)), 11);
      expect(SpecialPriceRules.nights(DateTime(2026, 11, 6), DateTime(2026, 11, 12)), 7);
      final t = calToday;
      expect(SpecialPriceRules.datesError(t, OwnerDates.addDays(t, 59), t), isNull);
      expect(SpecialPriceRules.datesError(t, OwnerDates.addDays(t, 60), t), StaySpecialPriceStrings.tooManyNights);
      expect(SpecialPriceRules.datesError(OwnerDates.addDays(t, 180), OwnerDates.addDays(t, 180), t), isNull);
      expect(SpecialPriceRules.datesError(OwnerDates.addDays(t, 181), OwnerDates.addDays(t, 181), t), StaySpecialPriceStrings.startTooFar);
      expect(SpecialPriceRules.datesError(OwnerDates.addDays(t, -2), t, t), StaySpecialPriceStrings.startPast);
      expect(SpecialPriceRules.datesError(OwnerDates.addDays(t, -2), t, t, keptStart: OwnerDates.addDays(t, -2)), isNull);
    });
    test('preview numbers of the frames', () {
      expect(SpecialPriceMath.adjust(3000, false, 20), 3600);
      expect(SpecialPriceMath.adjust(4500, false, 20), 5400);
      expect(SpecialPriceMath.adjust(3000, true, 15), 2550);
      expect(SpecialPriceMath.adjust(4500, true, 15), 3830);
      expect(SpecialPriceMath.adjust(4500, false, 25), 5630);
    });
    test('preview header follows the direction', () {
      expect(StaySpecialPriceStrings.previewLower('10 to 20 Jun', 11, 15), '10 to 20 Jun · 11 nights · travellers see the price with “15% off”');
      expect(StaySpecialPriceStrings.previewHigher('6 to 12 Nov', 7), '6 to 12 Nov · 7 nights · travellers see only the new price');
    });
  });

  group('strings', () {
    test('deletes on is the last date + 90 days', () {
      expect(StayCalendarStrings.deletesOn(OwnerDates.addDays(DateTime(2026, 11, 27), 90)), 'Deletes on 25 Feb 2027');
      expect(StayCalendarStrings.removedOn(OwnerDates.addDays(DateTime(2026, 11, 26), 90)), 'Removed automatically on 24 Feb, 90 days after this date.');
    });
    test('singular and plural lines', () {
      expect(StayCalendarStrings.beyondWindow(DateTime(2026, 12, 6), 1), 'After 6 Dec: 1 booking from the app (see Enquiries). Plus shows 6 months ahead.');
      expect(StayCalendarStrings.beyondWindow(DateTime(2026, 12, 6), 2), contains('2 bookings'));
      expect(StayCalendarStrings.confirmedInside(1), '1 confirmed booking is inside these days');
      expect(StayCalendarStrings.openEnquiriesFor(2), '2 open enquiries are for these days.');
      expect(StayCalendarStrings.alreadyBookings(1), 'You already have 1 booking on these days.');
      expect(StayCalendarStrings.hiddenMore(8), '8 more bookings are hidden. They show as dates pass.');
      expect(StayCalendarStrings.hiddenMore(1), '1 more booking is hidden. It shows as dates pass.');
      expect(StayCalendarStrings.bookingsOnDay(2), '2 bookings on this day');
      expect(StayCalendarStrings.dayTitle(DateTime(2026, 11, 27)), 'Fri, 27 Nov');
      expect(StayCalendarStrings.festivalDay('Diwali', 1), 'Diwali · 1 booking on this day');
    });
    test('gate copy G10, G11, G12 with Free numbers', () {
      PlanGate.debugPlan = OwnerPlans.free;
      final g10 = StayGateStringsCalendar.g10(used: 4);
      expect(g10.title, 'You have 4 active entries');
      expect(g10.body, 'Free keeps 4 bookings you add yourself. Plus keeps 50.');
      expect(g10.rows.map((r) => r.value), ['4 bookings you add', '50 bookings you add']);
      final g11 = StayGateStringsCalendar.g11();
      expect(g11.title, 'Free allows 1 blocked range');
      expect(g11.body, 'Plus lets you block up to 10. You can change or remove your current block at any time.');
      final g12 = StayGateStringsCalendar.g12(endsOn: DateTime(2026, 11, 12));
      expect(g12.title, '1 special price on Free');
      expect(g12.body, 'Plus keeps 5 at a time. Your current one ends on 12 Nov. You can change or remove it now.');
      expect(PlanGate.priceLine(taxi: false), '₹400 / month · 7 days free');
      PlanGate.debugPlan = OwnerPlans.freeNoTrial;
      expect(PlanGate.priceLine(taxi: false), '₹400 / month');
    });
  });

  group('controller', () {
    test('G10 / G11 decisions follow the meters and the plan', () async {
      final h = CalendarHarness.setUp(month: monthJson(entriesUsed: 4));
      await h.calendar.start();
      expect(h.calendar.needsG10(DateTime(2026, 11, 30)), isTrue);
      expect(h.calendar.needsG10(DateTime(2026, 11, 20)), isFalse, reason: 'a past entry is never active');
      expect(h.calendar.needsG11, isTrue);
      PlanGate.debugPlan = OwnerPlans.paymentOff;
      expect(h.calendar.needsG10(DateTime(2026, 11, 30)), isFalse);
      expect(h.calendar.needsG11, isFalse);
      PlanGate.debugPlan = OwnerPlans.plus;
      expect(h.calendar.needsG11, isFalse);
    });

    test('month rows, own active rows and overlap count are prepared once per payload', () async {
      final h = CalendarHarness.setUp();
      await h.calendar.start();
      expect(h.calendar.monthRows.map((e) => e.id), ['sanjay', 'walkin', 'neha', 'kapoor', 'gupta', 'rohit']);
      expect(h.calendar.ownActive.map((e) => e.id), ['kapoor', 'gupta']);
      expect(h.calendar.overlapCount(DateTime(2026, 11, 26), DateTime(2026, 11, 28)), 2);
      expect(h.calendar.overlapCount(DateTime(2026, 11, 26), DateTime(2026, 11, 28), exceptId: 'gupta'), 1);
      expect(h.calendar.blockedBetween(DateTime(2026, 11, 29), DateTime(2026, 12, 1)), isTrue);
      expect(h.calendar.blockedBetween(DateTime(2026, 11, 27), DateTime(2026, 11, 29)), isFalse);
    });

    test('day entries: check-in and check-out rows, app first', () async {
      final h = CalendarHarness.setUp();
      await h.calendar.start();
      expect(h.calendar.dayEntries(DateTime(2026, 11, 27)).map((e) => e.id), ['rohit', 'gupta']);
      expect(h.calendar.ruleOn(DateTime(2026, 11, 8))?.label, 'Diwali week');
      expect(h.calendar.festivalOn(DateTime(2026, 11, 8))?.name, 'Diwali');
    });

    test('Free summary is locked and never requested; Plus reads it', () async {
      final h = CalendarHarness.setUp();
      await h.calendar.start();
      expect(h.calendar.summaryOpen, isFalse);
      expect(h.transport.calls.where((c) => c.endsWith('/summary')), isEmpty);
      resetOwnerTestState();
      final p = CalendarHarness.setUp(plan: OwnerPlans.plus, month: monthJson(plus: true));
      await p.calendar.start();
      await Future<void>.delayed(Duration.zero);
      expect(p.calendar.summaryOpen, isTrue);
      expect(p.transport.calls.where((c) => c.endsWith('/summary')), isNotEmpty);
      expect(p.calendar.summary.value.valueOrNull?.toCollect, 14700);
    });

    test('payment OFF opens the summary without a plan', () async {
      final h = CalendarHarness.setUp(plan: OwnerPlans.paymentOff, month: monthJson(paymentEnabled: false));
      await h.calendar.start();
      expect(h.calendar.summaryOpen, isTrue);
      expect(h.calendar.freeLook, isFalse);
    });

    test('after Plus ends: sections load blocks and special prices', () async {
      final h = CalendarHarness.setUp(month: monthJson(hiddenCount: 8, entriesUsed: 4));
      await h.calendar.start();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(h.calendar.afterPlusSections, isTrue);
      expect(h.transport.calls, contains('GET /stays/me/blocked-ranges'));
      expect(h.transport.calls, contains('GET /stays/me/special-prices'));
    });
  });

  test('phase 2 demand count is not built (o_st_50)', () {
    final files = Directory('lib/features/stay_owner').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final text = f.readAsStringSync().toLowerCase();
      expect(text.contains('travellers asked'), isFalse, reason: f.path);
      expect(text.contains('/demand'), isFalse, reason: f.path);
    }
  });
}
