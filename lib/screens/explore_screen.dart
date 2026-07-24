import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../config/app_tabs.dart';
import '../controllers/auth_controller.dart';
import '../config/app_map_state.dart';
import '../controllers/listing_controller.dart';
import '../controllers/location_controller.dart';
import '../models/listing_model.dart';
import '../navigation/tour_keys.dart';
import '../widgets/add_listing_shortcut_button.dart';
import '../widgets/empty_radius_hint.dart';
import '../widgets/listing_bottom_sheet.dart';
import '../widgets/location_pill.dart';
import '../widgets/nearby_item_row.dart';
import 'explore_location_search_mixin.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, ExploreLocationSearchMixin<ExploreScreen> {
  // ── Map ──────────────────────────────────────────────────────────────────
  MapLibreMapController? _mapController;
  double _currentZoom = 13.0;
  // Real on-screen size, refreshed every build via LayoutBuilder below — lets
  // _zoomForRadius frame the circle for the actual device width instead of a
  // guessed constant, and keeps it correctly scaled on tablets for free.
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

  // ── State ─────────────────────────────────────────────────────────────────
  final _listingCtrl  = Get.find<ListingController>();
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
  Worker? _locationSelectionWorker;
  bool _stale = false;

  List<_MapMarkerData> _markerData = [];
  double _radius = 1.0;
  double _lastClusterZoom = 0;
  bool _mapReady = false;
  bool _checkingPermission = false;
  Timer? _loadNearbyDebounceTimer;
  String? _selectedRoomType;
  bool _loadingNearby = false;
  // Spans from the moment a reload is requested (radius/location/filter change) through
  // the debounce wait and the fetch itself — wider than `_loadingNearby`, which only covers
  // the fetch. Without this, a radius-chip tap clears `nearbyListings` synchronously but
  // `_loadingNearby` doesn't flip true until the 300ms debounce fires, leaving a gap where
  // the empty-radius hint would flash over the previous radius's still-visible pins.
  bool _reloadPending = false;
  // Guards the empty-radius hint against showing before a real fetch has ever completed —
  // on a fresh install, _loadingNearby/_reloadPending both stay false for several seconds
  // while GPS + district resolution run (see LocationController._initLocation), during which
  // nearbyListings is simply empty because nothing has been requested yet, not because a
  // search came back with zero results.
  bool _hasLoadedOnce = false;
  final _audioPlayer = AudioPlayer();
  int _revealedCount = 0;
  Timer? _revealTimer;
  late AnimationController _radarController;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

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
        if (_auth.tabIndex.value == AppTabs.rooms && !mapShouldPause.value) {
          _precomputeCircleCache();
          _loadNearby();
          if (_mapReady && !_isCameraMoving) _fitToRadius();
        } else {
          _stale = true;
        }
      }
    });

    // District-switch AND location-search feature: reload + refit whenever
    // the manually-browsed city OR a searched pin changes — this covers
    // picking a city, resetting back to the real location, applying a search
    // pick, and cancelling a search. Watches LocationController's combined
    // pulse (fired only once every underlying field has settled) rather than
    // browsingCity alone — reacting to browsingCity by itself can observe
    // searchPinOverride still holding its PREVIOUS value mid-transition,
    // since a search applies both fields in sequence.
    _locationSelectionWorker = ever(_locationCtrl.locationSelectionChanged, (_) {
      if (_auth.tabIndex.value == AppTabs.rooms && !mapShouldPause.value) {
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
    // Data reload is NOT this worker's job — _locationWorker (below) reloads
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
      // Rebuild so the shimmer condition (userLocation == null) re-evaluates.
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

    _postedWorker = ever(_listingCtrl.listingPostedTrigger, (_) {
      _stale = true;
      if (_auth.tabIndex.value == AppTabs.rooms && !mapShouldPause.value) _loadNearby();
    });
    _refreshWorker = ever(_listingCtrl.exploreRefreshTrigger, (_) {
      _stale = true;
      if (_locationCtrl.effectiveDistrict != null &&
          _auth.tabIndex.value == AppTabs.rooms && !mapShouldPause.value) {
        _loadNearby();
      }
    });
    _filterResetWorker = ever(_listingCtrl.filterResetTrigger, (_) {
      if (!mounted) return;
      // Manual browsing (own-district or cross-district) intentionally
      // survives tab switches — only the room-type filter resets here.
      setState(() { _selectedRoomType = null; });
      if (_mapReady) {
        _precomputeCircleCache();
        _updateNativeRadiusCircle();
        _fitToRadius();
      }
    });
    _loadingWorker = ever(_listingCtrl.isLoading, (loading) {
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
        if (_auth.tabIndex.value == AppTabs.rooms && _stale) _loadNearby();
      }
    });

    _tabWorker = ever(_auth.tabIndex, (index) {
      if (index == AppTabs.rooms) {
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
    _locationSelectionWorker?.dispose();
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
      // Search pin is temporary, same spirit as browsingCity — resetBrowsing()
      // inside refreshOnResume() already clears both, no separate call needed.
      _locationCtrl.refreshOnResume();
      if (!_listingCtrl.isLoading.value && _radarController.isAnimating) {
        _radarController.stop();
        _radarController.reset();
      }
    }
  }

  // ── Permission ────────────────────────────────────────────────────────────

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Location Required',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            content: const Text(
                'Bakhli needs location access to show rooms near you. Please enable it in Settings.',
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

  // ── Search center + zoom ──────────────────────────────────────────────────

  LatLng get _searchCenter => searchCenter;

  void _fitToRadius() {
    if (!_mapReady || !mounted) return;
    final center = _searchCenter;
    _cameraCenter = center;
    _precomputeCircleCache();      // always rebuild for current center before drawing
    _animateTo(center, _zoomForRadius(_radius, center.latitude));
    _updateNativeRadiusCircle();
  }

  Future<void> _initNativeCircle() async {
    final ctrl = _mapController;
    if (ctrl == null || !mounted) return;
    _precomputeCircleCache();
    await ctrl.addGeoJsonSource('radius-source', _circleCache[_radius]!);
    await ctrl.addFillLayer('radius-source', 'radius-fill',
        FillLayerProperties(fillColor: '#2f64ca', fillOpacity: 0.06));
    await ctrl.addLineLayer('radius-source', 'radius-glow',
        LineLayerProperties(lineColor: '#2f64ca', lineWidth: 6.0,
            lineOpacity: 0.15, lineBlur: 3.0));
    await ctrl.addLineLayer('radius-source', 'radius-border',
        LineLayerProperties(lineColor: '#2f64ca', lineWidth: 1.8,
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
      circleColor: '#1E88E5',
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

  // Zoom so circle diameter fills ~80% of usable screen height; accounts for latitude.
  double _zoomForRadius(double radiusKm, double lat) {
    const earthCircumference = 2 * pi * 6378137.0;
    const tileSize = 512.0;
    // Real measured width — was a hardcoded 480px guess that most phones
    // don't actually have, which is why the circle used to run off-screen.
    // Falls back to 480 only if called before the first layout pass.
    final usablePx = _screenSize.width > 0 ? _screenSize.width : 480.0;
    final metersPerPxAtZ0 =
        earthCircumference * cos(lat * pi / 180) / tileSize;
    final targetMetersPerPx = (radiusKm * 1000 * 2) / (usablePx * 0.93);
    final zoom = log(metersPerPxAtZ0 / targetMetersPerPx) / log(2);
    return zoom.clamp(10.0, 17.0);
  }

  void _animateTo(LatLng target, double zoom) {
    if (!_mapReady || _mapController == null || !mounted) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(target, zoom),
    );
  }

  // ── Style loaded callback ─────────────────────────────────────────────────

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
    _buildMarkers(animate: false);
    _fitToRadius();
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

  // ── Listings load ─────────────────────────────────────────────────────────

  void _loadNearby() {
    _reloadPending = true;
    _loadNearbyDebounceTimer?.cancel();
    _loadNearbyDebounceTimer =
        Timer(const Duration(milliseconds: 300), () async {
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
      await _listingCtrl.loadNearby(
          center.latitude, center.longitude, _radius, districtId);
      _radarController.stop();
      _radarController.reset();
      _buildMarkers();
      if (_listingCtrl.nearbyListings.isNotEmpty) _playTing();
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

  // ── Marker data building ──────────────────────────────────────────────────

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
              color: const Color(0xFF1E88E5)),
        ),
      ),
    );
  }

  // Single source of truth for "what matches the current room-type filter" — used by both
  // the marker builder below and the filter panel's count badge, so the two can never drift.
  List<NearbyListingModel> get _filteredListings {
    final all = _listingCtrl.nearbyListings.toList();
    return _selectedRoomType == null
        ? all
        : all.where((l) => l.roomTypeName == _selectedRoomType).toList();
  }

  void _buildMarkers({bool animate = true}) {
    final data = <_MapMarkerData>[];

    final userMarker = _buildUserMarkerData();
    if (userMarker != null) data.add(userMarker);

    final listings = _filteredListings
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final filtered = listings.take(AppConstants.maxMapMarkers).toList();
    final clusters = _mapReady
        ? _computeClusters(filtered)
        : filtered.map(_Cluster.new).toList();

    for (final cluster in clusters) {
      final count = cluster.listings.length;
      final rep = cluster.representative;

      if (count == 1) {
        final priceText =
            rep.priceMonthly != null ? _pinPrice(rep.priceMonthly!) : 'Call';
        final chipW = _chipWidth(priceText);
        data.add(_MapMarkerData(
          position: cluster.center,
          width: chipW,
          height: 34,
          widget: GestureDetector(
            onTap: () => _showDetail(rep.id),
            child: _AnimatedPin(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Center(
                  child: Text(
                    priceText,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3)),
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

  // ── Clustering ────────────────────────────────────────────────────────────

  // Zoom to the exact level where every pin in the cluster lands in non-adjacent
  // grid cells (max axis > 3 × clusterPxCap = 144 px).
  void _zoomToCluster(_Cluster cluster) {
    double minPx = double.infinity, maxPx = double.negativeInfinity;
    double minPy = double.infinity, maxPy = double.negativeInfinity;
    for (final l in cluster.listings) {
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

  List<_Cluster> _computeClusters(List<NearbyListingModel> listings) {
    if (listings.isEmpty) return [];
    const cellSize = 48.0;
    final zoom = _currentZoom;
    final scale = 512.0 * pow(2.0, zoom);
    final grid = <(int, int), List<_Cluster>>{};
    final anchors = <_Cluster, (double, double)>{};
    final result = <_Cluster>[];
    for (final listing in listings) {
      final sinLat = sin(listing.latitude * pi / 180);
      final mpy = 0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi);
      final spx = (listing.longitude + 180) / 360 * scale;
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
            if (d <= cellSize && d < bestDist) { bestDist = d; target = c; }
          }
        }
      }
      if (target != null) {
        target.listings.add(listing);
      } else {
        final c = _Cluster(listing);
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  double _chipWidth(String text) => (text.length * 9.0 + 26).clamp(52.0, 90.0);

  String _pinPrice(int price) {
    if (price >= 100000) {
      final l = price / 100000;
      return l == l.truncateToDouble()
          ? '₹${l.toInt()}L'
          : '₹${l.toStringAsFixed(1)}L';
    }
    if (price >= 1000) {
      final t = price ~/ 1000;
      final h = price % 1000;
      return h == 0 ? '₹${t}k' : '₹$t,${h.toString().padLeft(3, '0')}';
    }
    return '₹$price';
  }

  void _showDetail(String id) {
    final listing =
        _listingCtrl.nearbyListings.firstWhereOrNull((l) => l.id == id);
    if (listing == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListingBottomSheet(listing: listing),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _screenSize = constraints.biggest;
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


          // ── Layer 3: Flutter widget marker overlay ───────────────────────
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
                    if (_filteredListings.isEmpty && !_loadingNearby && !_reloadPending && _hasLoadedOnce)
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
                            child: EmptyRadiusHint(
                              label: 'No rooms in this radius',
                              circleRadiusPx: radiusPx,
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

          // ── Layer 4: UI overlays ──────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(children: [
                        // Fixed min-height guards against LocationPill collapsing to a
                        // zero-size SizedBox during the brief cold-start window before
                        // LocationController.effectiveDistrict resolves.
                        SizedBox(
                          height: 40,
                          child: LocationPill(key: TourKeys.roomsLocationPill, accentColor: AppColors.primary),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: KeyedSubtree(key: TourKeys.roomsRadiusChips, child: _buildRadiusChips())),
                          const SizedBox(width: 10),
                          KeyedSubtree(key: TourKeys.roomsSearchToggle, child: _buildSearchToggleButton()),
                        ]),
                      ]),
                    ),
                  ),
                ),
                // Current-location FAB sits right after the header, on the map,
                // aligned under Search — no overlap into the header at all.
                Padding(
                  padding: const EdgeInsets.only(top: 12, right: 20),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildLocationFab(),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: KeyedSubtree(
              key: TourKeys.roomsFilterPanel,
              child: _buildFilterPanel(),
            ),
          ),

          // View List stays a normal rounded pill, aligned to the same
          // left:20 inset as the filter panel below. "Add my room" is still
          // the edge tab flush with the screen's right edge (right:0).
          Positioned(
            bottom: 130,
            left: 20,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _filteredListings.isNotEmpty ? _buildViewListButton() : const SizedBox.shrink(),
                AddListingShortcutButton(
                  key: TourKeys.roomsAddShortcut,
                  label: 'Add my room',
                  icon: Iconsax.home,
                  onTap: () => Get.toNamed(AppRoutes.myListings),
                ),
              ],
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

  // ── UI widgets ────────────────────────────────────────────────────────────

  Widget _buildSearchToggleButton() {
    // Obx-wrapped: isSearchActive/searchResolving now read shared
    // LocationController state, not a local field, so this must react on
    // its own to a search started/resolved/cancelled from the OTHER tab.
    return Obx(() => GestureDetector(
      onTap: searchResolving ? null : () => onSearchToggleTap(context),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
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
        child: searchResolving
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSearchActive ? Icons.close_rounded : Icons.search_rounded,
                    color: AppColors.primary,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  const Text('Search',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ],
              ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                _listingCtrl.nearbyListings.clear();
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
                  gradient: active ? AppColors.primaryGradient : null,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.32),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
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

  Widget _buildFilterPanel() {
    return Obx(() {
      final types = _listingCtrl.roomTypes;
      if (types.isEmpty) return const SizedBox.shrink();

      final count = _filteredListings.length;

      final rows = <List>[];
      for (int i = 0; i < types.length; i += 3) {
        rows.add(types.sublist(i, (i + 3).clamp(0, types.length)));
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: AppColors.shadow,
                blurRadius: 20,
                offset: const Offset(0, 6))
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 54,
                constraints: const BoxConstraints(minHeight: 52),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$count',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text('room${count == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white)),
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
                          final rt = row[colIndex];
                          final selected = _selectedRoomType == rt.name;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                final newType =
                                    selected ? null : rt.name as String?;
                                setState(
                                    () => _selectedRoomType = newType);
                                _buildMarkers();
                                if (newType != null) {
                                  final hits = _listingCtrl.nearbyListings
                                      .where(
                                          (l) => l.roomTypeName == newType)
                                      .length;
                                  if (hits > 0) _playTing();
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: EdgeInsets.only(
                                    right: colIndex < row.length - 1
                                        ? 6
                                        : 0),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 7),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.divider,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(rt.name,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? Colors.white
                                            : AppColors.textDark,
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
        // Ends any manual district/city browsing and any active location
        // search in one call — "recenter" and "return to my real location"
        // are the same action for both temporary overrides.
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
            BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: const Icon(Icons.my_location_rounded,
            color: AppColors.primary, size: 22),
      ),
    );
  }

  // ── "View List" — lets the user browse every pinned room as a list ─────────
  // instead of tapping pins one at a time. Purely additive: doesn't touch
  // _showDetail, _buildMarkers, or the native radius-circle layer.

  Widget _buildViewListButton() {
    final count = _filteredListings.length;
    return GestureDetector(
      onTap: _showListSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary, width: 1.4),
          boxShadow: [
            BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.format_list_bulleted_rounded, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            const Text('View List',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              child: Text('$count',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Deliberately does NOT pop anything before Get.toNamed inside the sheet's
  // row onTap — this sheet is opened via showModalBottomSheet(context: ...)
  // with the default useRootNavigator:false, so it lives on THIS tab's own
  // local Navigator, while listingDetail pushes onto the global navigator on
  // top of everything (per this repo's own navigation architecture). Leaving
  // the sheet unpopped means it's simply covered by the detail page and is
  // still there, exactly as left, when the user backs out — no manual
  // "reopen the sheet" state needed. MainScreen's existing _tabLeaveWorker
  // already pops any stray route (including this sheet) if the user
  // switches tabs while it's open, so no extra tab-switch handling is
  // needed here either.
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
                    gradient: AppColors.primaryGradient,
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
                              final count = _filteredListings.length;
                              return Text('$count Room${count == 1 ? '' : 's'} Nearby',
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white));
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
                    final items = _filteredListings;
                    return ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.only(bottom: 16 + AppInsets.bottomViewPadding(context)),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final l = items[i];
                        return NearbyItemRow(
                          thumbnailUrl: l.thumbnailUrl,
                          title: l.roomTypeName ?? 'Room',
                          subtitle: '${l.furnishedStatus} · ${l.distanceKm.toStringAsFixed(1)} km away',
                          trailingText: l.shortPrice,
                          trailingColor: AppColors.primary,
                          placeholderIcon: Icons.home_rounded,
                          onTap: () => Get.toNamed(AppRoutes.listingDetail, arguments: {'id': l.id, 'distanceKm': l.distanceKm}),
                        );
                      },
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

// ── Data classes ─────────────────────────────────────────────────────────────

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
  final List<NearbyListingModel> listings;
  _Cluster(NearbyListingModel first) : listings = [first];

  LatLng get center => LatLng(
        listings.map((l) => l.latitude).reduce((a, b) => a + b) /
            listings.length,
        listings.map((l) => l.longitude).reduce((a, b) => a + b) /
            listings.length,
      );

  NearbyListingModel get representative => listings.reduce((a, b) =>
      (a.priceMonthly ?? 999999999) <= (b.priceMonthly ?? 999999999) ? a : b);
}

// ── Animation widgets ────────────────────────────────────────────────────────

class _AnimatedPin extends StatefulWidget {
  final Widget child;
  const _AnimatedPin({required this.child});
  @override
  State<_AnimatedPin> createState() => _AnimatedPinState();
}

class _AnimatedPinState extends State<_AnimatedPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
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
