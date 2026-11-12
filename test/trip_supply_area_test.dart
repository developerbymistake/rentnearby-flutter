import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_supply_area.dart';

TripCityLeg _leg(int i, double lat, double lng) =>
    TripCityLeg(index: i, cityKey: i, cityName: 'c$i', latitude: lat, longitude: lng);

void main() {
  test('centre is the leg city and each leg has its own city key', () {
    final almora = _leg(1, 29.5971, 79.6591);
    final nainital = _leg(2, 29.3919, 79.4542);
    expect(TripSupplyArea.centreOf(nainital), (lat: 29.3919, lng: 79.4542));
    expect(TripSupplyArea.keyOf(almora), isNot(TripSupplyArea.keyOf(nainital)));
    expect(TripSupplyArea.centreOf(_leg(3, 0, 0)), isNull);
    expect(TripSupplyArea.centreOf(null), isNull);
  });

  test('supply needs a city, not a district', () {
    expect(TripSupplyArea.hasCity(_leg(1, 29.5, 79.6)), isTrue);
    expect(TripSupplyArea.hasCity(null), isFalse);
    expect(TripSupplyArea.hasCity(const TripCityLeg(index: 1, cityKey: 0, cityName: '', latitude: 0, longitude: 0)), isFalse);
  });
}
