import 'dart:async';
import 'dart:math' show Point;
import 'dart:math' as math;

import 'package:bakhli/design/design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../controllers/location_controller.dart';
import '../../../utils/app_toast.dart';
import 'discovery_api.dart';
import 'discovery_geojson.dart';
import 'discovery_tiers.dart';
import 'trip_marker_images.dart';

class DiscPaint {
  static const double selIconScale = 1.2;
  static const double _selDotRing = 2;
  static const List<Object> always = ['==', 1, 1];

  static String get _white => TripKit.hexOf(FitnessAppTheme.white);

  static List<Object> get groupColor => [
        'match',
        ['get', 'grp'],
        DiscTiers.grpWater,
        TripKit.hexOf(TripTokens.spotWater),
        DiscTiers.grpNature,
        TripKit.hexOf(TripTokens.spotNature),
        DiscTiers.grpHeritage,
        TripKit.hexOf(TripTokens.spotHeritage),
        TripKit.hexOf(TripTokens.spotOther),
      ];

  static const Map<int, Color> groupColors = {
    DiscTiers.grpWater: TripTokens.spotWater,
    DiscTiers.grpNature: TripTokens.spotNature,
    DiscTiers.grpHeritage: TripTokens.spotHeritage,
    DiscTiers.grpOther: TripTokens.spotOther,
  };

  static LayerProperties of(DiscLayerSpec spec, DiscTuning t) => switch (spec.id) {
        DiscIds.layerDots => SymbolLayerProperties(
            iconImage: DiscLayers.iconImageDot,
            iconSize: t.dotIconSize,
            iconAllowOverlap: false,
            iconIgnorePlacement: false,
            symbolSortKey: DiscLayers.sortKey,
          ),
        DiscIds.layerBadge => SymbolLayerProperties(
            iconImage: DiscLayers.iconImageBadge,
            iconSize: t.badgeIconSize,
            iconAllowOverlap: false,
            iconIgnorePlacement: false,
            symbolSortKey: DiscLayers.sortKey,
          ),
        DiscIds.layerPhoto => SymbolLayerProperties(
            iconImage: DiscLayers.iconImagePhoto,
            iconSize: t.photoIconSize,
            iconAllowOverlap: false,
            iconIgnorePlacement: false,
            symbolSortKey: DiscLayers.sortKey,
          ),
        DiscIds.layerSelHalo => CircleLayerProperties(
            circleRadius: t.haloRadius(DiscSelKind.dot.name, selIconScale, plannedKind: DiscSelKind.planned.name),
            circleColor: TripKit.hexOf(DesignColors.textPrimary),
            circleOpacity: Alpha.v18,
          ),
        DiscIds.layerSelDot => CircleLayerProperties(
            circleRadius: t.selDotRadius(_selDotRing),
            circleColor: groupColor,
            circleStrokeColor: _white,
            circleStrokeWidth: _selDotRing,
          ),
        _ => SymbolLayerProperties(
            iconImage: DiscLayers.iconImagePhoto,
            iconSize: t.selIconSize(selIconScale),
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
          ),
      };
}

class MapLibreDiscoveryPort implements DiscoveryMapPort {
  final MapLibreMapController map;
  final List<String> _sources = [];
  final List<String> _layers = [];

  MapLibreDiscoveryPort(this.map);

  @override
  Future<void> addGeoJsonSource(String sourceId, Map<String, dynamic> data) async {
    await map.addSource(sourceId, GeojsonSourceProperties(data: data));
    _sources.add(sourceId);
  }

  @override
  Future<void> setGeoJson(String sourceId, Map<String, dynamic> data) => map.setGeoJsonSource(sourceId, data);

  @override
  Future<void> addLayer(DiscLayerSpec spec, DiscTuning tuning, {String? belowLayerId}) async {
    final props = DiscPaint.of(spec, tuning);
    if (props is CircleLayerProperties) {
      await map.addCircleLayer(spec.sourceId, spec.id, props,
          belowLayerId: belowLayerId, minzoom: spec.minZoom, filter: spec.filter, enableInteraction: spec.interactive);
    } else if (props is SymbolLayerProperties) {
      await map.addSymbolLayer(spec.sourceId, spec.id, props,
          belowLayerId: belowLayerId, minzoom: spec.minZoom, filter: spec.filter, enableInteraction: spec.interactive);
    }
    _layers.add(spec.id);
  }

