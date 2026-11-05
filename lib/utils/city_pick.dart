import 'dart:math';

import '../models/city_model.dart';
import 'geo_distance.dart';

class CityPick {
  CityPick._();

  static const double minGainKm = 0.3;
  static const double minGainRatio = 0.2;

  // GPS city for a fresh fix: switch to the server's nearest city only when it is clearly closer.
  static CityModel? next(CityModel? current, CityModel? nearest, double lat, double lng) {
    if (nearest == null) return current;
    if (current == null || current.id == nearest.id) return nearest;
    if (current.districtId != nearest.districtId) return nearest;
    final dCur = _km(current, lat, lng);
    final dNew = _km(nearest, lat, lng);
    if (dCur == null) return nearest;
    if (dNew == null) return current;
    return dCur - dNew >= max(minGainKm, dCur * minGainRatio) ? nearest : current;
  }

  static double? _km(CityModel c, double lat, double lng) {
    final la = c.latitude, lo = c.longitude;
    if (la == null || lo == null || !lat.isFinite || !lng.isFinite) return null;
    return GeoDistance.km(lat, lng, la, lo);
  }
}
