import 'package:bakhli/features/taxi/guest/v2/taxi_search_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final thu = DateTime(2026, 11, 26);
  final fri = DateTime(2026, 11, 27);

  test('date texts match the mock', () {
    expect(TaxiSearchStrings.dayText(thu), 'Thu 26 Nov');
    expect(TaxiSearchStrings.shortDay(fri), '27 Nov');
    expect(TaxiSearchStrings.dayText(DateTime(2026, 12, 1)), 'Tue 1 Dec');
    expect(TaxiSearchStrings.barText(thu, isToday: true), 'Today, Thu 26 Nov');
    expect(TaxiSearchStrings.barText(fri, isToday: false), 'Fri 27 Nov');
    expect(TaxiSearchStrings.dateRowSemantics(thu, isToday: true), 'Date of journey, Today, Thu 26 Nov');
    expect(TaxiSearchStrings.dateRowSemantics(fri, isToday: false), 'Date of journey, Fri 27 Nov');
  });

  test('counts and empty title', () {
    expect(TaxiSearchStrings.freeCount(9, thu), '9 taxis free on 26 Nov');
    expect(TaxiSearchStrings.freeCount(1, thu), '1 taxi free on 26 Nov');
    expect(TaxiSearchStrings.emptyTitle(fri), 'No taxi is free on 27 Nov');
    expect(TaxiSearchStrings.taxis(9), '9 taxis');
    expect(TaxiSearchStrings.taxis(1), '1 taxi');
  });

  test('popular route texts', () {
    expect(TaxiSearchStrings.routeTitle('Delhi', 'Rishikesh'), 'Delhi → Rishikesh');
    expect(TaxiSearchStrings.routeSemantics('Delhi', 'Rishikesh'), 'Delhi to Rishikesh');
    expect(TaxiSearchStrings.fromFare('₹899'), 'From ₹899');
  });

  test('fixed copy', () {
    expect(TaxiSearchStrings.searchTaxis, 'Search taxis');
    expect(TaxiSearchStrings.samePlace, 'From and To must be different places');
    expect(TaxiSearchStrings.dateSheetBody, 'Today up to 90 days ahead');
    expect(TaxiSearchStrings.errorTitle, 'Could not load taxis');
    expect(TaxiSearchStrings.errorBody, 'Check your connection and try again.');
    expect(TaxiSearchStrings.emptyBody, 'Try another day or another place.');
    expect(TaxiSearchErrors.invalidDate, 'InvalidDate');
  });
}
