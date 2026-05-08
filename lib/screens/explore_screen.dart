import 'dart:math';
import 'dart:ui' as ui;
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
import '../widgets/listing_bottom_sheet.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

// FIX #1 consequence: AutomaticKeepAliveClientMixin removed — IndexedStack in MainScreen
// keeps this screen alive natively, so KeepAlive mixin is redundant.
// FIX #6: TickerProviderStateMixin added for vsync-synced camera animation.
class _ExploreScreenState extends State<ExploreScreen> with TickerProviderStateMixin {
  final _mapController = MapController();
  final _listingCtrl = Get.find<ListingController>();
  Worker? _districtsWorker;
  List<Marker> _markers = [];
  LatLng? _userLocation;
  double _radius = 1.0;
  DistrictModel? _selectedDistrict;
  CityModel? _selectedCity;
  bool _locationLoading = true;
  bool _mapReady = false;
  int _currentPage = 1;
  final _audioPlayer = AudioPlayer();

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

    _districtsWorker = ever(_listingCtrl.districts, (_) => _tryAutoLoad());
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
    _districtsWorker?.dispose();
    _cameraAnimController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // FIX #3 (race condition): Guard added — do not auto-select district until
  // GPS is resolved. Prevents wrong district selection with null location.
  void _tryAutoLoad() {
    if (_selectedDistrict != null || _listingCtrl.districts.isEmpty) return;
    if (_locationLoading) return;
    _autoLoad();
  }

  Future<void> _autoLoad() async {
    final district = _nearestDistrict();
    setState(() => _selectedDistrict = district);
    await _listingCtrl.loadCities(district.id);
    _loadNearby();
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dlat = (lat2 - lat1) * pi / 180;
    final dlng = (lng2 - lng1) * pi / 180;
    final a = sin(dlat / 2) * sin(dlat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlng / 2) * sin(dlng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  List<DistrictModel> get _nearbyDistricts {
    final all = _listingCtrl.districts.toList();
    if (_userLocation == null) return all;
    final withDist = all.map((d) => MapEntry(d,
        _haversineKm(_userLocation!.latitude, _userLocation!.longitude, d.latitude ?? 0, d.longitude ?? 0)
    )).toList()..sort((a, b) => a.value.compareTo(b.value));
    final nearby = withDist.where((e) => e.value <= 100).map((e) => e.key).toList();
    return nearby.isNotEmpty ? nearby : [withDist.first.key];
  }

  DistrictModel _nearestDistrict() {
    final ds = _nearbyDistricts;
    return ds.isNotEmpty ? ds.first : _listingCtrl.districts.first;
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

      // FIX #4: Use last known position instantly — map appears immediately
      // without waiting for a fresh GPS fix (which can take 5–10 seconds cold).
      final lastKnown = await Geolocator.getLastKnownPosition();
      setState(() {
        if (lastKnown != null) {
          _userLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
        }
        _locationLoading = false;
      });
      if (_listingCtrl.districts.isNotEmpty && lastKnown != null) _tryAutoLoad();
      if (_mapReady) _fitToRadius();

      // FIX #3 (accuracy): LocationAccuracy.high uses network + GPS — resolves
      // in <1 second vs LocationAccuracy.best which waits for satellite fix.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));

      if (_listingCtrl.districts.isNotEmpty) {
        final nearest = _nearestDistrict();
        if (_selectedDistrict == null || _selectedDistrict!.id != nearest.id) {
          setState(() => _selectedDistrict = nearest);
          await _listingCtrl.loadCities(nearest.id);
        }
      }

      _loadNearby();
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
    return _userLocation ??
        (_selectedDistrict != null
            ? LatLng(_selectedDistrict!.latitude ?? 29.3803, _selectedDistrict!.longitude ?? 79.4636)
            : const LatLng(29.3803, 79.4636));
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

  Future<void> _loadNearby({bool reset = true}) async {
    if (_selectedDistrict == null) return;
    final wasEmpty = _listingCtrl.nearbyListings.isEmpty;
    if (reset) _currentPage = 1;
    final center = _searchCenter;
    await _listingCtrl.loadNearby(center.latitude, center.longitude, _radius, _selectedDistrict!.id, page: _currentPage);
    _buildMarkers();
    if (reset && wasEmpty && _listingCtrl.nearbyListings.isNotEmpty) _playTing();
  }

  void _playTing() async {
    try { await _audioPlayer.play(AssetSource('sounds/tone.mp3')); } catch (_) {}
  }

  Future<void> _loadMoreNearby() async {
    if (!_listingCtrl.hasMoreNearby.value || _listingCtrl.isLoading.value) return;
    _currentPage++;
    await _loadNearby(reset: false);
  }

  void _buildMarkers() {
    final markers = <Marker>[];

    if (_userLocation != null) {
      markers.add(Marker(
        point: _userLocation!,
        width: 16, height: 16,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E88E5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: const Color(0xFF1E88E5).withOpacity(0.35), blurRadius: 8, spreadRadius: 2)],
          ),
        ),
      ));
    }

