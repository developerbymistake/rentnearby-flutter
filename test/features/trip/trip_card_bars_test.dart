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
  test('no rows gives open bars and a saved plan', () {
    final b = TripCardBars.of(_trip(const []));
    expect(b.stay.fraction, 0);
    expect(b.stay.caption, 'not added');
    expect(b.taxi.caption, 'not added');
    expect(b.plan.fraction, 1);
    expect(b.plan.caption, 'saved');
  });

  test('stay asked for part of the nights is arranged and names the nights', () {
    final b = TripCardBars.of(_trip([
      _row(TripEasyRowKind.stay, TripRowState.asked, leg: 1, total: 3, covered: 2),
    ]));
    expect(b.stay.fraction, 1);
    expect(b.stay.caption, '2 of 3 nights');
  });

  test('stay done shows total nights', () {
    final b = TripCardBars.of(_trip([
      _row(TripEasyRowKind.stay, TripRowState.confirmed, leg: 1, total: 3, covered: 3),
    ]));
    expect(b.stay.fraction, 1);
    expect(b.stay.caption, '3 nights');
  });

  test('old travel rows are ignored, skipped parts read skipped', () {
    final b = TripCardBars.of(_trip([
      _row(TripEasyRowKind.gettingThere, TripRowState.booked),
      _row(TripEasyRowKind.between, TripRowState.skipped, leg: 2),
      _row(TripEasyRowKind.stay, TripRowState.skipped, leg: 1),
      _row(TripEasyRowKind.taxi, TripRowState.asked),
    ]));
    expect(b.stay.caption, 'skipped');
    expect(b.stay.fraction, 1);
    expect(b.taxi.caption, 'requested');
    expect(b.taxi.fraction, 1);
  });

  test('full taxi reads booked', () {
    final b = TripCardBars.of(_trip([_row(TripEasyRowKind.taxi, TripRowState.own)]));
    expect(b.taxi.fraction, 1);
    expect(b.taxi.caption, 'booked');
  });
}
