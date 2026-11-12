import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../controllers/location_controller.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/geo_distance.dart';
import '../../../widgets/location_search_sheet.dart';
import '../nearby_strings.dart';

class NearbyCentreController extends GetxController {
  static NearbyCentreController get to =>
      Get.isRegistered<NearbyCentreController>() ? Get.find<NearbyCentreController>() : Get.put(NearbyCentreController(), permanent: true);

  static const gpsMoveKm = 1.0;

  final centreVersion = 0.obs;
  final _pin = Rxn<LatLng>();
  final _pinLabel = Rxn<String>();
  final _workers = <Worker>[];
  bool _mirrored = false;
  LatLng? _lastGps;

  LocationController get _loc => Get.find<LocationController>();

  LatLng? get _activePin => _pin.value ?? _loc.searchPinOverride.value;
  bool get hasPin => _activePin != null;
  LatLng get centre => _pin.value ?? _loc.effectiveSearchCenter;
  String? get pinLabel => _pin.value != null ? _pinLabel.value : (_loc.searchPinOverride.value != null ? _loc.searchPinLabel.value : null);

  @override
  void onInit() {
    super.onInit();
    final loc = _loc;
    _lastGps = loc.userLocation.value;
    _workers.add(ever(loc.searchPinOverride, (_) => _bump()));
    _workers.add(ever(loc.locationSelectionChanged, (_) => _bump()));
    _workers.add(ever(loc.userLocation, _onGps));
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void _bump() => centreVersion.value++;

  void _onGps(LatLng? p) {
    if (p == null || hasPin) {
      if (p != null) _lastGps = p;
      return;
    }
    final last = _lastGps;
    if (last == null || GeoDistance.km(last.latitude, last.longitude, p.latitude, p.longitude) > gpsMoveKm) {
      _lastGps = p;
      _bump();
    }
  }

  Future<void> pickPlace(BuildContext context) async {
    try {
      final r = await LocationSearchSheet.show(context, bias: centre, palette: templateModulePalette);
      if (r == null) return;
      setPin(r.latLng, r.name);
    } catch (_) {
      AppToast.error(NearbyStrings.searchFailed);
    }
  }

  void setPin(LatLng pin, String label) {
    _pin.value = pin;
    _pinLabel.value = label;
    final loc = _loc;
    final d = loc.selectedDistrict.value;
    final c = loc.autoCity.value;
    if (d != null && c != null) {
      loc.beginSearchOverride(d, c, pin, label);
      _mirrored = true;
    }
    _bump();
  }

  void clearPin() {
    _pin.value = null;
    _pinLabel.value = null;
    final loc = _loc;
    if (_mirrored) {
      _mirrored = false;
      if (loc.searchPinOverride.value != null) loc.endSearchOverride();
    }
    _bump();
  }

  void useMyLocation() => clearPin();
}
