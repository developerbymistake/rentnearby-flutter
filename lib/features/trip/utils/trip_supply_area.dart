import '../models/trip_plan_model.dart';
import '../trip_constants.dart';
import 'trip_geo.dart';

// Where stays and taxis are looked up for a leg: the city's own centre and one fixed radius.
class TripSupplyArea {
  TripSupplyArea._();

  static TripPoint? centreOf(TripCityLeg? leg) {
    if (leg == null || !leg.hasPoint) return null;
    final c = (lat: leg.latitude, lng: leg.longitude);
    return TripGeo.valid(c) ? c : null;
  }

  static String keyOf(String districtId, TripCityLeg? leg) {
    final c = centreOf(leg);
    return c == null ? districtId : '$districtId#${c.lat.toStringAsFixed(5)},${c.lng.toStringAsFixed(5)}';
  }

  static bool within(TripPoint centre, TripPoint at) => TripGeo.km(centre, at) <= TripConstants.cityRadiusKm;
}
