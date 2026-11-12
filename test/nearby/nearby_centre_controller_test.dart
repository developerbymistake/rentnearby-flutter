import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
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
  late NearbyCentreController c;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    loc = Get.put<LocationController>(_Loc()) as _Loc;
    loc.userLocation.value = const LatLng(29.2, 79.5);
    c = Get.put(NearbyCentreController());
  });

  tearDown(Get.reset);

  test('gps is the centre by default', () {
    expect(c.hasPin, false);
    expect(c.centre.latitude, 29.2);
    expect(c.pinLabel, isNull);
  });

  test('pin wins, any place, no district needed', () {
    final v = c.centreVersion.value;
    c.setPin(const LatLng(28.6, 77.2), 'Delhi');
    expect(c.hasPin, true);
    expect(c.centre.latitude, 28.6);
    expect(c.pinLabel, 'Delhi');
    expect(c.centreVersion.value, greaterThan(v));
    expect(loc.searchPinOverride.value, isNull);
  });

  test('clear restores gps', () {
    c.setPin(const LatLng(28.6, 77.2), 'Delhi');
    final v = c.centreVersion.value;
    c.clearPin();
    expect(c.hasPin, false);
    expect(c.centre.latitude, 29.2);
    expect(c.centreVersion.value, greaterThan(v));
  });

  test('mirror to the map pin only when district and city exist, and clear ends it', () {
    loc.selectedDistrict.value = DistrictModel(id: 'd', name: 'Nainital');
    loc.autoCity.value = CityModel(id: 'c', districtId: 'd', name: 'Haldwani', latitude: 29.2, longitude: 79.5);
    c.setPin(const LatLng(28.6, 77.2), 'Delhi');
    expect(loc.searchPinOverride.value?.latitude, 28.6);
    c.clearPin();
    expect(loc.searchPinOverride.value, isNull);
  });

  test('map pin set elsewhere becomes the centre', () {
    loc.searchPinOverride.value = const LatLng(30.0, 78.0);
    loc.searchPinLabel.value = 'Dehradun';
    expect(c.hasPin, true);
    expect(c.centre.latitude, 30.0);
    expect(c.pinLabel, 'Dehradun');
  });

  test('gps move over 1 km bumps, small jitter does not, and a pin ignores gps', () {
    var v = c.centreVersion.value;
    loc.userLocation.value = const LatLng(29.2005, 79.5);
    expect(c.centreVersion.value, v);
    loc.userLocation.value = const LatLng(29.22, 79.5);
    expect(c.centreVersion.value, greaterThan(v));
    c.setPin(const LatLng(28.6, 77.2), 'Delhi');
    v = c.centreVersion.value;
    loc.userLocation.value = const LatLng(30.5, 79.5);
    expect(c.centreVersion.value, v);
    expect(c.centre.latitude, 28.6);
  });

  test('selection change bumps version', () {
    final v = c.centreVersion.value;
    loc.locationSelectionChanged.value++;
    expect(c.centreVersion.value, greaterThan(v));
  });
}
