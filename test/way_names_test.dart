import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:flutter_test/flutter_test.dart';

WayLeg _leg(int i, WayPlace from, WayPlace to) => WayLeg(legKey: 'l1~${from.key}~${to.key}', index: i, from: from, to: to, listedFare: 100);

void main() {
  test('wayNameOr falls back by key and end', () {
    expect(wayNameOr(' ', 'm:1:2', start: true, end: false), 'My location');
    expect(wayNameOr('', 'v:1:2', start: true, end: false), 'Pickup point');
    expect(wayNameOr(null, 'v:1:2', start: false, end: true), 'Drop point');
    expect(wayNameOr('', 'a1', start: false, end: false), 'Stop');
    expect(wayNameOr(' Home ', 'v:1:2', start: true, end: false), 'Home');
  });

  test('withEndNames keeps typed names on pinned ends and never leaves blanks', () {
    const from = WayPlace(key: 'v:1:2', name: '', lat: 1, lng: 2);
    const to = WayPlace(key: 'a5', name: '', lat: 3, lng: 4);
    final plan = WayPlan(planKey: 'p1~v:1:2~a5', cars: 1, total: 100, legs: [_leg(1, from, to)]);
    final named = plan.withEndNames(const WayPlace(key: 'v:1:2', name: 'Kamalwaganja', lat: 1, lng: 2), to);
    expect(named.from.name, 'Kamalwaganja');
    expect(named.to.name, 'Drop point');
  });
}
