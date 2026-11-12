import '../models/trip_plan_model.dart';
import 'trip_geo.dart';

// Stays and taxis of a leg are the ones of its single Atlas city, so the key is the city key.
class TripSupplyArea {
  TripSupplyArea._();

  static TripPoint? centreOf(TripCityLeg? leg) {
    if (leg == null || !leg.hasPoint) return null;
    final c = (lat: leg.latitude, lng: leg.longitude);
    return TripGeo.valid(c) ? c : null;
  }

  static String keyOf(TripCityLeg? leg) => 'c${leg?.cityKey ?? 0}';

  static bool hasCity(TripCityLeg? leg) => leg != null && leg.cityKey > 0;
}
