import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TripCityModel city(int key, String name, {String district = '', String state = ''}) => TripCityModel(
        cityKey: key,
        name: name,
        districtName: district,
        stateName: state,
        latitude: 30,
        longitude: 78,
      );

  final all = [
    city(1, 'Nainital', district: 'Nainital', state: 'Uttarakhand'),
    city(2, 'Rishikesh', district: 'Dehradun', state: 'Uttarakhand'),
    city(3, 'Manali', district: 'Kullu', state: 'Himachal Pradesh'),
    city(4, 'Bhimtal', district: 'Nainital', state: 'Uttarakhand'),
  ];

  test('prefix matches come before contains matches', () {
    final r = TripCitySearch.filter(all, 'na');
    expect(r.map((c) => c.cityKey), [1, 3, 4]);
  });

  test('place line matches by state', () {
    final r = TripCitySearch.filter(all, 'uttara');
    expect(r.map((c) => c.name), contains('Rishikesh'));
    expect(r.map((c) => c.name), isNot(contains('Manali')));
  });

  test('search is case-insensitive', () {
    expect(TripCitySearch.filter(all, 'RISHI').single.cityKey, 2);
  });

  test('blank query returns all in order', () {
    expect(TripCitySearch.filter(all, '  ').map((c) => c.cityKey), [1, 2, 3, 4]);
  });

  test('dedupe keeps the first by city key', () {
    final r = TripCitySearch.dedupe([city(1, 'A'), city(2, 'B'), city(1, 'C')]);
    expect(r.map((c) => c.name), ['A', 'B']);
  });

  test('accents are ignored on both sides', () {
    final list = [city(1, 'Dwārāhāt'), city(2, 'Hēm Kund'), city(3, 'Almora')];
    expect(TripCitySearch.filter(list, 'dwar').single.cityKey, 1);
    expect(TripCitySearch.filter(list, 'hēm').single.cityKey, 2);
    expect(TripCitySearch.filter(list, 'KUND').single.cityKey, 2);
  });

  test('popularFirst is stable', () {
    TripCityModel p(int key, bool pop) => TripCityModel(
          cityKey: key,
          name: 'C$key',
          latitude: 0,
          longitude: 0,
          isPopularDestination: pop,
        );
    final r = TripCitySearch.popularFirst([p(1, false), p(2, true), p(3, false), p(4, true)]);
    expect(r.map((c) => c.cityKey), [2, 4, 1, 3]);
  });

  test('popular flag round trips and defaults to false', () {
    final c = TripCityModel(cityKey: 1, name: 'A', latitude: 0, longitude: 0, isPopularDestination: true);
    expect(TripCityModel.fromJson(c.toJson()).isPopularDestination, isTrue);
    expect(
      TripCityModel.fromJson({'cityKey': 1, 'name': 'A', 'latitude': 0, 'longitude': 0}).isPopularDestination,
      isFalse,
    );
  });

  test('json round trip', () {
    final c = city(502141, 'Rishikesh', district: 'Dehradun', state: 'Uttarakhand');
    final back = TripCityModel.fromJson(c.toJson());
    expect(back.cityKey, 502141);
    expect(back.placeLine, 'Dehradun · Uttarakhand');
    expect(back.isReady, isTrue);
  });
}
