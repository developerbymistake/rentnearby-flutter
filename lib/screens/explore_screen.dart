import 'dart:math';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
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

class _ExploreScreenState extends State<ExploreScreen> with AutomaticKeepAliveClientMixin {
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
  bool _animateCancelled = false;
  final _audioPlayer = AudioPlayer();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _districtsWorker = ever(_listingCtrl.districts, (_) => _tryAutoLoad());
    _initLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoLoad());
  }

  @override
  void dispose() {
    _districtsWorker?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _tryAutoLoad() {
    if (_selectedDistrict != null || _listingCtrl.districts.isEmpty) return;
    _autoLoad();
  }

  Future<void> _autoLoad() async {
    final district = _nearestDistrict();
    setState(() => _selectedDistrict = district);
    await _listingCtrl.loadCities(district.id);
    // _selectedCity stays null → "Current" mode (use GPS as search center)
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
      if (!serviceEnabled) { setState(() => _locationLoading = false); return; }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) { setState(() => _locationLoading = false); return; }
      }
      if (permission == LocationPermission.deniedForever) { setState(() => _locationLoading = false); return; }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
        _locationLoading = false;
      });

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
    final degLat = _radius / 111.0;
    final degLng = _radius / (111.0 * cos(center.latitude * pi / 180));
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(center.latitude - degLat, center.longitude - degLng),
          LatLng(center.latitude + degLat, center.longitude + degLng),
        ),
        padding: const EdgeInsets.fromLTRB(24, 175, 24, 145),
        maxZoom: 17.0,
      ),
    );
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
        width: 22, height: 22,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE53935),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: const Color(0xFFE53935).withOpacity(0.5), blurRadius: 10, spreadRadius: 3)],
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
        width: 100,
        height: 32,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () => _showDetail(listing.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 6, offset: const Offset(0, 3)),
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 2, offset: const Offset(0, 1)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.home_rounded, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(priceText, style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white,
                )),
              ],
            ),
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

  Future<void> _animateTo(LatLng target, double zoom) async {
    if (!_mapReady || !mounted) return;
    _animateCancelled = false;
    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
    const frames = 24;
    for (var i = 1; i <= frames; i++) {
      if (!mounted || _animateCancelled) return;
      final t = Curves.easeInOut.transform(i / frames);
      _mapController.move(
        LatLng(
          startCenter.latitude + (target.latitude - startCenter.latitude) * t,
          startCenter.longitude + (target.longitude - startCenter.longitude) * t,
        ),
        startZoom + (zoom - startZoom) * t,
      );
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                      if (hasGesture) _animateCancelled = true;
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.rentnearby.rentnearby',
                      maxNativeZoom: 18,
                      keepBuffer: 2,
                      panBuffer: 1,
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
    final radii = [1.0, 2.0, 5.0, 10.0];
    return Row(
      children: radii.map((r) {
        final active = _radius == r;
        return GestureDetector(
          onTap: () {
            setState(() { _radius = r; _currentPage = 1; });
            _loadNearby();
            if (_mapReady) _fitToRadius();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${r.toInt() == r ? r.toInt() : r} km',
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : Colors.white,
                )),
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

class _PinBodyPainter extends CustomPainter {
  final Color color;
  const _PinBodyPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final circle = ui.Path()
      ..addOval(Rect.fromCircle(center: const Offset(18, 18), radius: 18));
    final spike = ui.Path()
      ..moveTo(10, 32)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(26, 32)
      ..close();
    final pin = ui.Path.combine(ui.PathOperation.union, circle, spike);
    canvas.drawShadow(pin, Colors.black38, 4, true);
    canvas.drawPath(pin, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinBodyPainter old) => old.color != color;
}
