import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/widgets/trip_city_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TripCityModel _city(String name, String district, String state) =>
    TripCityModel(cityKey: 1, name: name, districtName: district, stateName: state, latitude: 0, longitude: 0, spotCount: 2);

void main() {
  test('district first, then state', () {
    expect(TripCityTile.placeLines(_city('Didihat', 'Pithoragarh', 'Uttarakhand')), ['Pithoragarh', 'Uttarakhand']);
  });

  test('district equal to city or state is hidden', () {
    expect(TripCityTile.placeLines(_city('Haridwar', 'Haridwar', 'Uttarakhand')), ['Uttarakhand']);
    expect(TripCityTile.placeLines(_city('Shimla', 'Himachal Pradesh', 'Himachal Pradesh')), ['Himachal Pradesh']);
  });

  test('missing parts are dropped', () {
    expect(TripCityTile.placeLines(_city('X', '', '')), isEmpty);
    expect(TripCityTile.placeLines(_city('X', 'Almora', '')), ['Almora']);
  });

  testWidgets('tile renders district line above state line', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: TripCityTile(city: _city('Dwarahat', 'Almora', 'Uttarakhand'), width: 280, onTap: () {}))),
    ));
    final text = find.byWidgetPredicate((w) => w is Text && (w.data ?? '').contains('Almora'));
    expect((t.widget(text) as Text).data, r'Almora\nUttarakhand'.replaceAll(r'\n', '\n'));
  });
}