  @override
  Future<void> addImage(String name, Uint8List bytes) => map.addImage(name, bytes);

  @override
  Future<void> setFilter(String layerId, List<Object>? filter) => map.setFilter(layerId, filter ?? DiscPaint.always);

  @override
  Future<void> setVisibility(String layerId, bool visible) => map.setLayerVisibility(layerId, visible);

  @override
  Future<List<Object?>> queryRect(double left, double top, double right, double bottom, List<String> layerIds) async =>
      List<Object?>.from(await map.queryRenderedFeaturesInRect(Rect.fromLTRB(left, top, right, bottom), layerIds, null));

  @override
  Future<List<({double x, double y})>> toScreen(List<({double lat, double lon})> points) async {
    final out = await map.toScreenLocationBatch([for (final p in points) LatLng(p.lat, p.lon)]);
    return [for (final p in out) (x: p.x.toDouble(), y: p.y.toDouble())];
  }

  @override
  Future<void> animateTo(double lat, double lon, {double? zoom}) async {
    final at = LatLng(lat, lon);
    await map.animateCamera(zoom == null ? CameraUpdate.newLatLng(at) : CameraUpdate.newLatLngZoom(at, zoom));
  }

  @override
  Future<void> removeAll() async {
    for (final id in _layers.reversed.toList()) {
      try {
        await map.removeLayer(id);
      } catch (_) {}
    }
    for (final id in _sources.reversed.toList()) {
      try {
        await map.removeSource(id);
      } catch (_) {}
    }
    _layers.clear();
    _sources.clear();
  }
}

class TripDiscoveryLayer implements DiscoveryLayerApi {
  static bool _stayEye = true;
  static const double _probeDeg = 0.01;
  static final Map<String, Uint8List> _badgeCache = {};

  @override
  final DiscoveryMode mode;
  @override
  final DiscTuning tuning;
  @override
  final DiscoveryHost host;
  final DiscoveryDataSource? source;
  final List<DiscoverySpot> Function(DiscoveryDataSource source)? dataOf;
  final Size Function()? viewSize;
  final double Function() unitsPerDp;
  final double Function() cardHeight;
  final bool Function()? tapsBlocked;
  final TripMarkerImages _images;

  @override
  final RxBool attached = false.obs;
  @override
  final RxBool eyeOn;
  @override
  final RxBool hasSpotsHere = false.obs;
  @override
  final Rx<DiscoveryDataState> dataState = DiscoveryDataState.none.obs;
  @override
  final Rxn<DiscoverySpot> selected = Rxn<DiscoverySpot>();
  @override
  final RxnInt selectedPlannedDay = RxnInt();
  @override
  final RxnDouble selectedScreenX = RxnDouble();
  final Rxn<DiscSelKind> selectedKind = Rxn<DiscSelKind>();

  DiscoveryMapPort? _port;
  int _gen = 0;
  int _photoGen = 0;
  List<DiscoverySpot> _spots = const [];
  Map<String, DiscoverySpot> _byId = const {};
  Map<String, int> _tiers = const {};
  List<DiscoverySpot> _top = const [];
  Set<String> _registered = {};
  final Map<String, String> _slots = {};
  final List<String> _freeSlots = [];
  Set<String> _planned = {};
  DiscArea? _area;
  int? _dataSig;
  String? _photoSig;
  String? _selImg;
  bool _selSmall = false;
  Worker? _stateWorker;
  VoidCallback? _unhook;
  bool _disposed = false;

