import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_map_state.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../config/module_palette.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../../../models/browse_item.dart';
import '../../../screens/explore_location_search_mixin.dart';
import '../../../widgets/add_listing_shortcut_button.dart';
import '../../../widgets/empty_radius_hint.dart';
import '../../../widgets/location_pill.dart';
import '../../../widgets/nearby_item_row.dart';
import '../../../widgets/nearest_confirm_sheet.dart';
import '../../../widgets/nearest_control_bar.dart';
import '../setup/stay_option_sets.dart';
import '../models/stay_nearby_model.dart';
import 'stay_bottom_sheet.dart';
import 'stay_guest_controller.dart';
import 'stay_landing_controller.dart';


class StayMapScreen extends StatefulWidget {
  const StayMapScreen({super.key});
  @override
  State<StayMapScreen> createState() => _StayMapScreenState();
}

class _StayMapScreenState extends State<StayMapScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, ExploreLocationSearchMixin<StayMapScreen> {
  MapLibreMapController? _mapController;
  double _currentZoom = 13.0;
  Size _screenSize = Size.zero;
  Circle? _nativeUserDot;
  final _circleCache = <double, Map<String, dynamic>>{};
  bool _pinsVisible = true;
  bool _styleLoaded = false;
  LatLng? _cameraCenter;
  bool _mapActive = true;
  bool _isCameraMoving = false;
  Timer? _cameraIdleDebounce;
  Worker? _mapPauseWorker;

  final _guest = StayGuestController.to;
  final _locationCtrl = Get.find<LocationController>();
  final _auth = Get.find<AuthController>();
  final _workers = <Worker>[];
  bool _stale = false;

  List<_MapMarkerData> _markerData = [];
  double _radius = 1.0;
  double? _preSearchRadius;
  double _lastClusterZoom = 0;
  bool _mapReady = false;
  Timer? _loadNearbyDebounceTimer;
  bool _loadingNearby = false;
  bool _reloadPending = false;
  bool _hasLoadedOnce = false;
  int _revealedCount = 0;
  Timer? _revealTimer;
  late AnimationController _radarController;

  late final AnimationController _nearestCircleController;
  Animation<double>? _nearestCircleAnim;
  LatLng? _nearestCircleCenter;

  bool get _onStaysTab => _auth.tabIndex.value == AppTabs.stays;

  @override
  ModulePalette get searchPalette => StayColors.palette;

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

    _nearestCircleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
      ..addListener(() {
        final anim = _nearestCircleAnim;
        final ctrl = _mapController;
        final center = _nearestCircleCenter;
        if (anim == null || ctrl == null || center == null) return;
        ctrl.setGeoJsonSource('radius-source', _buildCircleGeojson(center, anim.value));
      });

    WidgetsBinding.instance.addObserver(this);

    _workers.add(ever(_locationCtrl.selectedDistrict, (_) {
      if (_locationCtrl.selectedDistrict.value != null) {
        if (_onStaysTab && !mapShouldPause.value) {
          _precomputeCircleCache();
          _loadNearby();
          if (_mapReady && !_isCameraMoving) _fitToRadius();
        } else {
          _stale = true;
        }
      }
    }));

    _workers.add(ever(_locationCtrl.locationSelectionChanged, (_) {
      if (isSearchActive && _preSearchRadius == null) {
        _preSearchRadius = _radius;
        setState(() => _radius = AppConstants.radiusOptions.last);
      } else if (!isSearchActive && _preSearchRadius != null) {
        setState(() => _radius = _preSearchRadius!);
        _preSearchRadius = null;
      }
      if (_onStaysTab && !mapShouldPause.value) {
        _precomputeCircleCache();
        _loadNearby();
        if (_mapReady) _fitToRadius();
      } else {
        _stale = true;
      }
    }));

    _workers.add(ever(_locationCtrl.locationRefreshedTrigger, (_) {
      if (!mounted) return;
      if (_locationCtrl.browsingCity.value == null) {
        _precomputeCircleCache();
        if (_mapReady) {
          _updateNativeRadiusCircle();
          _fitToRadius();
        }
      }
      setState(() {});
    }));

