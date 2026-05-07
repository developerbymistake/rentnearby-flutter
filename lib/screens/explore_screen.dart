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
  Worker? _citiesWorker;
  List<Marker> _markers = [];
  LatLng? _userLocation;
  double _radius = 1.0;
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
    _citiesWorker = ever(_listingCtrl.cities, (_) => _tryAutoLoad());
    _initLocation();
    // Cities may have loaded before the ever() listener was registered
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoLoad());
  }

  @override
  void dispose() {
    _citiesWorker?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _tryAutoLoad() {
    if (_selectedCity != null || _listingCtrl.cities.isEmpty) return;
    setState(() => _selectedCity = _nearestCity());
    _loadNearby();
  }

  // Haversine distance in km between two lat/lng points
  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dlat = (lat2 - lat1) * pi / 180;
    final dlng = (lng2 - lng1) * pi / 180;
    final a = sin(dlat / 2) * sin(dlat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlng / 2) * sin(dlng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // Cities within 100km of user, sorted by distance. Falls back to all if no location.
  List<CityModel> get _nearbyCities {
    final all = _listingCtrl.cities.toList();
    if (_userLocation == null) return all;
    final withDist = all.map((c) => MapEntry(c,
        _haversineKm(_userLocation!.latitude, _userLocation!.longitude, c.latitude ?? 0, c.longitude ?? 0)
    )).toList()..sort((a, b) => a.value.compareTo(b.value));
    final nearby = withDist.where((e) => e.value <= 100).map((e) => e.key).toList();
    // Always show at least the nearest city even if > 100km
    return nearby.isNotEmpty ? nearby : [withDist.first.key];
  }

  CityModel _nearestCity() {
    final cities = _nearbyCities;
    return cities.isNotEmpty ? cities.first : _listingCtrl.cities.first;
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
      if (_mapReady) _animateTo(_userLocation!, _radiusToZoom(_radius));
      // Re-evaluate nearest city now that we have exact coordinates
      if (_listingCtrl.cities.isNotEmpty) {
        final nearest = _nearestCity();
        if (_selectedCity == null || _selectedCity!.id != nearest.id) {
          setState(() => _selectedCity = nearest);
        }
      }
      _loadNearby();
    } catch (_) {
      setState(() => _locationLoading = false);
    }
  }

  Future<void> _loadNearby({bool reset = true}) async {
    if (_selectedCity == null) return;
    final wasEmpty = _listingCtrl.nearbyListings.isEmpty;
    if (reset) _currentPage = 1;
    final lat = _userLocation?.latitude ?? _selectedCity!.latitude ?? 29.3803;
    final lng = _userLocation?.longitude ?? _selectedCity!.longitude ?? 79.4636;
    await _listingCtrl.loadNearby(lat, lng, _radius, _selectedCity!.id, page: _currentPage);
    _buildMarkers();
    // Play ting only on first load when rooms are found
    if (reset && wasEmpty && _listingCtrl.nearbyListings.isNotEmpty) {
      _playTing();
    }
    if (_userLocation == null && _mapReady) {
      _animateTo(LatLng(lat, lng), _radiusToZoom(_radius));
    }
  }

  void _playTing() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/tone.mp3'));
    } catch (_) {}
  }

  Future<void> _loadMoreNearby() async {
    if (!_listingCtrl.hasMoreNearby.value || _listingCtrl.isLoading.value) return;
    _currentPage++;
    await _loadNearby(reset: false);
  }

  void _buildMarkers() {
    final markers = <Marker>[];

    // User location — red dot
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

    // Sorted by distance, capped at 30
    final listings = (_listingCtrl.nearbyListings.toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm)))
      .take(30);

    for (final listing in listings) {
      final priceText = listing.priceMonthly != null
          ? _pinPrice(listing.priceMonthly!)
          : 'Call';
      markers.add(Marker(
        point: LatLng(listing.latitude, listing.longitude),
        width: 90,
        height: 76,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () => _showDetail(listing.id),
          child: Stack(
            children: [
              // Price label — floats above the pin, centered
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Text(
                      priceText,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              // Pin body: blue circle + spike
              // Align.bottomCenter ensures spike tip = marker anchor = exact coordinate
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 36,
                  height: 46,
                  child: Stack(
                    children: [
                      CustomPaint(
                        painter: _PinBodyPainter(color: AppColors.primary),
                        size: const Size(36, 46),
                      ),
                      const Positioned(
                        top: 9, left: 9,
                        child: Icon(Icons.home_rounded, size: 18, color: Colors.white),
                      ),
                    ],
                  ),
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
    if (price >= 1000) {
      final t = price ~/ 1000;
      final h = price % 1000;
      return '₹$t,${h.toString().padLeft(3, '0')}/-';
    }
    return '₹$price/-';
  }

  void _showDetail(String id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListingBottomSheet(listingId: id),
    );
  }

  double _radiusToZoom(double km) {
    if (km <= 1) return 13.5;
    if (km <= 2) return 12.5;
    if (km <= 5) return 11.0;
    return 10.0;
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

  LatLng get _circleCenter =>
      _userLocation ??
      (_selectedCity != null
          ? LatLng(_selectedCity!.latitude ?? 29.3803, _selectedCity!.longitude ?? 79.4636)
          : const LatLng(29.3803, 79.4636));

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
                    initialZoom: _radiusToZoom(_radius),
                    minZoom: 8,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      enableMultiFingerGestureRace: true,
                      pinchZoomThreshold: 0.3,
                      pinchMoveThreshold: 30.0,
                    ),
                    onMapReady: () {
                      _mapReady = true;
                      if (_userLocation != null) {
                        _mapController.move(_userLocation!, _radiusToZoom(_radius));
                      }
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
                    // Radius circle
                    if (_userLocation != null || _selectedCity != null)
                      CircleLayer(circles: [
                        CircleMarker(
                          point: _circleCenter,
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

          // Top gradient header
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(children: [
                    Row(children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 6),
                      const Text('RentNearBy',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                      const Spacer(),
                      _buildCitySelector(),
                    ]),
                    const SizedBox(height: 14),
                    _buildRadiusChips(),
                  ]),
                ),
              ),
            ),
          ),

          // Counter card
          Obx(() => Positioned(
            bottom: 20, left: 20, right: 20,
            child: _listingCtrl.isLoading.value ? const SizedBox() : _buildCounterCard(),
          )),

          // My location FAB
          Positioned(
            bottom: 100, right: 20,
            child: _buildLocationFab(),
          ),
        ],
      ),
    );
  }

  Widget _buildCitySelector() {
    return Obx(() {
      if (_listingCtrl.cities.isEmpty) return const SizedBox();
      final nearby = _nearbyCities;
      if (nearby.isEmpty) return const SizedBox();
      return GestureDetector(
        onTap: nearby.length > 1 ? _showCityPicker : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_selectedCity?.name ?? nearby.first.name,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
              if (nearby.length > 1) ...[
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
              ],
            ],
          ),
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
            // Zoom map to match new radius
            final center = _userLocation ??
                (_selectedCity != null
                    ? LatLng(_selectedCity!.latitude ?? 29.3803, _selectedCity!.longitude ?? 79.4636)
                    : null);
            if (center != null) _animateTo(center, _radiusToZoom(r));
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
        if (_userLocation != null) {
          _animateTo(_userLocation!, _radiusToZoom(_radius));
        }
      },
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Icon(Iconsax.location, color: AppColors.primary, size: 22),
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

  void _showCityPicker() {
    final nearby = _nearbyCities;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Column(children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
        const Text('Nearby Districts', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: nearby.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (_, i) {
              final city = nearby[i];
              final selected = _selectedCity?.id == city.id;
              return ListTile(
                title: Text(city.name, style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.textDark,
                )),
                trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () {
                  setState(() { _selectedCity = city; _currentPage = 1; });
                  Navigator.pop(context);
                  _loadNearby();
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// Map pin painter: blue circle (house icon inside) + downward spike.
// Spike tip is at (size.width/2, size.height) = exact bottom-center of the widget.
// Marker uses alignment: Alignment.bottomCenter so spike tip = lat/lng coordinate at all zoom levels.
class _PinBodyPainter extends CustomPainter {
  final Color color;
  const _PinBodyPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Circle: radius 18, centered at (18, 18)
    final circle = ui.Path()
      ..addOval(Rect.fromCircle(center: const Offset(18, 18), radius: 18));

    // Spike: base inside circle at y=32, tip at exact bottom-center
    final spike = ui.Path()
      ..moveTo(10, 32)
      ..lineTo(size.width / 2, size.height) // tip = coordinate
      ..lineTo(26, 32)
      ..close();

    final pin = ui.Path.combine(ui.PathOperation.union, circle, spike);

    canvas.drawShadow(pin, Colors.black38, 4, true);
    canvas.drawPath(pin, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinBodyPainter old) => old.color != color;
}
