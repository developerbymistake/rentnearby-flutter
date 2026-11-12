import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pinned key parses to city and pin; m: and v: stay virtual', () {
    expect(WayKey.cityOf('a210000001:p29.218:79.542'), 210000001);
    expect(WayKey.pinOf('a210000001:p29.218:79.542'), (lat: 29.218, lng: 79.542));
    expect(WayKey.cityOf('a5'), 5);
    expect(WayKey.isPinned('a5'), isFalse);
    expect(WayKey.isVirtual('m:1'), isTrue);
    expect(WayKey.isVirtual('v:x'), isTrue);
    expect(WayKey.cityOf('m:1'), isNull);
  });

  test('single plan keeps the pinned server keys end to end', () {
    const from = WayPlace(key: 'a1:p29.218:79.542', name: 'A', lat: 29.2, lng: 79.5);
    const to = WayPlace(key: 'a2', name: 'B', lat: 29.4, lng: 79.4);
    final plan = WayPlan.single(from, to, const []);
    expect(plan.planKey, 'p1~a1:p29.218:79.542~a2');
    expect(plan.legs.single.legKey, 'l1~a1:p29.218:79.542~a2');
    expect(plan.legs.single.legKey.split('~'), ['l1', 'a1:p29.218:79.542', 'a2']);
    expect(from.isVirtual, isFalse);
    expect(from.cityKey, 1);
  });

  test('result reads citiesUnavailable and leg passStops', () {
    final r = TaxiWaysResult.fromJson({
      'citiesUnavailable': true,
      'plans': [
        {
          'planKey': 'p1~a1~a3',
          'legs': [
            {
              'legKey': 'l1~a1~a3',
              'index': 1,
              'passStops': [
                {'key': 'a2', 'name': 'Kathgodam', 'lat': 29.26, 'lng': 79.52},
                {'key': 'a9', 'name': '', 'lat': 0, 'lng': 0},
              ],
            }
          ]
        }
      ]
    });
    expect(r.citiesUnavailable, isTrue);
    expect(r.plans.single.legs.single.passStops.map((s) => s.name), ['Kathgodam']);
    expect(TaxiWaysResult.fromJson(const {}).citiesUnavailable, isFalse);
  });
}
