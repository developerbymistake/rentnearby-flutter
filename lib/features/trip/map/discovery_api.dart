import 'dart:typed_data';

import 'package:get/get.dart';

import '../../map_discovery/pack/map_pack_models.dart';
import 'discovery_ids.dart';

export '../../map_discovery/pack/map_pack_models.dart' show MapPackSpot;
export 'discovery_ids.dart' show DiscIds, DiscTuning, DiscLayerSpec, DiscLayerKind, DiscLayers;

typedef DiscoverySpot = MapPackSpot;

enum DiscoveryMode { full, readOnly }

enum DiscoveryDataState { none, loading, ready }

abstract class DiscoveryDataSource {
  Rx<DiscoveryDataState> get state;
  bool get enabled;
  int get version;
  List<DiscoverySpot> forCities(Iterable<int> cityKeys);
  List<DiscoverySpot> all();
  DiscoverySpot? byId(String id);
  List<DiscoverySpot> near(double lat, double lon, double km);
  Future<void> ensureForCities(Iterable<int> cityKeys);
  Future<void> ensureForPoint(double lat, double lon);
}

abstract class DiscoveryMapPort {
  Future<void> addGeoJsonSource(String sourceId, Map<String, dynamic> data);
  Future<void> setGeoJson(String sourceId, Map<String, dynamic> data);
  Future<void> addLayer(DiscLayerSpec spec, DiscTuning tuning, {String? belowLayerId});
  Future<void> addImage(String name, Uint8List bytes);
  Future<void> setFilter(String layerId, List<Object>? filter);
  Future<void> setVisibility(String layerId, bool visible);
  Future<List<Object?>> queryRect(double left, double top, double right, double bottom, List<String> layerIds);
  Future<List<({double x, double y})>> toScreen(List<({double lat, double lon})> points);
  Future<void> animateTo(double lat, double lon, {double? zoom});
  Future<void> removeAll();
}

class DiscoveryHost {
  final String? Function() anchorLayerId;
  final int? Function(String spotId) plannedDayOf;
  final int? Function(DiscoverySpot spot)? targetDayFor;
  final void Function(DiscoverySpot spot)? onAdd;
  final void Function(DiscoverySpot spot)? onRemove;
  final void Function(DiscoverySpot spot)? onDetails;
  final String? Function(DiscoverySpot spot)? lineFor;
  final double Function() topInset;
  final double Function() bottomInset;

  const DiscoveryHost({
    required this.anchorLayerId,
    required this.plannedDayOf,
    required this.topInset,
    required this.bottomInset,
    this.targetDayFor,
    this.onAdd,
    this.onRemove,
    this.onDetails,
    this.lineFor,
  });

  static String? _noAnchor() => null;
  static int? _noDay(String _) => null;
  static double _zero() => 0;

  const DiscoveryHost.readOnly({
    this.anchorLayerId = _noAnchor,
    this.topInset = _zero,
    this.bottomInset = _zero,
    this.onDetails,
    this.lineFor,
  })  : plannedDayOf = _noDay,
        targetDayFor = null,
        onAdd = null,
        onRemove = null;
}

abstract class DiscoveryLayerApi {
  DiscoveryMode get mode;
  DiscTuning get tuning;
  DiscoveryHost get host;

  RxBool get attached;
  RxBool get eyeOn;
  RxBool get hasSpotsHere;
  Rx<DiscoveryDataState> get dataState;
  Rxn<DiscoverySpot> get selected;
  RxnInt get selectedPlannedDay;
  RxnDouble get selectedScreenX;

  Future<bool> attach(DiscoveryMapPort port);
  Future<void> detach();

  Future<void> setData(List<DiscoverySpot> spots);
  Future<void> setPlannedIds(Set<String> ids);
  Future<void> setPhotoArea(double lat, double lon, double km);

  Future<void> select(String spotId, {bool planned = false});
  Future<void> clearSelection();
  Future<void> setEye(bool on);

  Future<bool> onFeatureTap(String layerId, Object? featureId);
  Future<bool> onMapTap(double x, double y);
}
