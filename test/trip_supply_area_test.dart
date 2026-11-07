import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_constants.dart';
import 'package:bakhli/features/trip/utils/trip_supply_area.dart';

TripCityLeg _leg(int i, double lat, double lng) =>
    TripCityLeg(index: i, cityKey: i, cityName: 'c$i', latitude: lat, longitude: lng);

void main() {
  test('centre is the leg city and each leg has its own key', () {
    final almora = _leg(1, 29.5971, 79.6591);
    final nainital = _leg(2, 29.3919, 79.4542);
    expect(TripSupplyArea.centreOf(nainital), (lat: 29.3919, lng: 79.4542));
    expect(TripSupplyArea.keyOf('d', almora), isNot(TripSupplyArea.keyOf('d', nainital)));
    expect(TripSupplyArea.centreOf(_leg(3, 0, 0)), isNull);
    expect(TripSupplyArea.centreOf(null), isNull);
  });

  test('radius keeps Kainchi Dham in Nainital and drops Ramnagar', () {
    final c = TripSupplyArea.centreOf(_leg(1, 29.3919, 79.4542))!;
    expect(TripSupplyArea.within(c, (lat: 29.3396, lng: 79.5110)), isTrue);
    expect(TripSupplyArea.within(c, (lat: 29.3944, lng: 79.1285)), isFalse);
    expect(TripConstants.cityRadiusKm, 10);
  });
}