  TripDiscoveryLayer({
    required this.mode,
    required this.host,
    DiscTuning? tuning,
    this.source,
    this.dataOf,
    this.viewSize,
    double Function()? unitsPerDp,
    double Function()? cardHeight,
    this.tapsBlocked,
    TripMarkerImages? images,
  })  : tuning = tuning ?? (mode == DiscoveryMode.full ? DiscTuning.trip : DiscTuning.stay),
        unitsPerDp = unitsPerDp ?? _one,
        cardHeight = cardHeight ?? _zero,
        _images = images ?? TripMarkerImages(),
        eyeOn = (mode == DiscoveryMode.readOnly ? _stayEye : true).obs {
    final s = source;
    if (s != null) {
      dataState.value = s.state.value;
      _stateWorker = ever<DiscoveryDataState>(s.state, _onSourceState);
    }
  }

  static double _one() => 1;
  static double _zero() => 0;

  bool get _needsArea => mode == DiscoveryMode.readOnly;

  bool get isAttached => attached.value && _port != null;

  void onUnhook(VoidCallback unhook) => _unhook = unhook;

  void _onSourceState(DiscoveryDataState v) {
    if (_disposed) return;
    dataState.value = v;
    if (v == DiscoveryDataState.ready) refreshData().ignore();
  }

  Future<void> refreshData() async {
    final s = source, of = dataOf;
    if (_disposed || s == null) return;
    await setData(of == null ? s.all() : of(s));
  }

  @override
  Future<bool> attach(DiscoveryMapPort port) async {
    if (_disposed) return false;
    if (isAttached) return true;
    final gen = ++_gen;
    _port = port;
    _registered = {};
    _slots.clear();
    _freeSlots.clear();
    _photoSig = null;
    try {
      final below = host.anchorLayerId();
      await port.addGeoJsonSource(DiscIds.srcAll, DiscGeoJson.all(_spots, _tiers));
      await port.addGeoJsonSource(DiscIds.srcPhoto, DiscGeoJson.empty);
      await port.addGeoJsonSource(DiscIds.srcSel, DiscGeoJson.empty);
      for (final cat in DiscIds.badgeCategories) {
        await port.addImage(DiscIds.badgeImage(cat), await _badge(cat));
      }
      for (final g in DiscPaint.groupColors.keys) {
        await port.addImage(DiscIds.dotImage(g), await _dot(g));
      }
      for (final spec in DiscLayers.specs(tuning)) {
        await port.addLayer(spec, tuning, belowLayerId: below);
      }
      if (gen != _gen) return false;
      if (_planned.isNotEmpty) await _applyFilters(port);
      if (!eyeOn.value) await _applyEye(port, false);
      if (gen != _gen) return false;
      attached.value = true;
      _startPhotos();
      return true;
    } catch (_) {
      if (gen == _gen) {
        _port = null;
        attached.value = false;
        try {
          await port.removeAll();
        } catch (_) {}
      }
      return false;
    }
  }

  Future<Uint8List> _dot(int group) async {
    final key = 'dot_${group}_${tuning.dotDp}_${tuning.pxPerDp}';
    return _badgeCache[key] ??= await _images.dot(DiscPaint.groupColors[group]!, tuning);
  }

  Future<Uint8List> _badge(String cat) async {
    final key = '${cat}_${tuning.badgeDp}_${tuning.pxPerDp}';
    return _badgeCache[key] ??= await _images.badge(cat, tuning);
  }

