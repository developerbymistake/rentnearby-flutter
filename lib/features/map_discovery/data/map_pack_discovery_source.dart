import 'package:get/get.dart';

import '../../trip/map/discovery_api.dart';
import '../pack/map_pack_models.dart';
import 'map_pack_service.dart';

class MapPackDiscoverySource implements DiscoveryDataSource {
  final MapPackService _service;

  MapPackDiscoverySource(this._service);

  @override
  final Rx<DiscoveryDataState> state = DiscoveryDataState.none.obs;

  static DiscoveryDataState of(MapPackStatus s) => switch (s) {
        MapPackStatus.off || MapPackStatus.none => DiscoveryDataState.none,
        MapPackStatus.loading => DiscoveryDataState.loading,
        MapPackStatus.ready => DiscoveryDataState.ready,
      };

  void sync(MapPackStatus s) {
    final v = of(s);
    if (state.value != v) state.value = v;
  }

  @override
  bool get enabled => _service.enabled;

  @override
  int get version => _service.revision.value;

  @override
  List<DiscoverySpot> forCities(Iterable<int> cityKeys) => _service.index?.forCities(cityKeys) ?? const [];

  @override
  List<DiscoverySpot> all() => _service.index?.ranked ?? const [];

  @override
  DiscoverySpot? byId(String id) => _service.index?.byId(id);

  @override
  List<DiscoverySpot> near(double lat, double lon, double km) => _service.index?.near(lat, lon, km) ?? const [];

  @override
  Future<void> ensureForCities(Iterable<int> cityKeys) => _service.ensureForCities(cityKeys);

  @override
  Future<void> ensureForPoint(double lat, double lon) => _service.ensureForPoint(lat, lon);
}
