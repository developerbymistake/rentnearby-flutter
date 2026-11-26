import 'package:bakhli/features/taxi/guest/v2/taxi_journey_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 26);

  test('IST today flips at 18:30 UTC', () {
    expect(TaxiJourneyDate.today(DateTime.utc(2026, 11, 25, 18, 29)), DateTime(2026, 11, 25));
    expect(TaxiJourneyDate.today(DateTime.utc(2026, 11, 25, 18, 30)), DateTime(2026, 11, 26));
    expect(TaxiJourneyDate.today(DateTime.utc(2026, 12, 31, 19)), DateTime(2027, 1, 1));
  });

  test('window is today up to 90 days ahead', () {
    expect(TaxiJourneyDate.last(today), DateTime(2027, 2, 24));
    expect(TaxiJourneyDate.clamp(today, today), today);
    expect(TaxiJourneyDate.clamp(TaxiJourneyDate.addDays(today, 90), today), DateTime(2027, 2, 24));
    expect(TaxiJourneyDate.clamp(TaxiJourneyDate.addDays(today, 91), today), DateTime(2027, 2, 24));
    expect(TaxiJourneyDate.clamp(DateTime(2026, 11, 20), today), today);
    expect(TaxiJourneyDate.clamp(DateTime(2026, 11, 27, 23, 59), today), DateTime(2026, 11, 27));
  });

  test('previous and next flags stop at the window edges', () {
    expect(TaxiJourneyDate.canPrev(today, today), isFalse);
    expect(TaxiJourneyDate.canNext(today, today), isTrue);
    final day1 = TaxiJourneyDate.addDays(today, 1);
    expect(TaxiJourneyDate.canPrev(day1, today), isTrue);
    final day90 = TaxiJourneyDate.addDays(today, 90);
    expect(TaxiJourneyDate.canNext(day90, today), isFalse);
    expect(TaxiJourneyDate.canNext(TaxiJourneyDate.addDays(today, 89), today), isTrue);
  });

  test('api text and strict parsing', () {
    expect(TaxiJourneyDate.apiText(DateTime(2026, 3, 5)), '2026-03-05');
    expect(TaxiJourneyDate.parse('2026-11-27'), DateTime(2026, 11, 27));
    expect(TaxiJourneyDate.parse(' 2026-11-27 '), DateTime(2026, 11, 27));
    for (final bad in [null, 5, '', '2026-11-31', '2026-13-01', '26-11-2026', '2026-11-27T00:00:00', '2026/11/27']) {
      expect(TaxiJourneyDate.parse(bad), isNull, reason: '$bad');
    }
  });

  test('same compares calendar days only', () {
    expect(TaxiJourneyDate.same(DateTime(2026, 11, 26, 8), today), isTrue);
    expect(TaxiJourneyDate.same(null, today), isFalse);
    expect(TaxiJourneyDate.same(DateTime(2026, 11, 27), today), isFalse);
  });
}
