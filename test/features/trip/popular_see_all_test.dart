import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/widgets/trip_city_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_popular_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Catalog extends TripCityCatalog {
  @override
  void warmFromDisk() {}

  @override
  Future<List<TripCityModel>> load({bool force = false}) async => popular();

  @override
  List<TripCityModel> popular({String? stateName}) => [
        for (var i = 0; i < 4; i++)
          TripCityModel(
            cityKey: i,
            name: 'Popular city $i',
            stateName: 'Uttarakhand',
            latitude: 1,
            longitude: 1,
            isPopularDestination: true,
            status: TripCityStatus.ready,
          ),
      ];
}

void main() {
  tearDown(Get.reset);

  testWidgets('See all on the Home popular rail opens the Trip Planner city pick, not the trips tab', (t) async {
    Get.put<TripCityCatalog>(_Catalog(), permanent: true);
    await t.pumpWidget(const GetMaterialApp(home: Scaffold(body: SingleChildScrollView(child: TripPopularRail()))));
    await t.pumpAndSettle();
    expect(find.byType(TripCitySheet), findsNothing);
    await t.tap(find.text('See all'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(TripCitySheet), findsOneWidget);
  });
}
