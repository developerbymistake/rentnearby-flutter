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
import '../controllers/listing_controller.dart';
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
  LatLng? _cameraCenter;
  Size _screenSize = Size.zero;
  Fill? _nativeCircle;
  Line? _nativeCircleGlow;
  Line? _nativeCircleLine;
  Circle? _nativeUserDot;
  bool _pinsVisible = true;
  bool _styleLoaded = false;

  // ── State ─────────────────────────────────────────────────────────────────
  final _listingCtrl = Get.find<ListingController>();
  Worker? _districtsWorker;
  Worker? _postedWorker;
  Worker? _loadingWorker;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  List<_MapMarkerData> _markerData = [];
  LatLng? _userLocation;
  double _radius = 1.0;
  double _lastClusterZoom = 0;
  DistrictModel? _selectedDistrict;
  CityModel? _selectedCity;
  CityModel? _autoCity;
  bool _locationLoading = true;
  bool _mapReady = false;
  bool _checkingPermission = false;
  Timer? _loadNearbyDebounceTimer;
  String? _selectedRoomType;
  bool _autoLoading = false;
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
    _districtsWorker = ever(_listingCtrl.districts, (_) => _tryAutoLoad());
    _postedWorker = ever(_listingCtrl.listingPostedTrigger, (_) => _loadNearby());
    ever(_listingCtrl.exploreRefreshTrigger, (_) {
      if (_selectedDistrict != null) _loadNearby();
    });
    _loadingWorker = ever(_listingCtrl.isLoading, (loading) {
      if (!loading && _radarController.isAnimating) {
        _radarController.stop();
        _radarController.reset();
      }
    });

    _serviceStatusSub = Geolocator.getServiceStatusStream().listen((status) {
      if (!mounted) return;
      if (status == ServiceStatus.enabled) {
        if (_userLocation == null && !_locationLoading) {
          setState(() => _locationLoading = true);
          _initLocation();
        }
      } else {
        setState(() {
          _userLocation = null;
          _locationLoading = false;
        });
        _buildMarkers(animate: false);
      }
    });

    _initLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoLoad());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _districtsWorker?.dispose();
    _postedWorker?.dispose();
    _loadingWorker?.dispose();
    _serviceStatusSub?.cancel();
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
        if (_userLocation == null && !_locationLoading) _initLocation();
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

  // ── Location ──────────────────────────────────────────────────────────────

  void _tryAutoLoad() {
    if (_selectedDistrict != null) return;
    if (_locationLoading) return;
    if (_autoLoading) return;
    _autoLoad();
  }

  String? get _effectiveCityId => _selectedCity?.id ?? _autoCity?.id;

  Future<void> _autoLoad() async {
    if (_userLocation == null) return;
    _autoLoading = true;
    try {
      final ctx = await _listingCtrl.loadContext(
          _userLocation!.latitude, _userLocation!.longitude);
      if (!mounted || ctx == null) return;
      setState(() {
        _selectedDistrict = ctx.district;
        _autoCity = ctx.nearestCity;
      });
      _loadNearby();
      if (_mapReady) _fitToRadius();
    } finally {
      _autoLoading = false;
    }
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationLoading = false);
        _tryAutoLoad();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationLoading = false);
          _tryAutoLoad();
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationLoading = false);
        _tryAutoLoad();
        return;
      }

      // Show last known position immediately — map appears without waiting for fresh GPS fix.
      final lastKnown = await Geolocator.getLastKnownPosition();
      setState(() {
        if (lastKnown != null) {
          _userLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
        }
        _locationLoading = false;
      });
      if (_listingCtrl.districts.isNotEmpty && lastKnown != null) {
        _tryAutoLoad();
      }
      if (_mapReady) {
        if (_nativeUserDot == null) _initNativeUserDot();
        else _updateNativeUserDot();
        _fitToRadius();
      }

      // High accuracy resolves in <1 s via network+GPS rather than satellite-only fix.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
      if (_mapReady) {
        if (_nativeUserDot == null) _initNativeUserDot();
        else _updateNativeUserDot();
      }

      final ctx =
          await _listingCtrl.loadContext(pos.latitude, pos.longitude);
      if (!mounted) return;
      if (ctx != null &&
          (_selectedDistrict == null ||
              _selectedDistrict!.id != ctx.district.id)) {
        setState(() {
          _selectedDistrict = ctx.district;
          _autoCity = ctx.nearestCity;
        });
        _loadNearby();
      }

      if (_mapReady) _fitToRadius();
    } catch (_) {
      setState(() => _locationLoading = false);
      _tryAutoLoad();
    }
  }

  // ── Search center + zoom ──────────────────────────────────────────────────

  LatLng get _searchCenter {
    if (_selectedCity?.latitude != null && _selectedCity?.longitude != null) {
      return LatLng(_selectedCity!.latitude!, _selectedCity!.longitude!);
    }
    if (_userLocation != null) return _userLocation!;
    if (_autoCity?.latitude != null && _autoCity?.longitude != null) {
      return LatLng(_autoCity!.latitude!, _autoCity!.longitude!);
    }
    if (_selectedDistrict?.latitude != null &&
        _selectedDistrict?.longitude != null) {
      return LatLng(
          _selectedDistrict!.latitude!, _selectedDistrict!.longitude!);
    }
    final first = _listingCtrl.districts.firstOrNull;
    if (first?.latitude != null && first?.longitude != null) {
      return LatLng(first!.latitude!, first.longitude!);
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
    _nativeCircleGlow = await ctrl.addLine(LineOptions(
      geometry: points,
      lineColor: '#2f64ca',
      lineWidth: 6.0,
      lineOpacity: 0.15,
      lineBlur: 3.0,
    ));
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
    final loc = _userLocation;
    if (ctrl == null || loc == null || !mounted) return;
    _nativeUserDot = await ctrl.addCircle(CircleOptions(
      geometry: loc,
      circleRadius: 8.0,
      circleColor: '#1E88E5',
      circleOpacity: 1.0,
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 2.5,
    ));
  }

  void _updateNativeUserDot() {
    final ctrl = _mapController;
    final dot = _nativeUserDot;
    final loc = _userLocation;
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
    _cameraCenter = _searchCenter;
    setState(() {});
    _initNativeCircle();
    _initNativeUserDot();
    _buildMarkers(animate: false);
    _fitToRadius();
  }

  // ── Marker screen-position projection ────────────────────────────────────

  Offset? _latLngToScreen(LatLng latlng) {
    final center = _cameraCenter;
    if (center == null || _screenSize == Size.zero) return null;
    final scale = 512.0 * pow(2.0, _currentZoom);
    final px = (latlng.longitude + 180) / 360 * scale;
    final py = _mercatorY(latlng.latitude) * scale;
    final cx = (center.longitude + 180) / 360 * scale;
    final cy = _mercatorY(center.latitude) * scale;
    return Offset(
      _screenSize.width / 2 + (px - cx),
      _screenSize.height / 2 + (py - cy),
    );
  }

  void _updateMarkerScreenPositions() {
    if (!_mapReady || !mounted) return;
    final snapshot = _markerData.take(_revealedCount).toList();
    for (final d in snapshot) {
      d.screenPosition = _latLngToScreen(d.position);
    }
    setState(() {});
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
    if (_selectedDistrict == null) return;
    final cityId = _effectiveCityId;
    if (cityId == null) return;
    _revealTimer?.cancel();
    _radarController.repeat();
    _markerData = _userLocation != null ? [_buildUserMarkerData()] : [];
    _revealedCount = _markerData.length;
    setState(() {});
    final center = _searchCenter;
    await _listingCtrl.loadNearby(
        center.latitude, center.longitude, _radius, cityId);
    _radarController.stop();
    _radarController.reset();
    _buildMarkers();
    if (_listingCtrl.nearbyListings.isNotEmpty) _playTing();
  }

  void _playTing() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/tone.mp3'));
    } catch (_) {}
  }

  // ── Marker data building ──────────────────────────────────────────────────

  _MapMarkerData _buildUserMarkerData() => _MapMarkerData(
        position: _userLocation!,
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

    if (_userLocation != null) data.add(_buildUserMarkerData());

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
            onTap: () => _showDetail(rep.id),
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
      _updateMarkerScreenPositions();
      return;
    }

    final userCount = _userLocation != null ? 1 : 0;
    _revealedCount = userCount;
    setState(() {});
    _updateMarkerScreenPositions();

    if (data.length <= userCount) return;

    int i = userCount;
    _revealTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      i++;
      setState(() => _revealedCount = i);
      _updateMarkerScreenPositions();
      if (i >= data.length) timer.cancel();
    });
  }

  // ── Clustering ────────────────────────────────────────────────────────────

  List<_Cluster> _computeClusters(List<NearbyListingModel> listings) {
    final clusters = <_Cluster>[];
    const clusterPx = 112.0;
    final zoom = _currentZoom;
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
          _screenSize = constraints.biggest;
          return Stack(
            children: [
          // ── Layer 1: Map or loading shimmer ─────────────────────────────
          if (_locationLoading)
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
                onCameraIdle: () {
                  if ((_currentZoom - _lastClusterZoom).abs() >= 0.4) {
                    _lastClusterZoom = _currentZoom;
                    _buildMarkers(animate: false);
                  } else {
                    _updateMarkerScreenPositions();
                  }
                  if (mounted && !_pinsVisible) setState(() => _pinsVisible = true);
                },
              ),
            ),


          // ── Layer 3: Flutter widget marker overlay ───────────────────────
          if (!_locationLoading && _mapReady)
            IgnorePointer(
              ignoring: !_pinsVisible,
              child: AnimatedOpacity(
                opacity: _pinsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 100),
                child: Stack(
                  fit: StackFit.expand,
                  children: _markerData
                      .take(_revealedCount)
                      .where((d) => d.screenPosition != null)
                      .map((d) => Positioned(
                            left: d.screenPosition!.dx - d.width / 2,
                            top: d.screenPosition!.dy - d.height / 2,
                            width: d.width,
                            height: d.height,
                            child: d.widget,
                          ))
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
      final cs = _listingCtrl.nearbyCities;
      if (cs.isEmpty) {
        return _selectedDistrict != null
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
                  Text(_selectedDistrict!.name,
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
    final radii = [1.0, 4.0, 8.0];
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
      if (_listingCtrl.isLoading.value) return const SizedBox.shrink();

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
  Offset? screenPosition;

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
