import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay/guest/stay_nearby_list_sheet.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StayNearbyModel _stay({String? thumb}) => StayNearbyModel(
      id: 's1',
      name: 'Lake View Homestay',
      stayTypeName: 'Homestay',
      latitude: 29.4,
      longitude: 79.4,
      minPricePerNight: 2400,
      thumbnailUrl: thumb,
      distanceKm: 3.4,
      isActive: true,
      cityName: 'Bhimtal',
    );

Widget _host(StayNearbyModel s, VoidCallback onOpen) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: StayNearbyRow(stay: s, index: 0, onOpen: onOpen))),
    );

void main() {
  testWidgets('row without photo shows stay art and opens on tap', (t) async {
    var opened = 0;
    await t.pumpWidget(_host(_stay(), () => opened++));
    expect(find.text('Lake View Homestay'), findsOneWidget);
    expect(find.text('3.4 km away'), findsOneWidget);
    expect(find.byType(KitPhoto), findsNothing);
    await t.tap(find.text('Lake View Homestay'));
    expect(opened, 1);
  });
}
