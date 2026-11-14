import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_card_bars.dart';
import 'package:flutter_test/flutter_test.dart';

TripEasyRowModel _row(TripEasyRowKind k, TripRowState s, {int? leg, int? total, int? covered}) =>
    TripEasyRowModel(key: TripEasyRowKey(k, leg), state: s, nightsTotal: total, nightsCovered: covered);

TripSummaryModel _trip(List<TripEasyRowModel> rows) => TripSummaryModel(
      id: 't',
      title: '',
      status: 'draft',
      cityName: 'Manali',
      dayCount: 3,
      spotCount: 4,
      category: 'trip',
      updatedAt: DateTime(2026, 11, 1),
      progress: TripProgress(rows: rows),
    );

void main() {
  test('no rows gives empty bars', () {
    final b = TripCardBars.of(_trip(const []));
    expect(b.stay.fraction, 0);
    expect(b.taxi.caption, 'not started');
    expect(b.travel.caption, 'not started');
  });

  test('stay uses nights when known', () {
    final b = TripCardBars.of(_trip([
      _row(TripEasyRowKind.stay, TripRowState.asked, leg: 1, total: 3, covered: 2),
    ]));
    expect(b.stay.fraction, closeTo(2 / 3, 0.001));
  });

  test('stay done shows total nights', () {
    final b = TripCardBars.of(_trip([
      _row(TripEasyRowKind.stay, TripRowState.confirmed, leg: 1, total: 3, covered: 3),
    ]));
    expect(b.stay.fraction, 1);
    expect(b.stay.caption, '3 nights');
  });

  test('skipped rows are ignored and travel groups kinds', () {
    final b = TripCardBars.of(_trip([
      _row(TripEasyRowKind.gettingThere, TripRowState.booked),
      _row(TripEasyRowKind.comingBack, TripRowState.todo),
      _row(TripEasyRowKind.between, TripRowState.skipped, leg: 2),
      _row(TripEasyRowKind.taxi, TripRowState.asked),
    ]));
    expect(b.travel.fraction, 0.5);
    expect(b.travel.caption, '1 of 2 done');
    expect(b.taxi.caption, '0 of 1 done');
    expect(b.taxi.fraction, 0);
  });

  test('full taxi reads booked', () {
    final b = TripCardBars.of(_trip([_row(TripEasyRowKind.taxi, TripRowState.own)]));
    expect(b.taxi.fraction, 1);
    expect(b.taxi.caption, 'booked');
  });
}
