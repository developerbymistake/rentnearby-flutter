import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/widgets/trip_city_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

TripCityModel _city(int key) => TripCityModel(cityKey: key, name: 'C$key', latitude: 29, longitude: 79);

void main() {
  test('single pick keeps one city and no next', () {
    final p = TripCityPick(_city(1));
    expect(p.cities.map((c) => c.cityKey), [1]);
    expect(p.next, isNull);
    expect(p.draftIds, isEmpty);
  });

  test('legacy next is the second city', () {
    final p = TripCityPick(_city(1), next: _city(2));
    expect(p.cities.map((c) => c.cityKey), [1, 2]);
  });

  test('ordered multi pick keeps order', () {
    final p = TripCityPick(_city(3), cities: [_city(3), _city(1), _city(2)]);
    expect(p.cities.map((c) => c.cityKey), [3, 1, 2]);
  });

  test('draft ids come from the first leg', () {
    final p = TripCityPick(_city(1), draftLegs: [
      TripDraftLeg(_city(1), const ['a', 'b']),
      TripDraftLeg(_city(2), const ['c']),
    ]);
    expect(p.draftIds, ['a', 'b']);
  });

  test('own phone normalises or drops', () {
    expect(TripPlanController.ownPhoneOf('+91 98765 43210'), '9876543210');
    expect(TripPlanController.ownPhoneOf('09876543210'), '9876543210');
    expect(TripPlanController.ownPhoneOf('12345'), isNull);
    expect(TripPlanController.ownPhoneOf(null), isNull);
  });
}
