import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
  bool _styleLoaded = false;
  bool _layersReady = false;

  static const _sourceId = 'listings-source';
  static const _clusterLayerId = 'cluster-circles';
  static const _clusterCountLayerId = 'cluster-count';
  static const _pinLayerId = 'listing-pins';

  // ── State ─────────────────────────────────────────────────────────────────
  final _listingCtrl = Get.find<ListingController>();
  Worker? _districtsWorker;
  Worker? _postedWorker;
  Worker? _loadingWorker;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  LatLng? _userLocation;
  double _radius = 1.0;
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

  // ── Style loaded ──────────────────────────────────────────────────────────

  void _onStyleLoaded() {
    if (_styleLoaded) return;
    _styleLoaded = true;
    _mapReady = true;
    if (!mounted) return;
    _cameraCenter = _searchCenter;
    setState(() {});
    _initNativeCircle();
    _initNativeUserDot();
    _setupMapLayers().then((_) => _updateGeoJsonSource());
    _fitToRadius();
  }

  // ── Badge image ───────────────────────────────────────────────────────────

  Future<Uint8List> _createBadgeImage(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 80, 30),
        const Radius.circular(8),
      ),
      Paint()..color = color,
    );
    final img = await recorder.endRecording().toImage(80, 30);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  // ── Layer setup ───────────────────────────────────────────────────────────

  Future<void> _setupMapLayers() async {
    if (_mapController == null) return;
    try {
      await _mapController!.addImage(
          'pin-badge', await _createBadgeImage(AppColors.primary));

      await _mapController!.addSource(
        _sourceId,
        GeojsonSourceProperties(
          data: '{"type":"FeatureCollection","features":[]}',
          cluster: true,
          clusterMaxZoom: 13,
          clusterRadius: 50,
        ),
      );

      await _mapController!.addCircleLayer(
        _sourceId,
        _clusterLayerId,
        CircleLayerProperties(
          circleRadius: [
            'step', ['get', 'point_count'], 22, 10, 28, 50, 34
          ],
          circleColor: '#1E88E5',
          circleStrokeWidth: 2.0,
          circleStrokeColor: '#FFFFFF',
        ),
        filter: ['has', 'point_count'],
      );

      await _mapController!.addSymbolLayer(
        _sourceId,
        _clusterCountLayerId,
        SymbolLayerProperties(
          textField: '{point_count}',
          textSize: 13.0,
          textColor: '#FFFFFF',
          textAllowOverlap: true,
          iconAllowOverlap: true,
        ),
        filter: ['has', 'point_count'],
      );

      await _mapController!.addSymbolLayer(
        _sourceId,
        _pinLayerId,
        SymbolLayerProperties(
          iconImage: 'pin-badge',
          iconTextFit: 'both',
          iconTextFitPadding: [5.0, 10.0, 5.0, 10.0],
          textField: '{label}',
          textSize: 11.0,
          textColor: '#FFFFFF',
          iconAllowOverlap: false,
          textAllowOverlap: false,
        ),
        filter: ['!', ['has', 'point_count']],
      );

      _layersReady = true;
    } catch (_) {}
  }

  // ── GeoJSON update ────────────────────────────────────────────────────────

  Future<void> _updateGeoJsonSource() async {
    if (_mapController == null || !_layersReady) return;
    final all = _listingCtrl.nearbyListings.toList();
    final filtered = _selectedRoomType == null
        ? all
        : all.where((l) => l.roomTypeName == _selectedRoomType).toList();
    final geojson = {
      'type': 'FeatureCollection',
      'features': filtered
          .map((l) => {
                'type': 'Feature',
                'id': l.id,
                'geometry': {
                  'type': 'Point',
                  'coordinates': [l.longitude, l.latitude]
                },
                'properties': {
                  'id': l.id,
                  'label': _formatLabel(l),
                  'roomType': l.roomTypeName ?? '',
                },
              })
          .toList(),
    };
    await _mapController!.setGeoJsonSource(_sourceId, geojson);
  }

  String _formatLabel(NearbyListingModel l) {
    final p = l.priceMonthly;
    if (p == null || p == 0) return 'Call';
    if (p >= 100000) {
      final lakh = p / 100000;
      return lakh == lakh.truncateToDouble()
          ? '₹${lakh.toInt()}L'
          : '₹${lakh.toStringAsFixed(1)}L';
    }
    if (p >= 1000) {
      final t = p ~/ 1000;
      final h = p % 1000;
      return h == 0 ? '₹${t}k' : '₹$t,${h.toString().padLeft(3, '0')}';
    }
    return '₹$p';
  }

  // ── Tap handler ───────────────────────────────────────────────────────────

  Future<void> _onMapTap(Point<double> point, LatLng latLng) async {
    if (_mapController == null || !_layersReady) return;
    final features = await _mapController!.queryRenderedFeatures(
        point, [_clusterLayerId, _pinLayerId], null);
    if (features.isEmpty) return;
    final props = Map<String, dynamic>.from(
        (features.first['properties'] as Map?) ?? {});
    if (props['cluster'] == true) {
      await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, (_currentZoom + 2).clamp(0.0, 18.0)));
    } else {
      final id = props['id'] as String?;
      if (id != null) _showDetail(id);
    }
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
    _radarController.repeat();
    setState(() {});
    final center = _searchCenter;
    await _listingCtrl.loadNearby(
        center.latitude, center.longitude, _radius, cityId);
    _radarController.stop();
    _radarController.reset();
    await _updateGeoJsonSource();
    if (_listingCtrl.nearbyListings.isNotEmpty) _playTing();
  }

  void _playTing() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/tone.mp3'));
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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
                onMapClick: _onMapTap,
                onCameraMove: (CameraPosition pos) {
                  _currentZoom = pos.zoom;
                  _cameraCenter = pos.target;
                  if (mounted) setState(() {});
                },
                onCameraIdle: () {
                  if (mounted) setState(() {});
                },
              ),
            ),

          // ── Layer 2: Radar overlay (user location loading animation) ─────
          if (!_locationLoading && _mapReady && _userLocation != null)
            _buildRadarOverlay(),

          // ── Layer 3: UI overlays ─────────────────────────────────────────
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

  // ── Radar overlay ─────────────────────────────────────────────────────────

  Widget _buildRadarOverlay() {
    final pos = _latLngToScreen(_userLocation!);
    if (pos == null) return const SizedBox.shrink();
    return Positioned(
      left: pos.dx - 60,
      top: pos.dy - 60,
      width: 120,
      height: 120,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _radarController,
          builder: (_, __) => CustomPaint(
            painter: _RadarPainter(
                progress: _radarController.value,
                color: const Color(0xFF1E88E5)),
          ),
        ),
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
                                _updateGeoJsonSource();
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

// ── Radar animation ───────────────────────────────────────────────────────────

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
