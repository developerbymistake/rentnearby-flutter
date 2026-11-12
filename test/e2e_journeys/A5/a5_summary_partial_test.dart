import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_summary_model.dart';
import 'package:bakhli/features/trip/widgets/trip_summary_day_card.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> base({
  List<Map<String, dynamic>> arrangements = const [],
  List<Map<String, dynamic>> nights = const [],
  List<Map<String, dynamic>> taxis = const [],
  String end = '2099-12-03',
  String? status,
}) =>
    {
      'tripId': 't1',
      'city': 'Nainital',
      'startDate': '2099-12-01',
      'endDate': end,
      'status': ?status,
      'days': [
        {'day': 1, 'spots': ['Naini Lake']},
        {'day': 2, 'spots': ['Snow View']},
        {'day': 3, 'spots': ['Bhimtal']},
      ],
      'nights': nights,
      'taxis': taxis,
      'arrangements': arrangements,
    };

void main() {
  // Real life: a traveller booked a stay for 2 of the 3 nights. The row says Confirmed but it is only partly covered.
  test('partial stay row is not done and stays in Still to do with its detail line', () {
    final r = TripSummaryRecord.fromJson(base(arrangements: [
      {
        'key': 'stay:1',
        'title': 'Stay in Nainital',
        'state': 'confirmed',
        'partial': true,
        'nightsCovered': 2,
        'nightsTotal': 3,
        'detail': 'Hill View · 2 of 3 nights',
      },
      {'key': 'taxi', 'title': 'Local taxi', 'state': 'confirmed'},
    ]));
    final stay = r.arrangements.first;
    expect(stay.partial, isTrue);
    expect(stay.isDone, isFalse);
    expect(r.stillToDo.map((a) => a.key.id), ['stay:1']);
    expect(r.percentDone, 50);
    expect(stay.detailLine, 'Hill View · 2 of 3 nights');
  });

  test('detail line falls back to the counts when the server sends no detail', () {
    final r = TripSummaryRecord.fromJson(base(arrangements: [
      {'key': 'stay:1', 'title': 'Stay', 'state': 'confirmed', 'nightsCovered': 2, 'nightsTotal': 3},
    ]));
    expect(r.arrangements.first.partial, isTrue);
    expect(r.arrangements.first.detailLine, '2 of 3 nights');
  });

  test('old servers without the new fields still parse as before', () {
    final r = TripSummaryRecord.fromJson(base(arrangements: [
      {'key': 'stay:1', 'title': 'Stay', 'state': 'confirmed'},
      {'key': 'taxi', 'title': 'Taxi', 'state': 'todo'},
    ]));
    expect(r.arrangements.first.partial, isFalse);
    expect(r.arrangements.first.isDone, isTrue);
    expect(r.arrangements.first.detailLine, isNull);
    expect(r.stillToDo.map((a) => a.key.id), ['taxi']);
  });

  test('uncovered night shows To do, covered night keeps its status', () {
    final r = TripSummaryRecord.fromJson(base(
      arrangements: [
        {'key': 'stay:1', 'title': 'Stay', 'state': 'confirmed', 'partial': true, 'nightsCovered': 1, 'nightsTotal': 2},
      ],
      nights: [
        {'night': 1, 'listingName': 'Hill View', 'displayStatus': 'confirmedByBoth'},
      ],
    ));
    expect(TripDayChips.stay(r, r.days[0])!.label, contains('Confirmed'));
    expect(TripDayChips.stay(r, r.days[1])!.label, 'Stay: To do');
  });

  test('taxi row with empty days still shows its chip on the first itinerary day only', () {
    final r = TripSummaryRecord.fromJson(base(taxis: [
      {'listingName': 'Ramesh', 'days': <int>[], 'displayStatus': 'asked'},
    ]));
    expect(TripDayChips.taxi(r, r.days[0])!.label, startsWith('Taxi:'));
    expect(TripDayChips.taxi(r, r.days[1]), isNull);
    expect(TripDayChips.taxi(r, r.days[2]), isNull);
  });

  test('past or completed trips are completed; future ones are not', () {
    expect(TripSummaryRecord.fromJson(base(end: '2020-01-03')).isCompleted, isTrue);
    expect(TripSummaryRecord.fromJson(base(status: 'completed')).isCompleted, isTrue);
    expect(TripSummaryRecord.fromJson(base()).isCompleted, isFalse);
  });

  test('row key kind still parses for partial rows', () {
    final r = TripSummaryRecord.fromJson(base(arrangements: [
      {'key': 'stay:1', 'title': 'Stay', 'state': 'booked', 'partial': true},
    ]));
    expect(r.arrangements.first.key.kind, TripEasyRowKind.stay);
  });
}
