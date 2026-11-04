import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> driver(String id, int fare, {bool partial = false}) => {
      'taxiId': id,
      'driverName': 'Driver $id',
      'vehicleTypeName': 'Innova',
      'vehicleCategory': 'SUV',
      'seats': 7,
      'plateDisplay': 'UK07 AB 1234',
      'cityName': 'Haridwar',
      'basedHere': false,
      'tripReplyLabel': 'app',
      'priorityRank': 0,
      'isFeatured': false,
      'routeId': 'r$id',
      'fromName': 'Delhi',
      'toName': 'Badrinath',
      'listedFare': fare,
      'tripType': 'OneWay',
      'partial': partial,
      'reversed': false,
      'distanceKm': 520.4,
      'minutes': 700,
      'hasRoadLine': true,
    };

Map<String, dynamic> place(String key, String name) => {'key': key, 'name': name, 'lat': 29.9, 'lng': 78.1};

Map<String, dynamic> leg(int i, int fare, String id) => {
      'legKey': 'l1~a$i~a${i + 1}',
      'index': i,
      'from': place('a$i', 'P$i'),
      'to': place('a${i + 1}', 'P${i + 1}'),
      'meetingPlace': null,
      'listedFare': fare,
      'partial': false,
      'distanceKm': 200,
      'passes': ['Rishikesh', 'Srinagar'],
      'topDrivers': [driver(id, fare)],
      'driverCount': 8,
      'hasRoadLine': false,
    };

Map<String, dynamic> plan(String key, int cars, int total) => {
      'planKey': key,
      'cars': cars,
      'total': total,
      'legs': [for (var i = 1; i <= cars; i++) leg(i, total ~/ cars, 'd$i')],
    };

Map<String, dynamic> result() => {
      'version': '1731',
      'from': {...place('a1', 'Delhi'), 'resolved': true},
      'to': {...place('a9', 'Badrinath'), 'resolved': true, 'districtId': null},
      'bestWay': {'kind': 'driver', 'id': 'x1', 'reason': '1 car, all the way'},
      'allTheWay': [driver('x1', 20000), driver('x2', 15000)],
      'allTheWayHasMore': false,
      'plans': [plan('p1~a1~a2~a9', 2, 14000), plan('p1~a1~a3~a9', 2, 12000), plan('p1~a1~a4~a5~a9', 3, 9000)],
      'truncated': false,
      'localTaxis': [],
      'stays': [],
      'reachFirstPlace': null,
      'roadLines': true,
    };

void main() {
  test('result parses every section', () {
    final r = TaxiWaysResult.fromJson(result());
    expect(r.version, '1731');
    expect(r.from.name, 'Delhi');
    expect(r.to.resolved, isTrue);
    expect(r.bestWay?.kind, 'driver');
    expect(r.allTheWay.length, 2);
    expect(r.plans.length, 3);
    expect(r.reachFirstPlace, isNull);
    expect(r.roadLines, isTrue);
  });

  test('driver and leg fields', () {
    final d = WayDriver.fromJson(driver('a', 4200));
    expect(d.listedFare, 4200);
    expect(d.seats, 7);
    expect(d.phone, isNull);
    final l = WayLeg.fromJson(leg(1, 4200, 'a'));
    expect(l.passes, ['Rishikesh', 'Srinagar']);
    expect(l.topDrivers.single.taxiId, 'a');
    expect(l.driverCount, 8);
  });

  test('missing optional fields do not throw', () {
    final j = result()
      ..remove('bestWay')
      ..remove('reachFirstPlace');
    expect(TaxiWaysResult.fromJson(j).bestWay, isNull);
  });

  test('totalWith sums chosen fares', () {
    final p = WayPlan.fromJson(plan('p1~a1~a2~a9', 2, 14000));
    final chosen = {1: WayDriver.fromJson(driver('a', 5000)), 2: WayDriver.fromJson(driver('b', 8000))};
    expect(p.totalWith(chosen), 13000);
  });

  test('fewest cars: drivers first, then plans by cars then total', () {
    final rows = sortedRows(TaxiWaysResult.fromJson(result()), WaysSort.fewestCars);
    expect(rows.length, 5);
    expect(rows[0], isA<WayDriver>());
    expect(rows[1], isA<WayDriver>());
    expect((rows[2] as WayPlan).total, 12000);
    expect((rows[3] as WayPlan).total, 14000);
    expect((rows[4] as WayPlan).cars, 3);
  });

  test('lowest price: everything by price', () {
    final rows = sortedRows(TaxiWaysResult.fromJson(result()), WaysSort.lowestPrice);
    int price(Object o) => o is WayDriver ? o.listedFare : (o as WayPlan).total;
    final prices = rows.map(price).toList();
    expect(prices, [...prices]..sort());
    expect(prices.first, 9000);
  });
}
