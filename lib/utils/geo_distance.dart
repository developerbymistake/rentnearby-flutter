import 'dart:math';

class GeoDistance {
  GeoDistance._();

  static const double earthRadiusKm = 6371.0088;

  static double km(double lat1, double lon1, double lat2, double lon2) {
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final la1 = lat1 * pi / 180, la2 = lat2 * pi / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) + cos(la1) * cos(la2) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * earthRadiusKm * asin(min(1.0, sqrt(h)));
  }
}
