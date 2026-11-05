import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/utils/city_pick.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final nainital = CityModel(id: 'n', districtId: 'd', name: 'Nainital', latitude: 29.3878, longitude: 79.4581);
  final bhimtal = CityModel(id: 'b', districtId: 'd', name: 'Bhimtal', latitude: 29.3506, longitude: 79.5542);

  test('moving Nainital to Bhimtal in the same district switches the city', () {
    expect(CityPick.next(nainital, bhimtal, 29.3506, 79.5542)!.id, 'b');
  });

  test('jitter near the midpoint keeps the current city', () {
    expect(CityPick.next(nainital, bhimtal, 29.3690, 79.5065)!.id, 'n');
    expect(CityPick.next(nainital, bhimtal, 29.3692, 79.5075)!.id, 'n');
  });

  test('no current, same city, other district', () {
    expect(CityPick.next(null, bhimtal, 29.35, 79.55)!.id, 'b');
    expect(CityPick.next(bhimtal, bhimtal, 29.39, 79.45)!.id, 'b');
    final other = CityModel(id: 'x', districtId: 'e', name: 'X', latitude: 29.39, longitude: 79.45);
    expect(CityPick.next(bhimtal, other, 29.39, 79.45)!.id, 'x');
    expect(CityPick.next(nainital, null, 29.35, 79.55)!.id, 'n');
  });

  test('missing coordinates', () {
    final noPoint = CityModel(id: 'z', districtId: 'd', name: 'Z');
    expect(CityPick.next(nainital, noPoint, 29.35, 79.55)!.id, 'n');
    expect(CityPick.next(noPoint, bhimtal, 29.35, 79.55)!.id, 'b');
  });
}
