import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/trip/data/trip_segment_geometry_cache.dart';
import 'package:flutter_test/flutter_test.dart';

WayLeg _leg(int i, List<LatLngPair>? geometry) => WayLeg(
      legKey: 'l$i',
      index: i,
      from: const WayPlace(key: 'a', name: 'A', lat: 0, lng: 0),
      to: const WayPlace(key: 'b', name: 'B', lat: 0, lng: 0),
      listedFare: 1000,
      geometry: geometry,
    );

void main() {
  setUp(TripSegmentGeometryCache.clear);

  test('put and get keep the points in order', () {
    TripSegmentGeometryCache.put('k1', [(lat: 29.9, lng: 78.1), (lat: 30.7, lng: 79.4)]);
    final line = TripSegmentGeometryCache.get('k1')!;
    expect(line.length, 2);
    expect(line.first.latitude, 29.9);
    expect(line.last.longitude, closeTo(79.4, 1e-9));
    expect(TripSegmentGeometryCache.get('other'), isNull);
    expect(TripSegmentGeometryCache.get(null), isNull);
  });

  test('the last plan for a key wins', () {
    TripSegmentGeometryCache.put('k1', [(lat: 1.0, lng: 1.0), (lat: 2.0, lng: 2.0)]);
    TripSegmentGeometryCache.put('k1', [(lat: 3.0, lng: 3.0), (lat: 4.0, lng: 4.0), (lat: 5.0, lng: 5.0)]);
    expect(TripSegmentGeometryCache.get('k1')!.length, 3);
    expect(TripSegmentGeometryCache.get('k1')!.first.latitude, 3);
  });

  test('a list shorter than two points is dropped', () {
    TripSegmentGeometryCache.put('k1', [(lat: 1.0, lng: 1.0)]);
    TripSegmentGeometryCache.put('k2', const []);
    expect(TripSegmentGeometryCache.get('k1'), isNull);
    expect(TripSegmentGeometryCache.get('k2'), isNull);
  });

  test('putPlan joins the legs in index order and skips a plan with a leg missing geometry', () {
    TripSegmentGeometryCache.putPlan(WayPlan(planKey: 'p1', cars: 2, total: 0, legs: [
      _leg(2, [(lat: 3.0, lng: 3.0), (lat: 4.0, lng: 4.0)]),
      _leg(1, [(lat: 1.0, lng: 1.0), (lat: 2.0, lng: 2.0)]),
    ]));
    expect(TripSegmentGeometryCache.get('p1')!.map((p) => p.latitude), [1, 2, 3, 4]);
    TripSegmentGeometryCache.putPlan(WayPlan(planKey: 'p2', cars: 2, total: 0, legs: [
      _leg(1, [(lat: 1.0, lng: 1.0), (lat: 2.0, lng: 2.0)]),
      _leg(2, null),
    ]));
    expect(TripSegmentGeometryCache.get('p2'), isNull);
  });

  test('clear empties the cache', () {
    TripSegmentGeometryCache.put('k1', [(lat: 1.0, lng: 1.0), (lat: 2.0, lng: 2.0)]);
    TripSegmentGeometryCache.clear();
    expect(TripSegmentGeometryCache.get('k1'), isNull);
  });
}
