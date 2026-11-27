import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/widgets/trip_city_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

TripCityModel _city(int key) => TripCityModel(cityKey: key, name: 'C$key', latitude: 29, longitude: 79);

void main() {
  test('a pick carries its city', () {
    expect(TripCityPick(_city(1)).city.cityKey, 1);
  });

  test('a draft knows its places and keeps the first city', () {
    final d = TripNewDraft([
      TripDraftLeg(_city(2), const ['a', 'b']),
      TripDraftLeg(_city(1), const ['c']),
    ], 3);
    expect(d.placeCount, 3);
    expect(d.city.cityKey, 2);
    expect(d.days, 3);
    expect(const TripNewDraft([]).days, isNull);
  });
}
