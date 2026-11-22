import 'package:bakhli/features/map_discovery/pack/map_pack_index.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_models.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_parser.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_synthetic.dart';
import 'package:flutter_test/flutter_test.dart';

MapPackSpot _s(String id, {int rank = 1, String name = 'N', int? city, double lat = 30, double lon = 78}) =>
    MapPackSpot(id: id, lat: lat, lon: lon, category: 'temple', rank: rank, name: name, cityKey: city);

void main() {
  test('empty index', () {
    final i = MapPackIndex.of(const []);
    expect(i.isEmpty, isTrue);
    expect(i.length, 0);
    expect(i.byId('x'), isNull);
    expect(i.byCity(1), isEmpty);
    expect(i.forCities([1, 2]), isEmpty);
    expect(i.near(30, 78, 10), isEmpty);
    expect(MapPackIndex.empty.isEmpty, isTrue);
  });

  test('ranked by rank then name then id; duplicates across packs keep the first', () {
    final a = MapPack(version: '1', stateId: 'A', spots: [
      _s('c', rank: 2, name: 'B', city: 1),
      _s('b', rank: 2, name: 'A', city: 2),
      _s('x', rank: 1, name: 'Z', city: 1),
    ]);
    final b = MapPack(version: '1', stateId: 'B', spots: [
      _s('x', rank: 9, name: 'Other', city: 7),
      _s('a', rank: 2, name: 'A', city: 1),
      _s('n', rank: 3, name: 'No city'),
    ]);
    final i = MapPackIndex.of([a, b]);
    expect(i.ranked.map((s) => s.id), ['x', 'a', 'b', 'c', 'n']);
    expect(i.byId('x')!.name, 'Z');
    expect(i.byCity(1).map((s) => s.id), ['x', 'a', 'c']);
    expect(i.byCity(7), isEmpty);
    expect(i.forCities([2, 1]).map((s) => s.id), ['x', 'a', 'b', 'c']);
    expect(i.stateIds, ['A', 'B']);
  });

  test('near uses km distance', () {
    final i = MapPackIndex.of([
      MapPack(version: '1', stateId: 'A', spots: [
        _s('here', lat: 30, lon: 78),
        _s('5km', lat: 30.045, lon: 78),
        _s('far', lat: 31, lon: 78),
      ]),
    ]);
    expect(i.near(30, 78, 6).map((s) => s.id), ['5km', 'here']..sort());
    expect(i.near(30, 78, 0), isEmpty);
    expect(i.near(double.nan, 78, 5), isEmpty);
    expect(MapPackGeo.km(30, 78, 31, 78), closeTo(111.2, 0.3));
  });

  test('1,500 synthetic rows build the index with exact counts', () {
    final p = MapPackParser.parse(MapPackSynthetic.body(rows: 1500, cities: 10))!;
    final sw = Stopwatch()..start();
    final i = MapPackIndex.of([p]);
    sw.stop();
    // ignore: avoid_print
    print('index 1500 rows: ${sw.elapsedMilliseconds} ms');
    expect(i.length, 1500);
    var total = 0;
    for (var c = 1; c <= 10; c++) {
      final list = i.byCity(c);
      total += list.length;
      for (var k = 1; k < list.length; k++) {
        expect(list[k - 1].rank <= list[k].rank, isTrue);
      }
    }
    expect(total, 1500);
  });
}