  @override
  Future<void> detach() async {
    _gen++;
    _photoGen++;
    final port = _port;
    _port = null;
    attached.value = false;
    _clearSelectionState();
    if (port != null) {
      try {
        await port.removeAll();
      } catch (_) {}
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _gen++;
    _photoGen++;
    _port = null;
    attached.value = false;
    _stateWorker?.dispose();
    _stateWorker = null;
    _unhook?.call();
    _unhook = null;
  }

  @override
  Future<void> setData(List<DiscoverySpot> spots) async {
    if (_disposed) return;
    final sig = Object.hashAll([
      spots.length,
      for (final s in spots) Object.hash(s.id, s.lat, s.lon, s.name, s.category, s.rank, s.cityKey, s.thumbUrl, s.nPhotos),
    ]);
    if (sig == _dataSig) return;
    _dataSig = sig;
    final before = _byId;
    _spots = DiscTiers.sorted(spots);
    _byId = {for (final s in _spots) s.id: s};
    // A new cover is composed again under the same slot.
    final newCover = {for (final s in _spots) if (before[s.id] case final o? when o.thumbUrl != s.thumbUrl) s.id};
    if (newCover.isNotEmpty) _registered = {..._registered}..removeAll(newCover);
    _retier();
    final sel = selected.value;
    if (sel != null && selectedKind.value != DiscSelKind.planned && !_byId.containsKey(sel.id)) await clearSelection();
    final port = _port;
    if (!isAttached || port == null) return;
    final gen = _gen;
    try {
      await port.setGeoJson(DiscIds.srcAll, DiscGeoJson.all(_spots, _tiers));
    } catch (_) {}
    if (gen != _gen) return;
    final open = selected.value;
    final row = open == null ? null : _byId[open.id];
    if (row != null && !identical(row, open)) {
      await _show(row, selectedKind.value == DiscSelKind.planned ? DiscSelKind.planned : _naturalKind(row), lift: false);
      if (gen != _gen) return;
    }
    _startPhotos();
    await _refreshSelection();
  }

  void _retier() {
    final area = _area;
    final photoMax = _needsArea && area == null ? 0 : tuning.photoMax;
    _tiers = DiscTiers.assign(_spots, photoMax: photoMax, badgeMax: tuning.badgeMax, area: area);
    _top = [for (final s in _spots) if (_tiers[s.id] == DiscTiers.photo) s];
    hasSpotsHere.value = area == null ? _spots.isNotEmpty : _spots.any(area.contains);
  }

  @override
  Future<void> setPlannedIds(Set<String> ids) async {
    if (_disposed) return;
    final next = {...ids};
    if (setEquals(next, _planned)) return;
    _planned = next;
    final port = _port;
    if (isAttached && port != null) {
      try {
        await _applyFilters(port);
      } catch (_) {}
    }
    await _followPlan();
  }

  Future<void> _applyFilters(DiscoveryMapPort port) async {
    for (final id in DiscIds.discoveryLayers) {
      await port.setFilter(id, DiscGeoJson.layerFilter(id, _planned));
    }
  }

  Future<void> _followPlan() async {
    final sel = selected.value;
    if (sel == null) return;
    final day = host.plannedDayOf(sel.id);
    final wasPlanned = selectedKind.value == DiscSelKind.planned;
    if (day != null && !wasPlanned) {
      await _show(sel, DiscSelKind.planned, lift: false);
    } else if (day == null && wasPlanned) {
      final row = _byId[sel.id];
      if (row == null) {
        await clearSelection();
      } else {
        await _show(row, _naturalKind(row), lift: false);
      }
    } else {
      selectedPlannedDay.value = day;
      if (wasPlanned) await refreshPlanned();
    }
  }

  @override
  Future<void> setPhotoArea(double lat, double lon, double km) async {
    if (_disposed) return;
    final a = DiscArea(lat, lon, km);
    if (!a.valid) return;
    final old = _area;
    if (old != null && old.lat == a.lat && old.lon == a.lon && old.km == a.km) return;
    _area = a;
    final before = _tiers;
    _retier();
    final port = _port;
    if (!isAttached || port == null) return;
    final gen = _gen;
    if (!mapEquals(before, _tiers)) {
      try {
        await port.setGeoJson(DiscIds.srcAll, DiscGeoJson.all(_spots, _tiers));
      } catch (_) {}
    }
    if (gen != _gen) return;
    _startPhotos();
    await _refreshSelection();
  }

  /// Retries marker photos that failed to load (connection back); no work when every top photo is registered.
  void retryPhotos() {
    if (!isAttached || _disposed) return;
    if (_top.every((s) => !s.hasThumb || _registered.contains(s.id))) return;
    _startPhotos();
  }

  // The open card follows its row: a freed or reused slot must never show another place's photo.
  Future<void> _refreshSelection() async {
    final sel = selected.value;
    final kind = selectedKind.value;
    if (sel == null || kind == null || kind == DiscSelKind.planned || !isAttached) return;
    final row = _byId[sel.id];
    if (row == null) {
      await clearSelection();
      return;
    }
    final natural = _naturalKind(row);
    final img = natural == DiscSelKind.photo ? _slotName(row.id) : null;
    if (natural == kind && img == _selImg) return;
    await _show(row, natural, lift: false);
  }

  void _startPhotos() {
    final port = _port;
    if (!isAttached || port == null) return;
    final gen = _gen;
    final photoGen = ++_photoGen;
    final top = _top;
    final tiers = _tiers;
    bool alive() => !_disposed && gen == _gen && photoGen == _photoGen && identical(_port, port);
    Future<void> publish(Set<String> reg) async {
      final sig = Object.hashAll([for (final s in top) if (reg.contains(s.id)) s.id]).toString();
      if (sig == _photoSig) return;
      _photoSig = sig;
      await port.setGeoJson(DiscIds.srcPhoto, DiscGeoJson.photo(top, reg, tiers: tiers, imgOf: _slotName));
    }

    final keep = {for (final s in top) s.id};
    for (final id in [..._slots.keys]) {
      if (keep.contains(id)) continue;
      _freeSlots.add(_slots.remove(id)!);
      _registered = {..._registered}..remove(id);
    }

    () async {
      try {
        await _refreshSelection();
        if (!alive()) return;
        if (_registered.isNotEmpty || _photoSig != null) await publish(_registered);
        if (!alive()) return;
        await _images.register(
          spots: top,
          tuning: tuning,
          already: _registered,
          addImage: port.addImage,
          nameOf: (s) => _slots[s.id] ??= _freeSlots.isNotEmpty ? _freeSlots.removeLast() : DiscIds.photoSlot(_slots.length),
          onBatch: (reg) async {
            if (!alive()) return;
            _registered = reg;
            await publish(reg);
            if (alive()) await _refreshSelection();
          },
          alive: alive,
        );
      } catch (_) {}
    }();
  }

  String _slotName(String id) => _slots[id] ?? DiscIds.photoImage(id);

  DiscSelKind _naturalKind(DiscoverySpot s) {
    if (_registered.contains(s.id) && _tiers[s.id] == DiscTiers.photo) return DiscSelKind.photo;
    if ((_tiers[s.id] ?? DiscTiers.dot) <= DiscTiers.badge) return DiscSelKind.badge;
    return DiscSelKind.dot;
  }

  @override
  Future<void> select(String spotId, {bool planned = false, DiscoverySpot? spot}) async {
    final s = _byId[spotId] ?? spot ?? source?.byId(spotId);
    if (s == null || !isAttached) return;
    await _show(s, planned ? DiscSelKind.planned : _naturalKind(s), lift: true);
  }

  Future<void> _show(DiscoverySpot s, DiscSelKind kind, {required bool lift}) async {
    final port = _port;
    if (!isAttached || port == null) return;
    final gen = _gen;
    if (lift || selected.value?.id != s.id) selectedScreenX.value = null;
    selectedKind.value = kind;
    selectedPlannedDay.value = host.plannedDayOf(s.id);
    selected.value = s;
    final img = kind == DiscSelKind.photo ? _slotName(s.id) : null;
    final small = kind == DiscSelKind.planned && host.plannedIsDot(s.id);
    _selImg = img;
    _selSmall = small;
    try {
      await port.setGeoJson(DiscIds.srcSel, DiscGeoJson.sel(s, kind, tier: _tiers[s.id], img: img, small: small));
      if (lift && gen == _gen) await _lift(port, s, kind, small: small);
    } catch (_) {}
  }

  /// The trip map changed which day shows full stops: an open planned stop takes the halo of its new size.
  Future<void> refreshPlanned() async {
    final sel = selected.value;
    if (sel == null || selectedKind.value != DiscSelKind.planned || !isAttached) return;
    if (host.plannedIsDot(sel.id) == _selSmall) return;
    await _show(sel, DiscSelKind.planned, lift: false);
  }

  // MapLibre world = 512 dp x 2^zoom, so dp per degree of latitude gives the camera zoom.
  static double zoomOf(double dpPerLat, double lat) => math.log(dpPerLat * 360 * math.cos(lat * math.pi / 180) / 512) / math.ln2;

  Future<void> _lift(DiscoveryMapPort port, DiscoverySpot s, DiscSelKind kind, {required bool small}) async {
    final view = viewSize?.call();
    if (view == null || view.isEmpty) return;
    final u = unitsPerDp();
    if (!(u > 0)) return;
    final pts = await port.toScreen([
      (lat: s.lat, lon: s.lon),
      (lat: s.lat + _probeDeg, lon: s.lon),
      (lat: s.lat, lon: s.lon + _probeDeg),
    ]);
    if (pts.length < 3) return;
    final perLat = (pts[0].y - pts[1].y) / _probeDeg / u;
    final perLon = (pts[2].x - pts[0].x) / _probeDeg / u;
    if (!(perLat > 0) || !(perLon > 0) || !perLat.isFinite || !perLon.isFinite) return;
    final x = pts[0].x / u, y = pts[0].y / u;
    if (selected.value?.id == s.id) selectedScreenX.value = x;
    final zoom = zoomOf(perLat, s.lat);
    final halo = zoom.isFinite
        ? tuning.haloRadiusAt(kind.name, zoom,
            dotKind: DiscSelKind.dot.name, plannedKind: DiscSelKind.planned.name, photoScale: DiscPaint.selIconScale, small: small)
        : tuning.haloPhotoDp / 2;
    double? target;
    if (mode == DiscoveryMode.full) {
      final top = host.topInset() + cardHeight() + halo;
      if (y < top) target = top + halo;
    } else {
      final bottom = view.height - host.bottomInset() - cardHeight() - halo;
      if (y > bottom) target = bottom - halo;
    }
    if (target == null) return;
    final low = host.topInset() + halo;
    final high = math.max(low, view.height - host.bottomInset() - halo);
    target = target.clamp(low, high);
    final centreLat = s.lat + (y - view.height / 2) / perLat;
    final centreLon = s.lon + (view.width / 2 - x) / perLon;
    await port.animateTo(centreLat + (target - y) / perLat, centreLon);
  }

  @override
  Future<void> clearSelection() async {
    if (selected.value == null && selectedKind.value == null) return;
    _clearSelectionState();
    final port = _port;
    if (!isAttached || port == null) return;
    try {
      await port.setGeoJson(DiscIds.srcSel, DiscGeoJson.empty);
    } catch (_) {}
  }

  void _clearSelectionState() {
    _selImg = null;
    _selSmall = false;
    selected.value = null;
    selectedKind.value = null;
    selectedPlannedDay.value = null;
    selectedScreenX.value = null;
  }

  @override
  Future<void> setEye(bool on) async {
    if (eyeOn.value == on) return;
    eyeOn.value = on;
    if (mode == DiscoveryMode.readOnly) _stayEye = on;
    final port = _port;
    if (isAttached && port != null) {
      try {
        await _applyEye(port, on);
      } catch (_) {}
    }
    if (!on) await clearSelection();
  }

  Future<void> _applyEye(DiscoveryMapPort port, bool on) async {
    for (final id in DiscIds.discoveryLayers) {
      await port.setVisibility(id, on);
    }
  }

  @override
  Future<bool> onFeatureTap(String layerId, Object? featureId) async {
    if (!isAttached || !eyeOn.value || !DiscIds.tapLayers.contains(layerId)) return false;
    final id = DiscGeoJson.featureId(featureId);
    final s = id == null ? null : _byId[id];
    if (s == null || _planned.contains(s.id)) return false;
    if (tapsBlocked?.call() ?? false) {
      await clearSelection();
      return true;
    }
    await _show(s, layerId == DiscIds.layerPhoto ? DiscSelKind.photo : DiscSelKind.badge, lift: true);
    return true;
  }

  @override
  Future<bool> onMapTap(double x, double y) async {
    final port = _port;
    if (!isAttached || port == null) return false;
    if (!eyeOn.value || (tapsBlocked?.call() ?? false)) {
      await clearSelection();
      return false;
    }
    final gen = _gen;
    final half = tuning.hitDp / 2 * unitsPerDp();
    List<DiscFeatureRef> refs;
    try {
      final raw = await port.queryRect(x - half, y - half, x + half, y + half, const [DiscIds.layerDots]);
      refs = [for (final r in DiscGeoJson.refsOf(raw)) if (_byId.containsKey(r.id) && !_planned.contains(r.id)) r];
    } catch (_) {
      refs = const [];
    }
    if (gen != _gen) return false;
    if (refs.isEmpty) {
      await clearSelection();
      return false;
    }
    var id = refs.first.id;
    if (refs.length > 1) {
      try {
        final pts = await port.toScreen([for (final r in refs) (lat: r.lat, lon: r.lon)]);
        if (gen != _gen) return false;
        id = DiscGeoJson.nearest([
              for (var i = 0; i < refs.length && i < pts.length; i++) (id: refs[i].id, x: pts[i].x, y: pts[i].y),
            ], x, y) ??
            id;
      } catch (_) {}
    }
    final s = _byId[id];
    if (s == null) return false;
    await _show(s, DiscSelKind.dot, lift: true);
    return true;
  }
}

class DiscoveryAttach {
  static bool wanted(DiscoveryDataSource? source) =>
      source != null && source.enabled && source.state.value != DiscoveryDataState.none;

