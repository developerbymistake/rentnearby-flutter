import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_popular_routes.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({String id = 'r1', Object? fare = 899, Object? count = 9, Object? fromLat = 28.61, Object? toLng = 78.27}) => {
      'id': id,
      'fromCityKey': 101,
      'fromName': 'Delhi',
      'fromLat': fromLat,
      'fromLng': 77.21,
      'toCityKey': 245,
      'toName': 'Rishikesh',
      'toLat': 30.09,
      'toLng': toLng,
      'minFare': fare,
      'taxiCount': count,
      'extra': 'ignored',
    };

void main() {
  test('parses the contract shape', () {
    final r = TaxiPopularRoute.tryParse(_row())!;
    expect(r.fromName, 'Delhi');
    expect(r.toName, 'Rishikesh');
    expect(r.minFare, 899);
    expect(r.taxiCount, 9);
    expect(r.fromLat, 28.61);
    expect(r.toLng, 78.27);
    expect(r.from.latLng.latitude, 28.61);
    // maplibre LatLng normalises longitude with (lng + 180) % 360 - 180, which moves the last bit.
    expect(r.to.latLng.longitude, closeTo(78.27, 1e-9));
    expect(r.cities, const TaxiCityPair(101, 245));
  });

  test('missing fare keeps the route without a fare', () {
    expect(TaxiPopularRoute.tryParse(_row(fare: null))!.minFare, isNull);
    expect(TaxiPopularRoute.tryParse(_row(fare: 'x'))!.minFare, isNull);
    expect(TaxiPopularRoute.tryParse(_row(fare: 949.0))!.minFare, 949);
  });

  test('bad numbers or missing coordinates drop the row', () {
    expect(TaxiPopularRoute.tryParse(_row(fromLat: null)), isNull);
    expect(TaxiPopularRoute.tryParse(_row(fromLat: '28.6')), isNull);
    expect(TaxiPopularRoute.tryParse(_row(fromLat: 120)), isNull);
    expect(TaxiPopularRoute.tryParse(_row(toLng: double.nan)), isNull);
    expect(TaxiPopularRoute.tryParse(_row(count: 0)), isNull);
    expect(TaxiPopularRoute.tryParse(_row(count: null)), isNull);
    expect(TaxiPopularRoute.tryParse(_row(id: '')), isNull);
    expect(TaxiPopularRoute.tryParse('x'), isNull);
    expect(TaxiPopularRoute.tryParse({..._row(), 'toName': '  '}), isNull);
  });

  test('list parsing skips junk and duplicate ids and keeps order', () {
    final list = TaxiPopularRoute.listFrom([_row(id: 'a'), 'junk', null, _row(id: 'b', fromLat: null), _row(id: 'c'), _row(id: 'a')]);
    expect(list.map((e) => e.id), ['a', 'c']);
    expect(TaxiPopularRoute.listFrom(null), isEmpty);
    expect(TaxiPopularRoute.listFrom({'items': []}), isEmpty);
  });

  test('toJson round trips', () {
    final r = TaxiPopularRoute.tryParse(_row())!;
    final back = TaxiPopularRoute.tryParse(r.toJson())!;
    expect(back.toJson(), r.toJson());
  });

  test('route feed reads date and freeCount defensively', () {
    final f = TaxiRouteFeed.fromResponse({
      'data': {'date': '2026-11-27', 'freeCount': 9, 'tiers': []},
    });
    expect(f.date, '2026-11-27');
    expect(f.freeCount, 9);
    final bad = TaxiRouteFeed.fromResponse({
      'data': {'date': 'tomorrow', 'freeCount': -1},
    });
    expect(bad.date, isNull);
    expect(bad.freeCount, isNull);
    final none = TaxiRouteFeed.fromResponse({'data': null});
    expect(none.freeCount, isNull);
    expect(none.tiers, isEmpty);
  });
}
