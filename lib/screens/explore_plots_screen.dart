import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_constants.dart';
import '../config/app_map_state.dart';
import '../config/app_tabs.dart';
import '../controllers/app_feature_controller.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/plot_controller.dart';
import '../models/plot_model.dart';
import '../utils/app_toast.dart';
import '../widgets/empty_radius_hint.dart';
import '../widgets/location_switch_sheet.dart';
import '../widgets/near_me_plot_detail_sheet.dart';
import '../widgets/near_me_tour_card.dart';
import '../widgets/near_me_tour_state.dart';

class ExplorePlotsScreen extends StatefulWidget {
  const ExplorePlotsScreen({super.key});
  @override
  State<ExplorePlotsScreen> createState() => _ExplorePlotsScreenState();
}

class _ExplorePlotsScreenState extends State<ExplorePlotsScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Map ──────────────────────────────────────────────────────────────────
  MapLibreMapController? _mapController;
  double _currentZoom = 13.0;
  Circle? _nativeUserDot;
  final _circleCache = <double, Map<String, dynamic>>{};
  bool _pinsVisible = true;
  bool _styleLoaded = false;
  LatLng? _cameraCenter;
  bool _mapActive = true;
  bool _isCameraMoving = false;
  Timer? _cameraIdleDebounce;
  Worker? _mapPauseWorker;

  // ── State ─────────────────────────────────────────────────────────────────
  final _plotCtrl     = Get.find<PlotController>();
  final _locationCtrl = Get.find<LocationController>();
  final _auth         = Get.find<AuthController>();
  Worker? _locationWorker;
  Worker? _locationRefreshedWorker;
  Worker? _userLocationWorker;
  Worker? _postedWorker;
  Worker? _loadingWorker;
  Worker? _refreshWorker;
  Worker? _tabWorker;
  Worker? _filterResetWorker;
  Worker? _browsingWorker;
  bool _stale = false;
  List<_MapMarkerData> _markerData = [];
  double _radius = 1.0;
  double _lastClusterZoom = 0;
  bool _mapReady = false;
  bool _checkingPermission = false;
  Timer? _loadNearbyDebounceTimer;
  String? _selectedPlotType;
  bool _loadingNearby = false;
  // Spans from the moment a reload is requested (radius/location/filter change) through
  // the debounce wait and the fetch itself — wider than `_loadingNearby`, which only covers
  // the fetch. Without this, a radius-chip tap clears `nearbyPlots` synchronously but
  // `_loadingNearby` doesn't flip true until the 300ms debounce fires, leaving a gap where
  // the empty-radius hint would flash over the previous radius's still-visible pins.
  bool _reloadPending = false;
  // Guards the empty-radius hint against showing before a real fetch has ever completed —
  // on a fresh install, _loadingNearby/_reloadPending both stay false for several seconds
  // while GPS + district resolution run (see LocationController._initLocation), during which
  // nearbyPlots is simply empty because nothing has been requested yet, not because a
  // search came back with zero results.
  bool _hasLoadedOnce = false;
  final _audioPlayer = AudioPlayer();
  int _revealedCount = 0;
  Timer? _revealTimer;
  late AnimationController _radarController;

  // "Find Near Me" — a plain field, never a GetX singleton (mapShouldPause is
  // global and shared with Explore Rooms; this must stay screen-local so the
  // two tours can never see or clobber each other).
  final _tour = NearMeTour<NearMePlotModel>();

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    WidgetsBinding.instance.addObserver(this);

    // Trigger data load whenever LocationController resolves the district.
    _locationWorker = ever(_locationCtrl.selectedDistrict, (_) {
      if (_locationCtrl.selectedDistrict.value != null) {
        if (_auth.tabIndex.value == AppTabs.plots && !mapShouldPause.value) {
          _precomputeCircleCache();
          _loadNearby();
          if (_mapReady && !_isCameraMoving) _fitToRadius();
        } else {
          _stale = true;
        }
      }
    });

    // District-switch feature: reload + refit whenever the manually-browsed
    // city changes — this covers both picking a city (own district or a
    // browsed one) and resetting back to the real location (browsingCity
    // becomes null again), mirroring _locationWorker above.
    _browsingWorker = ever(_locationCtrl.browsingCity, (_) {
      if (_auth.tabIndex.value == AppTabs.plots && !mapShouldPause.value) {
        _precomputeCircleCache();
        _loadNearby();
        // Unconditional, unlike the _isCameraMoving-gated calls elsewhere:
        // this is a deliberate, explicit location pick by the user, not a
        // passive GPS update — the camera must always move to it, even if
        // it still thinks a previous gesture/animation is in flight.
        if (_mapReady) _fitToRadius();
      } else {
        _stale = true;
      }
    });

    // Fit camera when a fresh GPS position arrives (GPS on/off/on, app resume,
    // or first fix). locationLoading is no longer used by this screen.
    // Data reload is NOT this worker's job — _locationWorker (above) reloads
    // whenever selectedDistrict actually changes. LocationController fires
    // this trigger at most once per location-resolution event (see its
    // _initLocation()/_refreshLocation() — refinement updates userLocation
    // silently without re-firing), so a single _fitToRadius() here is
    // always the right amount of camera movement, never redundant.
    _locationRefreshedWorker = ever(_locationCtrl.locationRefreshedTrigger, (_) {
      if (!mounted) return;
      if (_locationCtrl.browsingCity.value == null) {
        _precomputeCircleCache();
        if (_mapReady) {
          _updateNativeRadiusCircle();
          _fitToRadius();
        }
      }
      setState(() {});
    });

    // Propagate user-dot position updates to the map.
    _userLocationWorker = ever(_locationCtrl.userLocation, (_) {
      if (!mounted) return;
      if (_mapReady) {
        final loc = _locationCtrl.userLocation.value;
        if (loc != null) {
          if (_nativeUserDot == null) _initNativeUserDot();
          else _updateNativeUserDot();
          // Keep radius circle centred on user when no city is manually selected.
          if (_locationCtrl.browsingCity.value == null) {
            _precomputeCircleCache();
            _updateNativeRadiusCircle();
          }
          // Patch user marker position in overlay without re-animating listing pins.
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
    });

    _postedWorker = ever(_plotCtrl.plotPostedTrigger, (_) {
      _stale = true;
      if (_auth.tabIndex.value == AppTabs.plots && !mapShouldPause.value) _loadNearby();
    });
    _refreshWorker = ever(_plotCtrl.exploreRefreshTrigger, (_) {
      _stale = true;
      if (_locationCtrl.effectiveDistrict != null &&
          _auth.tabIndex.value == AppTabs.plots && !mapShouldPause.value) {
        _loadNearby();
      }
    });
    _filterResetWorker = ever(_plotCtrl.filterResetTrigger, (_) {
      if (!mounted) return;
      // Manual browsing (own-district or cross-district) intentionally
      // survives tab switches — only the plot-type filter resets here.
      setState(() { _selectedPlotType = null; });
      if (_mapReady) {
        _precomputeCircleCache();
        _updateNativeRadiusCircle();
        _fitToRadius();
      }
    });
    _loadingWorker = ever(_plotCtrl.isLoading, (loading) {
      if (!loading && _radarController.isAnimating) {
        _radarController.stop();
        _radarController.reset();
      }
    });

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
        if (_auth.tabIndex.value == AppTabs.plots && _stale) _loadNearby();
      }
    });

    _tabWorker = ever(_auth.tabIndex, (index) {
      if (index == AppTabs.plots) {
        if (_stale && !mapShouldPause.value) {
          _loadNearby();
          if (_mapReady && !_isCameraMoving) _fitToRadius();
        }
      } else {
        if (_radarController.isAnimating) {
          _radarController.stop();
          _radarController.reset();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationWorker?.dispose();
    _browsingWorker?.dispose();
    _locationRefreshedWorker?.dispose();
    _userLocationWorker?.dispose();
    _postedWorker?.dispose();
    _loadingWorker?.dispose();
    _refreshWorker?.dispose();
    _mapPauseWorker?.dispose();
    _tabWorker?.dispose();
    _filterResetWorker?.dispose();
    _radarController.dispose();
    _revealTimer?.cancel();
    _loadNearbyDebounceTimer?.cancel();
    _cameraIdleDebounce?.cancel();
    _audioPlayer.dispose();
    if (_mapController != null && _nativeUserDot != null) {
      _mapController!.removeCircle(_nativeUserDot!);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionOnResume();
      _locationCtrl.refreshOnResume();
      Get.find<AppFeatureController>().refresh();
      if (!_plotCtrl.isLoading.value && _radarController.isAnimating) {
        _radarController.stop();
        _radarController.reset();
      }
    }
  }

  Future<void> _checkPermissionOnResume() async {
    if (_checkingPermission) return;
    _checkingPermission = true;
    try {
      final permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        return;
      }
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Location Required',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            content: const Text(
                'Bakhli needs location access to show plots near you. Please enable it in Settings.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Geolocator.openAppSettings();
                },
                child: const Text('Open Settings',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    } finally {
      _checkingPermission = false;
    }
  }

  LatLng get _searchCenter {
    final browsingCity = _locationCtrl.browsingCity.value;
    if (browsingCity?.latitude != null && browsingCity?.longitude != null) {
      return LatLng(browsingCity!.latitude!, browsingCity.longitude!);
    }
    final loc = _locationCtrl.userLocation.value;
    if (loc != null) return loc;
    final city = _locationCtrl.autoCity.value;
    if (city?.latitude != null && city?.longitude != null) {
      return LatLng(city!.latitude!, city.longitude!);
    }
    return const LatLng(AppConstants.fallbackLat, AppConstants.fallbackLng);
  }

  void _fitToRadius() {
    // True single choke point for camera control — several workers
    // (location/browsing/refresh/filter-reset/tab) and the recenter FAB all
    // call this directly, not just _loadNearby(). Guarding only _loadNearby()
    // left this callable while a tour is active, silently snapping the
    // camera to the default radius view without ending the tour.
    if (_tour.isActive) return;
    if (!_mapReady || !mounted) return;
    final center = _searchCenter;
    _cameraCenter = center;
    _precomputeCircleCache();      // always rebuild for current center before drawing
    _animateTo(center, _zoomForRadius(_radius, center.latitude));
    _updateNativeRadiusCircle();
  }

  double _zoomForRadius(double radiusKm, double lat) {
    const earthCircumference = 2 * pi * 6378137.0;
    const tileSize = 512.0;
    const usablePx = 480.0;
    final metersPerPxAtZ0 = earthCircumference * cos(lat * pi / 180) / tileSize;
    final targetMetersPerPx = (radiusKm * 1000 * 2) / (usablePx * 0.80);
    final zoom = log(metersPerPxAtZ0 / targetMetersPerPx) / log(2);
    return zoom.clamp(10.0, 17.0);
  }

  void _animateTo(LatLng target, double zoom) {
    if (!_mapReady || _mapController == null || !mounted) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(target, zoom),
    );
  }

  void _onStyleLoaded() async {
    if (_styleLoaded) return;
    _styleLoaded = true;
    if (!mounted) return;
    // Initialise native layers BEFORE marking map ready.
    // Any worker that checks _mapReady=true will find radius-source + user dot already
    // on the map, so setGeoJsonSource / updateCircle calls won't silently fail.
    await _initNativeCircle();
    await _initNativeUserDot();
    if (!mounted) return;
    _mapReady = true;
    setState(() {});
    if (_tour.isActive) {
      // Resuming into an active tour (e.g. back from "View Details", My
      // Plots, Chat — any route in MapPauseObserver's _pauseRoutes) — land
      // the camera back on the exact pin/index the tour was at, not the
      // default radius view. Tour data itself already survived (this is a
      // plain field), only the map's native layers were torn down.
      _flyToTourResult(_tour.currentIndex);
    } else {
      _buildMarkers(animate: false);
      _fitToRadius();
    }
  }

  Future<void> _initNativeCircle() async {
    final ctrl = _mapController;
    if (ctrl == null || !mounted) return;
    _precomputeCircleCache();
    await ctrl.addGeoJsonSource('radius-source', _circleCache[_radius]!);
    await ctrl.addFillLayer('radius-source', 'radius-fill',
        FillLayerProperties(fillColor: '#92400e', fillOpacity: 0.06));
    await ctrl.addLineLayer('radius-source', 'radius-glow',
        LineLayerProperties(lineColor: '#92400e', lineWidth: 6.0,
            lineOpacity: 0.15, lineBlur: 3.0));
    await ctrl.addLineLayer('radius-source', 'radius-border',
        LineLayerProperties(lineColor: '#92400e', lineWidth: 1.8,
            lineOpacity: 0.65));
  }

  void _updateNativeRadiusCircle() {
    final ctrl = _mapController;
    if (ctrl == null) return;
    ctrl.setGeoJsonSource('radius-source',
        _circleCache[_radius] ?? _buildCircleGeojson(_searchCenter, _radius));
  }

  Future<void> _initNativeUserDot() async {
    final ctrl = _mapController;
    final loc = _locationCtrl.userLocation.value;
    if (ctrl == null || loc == null || !mounted) return;
    _nativeUserDot = await ctrl.addCircle(CircleOptions(
      geometry: loc,
      circleRadius: 8.0,
      circleColor: '#92400E',
      circleOpacity: 1.0,
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 2.5,
    ));
    if (!_mapActive) return;
  }

  void _updateNativeUserDot() {
    final ctrl = _mapController;
    final dot = _nativeUserDot;
    final loc = _locationCtrl.userLocation.value;
    if (ctrl == null || dot == null || loc == null) return;
    ctrl.updateCircle(dot, CircleOptions(geometry: loc));
  }

  void _onCameraIdle() {
    // Debounce: MapLibre fires onCameraIdle during brief pauses in inertial
    // scroll. Without this, markers flash at an intermediate position then
    // disappear again as the camera resumes — that's the visible "shake".
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

  void _loadNearby() {
    // Single choke point: while a "Find Near Me" tour is active, none of the
    // six workers above (location/browsing/posted/refresh/filter-reset/tab)
    // may clobber the tour's markers/camera. Mark stale so a real reload
    // still happens the moment the tour ends (_cancelTour) or the map is
    // rebuilt after a pause (_onStyleLoaded's resume branch).
    if (_tour.isActive) { _stale = true; return; }
    _reloadPending = true;
    _loadNearbyDebounceTimer?.cancel();
    _loadNearbyDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await _executeLoadNearby();
    });
  }

  Future<void> _executeLoadNearby() async {
    if (_loadingNearby) return;
    final district = _locationCtrl.effectiveDistrict;
    if (district == null) { _reloadPending = false; return; }
    final districtId = district.id;
    if (mapShouldPause.value) { _stale = true; _reloadPending = false; return; }
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
      await _plotCtrl.loadNearby(center.latitude, center.longitude, _radius, districtId);
      _radarController.stop();
      _radarController.reset();
      _buildMarkers();
      if (_plotCtrl.nearbyPlots.isNotEmpty) _playTing();
    } finally {
      _loadingNearby = false;
      _reloadPending = false;
      _hasLoadedOnce = true;
    }
  }

  void _playTing() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/tone.mp3'));
    } catch (_) {}
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
          painter: _RadarPainter(
              progress: _radarController.value,
              color: const Color(0xFF92400E)),
        ),
      ),
    );
  }

  // Single source of truth for "what matches the current plot-type filter" — used by both
  // the marker builder below and the filter panel's count badge, so the two can never drift.
  List<NearbyPlotModel> get _filteredPlots {
    final all = _plotCtrl.nearbyPlots.toList();
    return _selectedPlotType == null
        ? all
        : all.where((p) => p.plotType == _selectedPlotType).toList();
  }

  void _buildMarkers({bool animate = true}) {
    final data = <_MapMarkerData>[];

    final userMarker = _buildUserMarkerData();
    if (userMarker != null) data.add(userMarker);

    final plots = _filteredPlots
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final filtered = plots.take(AppConstants.maxMapMarkers).toList();
    final clusters = _mapReady
        ? _computeClusters(filtered)
        : filtered.map((p) => _PlotCluster(p)).toList();

    for (final cluster in clusters) {
      final count = cluster.plots.length;
      final rep = cluster.representative;

      if (count == 1) {
        final areaText = rep.areaDisplay;
        final chipW = (areaText.length * 8.5 + 28).clamp(60.0, 110.0);
        data.add(_MapMarkerData(
          position: cluster.center,
          width: chipW,
          height: 34,
          widget: GestureDetector(
            onTap: () => _showDetail(rep),
            child: _AnimatedPin(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: const Color(0xFF92400E), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: Center(
                  child: Text(
                    areaText,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF78350F),
                    ),
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
                  gradient: LinearGradient(
                    colors: [Color(0xFF92400E), Color(0xFF78350F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
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

  void _zoomToCluster(_PlotCluster cluster) {
    double minPx = double.infinity, maxPx = double.negativeInfinity;
    double minPy = double.infinity, maxPy = double.negativeInfinity;
    for (final p in cluster.plots) {
      final sinLat = sin(p.latitude * pi / 180);
      final py = 0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi);
      final px = (p.longitude + 180) / 360;
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

  List<_PlotCluster> _computeClusters(List<NearbyPlotModel> plots) {
    if (plots.isEmpty) return [];
    const cellSize = 48.0;
    final zoom = _currentZoom;
    final scale = 512.0 * pow(2.0, zoom);
    final grid = <(int, int), List<_PlotCluster>>{};
    final anchors = <_PlotCluster, (double, double)>{};
    final result = <_PlotCluster>[];
    for (final plot in plots) {
      final sinLat = sin(plot.latitude * pi / 180);
      final mpy = 0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi);
      final spx = (plot.longitude + 180) / 360 * scale;
      final spy = mpy * scale;
      final gi = (spx / cellSize).floor();
      final gj = (spy / cellSize).floor();
      _PlotCluster? target;
      double bestDist = double.infinity;
      for (var di = -1; di <= 1; di++) {
        for (var dj = -1; dj <= 1; dj++) {
          for (final c in grid[(gi + di, gj + dj)] ?? const []) {
            final (ax, ay) = anchors[c]!;
            final dx = spx - ax, dy = spy - ay;
            final d = sqrt(dx * dx + dy * dy);
            if (d <= cellSize && d < bestDist) { bestDist = d; target = c; }
          }
        }
      }
      if (target != null) {
        target.plots.add(plot);
      } else {
        final c = _PlotCluster(plot);
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
      final dLng = (radiusKm * 1000 * sin(angle)) /
          (earthRadius * cos(latRad)) * (180 / pi);
      points.add(LatLng(center.latitude + dLat, center.longitude + dLng));
    }
    return points;
  }

  Map<String, dynamic> _buildCircleGeojson(LatLng center, double radiusKm) {
    final pts = _circlePolygonPoints(center, radiusKm);
    return {
      'type': 'FeatureCollection',
      'features': [{
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [pts.map((p) => [p.longitude, p.latitude]).toList()]
        },
        'properties': <String, dynamic>{}
      }]
    };
  }

  void _precomputeCircleCache() {
    _circleCache.clear();
    final center = _searchCenter;
    for (final r in AppConstants.radiusOptions) {
      _circleCache[r] = _buildCircleGeojson(center, r);
    }
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

  // On-screen pixel radius of the radius circle actually drawn on the map right now —
  // reuses the exact same polygon point (north edge, angle 0) and projection the native
  // circle layer and every marker are already positioned with, so it tracks zoom/pan
  // exactly instead of a separately-tuned formula drifting out of sync.
  double _radiusPixelRadius(Size screenSize) {
    final cam = _cameraCenter ?? _searchCenter;
    final edge = _circlePolygonPoints(_searchCenter, _radius)[0];
    final centerPx = _projectToScreen(_searchCenter, cam, _currentZoom, screenSize);
    final edgePx = _projectToScreen(edge, cam, _currentZoom, screenSize);
    return (centerPx - edgePx).distance;
  }

  // Anchors the empty-radius chip toward the TOP of the circle, capping how far up it
  // can sit at whichever is smaller: 65% of the circle's own computed radius, or
  // however much room is left before the header. The 65% (not 100%) margin is
  // deliberate: `radiusPx` comes from a hand-rolled Mercator projection that has to
  // independently match wherever MapLibre's native GL renderer actually draws the
  // circle layer, and any small drift between the two (device pixel ratio, native map
  // padding, projection rounding) can make the computed radius larger than the true
  // on-screen one — which pushes a 100%-radius anchor past the real boundary, i.e.
  // visibly outside the circle. Capping the *offset distance* itself (not clamping x/y
  // separately) is what guarantees the point stays inside the circle at every zoom
  // level regardless of that drift.
  static Offset _radiusTopAnchor(Offset center, double radiusPx, Size screenSize) {
    const topMargin = 150.0; // clears the gradient header
    final insetRadius = radiusPx * 0.65;
    final maxUpward = (center.dy - topMargin).clamp(0.0, insetRadius);
    return Offset(center.dx, center.dy - maxUpward);
  }

  void _showDetail(NearbyPlotModel plot) {
    final isAuth = _auth.user.value != null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlotBottomSheet(plot: plot, isAuthenticated: isAuth),
    );
  }

  // ── "Find Near Me" tour ───────────────────────────────────────────────────

  Future<void> _startNearMeTour() async {
    final districtId = _locationCtrl.effectiveDistrict?.id;
    if (districtId == null) return;
    final typeId = _selectedPlotType == null
        ? null
        : _plotCtrl.plotTypes.firstWhereOrNull((t) => t.name == _selectedPlotType)?.id;
    final center = _searchCenter;
    final ok = await _plotCtrl.findNearMe(center.latitude, center.longitude, districtId, plotTypeId: typeId);
    if (!ok || !mounted) return;
    if (_plotCtrl.nearMePlots.isEmpty) {
      AppToast.error('No plots found nearby.');
      return;
    }
    setState(() => _tour.start(_plotCtrl.nearMePlots, totalMatching: _plotCtrl.nearMeTotalMatching.value));
    _flyToTourResult(0);
  }

  void _buildTourMarkers() {
    final data = <_MapMarkerData>[];
    final userMarker = _buildUserMarkerData();
    if (userMarker != null) data.add(userMarker);

    for (var i = 0; i < _tour.results.length; i++) {
      final p = _tour.results[i];
      final active = i == _tour.currentIndex;
      final areaText = p.areaDisplay;
      final chipW = (areaText.length * 8.5 + 28).clamp(60.0, 110.0);
      data.add(_MapMarkerData(
        position: LatLng(p.latitude, p.longitude),
        width: chipW,
        height: 34,
        widget: IgnorePointer(
          ignoring: !active,
          child: Opacity(
            opacity: active ? 1.0 : 0.35,
            child: GestureDetector(
              onTap: active ? _showTourDetail : null,
              child: _AnimatedPin(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: const Color(0xFF92400E), width: active ? 2.5 : 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      areaText,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF78350F),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
    }
    setState(() {
      _markerData = data;
      _revealedCount = data.length;
    });
  }

  void _flyToTourResult(int index) {
    if (index < 0 || index >= _tour.results.length) return;
    _buildTourMarkers();
    final p = _tour.results[index];
    _animateTo(LatLng(p.latitude, p.longitude), 16.0);
  }

  void _tourPrev() {
    _tour.prev();
    setState(() {});
    _flyToTourResult(_tour.currentIndex);
  }

  void _tourNext() {
    _tour.next();
    setState(() {});
    _flyToTourResult(_tour.currentIndex);
  }

  void _cancelTour() {
    setState(() => _tour.reset());
    _buildMarkers();
    _fitToRadius();
    if (_stale) _loadNearby();
  }

  void _showTourDetail() {
    if (!_tour.isActive) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NearMePlotDetailSheet(plot: _tour.current),
    );
  }

  void _goToViewAllFromTour() {
    final typeId = _selectedPlotType == null
        ? null
        : _plotCtrl.plotTypes.firstWhereOrNull((t) => t.name == _selectedPlotType)?.id;
    Get.toNamed(AppRoutes.viewAllPlots, arguments: {'typeId': typeId});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // ── Layer 1: Map — stays alive for the screen's lifetime.
              // Never destroyed by GPS toggle; shimmer overlays it instead.
              if (_mapActive)
                RepaintBoundary(
                  child: MapLibreMap(
                    styleString: "assets/map_style.json",
                    initialCameraPosition: CameraPosition(
                      target: _searchCenter,
                      zoom: 13.0,
                    ),
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

              // ── Layer 2: Shimmer — during map init OR before first GPS fix.
              // GPS toggle does NOT re-show shimmer because userLocation is kept at
              // last-known when GPS turns off. Only fresh-install/first-fix waits here.
              if (!_mapActive || !_mapReady || _locationCtrl.userLocation.value == null)
                _buildMapShimmer(),

              // ── Layer 2: Flutter widget marker overlay ──────────────────────
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
                        if (_filteredPlots.isEmpty && !_loadingNearby && !_reloadPending && _hasLoadedOnce && !_tour.isActive)
                          Builder(builder: (_) {
                            // Anchored to the TOP of the radius circle — the chip's tail tip
                            // lands on the boundary when the circle fits on screen, or just
                            // inside it (never outside) when the circle is bigger than the
                            // viewport. The circle's own center (where the user's location pin
                            // sits) stays completely uncluttered.
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
                                child: Column(
                                  children: [
                                    EmptyRadiusHint(
                                      label: 'No plots in this radius',
                                      circleRadiusPx: radiusPx,
                                    ),
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onTap: _startNearMeTour,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF92400E), Color(0xFF78350F)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(color: const Color(0xFF92400E).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5)),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Obx(() => _plotCtrl.isLoadingNearMe.value
                                                ? const SizedBox(
                                                    width: 12, height: 12,
                                                    child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white),
                                                  )
                                                : const Icon(Icons.radar_rounded, size: 14, color: Colors.white)),
                                            const SizedBox(width: 7),
                                            const Text('Find Near Me',
                                                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),

              // ── Header ──────────────────────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF92400E), Color(0xFF78350F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(children: [
                        IgnorePointer(
                          ignoring: _tour.isActive,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _tour.isActive ? 0.45 : 1.0,
                            child: _buildLocationPill(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: IgnorePointer(
                              ignoring: _tour.isActive,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _tour.isActive ? 0.45 : 1.0,
                                child: _buildRadiusChips(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _tour.isActive
                              ? GestureDetector(
                                  onTap: _cancelTour,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
                                      ],
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 17, color: Color(0xFF92400E)),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () => Get.toNamed(AppRoutes.myPlots),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.12),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: const BoxDecoration(
                                              color: Color(0xFF92400E), shape: BoxShape.circle),
                                          child: const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text('Plot',
                                            style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF92400E))),
                                      ],
                                    ),
                                  ),
                                ),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ),

              // ── Filter panel / tour card ────────────────────────────────────
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: _tour.isActive
                    ? NearMeTourCard(
                        accentColor: const Color(0xFF92400E),
                        thumbnailUrl: _tour.current.thumbnailUrl,
                        thumbnailIcon: Icons.landscape_rounded,
                        title: _tour.current.plotType,
                        subtitle: _tour.current.areaDisplay,
                        distanceKm: _tour.current.distanceKm,
                        currentIndex: _tour.currentIndex,
                        total: _tour.results.length,
                        isFirstResult: _tour.isFirstResult,
                        isLastResult: _tour.isLastResult,
                        showHandoff: _tour.showHandoff,
                        remainingCount: _tour.remainingCount,
                        handoffTypeLabel: 'plots',
                        onTapCard: _showTourDetail,
                        onPrev: _tourPrev,
                        onNext: _tourNext,
                        onCancel: _cancelTour,
                        onSeeAll: _goToViewAllFromTour,
                      )
                    : _buildFilterPanel(),
              ),

              // ── Location FAB ────────────────────────────────────────────────
              Positioned(
                bottom: 145,
                right: 20,
                child: IgnorePointer(
                  ignoring: _tour.isActive,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _tour.isActive ? 0.45 : 1.0,
                    child: _buildLocationFab(),
                  ),
                ),
              ),

              const Positioned(
                bottom: 4,
                left: 8,
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 9, color: Colors.black45),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Single entry point for the district-switch feature: shows the district
  /// currently being viewed (real or manually browsed) + city, opens the
  /// shared drill-down sheet on tap.
  Widget _buildLocationPill() {
    return Obx(() {
      final district = _locationCtrl.effectiveDistrict;
      if (district == null) return const SizedBox();
      final cityName = _locationCtrl.browsingCity.value?.name ??
          _locationCtrl.autoCity.value?.name ??
          'Current';

      return GestureDetector(
        onTap: () => LocationSwitchSheet.show(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(children: [
            const Icon(Icons.public_rounded, color: Color(0xFF92400E), size: 15),
            const SizedBox(width: 7),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: district.name),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.chevron_right_rounded,
                          size: 14, color: const Color(0xFF92400E).withValues(alpha: 0.6)),
                    ),
                  ),
                  TextSpan(text: cityName),
                ]),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E)),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF92400E), size: 16),
          ]),
        ),
      );
    });
  }

  Widget _buildRadiusChips() {
    final radii = AppConstants.radiusOptions;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: radii.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final active = _radius == r;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                _plotCtrl.nearbyPlots.clear();
                setState(() => _radius = r);
                _loadNearby();
                if (_mapReady) _fitToRadius();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 28,
                margin: EdgeInsets.only(right: i < radii.length - 1 ? 4 : 0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  '${r.toInt()} km',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? const Color(0xFF78350F) : Colors.white,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Obx(() {
      final types = _plotCtrl.plotTypes.toList();
      if (types.isEmpty) return const SizedBox.shrink();

      final count = _filteredPlots.length;

      final rows = <List>[];
      for (int i = 0; i < types.length; i += 2) {
        rows.add(types.sublist(i, (i + 2).clamp(0, types.length)));
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 54,
                constraints: const BoxConstraints(minHeight: 52),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF92400E), Color(0xFF78350F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$count',
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 20,
                            fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('plot${count == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 10,
                            fontWeight: FontWeight.w500, color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: rows.asMap().entries.map((entry) {
                    final rowIndex = entry.key;
                    final row = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(top: rowIndex > 0 ? 6 : 0),
                      child: Row(
                        children: List.generate(row.length, (colIndex) {
                          final type = row[colIndex];
                          final selected = _selectedPlotType == type.name;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                final newType = selected ? null : type.name as String?;
                                setState(() => _selectedPlotType = newType);
                                _buildMarkers();
                                if (newType != null) {
                                  final hits = _plotCtrl.nearbyPlots
                                      .where((p) => p.plotType == newType)
                                      .length;
                                  if (hits > 0) _playTing();
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: EdgeInsets.only(right: colIndex < row.length - 1 ? 6 : 0),
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: selected ? const Color(0xFF92400E) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected ? const Color(0xFF92400E) : AppColors.divider,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(type.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: selected ? Colors.white : AppColors.textDark,
                                      )),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildLocationFab() {
    return GestureDetector(
      onTap: () {
        // Also ends any manual district/city browsing — "recenter" and
        // "return to my real district" are the same action here.
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
          boxShadow: [
            BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: const Icon(Icons.my_location_rounded, color: Color(0xFF92400E), size: 22),
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

// ── Data classes ──────────────────────────────────────────────────────────────

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

class _PlotCluster {
  final List<NearbyPlotModel> plots;
  _PlotCluster(NearbyPlotModel first) : plots = [first];

  LatLng get center => LatLng(
        plots.map((p) => p.latitude).reduce((a, b) => a + b) / plots.length,
        plots.map((p) => p.longitude).reduce((a, b) => a + b) / plots.length,
      );

  NearbyPlotModel get representative => plots.reduce((a, b) => a.areaSqft <= b.areaSqft ? a : b);
}

// ── Animation widgets ─────────────────────────────────────────────────────────

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

// ── Bottom Sheet ──────────────────────────────────────────────────────────────

class _PlotBottomSheet extends StatelessWidget {
  final NearbyPlotModel plot;
  final bool isAuthenticated;

  const _PlotBottomSheet({required this.plot, required this.isAuthenticated});

  Color _typeColor(String type) => switch (type) {
        'Residential' => const Color(0xFF3B82F6),
        'Commercial' => const Color(0xFFF59E0B),
        'Agricultural' => const Color(0xFF92400E),
        'Farmhouse' => const Color(0xFF16A34A),
        _ => AppColors.primary,
      };

  Widget _photoPlaceholder() => Container(
        color: AppColors.surface,
        child: const Center(
          child: Icon(Icons.landscape_rounded, size: 40, color: AppColors.textHint),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with availability overlay
            Stack(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: plot.thumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: plot.thumbnailUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: AppColors.surface),
                          errorWidget: (context, url, err) => _photoPlaceholder(),
                        )
                      : _photoPlaceholder(),
                ),
                Positioned(
                  bottom: 10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: plot.isActive ? const Color(0xFF2E7D32) : Colors.red.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      plot.isActive ? 'Available' : 'Not Available',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + AppInsets.bottomViewPadding(context)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Type chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _typeColor(plot.plotType).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      plot.plotType,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _typeColor(plot.plotType),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Area display
                  Text(
                    plot.areaDisplay,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Owner + distance in same row
                  Row(children: [
                    if (plot.ownerName != null && plot.ownerName!.isNotEmpty) ...[
                      const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textLight),
                      const SizedBox(width: 5),
                      Text(
                        plot.ownerName!,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 13,
                            fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                    ] else
                      const SizedBox.shrink(),
                    const Spacer(),
                    const Icon(Icons.near_me_rounded, size: 13, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      '${plot.distanceKm.toStringAsFixed(1)} km away',
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // View Details
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Get.toNamed(AppRoutes.plotDetail, arguments: plot.id);
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text(
                        'View Details',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF92400E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