  static double unitsPerDp(BuildContext context) =>
      defaultTargetPlatform == TargetPlatform.android ? MediaQuery.devicePixelRatioOf(context) : 1.0;

  static Future<TripDiscoveryLayer?> maybe(
    MapLibreMapController? map, {
    required DiscoveryMode mode,
    required DiscoveryHost host,
    required DiscoveryDataSource? source,
    DiscTuning? tuning,
    List<DiscoverySpot> Function(DiscoveryDataSource source)? dataOf,
    Size Function()? viewSize,
    double Function()? unitsPerDp,
    double Function()? cardHeight,
    bool Function()? tapsBlocked,
  }) async {
    if (map == null || !wanted(source)) return null;
    final layer = TripDiscoveryLayer(
      mode: mode,
      host: host,
      tuning: tuning,
      source: source,
      dataOf: dataOf,
      viewSize: viewSize,
      unitsPerDp: unitsPerDp,
      cardHeight: cardHeight,
      tapsBlocked: tapsBlocked,
    );
    return attachLayer(layer, MapLibreDiscoveryPort(map), hook: (onTap) {
      void listener(Point<double> point, LatLng at, String id, String layerId, Annotation? annotation) {
        if (annotation == null) onTap(layerId, id);
      }

      map.onFeatureTapped.add(listener);
      return () => map.onFeatureTapped.remove(listener);
    });
  }