    final listings = (_listingCtrl.nearbyListings.toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm)))
      .take(30);

    for (final listing in listings) {
      final priceText = listing.priceMonthly != null ? _pinPrice(listing.priceMonthly!) : 'Call';
      markers.add(Marker(
        point: LatLng(listing.latitude, listing.longitude),
        width: 80,
        height: 90,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () => _showDetail(listing.id),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Price bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Text(
                  priceText,
                  style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 11,
                    fontWeight: FontWeight.w700, color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Pin with home icon
              SizedBox(
                width: 46, height: 58,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: const Size(46, 58),
                      painter: _PinBodyPainter(color: AppColors.primary),
                    ),
                    const Positioned(
                      top: 2, left: 0, right: 0,
                      child: SizedBox(
                        height: 40,
                        child: Center(
                          child: Icon(Icons.home_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
    }

    setState(() => _markers = markers);
  }

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListingBottomSheet(listingId: id),
    );
  }

  LatLngBounds? _districtBounds() {
    final d = _selectedDistrict;
    if (d?.latitude == null || d?.longitude == null) return null;
    final points = <LatLng>[LatLng(d!.latitude!, d.longitude!)];
    for (final city in _listingCtrl.cities) {
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
                    initialCenter: _userLocation ?? const LatLng(29.3803, 79.4636),
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
                    onPositionChanged: (_, hasGesture) {
                      if (hasGesture) _cameraAnimController.stop();
                    },
                  ),
                  children: [
                    // FIX #5: CachedTileProvider stores tiles on disk via flutter_cache_manager.
                    // Previously tiles were re-fetched from network on every app open.
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.rentnearby.rentnearby',
                      maxNativeZoom: 18,
                      keepBuffer: 2,
                      panBuffer: 1,
                      tileProvider: _CachedTileProvider(),
                      tileUpdateTransformer: TileUpdateTransformers.throttle(
                        const Duration(milliseconds: 150),
                      ),
                    ),
                    if (_userLocation != null || _selectedDistrict != null)
                      CircleLayer(circles: [
                        CircleMarker(
                          point: _searchCenter,
                          radius: _radius * 1000,
                          useRadiusInMeter: true,
                          color: AppColors.primary.withOpacity(0.08),
                          borderColor: AppColors.primary.withOpacity(0.7),
                          borderStrokeWidth: 2,
                        ),
                      ]),
                    MarkerLayer(markers: _markers),
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
                      const Text('RentNearBy',
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

          Obx(() => Positioned(
            bottom: 20, left: 20, right: 20,
            child: _listingCtrl.isLoading.value ? const SizedBox() : _buildCounterCard(),
          )),

          Positioned(
            bottom: 100, right: 20,
            child: _buildLocationFab(),
          ),
        ],
      ),
    );
  }

  Widget _buildCityDropdown() {
    return Obx(() {
      final cs = _listingCtrl.cities;
      if (cs.isEmpty) {
        return _selectedDistrict != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
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
            setState(() { _selectedCity = null; _currentPage = 1; });
          } else {
            final city = cs.firstWhereOrNull((c) => c.id == id);
            if (city == null) return;
            setState(() { _selectedCity = city; _currentPage = 1; });
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
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
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
              _listingCtrl.hasMoreNearby.value = false;
              setState(() { _radius = r; _currentPage = 1; });
              _loadNearby();
              if (_mapReady) _fitToRadius();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: EdgeInsets.only(right: i < radii.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white.withOpacity(0.15),
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

  Widget _buildCounterCard() {
    final count = _listingCtrl.nearbyListings.length;
    return Obx(() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('$count',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(count == 0 ? 'No rooms found' : '$count room${count == 1 ? '' : 's'} loaded',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              Text('within ${_radius.toInt() == _radius ? _radius.toInt() : _radius} km radius',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
            ])),
          ]),
          if (_listingCtrl.hasMoreNearby.value) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _loadMoreNearby,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('Load More', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ),
            ),
          ],
        ],
      ),
    ));
  }

  Widget _buildLocationFab() {
    return GestureDetector(
      onTap: () {
        setState(() { _selectedCity = null; _currentPage = 1; });
        _loadNearby();
        if (_mapReady) _fitToRadius();
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

// FIX #2 (pin painter): Path cached as static final — computed once at class
// load time instead of on every paint() call (was: Path.combine PathOperation.union
// + 2 Path allocations per frame per pin = ~1800 heavy ops/sec with 30 pins at 60fps).
class _PinBodyPainter extends CustomPainter {
  final Color color;
  const _PinBodyPainter({required this.color});

  static final ui.Path _pinPath = () {
    const cx = 23.0;
    const cy = 21.0;
    const r  = 21.0;
    final path = ui.Path()
      // circle body
      ..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: r))
      // smooth spike using bezier curves for a teardrop look
      ..moveTo(cx - 8, cy + r - 4)
      ..cubicTo(cx - 10, cy + r + 10, cx - 3, 56, cx, 58)
      ..cubicTo(cx + 3, 56, cx + 10, cy + r + 10, cx + 8, cy + r - 4)
      ..close();
    return path;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawShadow(_pinPath, Colors.black38, 4, true);
    canvas.drawPath(_pinPath, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinBodyPainter old) => old.color != color;
}

// FIX #5: Tile disk cache using flutter_cache_manager (bundled with cached_network_image).
// Tiles are stored on device and served from disk on subsequent sessions.
// OSM User-Agent header required to comply with tile usage policy.
class _CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      headers: const {'User-Agent': 'RentNearBy/1.0 (Flutter; com.rentnearby.rentnearby)'},
    );
  }
}
