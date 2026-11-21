import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/json/owner_dates.dart';
import 'package:bakhli/features/owner_core/json/owner_json.dart';
import 'package:bakhli/features/owner_core/money/money_note_math.dart';
import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/utils/account_delete_message.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';

void _noThrow(String name, Map<String, dynamic> sample, Object? Function(Map<String, dynamic>) parse) {
  test('$name: every variant parses without throwing', () {
    var n = 0;
    for (final v in jsonVariants(sample)) {
      expect(() => parse(v), returnsNormally, reason: '$v');
      n++;
    }
    expect(n, greaterThan(10));
  });
}

void main() {
  group('samples parse to the contract values', () {
    test('calendar month', () {
      final m = CalendarMonth.fromJson(loadSample('calendar_month'));
      expect(m.entries, hasLength(2));
      expect(m.entries.first.isAuto, isTrue);
      expect(m.entries.first.guests, 2);
      expect(m.entries.first.roomNames, 'Family Room');
      expect(m.entries.first.chip, MoneyChip.toCollect);
      expect(m.entries[1].isManual, isTrue);
      expect(m.blocks.single.reason, 'Family visit');
      expect(m.specialPrices.single.direction, PriceDirection.higher);
      expect(m.festivals.single.name, 'Diwali week');
      expect(Meter.find(m.meters, 'CalendarEntries')?.used, 3);
      expect(m.window.locked, isTrue);
      expect(m.window.monthTo, DateTime(2026, 11, 30));
      expect(m.today, DateTime(2026, 11, 21));
      expect(m.raw, isNotEmpty);
    });

    test('upcoming, write, summary', () {
      final u = UpcomingPage.fromJson(loadSample('calendar_upcoming'));
      expect(u.items, hasLength(2));
      expect(u.nextCursor, 'abc');
      expect(u.beyondWindowFirstDate, DateTime(2026, 12, 7));
      final w = EntryWriteResult.fromJson(loadSample('calendar_write'));
      expect(w.entry?.id, 'e2');
      expect(w.overlap.bookings, 1);
      final s = MoneySummary.fromJson(loadSample('calendar_summary'));
      expect(s.month, DateTime(2026, 11));
      expect(s.toCollect, 14800);
    });

    test('owner home', () {
      final h = OwnerHomeDto.fromJson(loadSample('owner_home'));
      expect(h.listing.name, 'Deodar Heights Homestay');
      expect(h.listing.statusLine?.code, 'CheckInsThisWeek');
      expect(h.attention.map((a) => a.code), ['EnquiriesWaiting', 'ShareListing', 'AddShareDetails']);
      expect(h.numbers.newEnquiries, 2);
      expect(h.numbers.centreBadge, 2);
      expect(h.numbers.ratingAvg, isNull);
      expect(h.upcoming.rows, hasLength(2));
      expect(h.upcoming.moreInWindowCount, 3);
      expect(h.planCard?.state, PlanCardState.free);
      expect(h.planCard?.weekly?.shown, 140);
      expect(h.festival?.daysAway, 33);
    });

    test('plans me: new fields and Free defaults', () {
      final p = MyPlanModel.fromJson(loadSample('plans_me'));
      expect(p.limits.calendarEntries, 4);
      expect(p.limits.monthSummary, isFalse);
      expect(p.hidden.photos, 1);
      expect(p.usage.photos, 2);
      expect(p.usage.routes, isNull);
      expect(p.canUpgrade, isTrue);
      expect(p.paymentStartsOn, DateTime(2027, 2, 1));
      final empty = MyPlanModel.fromJson(const {});
      expect(empty.limits.photos, 2);
      expect(empty.limits.upcomingDays, 15);
      expect(empty.limits.monthsAhead, 0);
      expect(empty.canUpgrade, isFalse);
    });

    test('unknown enum values fall back to neutral values', () {
      expect(CalendarEntry.fromJson(const {'id': 'x', 'kind': 'Robot', 'dateFrom': '2026-11-01'}).valid, isFalse);
      expect(CalendarEntry.fromJson(const {'id': 'x', 'kind': 'Manual', 'dateFrom': '2026-11-01', 'chip': 'Gold'}).chip, MoneyChip.none);
      expect(PlanCardStates.parse('Active'), PlanCardState.unknown);
      expect(SpecialPriceBand.fromJson(const {'id': 'p', 'direction': 'Sideways'}).direction, PriceDirection.unknown);
    });
  });

  group('defensive parsing', () {
    _noThrow('CalendarMonth', loadSample('calendar_month'), CalendarMonth.fromJson);
    _noThrow('CalendarEntry', loadSample('calendar_entry'), CalendarEntry.fromJson);
    _noThrow('UpcomingPage', loadSample('calendar_upcoming'), UpcomingPage.fromJson);
    _noThrow('EntryWriteResult', loadSample('calendar_write'), EntryWriteResult.fromJson);
    _noThrow('MoneySummary', loadSample('calendar_summary'), MoneySummary.fromJson);
    _noThrow('OwnerHomeDto', loadSample('owner_home'), OwnerHomeDto.fromJson);
    _noThrow('MyPlanModel', loadSample('plans_me'), MyPlanModel.fromJson);
    test('AccountDeleteBlock: every reason variant', () {
      final reasons = (loadSample('account_blocked')['data'] as Map<String, dynamic>)['reasons'] as List;
      for (final r in reasons.cast<Map<String, dynamic>>()) {
        for (final v in jsonVariants(r)) {
          expect(() => AccountDeleteBlock.fromJson(v), returnsNormally);
        }
      }
      expect(AccountDeleteBlock.fromJson('x'), isNull);
      expect(AccountDeleteBlock.fromJson(const {}), isNull);
    });
  });

  group('OwnerDates', () {
    test('day reads only real dates', () {
      expect(OwnerDates.day('2026-11-21'), DateTime(2026, 11, 21));
      expect(OwnerDates.day('2026-11-21T10:00:00Z'), DateTime(2026, 11, 21));
      expect(OwnerDates.day('2026-02-30'), isNull);
      expect(OwnerDates.day('2026/11/21'), isNull);
      expect(OwnerDates.day('x'), isNull);
      expect(OwnerDates.day(7), isNull);
    });
    test('time and month', () {
      expect(OwnerDates.time('07:30'), (hour: 7, minute: 30));
      expect(OwnerDates.time('25:00'), isNull);
      expect(OwnerDates.month('2026-11'), DateTime(2026, 11));
      expect(OwnerDates.month('2026-13'), isNull);
      expect(OwnerDates.monthKey(DateTime(2026, 3, 9)), '2026-03');
      expect(OwnerDates.dayText(DateTime(2026, 3, 9)), '2026-03-09');
    });
    test('OwnerJson readers never throw', () {
      expect(OwnerJson.integer('12'), 12);
      expect(OwnerJson.integer('x', 3), 3);
      expect(OwnerJson.doubleOrNull('4.5'), 4.5);
      expect(OwnerJson.strOrNull(''), isNull);
      expect(OwnerJson.boolOrNull('maybe'), isNull);
      expect(OwnerJson.ints([1, 'a', 2.0]), [1, 2]);
    });
  });
}