    _workers.add(ever(_locationCtrl.userLocation, (_) {
      if (!mounted) return;
      if (_mapReady) {
        final loc = _locationCtrl.userLocation.value;
        if (loc != null) {
          if (_nativeUserDot == null) {
            _initNativeUserDot();
          } else {
            _updateNativeUserDot();
          }
          if (_locationCtrl.browsingCity.value == null) {
            _precomputeCircleCache();
            _updateNativeRadiusCircle();
          }
          if (_markerData.isNotEmpty && _markerData.first.isUser) {
            final m = _buildUserMarkerData();
            if (m != null) _markerData[0] = m;
          }
        } else {
          if (_markerData.isNotEmpty && _markerData.first.isUser) {
            _markerData.removeAt(0);
          }
        }
      }
      if (_pinsVisible && !_isCameraMoving) setState(() {});
    }));

    if (Get.isRegistered<StayLandingController>(tag: StayLandingController.tag)) {
      final landing = Get.find<StayLandingController>(tag: StayLandingController.tag);
      _workers.add(ever(landing.stayPostedTrigger, (_) {
        _stale = true;
        if (_onStaysTab && !mapShouldPause.value) _loadNearby();
      }));
      _workers.add(ever(landing.exploreRefreshTrigger, (_) {
        _stale = true;
        if (_locationCtrl.effectiveDistrict != null && _onStaysTab && !mapShouldPause.value) _loadNearby();
      }));
      _workers.add(ever(landing.filterResetTrigger, (_) {
        if (!mounted || !_mapReady) return;
        _precomputeCircleCache();
        _updateNativeRadiusCircle();
        _fitToRadius();
      }));
    }

    _workers.add(ever(_guest.isLoading, (loading) {
      if (!loading && _radarController.isAnimating) {
        _radarController.stop();
        _radarController.reset();
      }
    }));

    _mapPauseWorker = ever(mapShouldPause, (bool paused) {
      if (!mounted) return;
      if (paused) {
        setState(() {
          _mapActive = false;
          _styleLoaded = false;
          _mapReady = false;
          _mapController = null;
          _nativeUserDot = null;
        });
      } else {
        setState(() => _mapActive = true);
        if (_onStaysTab && _stale) _loadNearby();
      }
    });

    _workers.add(ever(_auth.tabIndex, (index) {
      if (index == AppTabs.stays) {
        if (_stale && !mapShouldPause.value) {
          _loadNearby();
          if (_mapReady && !_isCameraMoving) _fitToRadius();
        }
      } else {
        if (_radarController.isAnimating) {
          _radarController.stop();
          _radarController.reset();
        }
        if (_radius != AppConstants.radiusOptions.first) {
          setState(() => _radius = AppConstants.radiusOptions.first);
          _stale = true;
        }
      }
    }));

    _workers.add(ever(_guest.nearestActive, (bool active) {
      if (!mounted) return;
      if (active) {
        _updateNearestFocus();
      } else {
        _nearestCircleAnim = null;
        _nearestCircleController.stop();
        _guest.clearNearest();
        if (_mapReady) {
          _updateNativeRadiusCircle();
          _fitToRadius();
        }
        _buildMarkers(animate: false);
      }
    }));
    _workers.add(ever(_guest.nearestFocusIndex, (_) {
      if (!mounted) return;
      if (_guest.nearestActive.value) _updateNearestFocus();
    }));

