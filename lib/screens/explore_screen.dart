import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';
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

// FIX #1 consequence: AutomaticKeepAliveClientMixin removed — IndexedStack in MainScreen
// keeps this screen alive natively, so KeepAlive mixin is redundant.
// FIX #6: TickerProviderStateMixin added for vsync-synced camera animation.
class _ExploreScreenState extends State<ExploreScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final _mapController = MapController();
  final _listingCtrl = Get.find<ListingController>();
  Worker? _districtsWorker;
  Worker? _postedWorker;
  Worker? _loadingWorker;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  List<Marker> _markers = [];
  LatLng? _userLocation;
  double _radius = 1.0;
  double _lastClusterZoom = 0;
  DistrictModel? _selectedDistrict;
  CityModel? _selectedCity;
  CityModel? _autoCity;
  bool _locationLoading = true;
  bool _mapReady = false;
  bool _checkingPermission = false;
  bool _nearbyLoaded = false; // Flag to prevent duplicate _loadNearby calls
  Timer? _loadNearbyDebounceTimer; // Debounce rapid _loadNearby calls
  final _selectedRoomTypes = <String>{};
  bool _autoLoading = false; // Prevent concurrent _autoLoad calls
  final _audioPlayer = AudioPlayer();
  int _revealedCount = 0;
  Timer? _revealTimer;
  late AnimationController _radarController;

  // FIX #6: AnimationController replaces manual Future.delayed loop.
  // Synced to device display refresh rate (60/90/120 Hz), smooth easeInOut.
  late AnimationController _cameraAnimController;
  LatLng? _animFromCenter;
  double? _animFromZoom;
  LatLng? _animToCenter;
  double? _animToZoom;

  @override
  void initState() {
    super.initState();
    _cameraAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(_onCameraAnimTick);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    WidgetsBinding.instance.addObserver(this);
    _districtsWorker = ever(_listingCtrl.districts, (_) => _tryAutoLoad());
    _postedWorker = ever(_listingCtrl.listingPostedTrigger, (_) => _loadNearby());
    ever(_listingCtrl.exploreRefreshTrigger, (_) { if (_selectedDistrict != null) _loadNearby(); });
    _loadingWorker = ever(_listingCtrl.isLoading, (loading) {
      if (!loading && _radarController.isAnimating) {
        _radarController.stop();
        _radarController.reset();
      }
    });

    // React to the user toggling GPS in device Settings without leaving the app.
    _serviceStatusSub = Geolocator.getServiceStatusStream().listen((status) {
      if (!mounted) return;
      if (status == ServiceStatus.enabled) {
        if (_userLocation == null && !_locationLoading) {
          setState(() => _locationLoading = true);
          _initLocation();
        }
      } else {
        // GPS turned off: clear user dot, stop loading state.
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

  void _onCameraAnimTick() {
    if (!_mapReady || !mounted) return;
    if (_animFromCenter == null || _animToCenter == null) return;
    final t = Curves.easeInOut.transform(_cameraAnimController.value);
    _mapController.move(
      LatLng(
        _animFromCenter!.latitude + (_animToCenter!.latitude - _animFromCenter!.latitude) * t,
        _animFromCenter!.longitude + (_animToCenter!.longitude - _animFromCenter!.longitude) * t,
      ),
      _animFromZoom! + (_animToZoom! - _animFromZoom!) * t,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _districtsWorker?.dispose();
    _postedWorker?.dispose();
    _loadingWorker?.dispose();
    _serviceStatusSub?.cancel();
    _cameraAnimController.dispose();
    _radarController.dispose();
    _revealTimer?.cancel();
    _loadNearbyDebounceTimer?.cancel();
    _audioPlayer.dispose();
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

  Future<void> _checkPermissionOnResume() async {
    // Guard: prevent concurrent checks and dialog stacking if user
    // backgrounds the app while the dialog is already showing.
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
      // Permission was revoked mid-session — block with dialog.
      // When user returns from Settings, resumed fires again and re-checks.
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

  void _tryAutoLoad() {
    if (_selectedDistrict != null) return;
    if (_locationLoading) return;
    if (_autoLoading) return; // Prevent concurrent _autoLoad calls
    _autoLoad();
  }

  String? get _effectiveCityId => _selectedCity?.id ?? _autoCity?.id;

  Future<void> _autoLoad() async {
    if (_userLocation == null) return;
    _autoLoading = true;
    try {
      final ctx = await _listingCtrl.loadContext(_userLocation!.latitude, _userLocation!.longitude);
      if (!mounted || ctx == null) return;
      setState(() {
        _selectedDistrict = ctx.district;
        _autoCity = ctx.nearestCity;
      });
      _loadNearby();
    } finally {
      _autoLoading = false;
    }
  }

  Future<void> _initLocation() async {
    _nearbyLoaded = false; // Reset flag for fresh initialization
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

      // FIX #4: Use last known position instantly — map appears immediately
      // without waiting for a fresh GPS fix (which can take 5–10 seconds cold).
      final lastKnown = await Geolocator.getLastKnownPosition();
      setState(() {
        if (lastKnown != null) {
          _userLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
        }
        _locationLoading = false;
      });
      if (_listingCtrl.districts.isNotEmpty && lastKnown != null) {
        _nearbyLoaded = true; // Mark before calling _tryAutoLoad to prevent duplicate paths
        _tryAutoLoad(); // Exclusively calls _loadNearby via _autoLoad
      }
      if (_mapReady) _fitToRadius();

      // FIX #3 (accuracy): LocationAccuracy.high uses network + GPS — resolves
      // in <1 second vs LocationAccuracy.best which waits for satellite fix.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));

      final ctx = await _listingCtrl.loadContext(pos.latitude, pos.longitude);
      if (!mounted) return;
      if (ctx != null && (_selectedDistrict == null || _selectedDistrict!.id != ctx.district.id)) {
        setState(() {
          _selectedDistrict = ctx.district;
          _autoCity = ctx.nearestCity;
        });
      }

      if (_mapReady) _fitToRadius();
    } catch (_) {
      setState(() => _locationLoading = false);
      _tryAutoLoad();
    }
  }

  LatLng get _searchCenter {
    // Explicit user city selection overrides everything
    if (_selectedCity?.latitude != null && _selectedCity?.longitude != null) {
      return LatLng(_selectedCity!.latitude!, _selectedCity!.longitude!);
    }
    // Actual GPS position takes priority over any auto-selected city
    if (_userLocation != null) return _userLocation!;
    // No GPS — fall back to auto-selected nearest city for browsing
    if (_autoCity?.latitude != null && _autoCity?.longitude != null) {
      return LatLng(_autoCity!.latitude!, _autoCity!.longitude!);
    }
    if (_selectedDistrict?.latitude != null && _selectedDistrict?.longitude != null) {
      return LatLng(_selectedDistrict!.latitude!, _selectedDistrict!.longitude!);
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
  }

  // Calculates zoom so the circle diameter fills ~80% of usable screen height.
  // Accounts for latitude (tiles shrink toward poles) via cos(lat).
  double _zoomForRadius(double radiusKm, double lat) {
    const earthCircumference = 2 * pi * 6378137.0;
    const tileSize = 256.0;
    const usablePx = 480.0;
    final metersPerPxAtZ0 = earthCircumference * cos(lat * pi / 180) / tileSize;
    final targetMetersPerPx = (radiusKm * 1000 * 2) / (usablePx * 0.80);
    final zoom = log(metersPerPxAtZ0 / targetMetersPerPx) / log(2);
    return zoom.clamp(10.0, 17.0);
  }

  Marker _buildUserMarker() => Marker(
    point: _userLocation!,
    width: 120, height: 120,
    alignment: Alignment.center,
    child: AnimatedBuilder(
      animation: _radarController,
      builder: (_, _) => CustomPaint(
        painter: _RadarPainter(progress: _radarController.value, color: const Color(0xFF1E88E5)),
        child: Center(
          child: Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [BoxShadow(color: const Color(0xFF1E88E5).withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)],
            ),
          ),
        ),
      ),
    ),
  );

  void _loadNearby() {
    // Debounce rapid calls to prevent duplicate API requests
    _loadNearbyDebounceTimer?.cancel();
    _loadNearbyDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await _executeLoadNearby();
    });
  }

  Future<void> _executeLoadNearby() async {
    if (_selectedDistrict == null) return;
    final cityId = _effectiveCityId;
    if (cityId == null) return;
    _revealTimer?.cancel();
    _radarController.repeat();
    _markers = _userLocation != null ? [_buildUserMarker()] : [];
    _revealedCount = _markers.length;
    setState(() {});
    final center = _searchCenter;
    await _listingCtrl.loadNearby(center.latitude, center.longitude, _radius, cityId);
    _radarController.stop();
    _radarController.reset();
    _buildMarkers();
    if (_listingCtrl.nearbyListings.isNotEmpty) _playTing();
  }

  void _playTing() async {
    try { await _audioPlayer.play(AssetSource('sounds/tone.mp3')); } catch (_) {}
  }

  void _buildMarkers({bool animate = true}) {
    final markers = <Marker>[];

    if (_userLocation != null) {
      markers.add(_buildUserMarker());
    }

    var listings = _listingCtrl.nearbyListings.toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    if (_selectedRoomTypes.isNotEmpty) {
      listings = listings
          .where((l) => l.roomTypeName != null &&
                        _selectedRoomTypes.contains(l.roomTypeName))
          .toList();
    }

    final filtered = listings.take(30).toList();

    final clusters = _mapReady
        ? _computeClusters(filtered)
        : filtered.map((l) => _Cluster(l)).toList();

    for (final cluster in clusters) {
      final count = cluster.listings.length;
      final rep = cluster.representative;

      if (count == 1) {
        final priceText = rep.priceMonthly != null ? _pinPrice(rep.priceMonthly!) : 'Call';
        final chipW = _chipWidth(priceText);
        markers.add(Marker(
          point: cluster.center,
          width: chipW,
          height: 34,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => _showDetail(rep.id),
            child: _AnimatedPin(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
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
        markers.add(Marker(
          point: cluster.center,
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => _showDetail(rep.id),
            child: _AnimatedPin(
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: const [
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
    _markers = markers;

    if (!animate || markers.isEmpty) {
      setState(() => _revealedCount = markers.length);
      return;
    }

    final userCount = _userLocation != null ? 1 : 0;
    _revealedCount = userCount;
    setState(() {});

    if (markers.length <= userCount) return;

    int i = userCount;
    _revealTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) { timer.cancel(); return; }
      i++;
      setState(() => _revealedCount = i);
      if (i >= markers.length) timer.cancel();
    });
  }

  List<_Cluster> _computeClusters(List<NearbyListingModel> listings) {
    final clusters = <_Cluster>[];
    const clusterPx = 56.0;
    final zoom = _mapController.camera.zoom;
    for (final listing in listings) {
      final pt = LatLng(listing.latitude, listing.longitude);
      _Cluster? best;
      double bestDist = double.infinity;
      for (final c in clusters) {
        final d = _mercatorPixelDist(pt, c.center, zoom);
        if (d < bestDist) { bestDist = d; best = c; }
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
    final scale = 256.0 * pow(2.0, zoom);
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
    final listing = _listingCtrl.nearbyListings.firstWhereOrNull((l) => l.id == id);
    if (listing == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListingBottomSheet(listing: listing),
    );
  }

  LatLngBounds? _districtBounds() {
    final d = _selectedDistrict;
    if (d?.latitude == null || d?.longitude == null) return null;
    final points = <LatLng>[LatLng(d!.latitude!, d.longitude!)];
    for (final city in _listingCtrl.nearbyCities) {
      if (city.latitude != null && city.longitude != null) {
        points.add(LatLng(city.latitude!, city.longitude!));
      }
    }
    var minLat = points.map((p) => p.latitude).reduce(min);
    var maxLat = points.map((p) => p.latitude).reduce(max);
    var minLng = points.map((p) => p.longitude).reduce(min);
    var maxLng = points.map((p) => p.longitude).reduce(max);
    const minSpan = 0.5;
    if (maxLat - minLat < minSpan) { final mid = (maxLat + minLat) / 2; minLat = mid - minSpan / 2; maxLat = mid + minSpan / 2; }
    if (maxLng - minLng < minSpan) { final mid = (maxLng + minLng) / 2; minLng = mid - minSpan / 2; maxLng = mid + minSpan / 2; }
    const pad = 0.2;
    return LatLngBounds(LatLng(minLat - pad, minLng - pad), LatLng(maxLat + pad, maxLng + pad));
  }

  CameraConstraint get _cameraConstraint {
    final b = _districtBounds();
    return b != null ? CameraConstraint.containCenter(bounds: b) : const CameraConstraint.unconstrained();
  }

  // FIX #6: Replaced 24-frame Future.delayed loop with AnimationController.
  // The controller calls _onCameraAnimTick() in sync with display refresh rate.
  void _animateTo(LatLng target, double zoom) {
    if (!_mapReady || !mounted) return;
    _animFromCenter = _mapController.camera.center;
    _animFromZoom = _mapController.camera.zoom;
    _animToCenter = target;
    _animToZoom = zoom;
    _cameraAnimController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _locationLoading
              ? _buildMapShimmer()
              : RepaintBoundary(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _searchCenter,
                    initialZoom: 13.0,
                    minZoom: 8,
                    maxZoom: 18,
                    cameraConstraint: _cameraConstraint,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      enableMultiFingerGestureRace: true,
                      pinchZoomThreshold: 0.3,
                      pinchMoveThreshold: 30.0,
                    ),
                    onMapReady: () {
                      _mapReady = true;
                      _fitToRadius();
                    },
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) _cameraAnimController.stop();
                      if ((camera.zoom - _lastClusterZoom).abs() >= 0.4) {
                        _lastClusterZoom = camera.zoom;
                        _buildMarkers(animate: false);
                      }
                    },
                  ),
                  children: [
                    // FIX #5: CachedTileProvider stores tiles on disk via flutter_cache_manager.
                    // Previously tiles were re-fetched from network on every app open.
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.bakhli.app',
                      maxNativeZoom: 18,
                      keepBuffer: 2,
                      panBuffer: 1,
                      tileProvider: _CachedTileProvider(),
                      tileUpdateTransformer: TileUpdateTransformers.throttle(
                        const Duration(milliseconds: 150),
                      ),
                      // Unloaded tiles show app shimmer color instead of OSM's
                      // grey placeholder — seamless transition from loading shimmer.
                      tileBuilder: (context, tileWidget, tile) => tile.readyToDisplay
                          ? tileWidget
                          : ColoredBox(color: AppColors.shimmerBase),
                    ),
                    if (_userLocation != null || _selectedDistrict != null)
                      CircleLayer(circles: [
                        CircleMarker(
                          point: _searchCenter,
                          radius: _radius * 1000,
                          useRadiusInMeter: true,
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderColor: AppColors.primary.withValues(alpha: 0.7),
                          borderStrokeWidth: 2,
                        ),
                      ]),
                    MarkerLayer(markers: _markers.take(_revealedCount).toList()),
                  ],
                ),
              ),


          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(children: [
                    Row(children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 6),
                      const Text('Bakhli',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
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
            bottom: 20, left: 20, right: 20,
            child: _buildRoomTypeChips(),
          ),

          Positioned(
            bottom: 120, right: 20,
            child: _buildLocationFab(),
          ),
        ],
      ),
    );
  }

  Widget _buildCityDropdown() {
    return Obx(() {
      final cs = _listingCtrl.nearbyCities;
      if (cs.isEmpty) {
        return _selectedDistrict != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Iconsax.location, color: Colors.white, size: 13),
                  const SizedBox(width: 5),
                  Text(_selectedDistrict!.name,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
                ]),
              )
            : const SizedBox();
      }

      final isCurrent = _selectedCity == null;
      final displayName = isCurrent ? 'Current' : _selectedCity!.name;

      return PopupMenuButton<String>(
        onSelected: (id) {
          if (id == '__current__') {
            setState(() { _selectedCity = null; });
          } else {
            final city = cs.firstWhereOrNull((c) => c.id == id);
            if (city == null) return;
            setState(() { _selectedCity = city; });
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
              Icon(Icons.my_location_rounded, size: 14,
                  color: isCurrent ? AppColors.primary : AppColors.textLight),
              const SizedBox(width: 10),
              Text('Current', style: TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w500,
                color: isCurrent ? AppColors.primary : AppColors.textDark,
              )),
            ]),
          ),
          ...cs.map((c) => PopupMenuItem<String>(
            value: c.id,
            child: Row(children: [
              Icon(Iconsax.location, size: 14,
                  color: _selectedCity?.id == c.id ? AppColors.primary : AppColors.textLight),
              const SizedBox(width: 10),
              Text(c.name, style: TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w500,
                color: _selectedCity?.id == c.id ? AppColors.primary : AppColors.textDark,
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
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
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
              setState(() { _radius = r; });
              _loadNearby();
              if (_mapReady) _fitToRadius();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 34,
              margin: EdgeInsets.only(right: i < radii.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text('${r.toInt()} km',
                    style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600,
                      color: active ? AppColors.primary : Colors.white,
                    )),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRoomTypeChips() {
    return Obx(() {
      final types = _listingCtrl.roomTypes;
      if (types.isEmpty) return const SizedBox.shrink();
      final count = _listingCtrl.nearbyListings.length;
      final visibleCount = _selectedRoomTypes.isEmpty
          ? count
          : _listingCtrl.nearbyListings
              .where((l) => l.roomTypeName != null && _selectedRoomTypes.contains(l.roomTypeName))
              .length;
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('$visibleCount', style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visibleCount == 0 ? 'No rooms found' : '$visibleCount room${visibleCount == 1 ? '' : 's'} found',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    Text('within ${_radius.toInt() == _radius ? _radius.toInt() : _radius} km radius',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((rt) {
            final selected = _selectedRoomTypes.contains(rt.name);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedRoomTypes.remove(rt.name);
                  } else {
                    _selectedRoomTypes.add(rt.name);
                  }
                });
                _buildMarkers();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.divider,
                    width: 1.5,
                  ),
                ),
                child: Text(rt.name,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textDark,
                    )),
              ),
            );
          }).toList(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLocationFab() {
    return GestureDetector(
      onTap: () {
        setState(() { _selectedCity = null; });
        _loadNearby();
        if (_mapReady) {
          if (_userLocation != null) {
            _animateTo(_userLocation!, _zoomForRadius(_radius, _userLocation!.latitude));
          } else {
            _fitToRadius();
          }
        }
      },
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 22),
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


class _Cluster {
  final List<NearbyListingModel> listings;
  _Cluster(NearbyListingModel first) : listings = [first];

  LatLng get center => LatLng(
    listings.map((l) => l.latitude).reduce((a, b) => a + b) / listings.length,
    listings.map((l) => l.longitude).reduce((a, b) => a + b) / listings.length,
  );

  NearbyListingModel get representative => listings.reduce((a, b) =>
      (a.priceMonthly ?? 999999999) <= (b.priceMonthly ?? 999999999) ? a : b);
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
      final opacity = (1.0 - p);

      // Filled glow ring
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.12)
          ..style = PaintingStyle.fill,
      );
      // Stroke ring
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

// FIX #5: Tile disk cache using flutter_cache_manager (bundled with cached_network_image).
// Tiles are stored on device and served from disk on subsequent sessions.
// OSM User-Agent header required to comply with tile usage policy.
class _CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      headers: const {'User-Agent': 'Bakhli/1.0 (Flutter; com.bakhli.app)'},
    );
  }
}
