import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/stay/guest/v2/stay_feed_item.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_controller_v2.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_screen_v2.dart';
import 'package:bakhli/features/stay/stay_types_controller.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_screen_v2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../support/real_phone.dart';
import '../ui_golden/golden_support.dart';

StayFeedItem _stay(String id, String name, String city, double km, int price, {bool featured = false, String label = 'near'}) =>
    StayFeedItem.fromJson({
      'id': id,
      'userId': 'u',
      'name': name,
      'cityName': city,
      'districtName': 'Nainital',
      'stateName': 'Uttarakhand',
      'minPricePerNight': price,
      'isFeatured': featured,
      'distanceKm': km,
      'labelKey': label,
    });

class _Types extends StayTypesController {
  @override
  void ensureLoaded() {}
}

class _Stays extends StayLandingControllerV2 {
  @override
  int? get tabIndex => null;
  @override
  RxInt? get tabRx => null;
  @override
  Future<NearbyPage<StayFeedItem>> fetchPage(String? token) async => NearbyPage(items: [
        _stay('a', 'Deodar Cottage', 'Nainital', 1.4, 1500, featured: true, label: 'inCity'),
        _stay('b', 'Himalayan View Homestay', 'Bhimtal', 9, 1800),
        _stay('c', 'Pine Ridge Stay', 'Mukteshwar', 24, 2400),
      ]);
}

Map<String, dynamic> _taxi(String id, String name, String vehicle, int seats, {int? rate, bool featured = false}) => {
      'id': id,
      'driverName': name,
      'vehicleTypeName': vehicle,
      'plateDisplay': 'UK04',
      'routeCount': 2,
      'createdAt': '2026-11-01T00:00:00Z',
      'cityName': 'Haldwani',
      'stateName': 'Uttarakhand',
      'distanceKm': 5.0,
      'labelKey': 'near',
      'minFare': 900,
      'seats': seats,
      'isFeatured': featured,
      'localDayRate': rate,
      'localDayKm': rate == null ? null : 80,
    };

class _Repo extends TaxiFeedRepository {
  @override
  Future<NearbyPage<TaxiFeedItem>> local({required double lat, required double lng, String? pageToken, int pageSize = 20, String? category}) async =>
      NearbyPage(items: [
        TaxiFeedItem.fromJson(_taxi('a', 'Pradeep Kumar', 'Dzire', 4, rate: 12, featured: true)),
        TaxiFeedItem.fromJson(_taxi('b', 'Rakesh Singh', 'Innova', 7, rate: 16)),
        TaxiFeedItem.fromJson(_taxi('c', 'Sunil Negi', 'Traveller', 12, rate: 22)),
      ]);
}

void _base() {
  Get.reset();
  (Get.put<LocationController>(JLoc()) as JLoc).userLocation.value = const LatLng(29.2, 79.5);
  Get.put<AuthController>(JAuth());
  Get.put<TabConfigController>(JTabs());
  Get.put(NearbyCentreController());
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  setUp(() => shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Listing\shots');
  tearDown(Get.reset);

  for (final h in [800.0, 1500.0]) {
    testWidgets('stay tab $h', (t) async {
      _base();
      Get.put<StayTypesController>(_Types());
      final c = Get.put<StayLandingControllerV2>(_Stays(), tag: StayLandingControllerV2.tag) as _Stays;
      c.reload();
      await pumpPhone(t, const StayLandingScreenV2(), size: Size(360, h));
      await settlePhone(t);
      await t.pump(const Duration(seconds: 1));
      await shot(t, 'tab_stay_${h.toInt()}');
    });

    testWidgets('taxi tab $h', (t) async {
      _base();
      Get.find<AuthController>().tabIndex.value = 3;
      Get.put(TaxiListControllerV2(root: true, repo: _Repo()), tag: TaxiListControllerV2.tag);
      await pumpPhone(t, const TaxiListScreenV2(root: true), size: Size(360, h));
      for (var i = 0; i < 6; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
        await t.pump(const Duration(milliseconds: 400));
      }
      await settlePhone(t);
      await shot(t, 'tab_taxi_${h.toInt()}');
    });
  }
}
