import 'package:bakhli/features/social/b/wizard/post_trip_controller.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../trip/support/archived_fixtures.dart';

const _catalog = [
  TripCityModel(cityKey: 7, name: 'Nainital', stateName: 'Uttarakhand', latitude: 29.4, longitude: 79.4),
  TripCityModel(cityKey: 9, name: 'Mukteshwar', stateName: 'Uttarakhand', latitude: 29.47, longitude: 79.65),
];

void main() {
  test('an archived trip gives its kept cities to the post wizard, not a blank plan leg', () {
    final trip = TripModel.fromJson(archivedTripJson());
    final cities = PostTripController.citiesOf(trip, _catalog);
    expect(cities.map((c) => c.cityKey), [7, 9]);
  });

  test('an archived trip without a summary uses its route cities; unknown names are dropped', () {
    final trip = TripModel.fromJson({...archivedTripJson(summary: null), 'legCities': ['Nainital', 'Nowhere']});
    final cities = PostTripController.citiesOf(trip, _catalog);
    expect(cities.map((c) => c.name), ['Nainital']);
  });

  test('an archived trip with a missing plan does not crash the loader', () {
    final trip = TripModel.fromJson(archivedTripJson(withPlan: false));
    expect(() => PostTripController.citiesOf(trip, const []), returnsNormally);
    expect(PostTripController.citiesOf(trip, const []), isEmpty);
  });
}