  @visibleForTesting
  static Future<TripDiscoveryLayer?> attachLayer(
    TripDiscoveryLayer layer,
    DiscoveryMapPort port, {
    VoidCallback Function(void Function(String layerId, String id) onTap)? hook,
  }) async {
    try {
      await layer.refreshData();
      if (!await layer.attach(port)) {
        layer.dispose();
        return null;
      }
      if (hook != null) layer.onUnhook(hook((layerId, id) => layer.onFeatureTap(layerId, id).ignore()));
      return layer;
    } catch (_) {
      layer.dispose();
      return null;
    }
  }
}

class DiscoveryCamera {
  static const double userZoom = 15;
  static const String noFixMessage = 'Waiting for GPS location. Please enable location and try again.';

  static Future<void> toUser(MapLibreMapController? map, {MinMaxZoomPreference? limits}) async {
    final loc = Get.isRegistered<LocationController>() ? Get.find<LocationController>().userLocation.value : null;
    if (map == null) return;
    if (loc == null) {
      AppToast.error(noFixMessage);
      return;
    }
    var zoom = userZoom;
    final lo = limits?.minZoom, hi = limits?.maxZoom;
    if (lo != null && zoom < lo) zoom = lo;
    if (hi != null && zoom > hi) zoom = hi;
    try {
      await map.animateCamera(CameraUpdate.newLatLngZoom(loc, zoom));
    } catch (_) {}
  }
}
