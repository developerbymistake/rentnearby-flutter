import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/triplimit/trip_limit_api.dart';
import 'package:bakhli/features/buddy/triplimit/trip_limit_gate.dart';
import 'package:bakhli/features/buddy/triplimit/trip_limit_models.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
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

class _FreeSlots extends TripLimitApi {
  const _FreeSlots();

  @override
  Future<BuddyResult<TripSlots>> slots() async => const BuddyOk(TripSlots(limit: 1, count: 0, trips: []));
}

void main() {
  tearDown(() {
    TripLimitGate.debugReset();
    Get.reset();
  });

  testWidgets('See all on the Home popular rail opens Where to next', (t) async {
    TripLimitGate.api = const _FreeSlots();
    Get.put<TripCityCatalog>(_Catalog(), permanent: true);
    await t.pumpWidget(GetMaterialApp(
      home: const Scaffold(body: SingleChildScrollView(child: TripPopularRail())),
      getPages: [GetPage(name: AppRoutes.tripWhere, page: () => const Scaffold(body: Text('where-page')))],
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('See all'));
    await t.pumpAndSettle();
    expect(find.text('where-page'), findsOneWidget);
  });
}
