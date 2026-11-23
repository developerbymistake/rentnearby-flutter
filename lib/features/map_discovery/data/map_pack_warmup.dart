import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../utils/search_fold.dart';
import '../../trip/data/trip_city_catalog.dart';
import '../../trip/models/trip_model.dart';
import 'map_pack_service.dart';

typedef MapPackWarm = Future<void> Function({double? lat, double? lon, Iterable<int> cityKeys});
typedef MapPackCityKeysOf = Iterable<int> Function(Iterable<String> cityNames);

// Downloads the user's state pack and the packs of his trip cities after login, so a map opens with spots.
class MapPackWarmup {
  final MapPackWarm _warm;
  final MapPackCityKeysOf _keysOf;
  final _workers = <Worker>[];
  bool _pointDone = false;
  Set<int> _keysDone = const {};

  MapPackWarmup({MapPackWarm? warm, MapPackCityKeysOf? keysOf})
      : _warm = warm ?? MapPackService.to.warm,
        _keysOf = keysOf ?? _catalogKeys;

  static Iterable<int> _catalogKeys(Iterable<String> cityNames) {
    final names = {for (final n in cityNames) SearchFold.fold(n)}..remove('');
    if (names.isEmpty) return const [];
    final catalog = TripCityCatalog.to..warmFromDisk();
    return [for (final c in catalog.search('')) if (names.contains(SearchFold.fold(c.name))) c.cityKey];
  }

  void start({required Rxn<LatLng> userLocation, required RxList<TripSummaryModel> trips}) {
    _onPoint(userLocation.value);
    _onTrips(trips);
    if (!_pointDone) _workers.add(ever<LatLng?>(userLocation, _onPoint));
    _workers.add(ever<List<TripSummaryModel>>(trips, _onTrips));
  }

  void _onPoint(LatLng? p) {
    if (_pointDone || p == null) return;
    _pointDone = true;
    _warm(lat: p.latitude, lon: p.longitude).ignore();
  }

  void _onTrips(List<TripSummaryModel> trips) {
    final keys = _keysOf([for (final t in trips) ...t.legCities]).toSet();
    if (keys.isEmpty || _keysDone.containsAll(keys)) return;
    _keysDone = {..._keysDone, ...keys};
    _warm(cityKeys: keys).ignore();
  }

  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    _workers.clear();
  }
}