    _mapActive = !mapShouldPause.value;
    if (isSearchActive) {
      _preSearchRadius = _radius;
      _radius = AppConstants.radiusOptions.last;
    }
    if (_locationCtrl.effectiveDistrict != null && !mapShouldPause.value) {
      _precomputeCircleCache();
      _loadNearby(keepNearest: true);
    } else {
      _stale = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final w in _workers) {
      w.dispose();
    }
    _mapPauseWorker?.dispose();
    if (_guest.nearestActive.value) _guest.nearestActive.value = false;
    _guest.clearNearest();
    _radarController.dispose();
    _nearestCircleController.dispose();
    _revealTimer?.cancel();
    _loadNearbyDebounceTimer?.cancel();
    _cameraIdleDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_guest.isLoading.value && _radarController.isAnimating) {
        _radarController.stop();
        _radarController.reset();
      }
    }
  }

  LatLng get _searchCenter => searchCenter;

  void _fitToRadius() {
    if (!_mapReady || !mounted) return;
    final center = _searchCenter;
    _cameraCenter = center;
    _precomputeCircleCache();
    _animateTo(center, _zoomForRadius(_radius, center.latitude));
    _updateNativeRadiusCircle();
  }

  void _animateNearestCircle(double targetKm, LatLng center) {
    final begin = _nearestCircleAnim?.value ?? _radius;
    _nearestCircleCenter = center;
    _nearestCircleAnim = Tween<double>(begin: begin, end: targetKm).animate(
      CurvedAnimation(parent: _nearestCircleController, curve: Curves.easeOut),
    );
    _nearestCircleController
      ..reset()
      ..forward();
  }

  void _updateNearestFocus() {
    final stays = _guest.nearestStays;
    final idx = _guest.nearestFocusIndex.value;
    if (idx < 0 || idx >= stays.length) return;
    final focused = stays[idx];
    final target = LatLng(focused.latitude, focused.longitude);
    _animateNearestCircle(AppConstants.nearestFocusRadiusKm, target);
    _animateTo(target, _zoomForRadius(AppConstants.nearestFocusRadiusKm, target.latitude));
    _buildMarkers(animate: false);
  }

  void _openNearestConfirm() {
    final district = _locationCtrl.effectiveDistrict;
    if (district == null) return;
    final center = _searchCenter;
    NearestConfirmSheet.show(
      context,
      itemLabel: 'stays',
      palette: StayColors.palette,
      onConfirm: () => _guest.loadNearest(center.latitude, center.longitude, district.id),
    );
  }

  Future<void> _initNativeCircle() async {
    final ctrl = _mapController;
    if (ctrl == null || !mounted) return;
    _precomputeCircleCache();
    await ctrl.addGeoJsonSource('radius-source', _circleCache[_radius]!);
    await ctrl.addFillLayer('radius-source', 'radius-fill', FillLayerProperties(fillColor: AppColors.stayHex, fillOpacity: 0.06));
    await ctrl.addLineLayer('radius-source', 'radius-glow',
        LineLayerProperties(lineColor: AppColors.stayHex, lineWidth: 6.0, lineOpacity: 0.15, lineBlur: 3.0));
    await ctrl.addLineLayer('radius-source', 'radius-border',
        LineLayerProperties(lineColor: AppColors.stayHex, lineWidth: 1.8, lineOpacity: 0.65));
  }

  void _updateNativeRadiusCircle() {
    final ctrl = _mapController;
    if (ctrl == null) return;
    ctrl.setGeoJsonSource('radius-source', _circleCache[_radius] ?? _buildCircleGeojson(_searchCenter, _radius));
  }

  Future<void> _initNativeUserDot() async {
    final ctrl = _mapController;
    final loc = _locationCtrl.userLocation.value;
    if (ctrl == null || loc == null || !mounted) return;
    _nativeUserDot = await ctrl.addCircle(CircleOptions(
      geometry: loc,
      circleRadius: 8.0,
      circleColor: AppColors.userDotHex,
      circleOpacity: 1.0,
      circleStrokeColor: AppColors.hexOf(AppColors.textWhite),
      circleStrokeWidth: 2.5,
    ));
  }

  void _updateNativeUserDot() {
    final ctrl = _mapController;
    final dot = _nativeUserDot;
    final loc = _locationCtrl.userLocation.value;
    if (ctrl == null || dot == null || loc == null) return;
    ctrl.updateCircle(dot, CircleOptions(geometry: loc));
  }

  double _zoomForRadius(double radiusKm, double lat) {
    const earthCircumference = 2 * pi * 6378137.0;
    const tileSize = 512.0;
    final usablePx = _screenSize.width > 0 ? _screenSize.width : 480.0;
    final metersPerPxAtZ0 = earthCircumference * cos(lat * pi / 180) / tileSize;
    final targetMetersPerPx = (radiusKm * 1000 * 2) / (usablePx * 0.93);
    final zoom = log(metersPerPxAtZ0 / targetMetersPerPx) / log(2);
    return zoom.clamp(9.0, 17.0);
  }

  void _animateTo(LatLng target, double zoom) {
    if (!_mapReady || _mapController == null || !mounted) return;
    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  void _onStyleLoaded() async {
    if (_styleLoaded) return;
    _styleLoaded = true;
    if (!mounted) return;
    await _initNativeCircle();
    await _initNativeUserDot();
    if (!mounted) return;
    _mapReady = true;
    setState(() {});
    _buildMarkers(animate: false);
    if (_guest.nearestActive.value) {
      _updateNearestFocus();
    } else {
      _fitToRadius();
    }
  }

  void _onCameraIdle() {
    _cameraIdleDebounce?.cancel();
    _cameraIdleDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _isCameraMoving = false;
      if ((_currentZoom - _lastClusterZoom).abs() >= 0.4) {
        _lastClusterZoom = _currentZoom;
        _buildMarkers(animate: false);
      }
      if (!_pinsVisible) setState(() => _pinsVisible = true);
    });
  }

  void _loadNearby({bool keepNearest = false}) {
    if (!keepNearest && _guest.nearestActive.value) _guest.nearestActive.value = false;
    _reloadPending = true;
    _loadNearbyDebounceTimer?.cancel();
    _loadNearbyDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await _executeLoadNearby();
    });
  }

  Future<void> _executeLoadNearby() async {
    if (_loadingNearby) return;
    final district = _locationCtrl.effectiveDistrict;
    if (district == null) {
      _reloadPending = false;
      return;
    }
    if (mapShouldPause.value) {
      _stale = true;
      _reloadPending = false;
      return;
    }
    _stale = false;
    _loadingNearby = true;
    try {
      _revealTimer?.cancel();
      _radarController.repeat();
      final userMarker = _buildUserMarkerData();
      _markerData = userMarker != null ? [userMarker] : [];
      _revealedCount = _markerData.length;
      setState(() {});
      final center = _searchCenter;
      await _guest.loadNearby(center.latitude, center.longitude, _radius, district.id);
      if (!mounted) return;
      _radarController.stop();
      _radarController.reset();
      _buildMarkers();
    } finally {
      _loadingNearby = false;
      _reloadPending = false;
      _hasLoadedOnce = true;
    }
  }

  _MapMarkerData? _buildUserMarkerData() {
    final loc = _locationCtrl.userLocation.value;
    if (loc == null) return null;
    return _MapMarkerData(
      position: loc,
      width: 120,
      height: 120,
      isUser: true,
      widget: AnimatedBuilder(
        animation: _radarController,
        builder: (context2, child2) => CustomPaint(
          painter: _RadarPainter(progress: _radarController.value, color: AppColors.userDot),
        ),
      ),
    );
  }

  void _buildMarkers({bool animate = true}) {
    final data = <_MapMarkerData>[];

    final userMarker = _buildUserMarkerData();
    if (userMarker != null) data.add(userMarker);

    final stays = _guest.nearbyStays.toList()..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final filtered = stays.take(AppConstants.maxMapMarkers).toList();
    final clusters = _mapReady ? _computeClusters(filtered) : filtered.map(_Cluster.new).toList();

    for (final cluster in clusters) {
      final count = cluster.stays.length;
      final rep = cluster.representative;

      if (count == 1) {
        final priceText = rep.minPricePerNight != null ? _pinPrice(rep.minPricePerNight!) : 'Stay';
        data.add(_MapMarkerData(
          position: cluster.center,
          width: _chipWidth(priceText),
          height: 34,
          widget: GestureDetector(
            onTap: () => _showDetail(rep.id),
            child: _AnimatedPin(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: StayColors.accent, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Center(
                  child: Text(
                    priceText,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: StayColors.accentDark),
                  ),
                ),
              ),
            ),
          ),
        ));
      } else {
        data.add(_MapMarkerData(
          position: cluster.center,
          width: 48,
          height: 48,
          widget: GestureDetector(
            onTap: () => _zoomToCluster(cluster),
            child: _AnimatedPin(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: StayColors.gradient,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ));
      }
    }

    if (_guest.nearestActive.value) {
      final nearest = _guest.nearestStays;
      final idx = _guest.nearestFocusIndex.value;
      if (idx >= 0 && idx < nearest.length) {
        final focused = nearest[idx];
        final priceText = focused.minPricePerNight != null ? _pinPrice(focused.minPricePerNight!) : 'Stay';
        data.add(_MapMarkerData(
          position: LatLng(focused.latitude, focused.longitude),
          width: _chipWidth(priceText) + 10,
          height: 38,
          widget: GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': focused.id, 'distanceKm': focused.distanceKm}),
            child: _AnimatedPin(
              child: Container(
                decoration: BoxDecoration(
                  gradient: StayColors.gradient,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: Center(
                  child: Text(
                    priceText,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ));
      }
    }

    _revealTimer?.cancel();
    _markerData = data;

    if (!animate || data.isEmpty) {
      setState(() => _revealedCount = data.length);
      return;
    }

    final userCount = _locationCtrl.userLocation.value != null ? 1 : 0;
    setState(() => _revealedCount = userCount);

    if (data.length <= userCount) return;

    int i = userCount;
    _revealTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      i++;
      setState(() => _revealedCount = i);
      if (i >= data.length) timer.cancel();
    });
  }

  void _zoomToCluster(_Cluster cluster) {
    double minPx = double.infinity, maxPx = double.negativeInfinity;
    double minPy = double.infinity, maxPy = double.negativeInfinity;
    for (final l in cluster.stays) {
      final sinLat = sin(l.latitude * pi / 180);
      final py = 0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi);
      final px = (l.longitude + 180) / 360;
      if (px < minPx) minPx = px;
      if (px > maxPx) maxPx = px;
      if (py < minPy) minPy = py;
      if (py > maxPy) maxPy = py;
    }
    final span = max(maxPx - minPx, maxPy - minPy);
    final targetZoom = span < 1e-10
        ? (_currentZoom + 2.5).clamp(10.0, 18.0)
        : (log(144.0 / (span * 512.0)) / log(2.0)).clamp(10.0, 18.0);
    _animateTo(cluster.center, targetZoom);
  }

  List<_Cluster> _computeClusters(List<StayNearbyModel> stays) {
    if (stays.isEmpty) return [];
    const cellSize = 48.0;
    final scale = 512.0 * pow(2.0, _currentZoom);
    final grid = <(int, int), List<_Cluster>>{};
    final anchors = <_Cluster, (double, double)>{};
    final result = <_Cluster>[];
    for (final stay in stays) {
      final sinLat = sin(stay.latitude * pi / 180);
      final mpy = 0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi);
      final spx = (stay.longitude + 180) / 360 * scale;
      final spy = mpy * scale;
      final gi = (spx / cellSize).floor();
      final gj = (spy / cellSize).floor();
      _Cluster? target;
      double bestDist = double.infinity;
      for (var di = -1; di <= 1; di++) {
        for (var dj = -1; dj <= 1; dj++) {
          for (final c in grid[(gi + di, gj + dj)] ?? const []) {
            final (ax, ay) = anchors[c]!;
            final dx = spx - ax, dy = spy - ay;
            final d = sqrt(dx * dx + dy * dy);
            if (d <= cellSize && d < bestDist) {
              bestDist = d;
              target = c;
            }
          }
        }
      }
      if (target != null) {
        target.stays.add(stay);
      } else {
        final c = _Cluster(stay);
        anchors[c] = (spx, spy);
        grid.putIfAbsent((gi, gj), () => []).add(c);
        result.add(c);
      }
    }
    return result;
  }

  static List<LatLng> _circlePolygonPoints(LatLng center, double radiusKm) {
    const steps = 64;
    const earthRadius = 6378137.0;
    final latRad = center.latitude * pi / 180;
    final points = <LatLng>[];
    for (int i = 0; i <= steps; i++) {
      final angle = 2 * pi * i / steps;
      final dLat = (radiusKm * 1000 * cos(angle)) / earthRadius * (180 / pi);
      final dLng = (radiusKm * 1000 * sin(angle)) / (earthRadius * cos(latRad)) * (180 / pi);
      points.add(LatLng(center.latitude + dLat, center.longitude + dLng));
    }
    return points;
  }

  Map<String, dynamic> _buildCircleGeojson(LatLng center, double radiusKm) {
    final pts = _circlePolygonPoints(center, radiusKm);
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Polygon',
            'coordinates': [pts.map((p) => [p.longitude, p.latitude]).toList()]
          },
          'properties': <String, dynamic>{}
        }
      ]
    };
  }

  void _precomputeCircleCache() {
    _circleCache.clear();
    final center = _searchCenter;
    for (final r in AppConstants.radiusOptions) {
      _circleCache[r] = _buildCircleGeojson(center, r);
    }
  }

  double _radiusPixelRadius(Size screenSize) {
    final cam = _cameraCenter ?? _searchCenter;
    final edge = _circlePolygonPoints(_searchCenter, _radius)[0];
    final centerPx = _projectToScreen(_searchCenter, cam, _currentZoom, screenSize);
    final edgePx = _projectToScreen(edge, cam, _currentZoom, screenSize);
    return (centerPx - edgePx).distance;
  }

  static Offset _radiusTopAnchor(Offset center, double radiusPx, Size screenSize) {
    const topMargin = 150.0;
    final insetRadius = radiusPx * 0.65;
    final maxUpward = (center.dy - topMargin).clamp(0.0, insetRadius);
    return Offset(center.dx, center.dy - maxUpward);
  }

  static Offset _projectToScreen(LatLng ll, LatLng center, double zoom, Size screenSize) {
    const tileSize = 512.0;
    final scale = tileSize * pow(2.0, zoom);
    double wx(double lng) => (lng + 180) / 360;
    double wy(double lat) {
      final s = sin(lat * pi / 180);
      return (1 - log((1 + s) / (1 - s)) / (2 * pi)) / 2;
    }

    final dx = (wx(ll.longitude) - wx(center.longitude)) * scale;
    final dy = (wy(ll.latitude) - wy(center.latitude)) * scale;
    return Offset(screenSize.width / 2 + dx, screenSize.height / 2 + dy);
  }

  double _chipWidth(String text) => (text.length * 9.0 + 26).clamp(52.0, 90.0);

  String _pinPrice(int price) {
    if (price >= 100000) {
      final l = price / 100000;
      return l == l.truncateToDouble() ? '₹${l.toInt()}L' : '₹${l.toStringAsFixed(1)}L';
    }
    if (price >= 1000) {
      final t = price ~/ 1000;
      final h = price % 1000;
      return h == 0 ? '₹${t}k' : '₹$t,${h.toString().padLeft(3, '0')}';
    }
    return '₹$price';
  }

  void _showDetail(String id) {
    final stay = _guest.nearbyStays.firstWhereOrNull((l) => l.id == id);
    if (stay == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StayBottomSheet(stay: stay),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _screenSize = constraints.biggest;
          return Stack(
            children: [
              if (_mapActive)
                RepaintBoundary(
                  child: MapLibreMap(
                    styleString: "assets/map_style.json",
                    initialCameraPosition: CameraPosition(target: _searchCenter, zoom: 13.0),
                    minMaxZoomPreference: const MinMaxZoomPreference(8, 18),
                    compassEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    myLocationEnabled: false,
                    trackCameraPosition: true,
                    attributionButtonMargins: const Point(-200.0, 0.0),
                    onMapCreated: (MapLibreMapController ctrl) {
                      _mapController = ctrl;
                    },
                    onStyleLoadedCallback: _onStyleLoaded,
                    onCameraMove: (CameraPosition pos) {
                      _currentZoom = pos.zoom;
                      _cameraCenter = pos.target;
                      _isCameraMoving = true;
                      _cameraIdleDebounce?.cancel();
                      if (mounted && _pinsVisible) setState(() => _pinsVisible = false);
                    },
                    onCameraIdle: _onCameraIdle,
                  ),
                ),
              if (!_mapActive || !_mapReady || _locationCtrl.userLocation.value == null) _buildMapShimmer(),
              if (_mapReady)
                IgnorePointer(
                  ignoring: !_pinsVisible,
                  child: AnimatedOpacity(
                    opacity: _pinsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 100),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ..._markerData.take(_revealedCount).map((d) {
                          final sp = _projectToScreen(
                            d.position,
                            _cameraCenter ?? _searchCenter,
                            _currentZoom,
                            constraints.biggest,
                          );
                          return Positioned(
                            left: sp.dx - d.width / 2,
                            top: sp.dy - d.height / 2,
                            width: d.width,
                            height: d.height,
                            child: d.widget,
                          );
                        }),
                        if (_guest.nearbyStays.isEmpty && !_loadingNearby && !_reloadPending && _hasLoadedOnce)
                          Obx(() {
                            if (_guest.nearestActive.value) return const SizedBox.shrink();
                            final radiusPx = _radiusPixelRadius(constraints.biggest);
                            final sp = _projectToScreen(
                              _searchCenter,
                              _cameraCenter ?? _searchCenter,
                              _currentZoom,
                              constraints.biggest,
                            );
                            final anchor = _radiusTopAnchor(sp, radiusPx, constraints.biggest);
                            return Positioned(
                              left: anchor.dx,
                              top: anchor.dy,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, -1.0),
                                child: EmptyRadiusHint(
                                  label: 'No stays in this radius — try Nearest',
                                  circleRadiusPx: radiusPx,
                                  palette: StayColors.palette,
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Container(
                      decoration: const BoxDecoration(gradient: StayColors.gradient),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                          child: Column(children: [
                            Row(children: [
                              _buildBackButton(),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: LocationPill(palette: StayColors.palette),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: _buildRadiusChips()),
                              const SizedBox(width: 10),
                              _buildSearchToggleButton(),
                            ]),
                          ]),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12, left: 20, right: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [_buildLocationFab()],
                      ),
                    ),
                  ],
                ),
              ),
              Obx(() {
                if (!_guest.nearestActive.value) {
                  return Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_guest.nearbyStays.isNotEmpty) _buildViewListButton() else const SizedBox.shrink(),
                        AddListingShortcutButton(
                          label: 'Find Nearest',
                          icon: Icons.travel_explore_rounded,
                          gradient: StayColors.gradient,
                          onTap: _openNearestConfirm,
                        ),
                      ],
                    ),
                  );
                }
                return Positioned(
                  bottom: 86,
                  left: 20,
                  right: 20,
                  child: _buildNearestPreviewCard(),
                );
              }),
              Obx(() {
                if (!_guest.nearestActive.value) return const SizedBox.shrink();
                final total = _guest.nearestStays.length;
                final idx = _guest.nearestFocusIndex.value;
                return Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: NearestControlBar(
                    current: idx,
                    total: total,
                    onPrev: () {
                      if (idx > 0) _guest.nearestFocusIndex.value = idx - 1;
                    },
                    onNext: () {
                      if (idx < total - 1) _guest.nearestFocusIndex.value = idx + 1;
                    },
                    onCancel: () => _guest.nearestActive.value = false,
                    palette: StayColors.palette,
                  ),
                );
              }),
              const Positioned(
                bottom: 4,
                left: 8,
                child: Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 9, color: Colors.black45)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () {
        if (_guest.isLoadingNearest.value) return;
        Navigator.of(context).maybePop();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: const Icon(Icons.chevron_left_rounded, color: StayColors.accentDark, size: 24),
      ),
    );
  }

  Widget _buildSearchToggleButton() {
    return Obx(() => GestureDetector(
          onTap: searchResolving ? null : () => onSearchToggleTap(context),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSearchActive ? AppColors.error : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: searchResolving
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: StayColors.accentDark),
                  )
                : (isSearchActive
                    ? const Text('Cancel',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded, color: StayColors.accentDark, size: 15),
                          SizedBox(width: 5),
                          Text('Search',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: StayColors.accentDark)),
                        ],
                      )),
          ),
        ));
  }

  Widget _buildRadiusChips() {
    final radii = AppConstants.radiusOptions;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: radii.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final active = _radius == r;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                _guest.nearbyStays.clear();
                setState(() => _radius = r);
                if (isSearchActive) _preSearchRadius = r;
                _loadNearby();
                if (_mapReady) _fitToRadius();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 28,
                margin: EdgeInsets.only(right: i < radii.length - 1 ? 4 : 0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: active ? StayColors.gradient : null,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: active
                      ? [BoxShadow(color: StayColors.accent.withValues(alpha: 0.32), blurRadius: 8, offset: const Offset(0, 3))]
                      : null,
                ),
                child: Text('${r.toInt()} km',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.textLight,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLocationFab() {
    return GestureDetector(
      onTap: () {
        _locationCtrl.resetBrowsing();
        _precomputeCircleCache();
        _loadNearby();
        if (_mapReady) _fitToRadius();
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.my_location_rounded, color: StayColors.accentDark, size: 22),
      ),
    );
  }

  Widget _buildNearestPreviewCard() {
    final stays = _guest.nearestStays;
    final idx = _guest.nearestFocusIndex.value;
    if (idx < 0 || idx >= stays.length) return const SizedBox.shrink();
    return _nearbyRow(stays[idx], elevated: true);
  }

  Widget _nearbyRow(StayNearbyModel s, {bool elevated = false}) {
    return NearbyItemRow(
      thumbnailUrl: s.thumbnailUrl,
      tag: 'FOR STAY',
      title: s.title,
      subtitle: [
        if (s.stayTypeName != null && s.stayTypeName!.isNotEmpty) s.stayTypeName!,
        '${s.distanceKm.toStringAsFixed(1)} km',
      ].join(' · '),
      caption: 'FROM',
      value: s.minPricePerNight != null ? BrowseItem.inr(s.minPricePerNight!) : 'On request',
      unit: s.minPricePerNight != null ? '/night' : '',
      palette: StayColors.palette,
      placeholderIcon: Iconsax.building_4,
      elevated: elevated,
      onTap: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': s.id, 'distanceKm': s.distanceKm}),
    );
  }

  Widget _buildViewListButton() {
    final count = _guest.nearbyStays.length;
    return GestureDetector(
      onTap: _showListSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: StayColors.accent, width: 1.4),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.format_list_bulleted_rounded, color: StayColors.accentDark, size: 16),
            const SizedBox(width: 6),
            const Text('View List',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: StayColors.accentDark)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: StayColors.accent, borderRadius: BorderRadius.circular(10)),
              child: Text('$count',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showListSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (sheetContext, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: StayColors.gradient,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Obx(() {
                              final count = _guest.nearbyStays.length;
                              return Text('$count Stay${count == 1 ? '' : 's'} Nearby',
                                  style: const TextStyle(
                                      fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white));
                            }),
                            GestureDetector(
                              onTap: () => Navigator.pop(sheetContext),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Obx(() {
                    final items = _guest.nearbyStays.toList()..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
                    return ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.only(bottom: 16 + AppInsets.bottomViewPadding(context)),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _nearbyRow(items[i]),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(color: AppColors.shimmerBase),
    );
  }
}

class _MapMarkerData {
  final LatLng position;
  final Widget widget;
  final double width;
  final double height;
  final bool isUser;

  _MapMarkerData({
    required this.position,
    required this.widget,
    required this.width,
    required this.height,
    this.isUser = false,
  });
}

class _Cluster {
  final List<StayNearbyModel> stays;
  _Cluster(StayNearbyModel first) : stays = [first];

  LatLng get center => LatLng(
        stays.map((l) => l.latitude).reduce((a, b) => a + b) / stays.length,
        stays.map((l) => l.longitude).reduce((a, b) => a + b) / stays.length,
      );

  StayNearbyModel get representative =>
      stays.reduce((a, b) => (a.minPricePerNight ?? 999999999) <= (b.minPricePerNight ?? 999999999) ? a : b);
}

class _AnimatedPin extends StatefulWidget {
  final Widget child;
  const _AnimatedPin({required this.child});
  @override
  State<_AnimatedPin> createState() => _AnimatedPinState();
}

class _AnimatedPinState extends State<_AnimatedPin> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    const maxRadius = 52.0;

    for (int i = 0; i < 3; i++) {
      final p = (progress + i / 3.0) % 1.0;
      final radius = maxRadius * p;
      final opacity = 1.0 - p;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.12)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}
