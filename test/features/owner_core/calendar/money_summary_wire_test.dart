import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';

void main() {
  test('server summary body gives the four numbers and three top rows', () {
    final s = MoneySummary.fromJson(loadSample('calendar_summary'));
    expect(s.month, DateTime(2026, 11));
    expect(s.booked, 23500);
    expect(s.received, 8700);
    expect(s.toCollect, 14800);
    expect(s.entryCount, 5);
    expect(s.dueCount, 4);
    expect(s.top, hasLength(3));
    expect(s.top.first.label, 'Gupta ji, 2 rooms');
    expect(s.top.first.chipAmount, 6000);
  });

  test('raw body round trips through the cache', () {
    final s = MoneySummary.fromJson(loadSample('calendar_summary'));
    final again = MoneySummary.fromJson(s.raw);
    expect(again.booked, s.booked);
    expect(again.toCollect, s.toCollect);
    expect(again.top, hasLength(3));
  });

  test('paid moves the amount and lowers the due count', () {
    final s = MoneySummary.fromJson(loadSample('calendar_summary')).paid(6000);
    expect(s.received, 14700);
    expect(s.toCollect, 8800);
    expect(s.dueCount, 3);
  });
}
