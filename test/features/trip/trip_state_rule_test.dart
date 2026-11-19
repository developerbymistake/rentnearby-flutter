import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/utils/trip_state_rule.dart';
import 'package:flutter_test/flutter_test.dart';

TripCityModel _c(int k, String state) => TripCityModel(cityKey: k, name: 'C$k', stateName: state, latitude: 1, longitude: 1);

void main() {
  final catalog = [
    _c(1, 'Uttarakhand'),
    _c(2, 'Uttarakhand'),
    _c(3, 'Himachal Pradesh'),
    _c(4, ' uttarakhand '),
    _c(5, ''),
  ];

  group('statesOf', () {
    test('one state', () => expect(TripStateRule.statesOf([1, 2], catalog), ['Uttarakhand']));
    test('two states in leg order', () => expect(TripStateRule.statesOf([3, 1], catalog), ['Himachal Pradesh', 'Uttarakhand']));
    test('case and spaces collapse, first spelling kept', () => expect(TripStateRule.statesOf([1, 4], catalog), ['Uttarakhand']));
    test('key missing in the catalog is skipped', () => expect(TripStateRule.statesOf([99, 3], catalog), ['Himachal Pradesh']));
    test('nothing known is empty', () {
      expect(TripStateRule.statesOf([99, 5], catalog), isEmpty);
      expect(TripStateRule.statesOf([1], const []), isEmpty);
    });
  });

  group('allows and filter', () {
    test('empty states allow every city', () {
      expect(TripStateRule.allows(const [], _c(3, 'Himachal Pradesh')), isTrue);
      expect(TripStateRule.filter(catalog, const []), catalog);
    });
    test('another state is dropped, case ignored', () {
      expect(TripStateRule.allows(const ['Uttarakhand'], _c(3, 'Himachal Pradesh')), isFalse);
      expect(TripStateRule.allows(const ['Uttarakhand'], _c(4, ' uttarakhand ')), isTrue);
    });
    test('empty stateName is dropped when states are known', () {
      expect(TripStateRule.allows(const ['Uttarakhand'], _c(5, '')), isFalse);
    });
    test('order is kept', () {
      expect(TripStateRule.filter(catalog, const ['Uttarakhand']).map((c) => c.cityKey), [1, 2, 4]);
      expect(TripStateRule.filter(catalog, const ['Himachal Pradesh', 'Uttarakhand']).map((c) => c.cityKey), [1, 2, 3, 4]);
    });
  });
}
