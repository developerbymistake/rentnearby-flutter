import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/calendar/month_grid_data.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEntry _e(String id, DateTime from, DateTime to, {bool auto = false, bool cancelled = false, String? time}) => CalendarEntry(
      id: id,
      kind: auto ? EntryKind.auto : EntryKind.manual,
      dateFrom: from,
      dateTo: to,
      cancelled: cancelled,
      timeOfDay: time,
    );

DayCell _cell(List<DayCell> cells, int day) => cells.firstWhere((c) => c.inMonth && c.date.day == day);

void main() {
  final nov = DateTime(2026, 11);
  final today = DateTime(2026, 11, 21);

  test('42 cells, Monday first, November 2026 starts on a Sunday', () {
    final cells = MonthGridData.build(month: nov, entries: const [], today: today);
    expect(cells, hasLength(42));
    expect(cells.first.date, DateTime(2026, 10, 26));
    expect(cells[6].date, DateTime(2026, 11, 1));
    expect(cells.where((c) => c.inMonth), hasLength(30));
  });

  test('stay nights: check-in to the day before check-out', () {
    final cells = MonthGridData.build(month: nov, entries: [_e('a', DateTime(2026, 11, 22), DateTime(2026, 11, 24), auto: true)], today: today);
    expect(_cell(cells, 22).appCount, 1);
    expect(_cell(cells, 23).appCount, 1);
    expect(_cell(cells, 24).appCount, 0);
    expect(_cell(cells, 22).bar, BarPart.start);
    expect(_cell(cells, 23).bar, BarPart.end);
  });

  test('taxi days: from and to inclusive', () {
    final cells = MonthGridData.build(
        month: nov, entries: [_e('t', DateTime(2026, 11, 25), DateTime(2026, 11, 25))], today: today, stayNights: false);
    expect(_cell(cells, 25).ownCount, 1);
    expect(_cell(cells, 25).bar, BarPart.none);
  });

  test('blocks and special prices are inclusive; festival names; cancelled is grey only', () {
    final cells = MonthGridData.build(
      month: nov,
      entries: [_e('c', DateTime(2026, 11, 27), DateTime(2026, 11, 28), cancelled: true)],
      blocks: [CalendarBlock(id: 'b', dateFrom: DateTime(2026, 11, 30), dateTo: DateTime(2026, 11, 30))],
      bands: [
        SpecialPriceBand(id: 'p', dateFrom: DateTime(2026, 11, 6), dateTo: DateTime(2026, 11, 12), direction: PriceDirection.higher, percent: 20),
        SpecialPriceBand(id: 'q', dateFrom: DateTime(2026, 11, 14), dateTo: DateTime(2026, 11, 14), direction: PriceDirection.lower, percent: 5, isPaused: true),
      ],
      festivals: [FestivalRow(id: 'f', name: 'Diwali week', dateFrom: DateTime(2026, 11, 6), dateTo: DateTime(2026, 11, 12))],
      today: today,
    );
    expect(_cell(cells, 30).blocked, isTrue);
    expect(_cell(cells, 6).specialPrice, isTrue);
    expect(_cell(cells, 12).specialPrice, isTrue);
    expect(_cell(cells, 13).specialPrice, isFalse);
    expect(_cell(cells, 14).specialPrice, isFalse);
    expect(_cell(cells, 8).festivalName, 'Diwali week');
    expect(_cell(cells, 27).onlyCancelled, isTrue);
    expect(_cell(cells, 27).bar, BarPart.none);
  });

  test('past days and days outside the window are not tappable', () {
    final cells = MonthGridData.build(
      month: nov,
      entries: const [],
      today: today,
      window: CalendarWindow(monthFrom: DateTime(2026, 11, 1), monthTo: DateTime(2026, 11, 30)),
    );
    expect(_cell(cells, 20).tappable, isFalse);
    expect(_cell(cells, 21).isToday, isTrue);
    expect(_cell(cells, 21).tappable, isTrue);
    expect(cells.last.inMonth, isFalse);
  });

  test('day list puts app bookings first, then by time', () {
    final list = MonthGridData.entriesOn(DateTime(2026, 11, 25), [
      _e('m2', DateTime(2026, 11, 25), DateTime(2026, 11, 25), time: '09:00'),
      _e('m1', DateTime(2026, 11, 25), DateTime(2026, 11, 25), time: '07:00'),
      _e('a1', DateTime(2026, 11, 25), DateTime(2026, 11, 25), auto: true, time: '18:00'),
    ], stayNights: false);
    expect(list.map((e) => e.id), ['a1', 'm1', 'm2']);
  });

  test('50 entries build fast and stay immutable', () {
    final many = [for (var i = 0; i < 50; i++) _e('e$i', DateTime(2026, 11, 1 + i % 28), DateTime(2026, 11, 2 + i % 28))];
    final sw = Stopwatch()..start();
    final cells = MonthGridData.build(month: nov, entries: many, today: today);
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(200));
    expect(() => (cells as List).add(cells.first), throwsUnsupportedError);
  });
}
