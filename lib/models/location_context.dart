import 'city_model.dart';

/// Result of resolving a coordinate to the district/city that contains it,
/// via the backend's point-in-polygon lookup (`GET /listings/context`).
class LocationContext {
  final DistrictModel district;
  final CityModel? nearestCity;
  final List<CityModel> citiesInDistrict;

  const LocationContext({
    required this.district,
    this.nearestCity,
    this.citiesInDistrict = const [],
  });
}

/// Thrown when the backend confirms (404) that a point lies outside every
/// active district's boundary — a legitimate, expected business outcome,
/// distinct from a network/parse failure.
class DistrictNotFoundException implements Exception {
  const DistrictNotFoundException();
}
