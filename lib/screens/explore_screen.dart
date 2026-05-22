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
import '../config/app_map_state.dart';
import '../controllers/listing_controller.dart';
import '../controllers/location_controller.dart';
import '../models/city_model.dart';
import '../models/listing_model.dart';
import '../widgets/listing_bottom_sheet.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Map ──────────────────────────────────────────────────────────────────
  MapLibreMapController? _mapController;
  double _currentZoom = 13.0;
  Fill? _nativeCircle;
  Line? _nativeCircleGlow;
  Line? _nativeCircleLine;
  Circle? _nativeUserDot;
  bool _pinsVisible = true;
  bool _styleLoaded = false;
  LatLng? _cameraCenter;
  bool _mapActive = true;
  Worker? _mapPauseWorker;

  // ── State ─────────────────────────────────────────────────────────────────
  final _listingCtrl  = Get.find<ListingController>();
  final _locationCtrl = Get.find<LocationController>();
  Worker? _locationWorker;
  Worker? _locationLoadingWorker;
  Worker? _userLocationWorker;
  Worker? _postedWorker;
  Worker? _loadingWorker;
  Worker? _refreshWorker;

  List<_MapMarkerData> _markerData = [];
  double _radius = 1.0;
  double _lastClusterZoom = 0;
  CityModel? _selectedCity;
  bool _mapReady = false;
  bool _checkingPermission = false;
  Timer? _loadNearbyDebounceTimer;
  String? _selectedRoomType;
  bool _loadingNearby = false;
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
        _loadNearby();
        if (_mapReady) _fitToRadius();
      }
    });

    // Propagate loading state changes → map shimmer / map visible.
    _locationLoadingWorker = ever(_locationCtrl.locationLoading, (bool loading) {
      if (!mounted) return;
      if (loading) {
        setState(() {
          _styleLoaded = false;
          _mapReady = false;
          _mapController = null;
          _nativeCircle = null;
          _nativeCircleGlow = null;
          _nativeCircleLine = null;
          _nativeUserDot = null;
        });
      } else {
        setState(() {});
      }
    });

    // Propagate user-dot position updates to the map.
    _userLocationWorker = ever(_locationCtrl.userLocation, (_) {
      if (!mounted) return;
      setState(() {});
      if (_mapReady) {
        if (_locationCtrl.userLocation.value != null) {
          if (_nativeUserDot == null) _initNativeUserDot();
          else _updateNativeUserDot();
        } else {
          _buildMarkers(animate: false);
        }
      }
    });

    _postedWorker = ever(_listingCtrl.listingPostedTrigger, (_) => _loadNearby());
    _refreshWorker = ever(_listingCtrl.exploreRefreshTrigger, (_) {
      if (_locationCtrl.selectedDistrict.value != null) _loadNearby();
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
          _nativeCircle = null;
          _nativeCircleGlow = null;
          _nativeCircleLine = null;
          _nativeUserDot = null;
        });
      } else {
        setState(() => _mapActive = true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationWorker?.dispose();
    _locationLoadingWorker?.dispose();
    _userLocationWorker?.dispose();
    _postedWorker?.dispose();
    _loadingWorker?.dispose();
    _refreshWorker?.dispose();
    _mapPauseWorker?.dispose();
    _radarController.dispose();
    _revealTimer?.cancel();
    _loadNearbyDebounceTimer?.cancel();
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

  String? get _effectiveCityId => _selectedCity?.id ?? _locationCtrl.autoCity.value?.id;

  LatLng get _searchCenter {
    if (_selectedCity?.latitude != null && _selectedCity?.longitude != null) {
      return LatLng(_selectedCity!.latitude!, _selectedCity!.longitude!);
    }
    final loc = _locationCtrl.userLocation.value;
    if (loc != null) return loc;
    final city = _locationCtrl.autoCity.value;
    if (city?.latitude != null && city?.longitude != null) {
      return LatLng(city!.latitude!, city.longitude!);
    }
    return const LatLng(28.6139, 77.2090);
  }

  void _fitToRadius() {
    if (!_mapReady || !mounted) return;
    final center = _searchCenter;
    _animateTo(center, _zoomForRadius(_radius, center.latitude));
    _updateNativeRadiusCircle();
  }

  Future<void> _initNativeCircle() async {
    final ctrl = _mapController;
    if (ctrl == null || !mounted) return;
    final points = _circlePolygonPoints(_searchCenter, _radius);
    _nativeCircle = await ctrl.addFill(FillOptions(
      geometry: [points],
      fillColor: '#2f64ca',
      fillOpacity: 0.06,
    ));
    if (!_mapActive) return;
    _nativeCircleGlow = await ctrl.addLine(LineOptions(
      geometry: points,
      lineColor: '#2f64ca',
      lineWidth: 6.0,
      lineOpacity: 0.15,
      lineBlur: 3.0,
    ));
    if (!_mapActive) return;
    _nativeCircleLine = await ctrl.addLine(LineOptions(
      geometry: points,
      lineColor: '#2f64ca',
      lineWidth: 1.8,
      lineOpacity: 0.65,
    ));
  }

  void _updateNativeRadiusCircle() {
    final ctrl = _mapController;
    if (ctrl == null) return;
    final points = _circlePolygonPoints(_searchCenter, _radius);
    if (_nativeCircle != null)     ctrl.updateFill(_nativeCircle!, FillOptions(geometry: [points]));
    if (_nativeCircleGlow != null) ctrl.updateLine(_nativeCircleGlow!, LineOptions(geometry: points));
    if (_nativeCircleLine != null) ctrl.updateLine(_nativeCircleLine!, LineOptions(geometry: points));
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
    const usablePx = 480.0;
    final metersPerPxAtZ0 =
        earthCircumference * cos(lat * pi / 180) / tileSize;
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

  // ── Style loaded callback ─────────────────────────────────────────────────

  void _onStyleLoaded() {
    if (_styleLoaded) return;
    _styleLoaded = true;
    _mapReady = true;
    if (!mounted) return;
    setState(() {});
    _initNativeCircle();
    _initNativeUserDot();
    _buildMarkers(animate: false);
    _fitToRadius();
  }

  void _onCameraIdle() {
    if ((_currentZoom - _lastClusterZoom).abs() >= 0.4) {
      _lastClusterZoom = _currentZoom;
      _buildMarkers(animate: false);
    }
    if (mounted && !_pinsVisible) setState(() => _pinsVisible = true);
  }

  // ── Listings load ─────────────────────────────────────────────────────────

  void _loadNearby() {
    _loadNearbyDebounceTimer?.cancel();
    _loadNearbyDebounceTimer =
        Timer(const Duration(milliseconds: 300), () async {
      await _executeLoadNearby();
    });
  }

  Future<void> _executeLoadNearby() async {
    if (_loadingNearby) return;
    if (_locationCtrl.selectedDistrict.value == null) return;
    final cityId = _effectiveCityId;
    if (cityId == null) return;
    _loadingNearby = true;
    try {
      _revealTimer?.cancel();
      _radarController.repeat();
      _markerData = _locationCtrl.userLocation.value != null ? [_buildUserMarkerData()] : [];
      _revealedCount = _markerData.length;
      setState(() {});
      final center = _searchCenter;
      await _listingCtrl.loadNearby(
          center.latitude, center.longitude, _radius, cityId);
      _radarController.stop();
      _radarController.reset();
      _buildMarkers();
      if (_listingCtrl.nearbyListings.isNotEmpty) _playTing();
    } finally {
      _loadingNearby = false;
    }
  }

  void _playTing() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/tone.mp3'));
    } catch (_) {}
  }

  // ── Marker data building ──────────────────────────────────────────────────

  _MapMarkerData _buildUserMarkerData() => _MapMarkerData(
        position: _locationCtrl.userLocation.value!,
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

  void _buildMarkers({bool animate = true}) {
    final data = <_MapMarkerData>[];

    if (_locationCtrl.userLocation.value != null) data.add(_buildUserMarkerData());

    var listings = _listingCtrl.nearbyListings.toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    if (_selectedRoomType != null) {
      listings = listings
          .where((l) => l.roomTypeName == _selectedRoomType)
          .toList();
    }

    final filtered = listings.take(30).toList();
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

  // Zoom in on cluster center so markers spread apart at the new zoom level.
  void _zoomToCluster(_Cluster cluster) {
    _animateTo(cluster.center, (_currentZoom + 2.5).clamp(10.0, 18.0));
  }

  // Hybrid threshold: cap at 48 px so clusters never visually overlap,
  // but never exceed 50 m physical distance so distant items don't merge.
  static double _metersToPixels(double meters, double zoom, double lat) {
    const earthCircumference = 40075016.686;
    const tileSize = 512.0;
    final metersPerPixel =
        earthCircumference * cos(lat * pi / 180) / (tileSize * pow(2.0, zoom));
    return meters / metersPerPixel;
  }

  List<_Cluster> _computeClusters(List<NearbyListingModel> listings) {
    final clusters = <_Cluster>[];
    const clusterMeters = 500.0;
    const clusterPxCap = 48.0;
    final zoom = _currentZoom;
    final refLat = _locationCtrl.userLocation.value?.latitude ?? _searchCenter.latitude;
    final clusterPx =
        _metersToPixels(clusterMeters, zoom, refLat).clamp(0.0, clusterPxCap);
    for (final listing in listings) {
      final pt = LatLng(listing.latitude, listing.longitude);
      _Cluster? best;
      double bestDist = double.infinity;
      for (final c in clusters) {
        final d = _mercatorPixelDist(pt, c.center, zoom);
        if (d < bestDist) {
          bestDist = d;
          best = c;
        }
      }
      if (best != null && bestDist <= clusterPx) {
        best.listings.add(listing);
      } else {
        clusters.add(_Cluster(listing));
      }
    }
    return clusters;
  }

  static double _mercatorPixelDist(LatLng a, LatLng b, double zoom) {
    final scale = 512.0 * pow(2.0, zoom);
    final ax = (a.longitude + 180) / 360 * scale;
    final ay = _mercatorY(a.latitude) * scale;
    final bx = (b.longitude + 180) / 360 * scale;
    final by = _mercatorY(b.latitude) * scale;
    final dx = ax - bx;
    final dy = ay - by;
    return sqrt(dx * dx + dy * dy);
  }

  static double _mercatorY(double lat) {
    final sinLat = sin(lat * pi / 180);
    return 0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi);
  }

  static List<LatLng> _circlePolygonPoints(LatLng center, double radiusKm) {
    const steps = 128;
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
          // ── Layer 1: Map or loading shimmer ─────────────────────────────
          if (_locationCtrl.locationLoading.value || !_mapActive)
            _buildMapShimmer()
          else
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
                  if (mounted && _pinsVisible) setState(() => _pinsVisible = false);
                },
                onCameraIdle: _onCameraIdle,
              ),
            ),


          // ── Layer 3: Flutter widget marker overlay ───────────────────────
          if (!_locationCtrl.locationLoading.value && _mapReady)
            IgnorePointer(
              ignoring: !_pinsVisible,
              child: AnimatedOpacity(
                opacity: _pinsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 100),
                child: Stack(
                  fit: StackFit.expand,
                  children: _markerData
                      .take(_revealedCount)
                      .map((d) {
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
                      })
                      .toList(),
                ),
              ),
            ),

          // ── Layer 4: UI overlays (unchanged) ─────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration:
                  const BoxDecoration(gradient: AppColors.primaryGradient),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(children: [
                    Row(children: [
                      const Icon(Icons.location_on_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 6),
                      const Text('Bakhli',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const Spacer(),
                      _buildCityDropdown(),
                    ]),
                    const SizedBox(height: 12),
                    _buildRadiusChips(),
                  ]),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildFilterPanel(),
          ),

          Positioned(
            bottom: 145,
            right: 20,
            child: _buildLocationFab(),
          ),
        ],
          );
        },
      ),
    );
  }

  // ── UI widgets ────────────────────────────────────────────────────────────

  Widget _buildCityDropdown() {
    return Obx(() {
      final cs = _locationCtrl.nearbyCities;
      if (cs.isEmpty) {
        return _locationCtrl.selectedDistrict.value != null
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Iconsax.location, color: Colors.white, size: 13),
                  const SizedBox(width: 5),
                  Text(_locationCtrl.selectedDistrict.value!.name,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white)),
                ]),
              )
            : const SizedBox();
      }

      final isCurrent = _selectedCity == null;
      final displayName = isCurrent ? 'Current' : _selectedCity!.name;

      return PopupMenuButton<String>(
        onSelected: (id) {
          if (id == '__current__') {
            setState(() => _selectedCity = null);
          } else {
            final city = cs.firstWhereOrNull((c) => c.id == id);
            if (city == null) return;
            setState(() => _selectedCity = city);
          }
          _loadNearby();
          if (_mapReady) _fitToRadius();
        },
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        itemBuilder: (_) => [
          PopupMenuItem<String>(
            value: '__current__',
            child: Row(children: [
              Icon(Icons.my_location_rounded,
                  size: 14,
                  color:
                      isCurrent ? AppColors.primary : AppColors.textLight),
              const SizedBox(width: 10),
              Text('Current',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    color:
                        isCurrent ? AppColors.primary : AppColors.textDark,
                  )),
            ]),
          ),
          ...cs.map((c) => PopupMenuItem<String>(
                value: c.id,
                child: Row(children: [
                  Icon(Iconsax.location,
                      size: 14,
                      color: _selectedCity?.id == c.id
                          ? AppColors.primary
                          : AppColors.textLight),
                  const SizedBox(width: 10),
                  Text(c.name,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        color: _selectedCity?.id == c.id
                            ? AppColors.primary
                            : AppColors.textDark,
                      )),
                ]),
              )),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isCurrent ? Icons.my_location_rounded : Iconsax.map,
                color: Colors.white, size: 13),
            const SizedBox(width: 6),
            Text(displayName,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white, size: 16),
          ]),
        ),
      );
    });
  }

  Widget _buildRadiusChips() {
    final radii = [1.0, 3.0, 6.0];
    return Row(
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
              height: 34,
              margin: EdgeInsets.only(right: i < radii.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text('${r.toInt()} km',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.primary : Colors.white,
                    )),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFilterPanel() {
    return Obx(() {
      final types = _listingCtrl.roomTypes;
      if (types.isEmpty) return const SizedBox.shrink();

      final allListings = _listingCtrl.nearbyListings.toList();
      final filtered = _selectedRoomType != null
          ? allListings
              .where((l) => l.roomTypeName == _selectedRoomType)
              .toList()
          : allListings;
      final count = filtered.length;

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
        setState(() => _selectedCity = null);
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
