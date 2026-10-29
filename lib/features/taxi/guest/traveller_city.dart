import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../controllers/location_controller.dart';
import '../../../models/place_result_model.dart';

typedef TaxiFromPlace = ({PlaceResult place, String districtId, String? cityId});

// GPS city only, never the browsing city.
TaxiFromPlace? travellerCity(LocationController loc) {
  final auto = loc.autoCity.value;
  if (auto != null && auto.latitude != null && auto.longitude != null) {
    return (
      place: PlaceResult(name: auto.name, subtitle: '', latLng: LatLng(auto.latitude!, auto.longitude!)),
      districtId: auto.districtId,
      cityId: auto.id,
    );
  }
  final gps = loc.userLocation.value;
  final district = loc.selectedDistrict.value;
  if (gps != null && district != null) {
    return (place: PlaceResult(name: district.name, subtitle: '', latLng: gps), districtId: district.id, cityId: null);
  }
  return null;
}
