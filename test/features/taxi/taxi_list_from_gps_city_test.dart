import 'dart:convert';
import 'dart:typed_data';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/taxi/guest/taxi_browse_repository.dart';
import 'package:bakhli/features/taxi/guest/taxi_list_controller.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:bakhli/widgets/location_switch_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../e2e_journeys/nearby/nearby_support.dart';

class _Loc extends JLoc {
  int asks = 0;

  @override
  Future<CityModel?> ensureGpsCity() {
    asks++;
    return Future.value(null);
  }
}

// GET /trips/cities/nearest: an available city, so an empty To browses the local list.
class _NearestAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      Future.value(ResponseBody.fromString(
          jsonEncode({
            'data': {'cityKey': 7, 'available': true, 'name': 'Haldwani'},
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          }));

  @override
  void close({bool force = false}) {}
}

class _Browse extends TaxiBrowseRepository {
  int local = 0;
  ({double lat, double lng})? lastCentre;

  @override
  Future<TaxiBrowsePage> browseLocal({
    required DateTime date,
    String? districtId,
    int? cityKey,
    String? cityId,
    String? category,
    bool cityOnly = false,
    bool localRate = false,
    int page = 1,
    int pageSize = 20,
    ({double lat, double lng})? centre,
  }) {
    local++;
    lastCentre = centre;
    return Future.value((items: const <TaxiBrowseItem>[], hasMore: false));
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Loc loc;
  late _Browse browse;
  final area = CityModel(id: 'area', districtId: 'd1', name: 'Kamalwaganja', latitude: 29.24, longitude: 79.52);
  final city = CityModel(id: 'hld', districtId: 'd1', name: 'Haldwani', latitude: 29.22, longitude: 79.51);

  setUp(() {
    Get.testMode = true;
    Get.reset();
    ApiService.init();
    ApiService.dio.httpClientAdapter = _NearestAdapter();
    loc = Get.put<LocationController>(_Loc()) as _Loc;
    Get.put<AuthController>(JAuth());
    Get.put<TabConfigController>(JTabs());
    browse = _Browse();
    loc.userLocation.value = const LatLng(29.24, 79.52);
    loc.autoCity.value = area;
  });

  tearDown(Get.reset);

  test('From moves from the area to the GPS city when it resolves late', () async {
    final c = Get.put(TaxiListController(browseRepo: browse), tag: TaxiListController.pushTag);
    await _settle();
    expect(loc.asks, 1);
    expect(c.from.value?.name, 'Kamalwaganja');
    expect(c.fromIsCurrent.value, isTrue);
    final before = browse.local;
    expect(before, greaterThan(0));
    expect(browse.lastCentre!.lat, closeTo(29.24, 1e-9));
    expect(browse.lastCentre!.lng, closeTo(79.52, 1e-9));

    loc.gpsCity.value = city;
    await _settle();
    expect(c.from.value?.name, 'Haldwani');
    expect(c.from.value?.latLng, const LatLng(29.22, 79.51));
    expect(c.fromIsCurrent.value, isTrue);
    expect(browse.local, greaterThan(before));
    expect(browse.lastCentre!.lat, closeTo(29.22, 1e-9));
    expect(browse.lastCentre!.lng, closeTo(79.51, 1e-9));
  });

  test('a From the user picked is kept when the GPS city resolves', () async {
    final c = Get.put(TaxiListController(browseRepo: browse), tag: TaxiListController.pushTag);
    await _settle();
    c.setFromCity(const PickedPlace(name: 'Almora', latitude: 29.6, longitude: 79.66, cityId: 'alm', districtId: 'd2', districtName: 'Almora'));
    await _settle();

    loc.gpsCity.value = city;
    await _settle();
    expect(c.from.value?.name, 'Almora');
    expect(c.fromIsCurrent.value, isFalse);
  });
}
