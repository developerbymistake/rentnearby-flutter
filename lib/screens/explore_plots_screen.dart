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
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/plot_controller.dart';
import '../models/city_model.dart';
import '../models/plot_model.dart';

class ExplorePlotsScreen extends StatefulWidget {
  const ExplorePlotsScreen({super.key});
  @override
  State<ExplorePlotsScreen> createState() => _ExplorePlotsScreenState();
}

class _ExplorePlotsScreenState extends State<ExplorePlotsScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _mapController = MapController();
  final _plotCtrl = Get.find<PlotController>();
  Worker? _districtsWorker;
  Worker? _postedWorker;
  Worker? _loadingWorker;
  Worker? _refreshWorker;
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
  Timer? _loadNearbyDebounceTimer;
  String? _selectedPlotType;
  bool _autoLoading = false;
  final _audioPlayer = AudioPlayer();
  int _revealedCount = 0;
  Timer? _revealTimer;
  late AnimationController _radarController;
  late AnimationController _cameraAnimController;
  LatLng? _animFromCenter;
  double? _animFromZoom;
  LatLng? _animToCenter;
  double? _animToZoom;

  static const _plotTypes = ['Residential', 'Commercial', 'Agricultural'];
  static const _plotTypeLabels = {
    'Residential': 'Resi.',
    'Commercial': 'Comm.',
    'Agricultural': 'Agri.',
  };

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
    _districtsWorker = ever(_plotCtrl.districts, (_) => _tryAutoLoad());
    _postedWorker = ever(_plotCtrl.plotPostedTrigger, (_) => _loadNearby());
    _refreshWorker = ever(_plotCtrl.exploreRefreshTrigger, (_) {
      if (_selectedDistrict != null) _loadNearby();
    });
    _loadingWorker = ever(_plotCtrl.isLoading, (loading) {
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
    _refreshWorker?.dispose();
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
        if (_userLocation == null && !_locationLoading) _initLocation();
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
      final ctx = await _plotCtrl.loadContext(_userLocation!.latitude, _userLocation!.longitude);
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
      if (_plotCtrl.districts.isNotEmpty && lastKnown != null) _tryAutoLoad();
      if (_mapReady) _fitToRadius();

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));

      final ctx = await _plotCtrl.loadContext(pos.latitude, pos.longitude);
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
    if (_selectedCity?.latitude != null && _selectedCity?.longitude != null) {
      return LatLng(_selectedCity!.latitude!, _selectedCity!.longitude!);
    }
    if (_userLocation != null) return _userLocation!;
    if (_autoCity?.latitude != null && _autoCity?.longitude != null) {
      return LatLng(_autoCity!.latitude!, _autoCity!.longitude!);
    }
    if (_selectedDistrict?.latitude != null && _selectedDistrict?.longitude != null) {
      return LatLng(_selectedDistrict!.latitude!, _selectedDistrict!.longitude!);
    }
    final first = _plotCtrl.districts.firstOrNull;
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
        width: 120,
        height: 120,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _radarController,
          builder: (_, _) => CustomPaint(
            painter: _RadarPainter(
                progress: _radarController.value,
                color: const Color(0xFF10B981)),
            child: Center(
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2)
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  void _loadNearby() {
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
    await _plotCtrl.loadNearby(center.latitude, center.longitude, _radius, cityId);
    _radarController.stop();
    _radarController.reset();
    _buildMarkers();
    if (_plotCtrl.nearbyPlots.isNotEmpty) _playTing();
  }

  void _playTing() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/tone.mp3'));
    } catch (_) {}
  }

  void _buildMarkers({bool animate = true}) {
    final markers = <Marker>[];

    if (_userLocation != null) markers.add(_buildUserMarker());

    var plots = _plotCtrl.nearbyPlots.toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    if (_selectedPlotType != null) {
      plots = plots.where((p) => p.plotType == _selectedPlotType).toList();
    }

    final filtered = plots.take(30).toList();
    final clusters = _mapReady ? _computeClusters(filtered) : filtered.map((p) => _PlotCluster(p)).toList();

    for (final cluster in clusters) {
      final count = cluster.plots.length;
      final rep = cluster.representative;

      if (count == 1) {
        final areaText = rep.areaDisplay;
        final chipW = (areaText.length * 8.5 + 28).clamp(60.0, 110.0);
        markers.add(Marker(
          point: cluster.center,
          width: chipW,
          height: 34,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => _showDetail(rep),
            child: _AnimatedPin(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: const Color(0xFF10B981), width: 2),
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
                      color: Color(0xFF059669),
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
            onTap: () => _showDetail(rep),
            child: _AnimatedPin(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
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
      if (!mounted) {
        timer.cancel();
        return;
      }
      i++;
      setState(() => _revealedCount = i);
      if (i >= markers.length) timer.cancel();
    });
  }

  List<_PlotCluster> _computeClusters(List<NearbyPlotModel> plots) {
    final clusters = <_PlotCluster>[];
    const clusterPx = 56.0;
    final zoom = _mapController.camera.zoom;
    for (final plot in plots) {
      final pt = LatLng(plot.latitude, plot.longitude);
      _PlotCluster? best;
      double bestDist = double.infinity;
      for (final c in clusters) {
        final d = _mercatorPixelDist(pt, c.center, zoom);
        if (d < bestDist) {
          bestDist = d;
          best = c;
        }
      }
      if (best != null && bestDist <= clusterPx) {
        best.plots.add(plot);
      } else {
        clusters.add(_PlotCluster(plot));
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

  void _showDetail(NearbyPlotModel plot) {
    final auth = Get.find<AuthController>();
    final isAuth = auth.user.value != null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlotBottomSheet(plot: plot, isAuthenticated: isAuth),
    );
  }

  LatLngBounds? _districtBounds() {
    final d = _selectedDistrict;
    if (d?.latitude == null || d?.longitude == null) return null;
    final points = <LatLng>[LatLng(d!.latitude!, d.longitude!)];
    for (final city in _plotCtrl.nearbyCities) {
      if (city.latitude != null && city.longitude != null) {
        points.add(LatLng(city.latitude!, city.longitude!));
      }
    }
    var minLat = points.map((p) => p.latitude).reduce(min);
    var maxLat = points.map((p) => p.latitude).reduce(max);
    var minLng = points.map((p) => p.longitude).reduce(min);
    var maxLng = points.map((p) => p.longitude).reduce(max);
    const minSpan = 0.5;
    if (maxLat - minLat < minSpan) {
      final mid = (maxLat + minLat) / 2;
      minLat = mid - minSpan / 2;
      maxLat = mid + minSpan / 2;
    }
    if (maxLng - minLng < minSpan) {
      final mid = (maxLng + minLng) / 2;
      minLng = mid - minSpan / 2;
      maxLng = mid + minSpan / 2;
    }
    const pad = 0.2;
    return LatLngBounds(
        LatLng(minLat - pad, minLng - pad), LatLng(maxLat + pad, maxLng + pad));
  }

  CameraConstraint get _cameraConstraint {
    final b = _districtBounds();
    return b != null
        ? CameraConstraint.containCenter(bounds: b)
        : const CameraConstraint.unconstrained();
  }

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
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.bakhli.app',
                        maxNativeZoom: 18,
                        keepBuffer: 2,
                        panBuffer: 1,
                        tileProvider: _CachedTileProvider(),
                        tileUpdateTransformer:
                            TileUpdateTransformers.throttle(const Duration(milliseconds: 150)),
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
                            color: const Color(0xFF10B981).withValues(alpha: 0.08),
                            borderColor: const Color(0xFF10B981).withValues(alpha: 0.7),
                            borderStrokeWidth: 2,
                          ),
                        ]),
                      MarkerLayer(markers: _markers.take(_revealedCount).toList()),
                    ],
                  ),
                ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(children: [
                    Row(children: [
                      const Icon(Icons.terrain_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 6),
                      const Text('Explore Plots',
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

          // Filter panel
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildFilterPanel(),
          ),

          // Location FAB
          Positioned(
            bottom: 145,
            right: 20,
            child: _buildLocationFab(),
          ),
        ],
      ),
    );
  }

  Widget _buildCityDropdown() {
    return Obx(() {
      final cs = _plotCtrl.nearbyCities;
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
                  size: 14, color: isCurrent ? const Color(0xFF10B981) : AppColors.textLight),
              const SizedBox(width: 10),
              Text('Current',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      color: isCurrent ? const Color(0xFF10B981) : AppColors.textDark)),
            ]),
          ),
          ...cs.map((c) => PopupMenuItem<String>(
                value: c.id,
                child: Row(children: [
                  Icon(Iconsax.location,
                      size: 14,
                      color: _selectedCity?.id == c.id
                          ? const Color(0xFF10B981)
                          : AppColors.textLight),
                  const SizedBox(width: 10),
                  Text(c.name,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          color: _selectedCity?.id == c.id
                              ? const Color(0xFF10B981)
                              : AppColors.textDark)),
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
              _plotCtrl.nearbyPlots.clear();
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
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '${r.toInt()} km',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? const Color(0xFF059669) : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFilterPanel() {
    return Obx(() {
      if (_plotCtrl.isLoading.value) return const SizedBox.shrink();

      final allPlots = _plotCtrl.nearbyPlots.toList();
      final filtered = _selectedPlotType != null
          ? allPlots.where((p) => p.plotType == _selectedPlotType).toList()
          : allPlots;
      final count = filtered.length;

      final rows = <List<String>>[];
      for (int i = 0; i < _plotTypes.length; i += 3) {
        rows.add(_plotTypes.sublist(i, (i + 3).clamp(0, _plotTypes.length)));
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
                width: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
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
                            fontFamily: 'Poppins', fontSize: 22,
                            fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('plot${count == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 11,
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
                          final selected = _selectedPlotType == type;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                final newType = selected ? null : type;
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
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(
                                  color: selected ? const Color(0xFF10B981) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected ? const Color(0xFF10B981) : AppColors.divider,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(_plotTypeLabels[type] ?? type,
                                      style: TextStyle(
                                        fontFamily: 'Poppins', fontSize: 13,
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
        setState(() => _selectedCity = null);
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
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: const Icon(Icons.my_location_rounded, color: Color(0xFF10B981), size: 22),
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

// --- Data Classes ---

class _PlotCluster {
  final List<NearbyPlotModel> plots;
  _PlotCluster(NearbyPlotModel first) : plots = [first];

  LatLng get center => LatLng(
        plots.map((p) => p.latitude).reduce((a, b) => a + b) / plots.length,
        plots.map((p) => p.longitude).reduce((a, b) => a + b) / plots.length,
      );

  NearbyPlotModel get representative => plots.first;
}

// --- Shared Widgets ---

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

class _CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      headers: const {'User-Agent': 'Bakhli/1.0 (Flutter; com.bakhli.app)'},
    );
  }
}

// --- Bottom Sheet ---

class _PlotBottomSheet extends StatelessWidget {
  final NearbyPlotModel plot;
  final bool isAuthenticated;

  const _PlotBottomSheet({required this.plot, required this.isAuthenticated});

  Color _typeColor(String type) => switch (type) {
        'Residential' => const Color(0xFF3B82F6),
        'Commercial' => const Color(0xFFF59E0B),
        'Agricultural' => const Color(0xFF10B981),
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
          if (plot.areaUnit != 'sqft') ...[
            const SizedBox(height: 2),
            Text(
              plot.sqftLabel,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textMedium,
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Distance
          Row(children: [
            const Icon(Icons.near_me_rounded, size: 15, color: AppColors.textLight),
            const SizedBox(width: 6),
            Text(
              '${plot.distanceKm.toStringAsFixed(1)} km away',
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium),
            ),
          ]),

          if (plot.ownerName != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textLight),
              const SizedBox(width: 6),
              Text(
                plot.ownerName!,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark),
              ),
            ]),
          ],

          const SizedBox(height: 20),

          // Call button
          if (isAuthenticated && plot.ownerPhone != null)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri(scheme: 'tel', path: plot.ownerPhone);
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text(
                  'Call Owner',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            )
          else if (!isAuthenticated)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text(
                    'Login to contact owner',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
