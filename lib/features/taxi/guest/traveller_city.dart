import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../controllers/location_controller.dart';
import '../../../models/place_result_model.dart';
import '../../../services/api_service.dart';

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

typedef NearestCityPin = ({bool available, int? cityKey, String? name});

// The single nearest city of a pin, from the server; null when the call fails so callers can fall back.
Future<NearestCityPin?> nearestCityOf(double lat, double lng) async {
  try {
    final res = await ApiService.get('/trips/cities/nearest', params: {'lat': lat, 'lng': lng});
    final d = res['data'];
    if (d is! Map<String, dynamic>) return null;
    final key = (d['cityKey'] as num?)?.toInt();
    return (available: d['available'] == true && key != null, cityKey: key, name: d['name'] as String?);
  } catch (_) {
    return null;
  }
}
