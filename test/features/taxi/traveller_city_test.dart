import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/features/taxi/guest/traveller_city.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class _Loc extends LocationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  late _Loc loc;
  final area = CityModel(id: 'area', districtId: 'd1', name: 'Kamalwaganja', latitude: 29.24, longitude: 79.52);
  final city = CityModel(id: 'hld', districtId: 'd1', name: 'Haldwani', latitude: 29.22, longitude: 79.51);

  setUp(() {
    Get.testMode = true;
    Get.reset();
    loc = Get.put<LocationController>(_Loc()) as _Loc;
  });

  tearDown(Get.reset);

  group('travellerCity (taxi From)', () {
    test('the GPS city wins over autoCity for name and latLng', () {
      loc.autoCity.value = area;
      loc.gpsCity.value = city;
      final c = travellerCity(loc)!;
      expect(c.place.name, 'Haldwani');
      expect(c.place.latLng, const LatLng(29.22, 79.51));
      expect(c.cityId, 'hld');
      expect(c.districtId, 'd1');
    });

    test('falls back to autoCity while the GPS city is not resolved', () {
      loc.autoCity.value = area;
      final c = travellerCity(loc)!;
      expect(c.place.name, 'Kamalwaganja');
      expect(c.cityId, 'area');
    });

    test('falls back to the district at the GPS point, then null', () {
      expect(travellerCity(loc), isNull);
      loc.userLocation.value = const LatLng(29.2, 79.5);
      loc.selectedDistrict.value = DistrictModel(id: 'd1', name: 'Nainital', stateName: 'Uttarakhand');
      final c = travellerCity(loc)!;
      expect(c.place.name, 'Nainital');
      expect(c.place.latLng, const LatLng(29.2, 79.5));
      expect(c.cityId, isNull);
    });

    test('never uses the browsing city', () {
      loc.autoCity.value = area;
      loc.gpsCity.value = city;
      loc.browsingCity.value = CityModel(id: 'mnl', districtId: 'd9', name: 'Manali', latitude: 32.2, longitude: 77.1);
      expect(travellerCity(loc)!.place.name, 'Haldwani');
    });
  });

  group('Taxi tab centre city (v2)', () {
    test('shows the GPS city when not browsing', () {
      loc.autoCity.value = area;
      expect(TaxiListControllerV2().centreCity, 'Kamalwaganja');
      loc.gpsCity.value = city;
      expect(TaxiListControllerV2().centreCity, 'Haldwani');
    });

    test('the browsing city still wins', () {
      loc.autoCity.value = area;
      loc.gpsCity.value = city;
      loc.browsingCity.value = CityModel(id: 'mnl', districtId: 'd9', name: 'Manali', latitude: 32.2, longitude: 77.1);
      expect(TaxiListControllerV2().centreCity, 'Manali');
    });
  });
}
