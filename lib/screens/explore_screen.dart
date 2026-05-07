import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
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
  GoogleMapController? _mapController;
  final _listingCtrl = Get.find<ListingController>();
  final Set<Marker> _markers = {};
  LatLng? _userLocation;
  double _radius = 5.0;
  CityModel? _selectedCity;
  bool _locationLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
        _locationLoading = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(_userLocation!));
      _loadNearby();
    } catch (_) {
      setState(() => _locationLoading = false);
    }
  }

  Future<void> _loadNearby() async {
    if (_userLocation == null || _selectedCity == null) return;
    await _listingCtrl.loadNearby(
      _userLocation!.latitude, _userLocation!.longitude, _radius, _selectedCity!.id);
    _buildMarkers();
  }

  void _buildMarkers() {
    setState(() {
      _markers.clear();
      for (final listing in _listingCtrl.nearbyListings) {
        _markers.add(Marker(
          markerId: MarkerId(listing.id),
          position: LatLng(listing.latitude, listing.longitude),
          infoWindow: InfoWindow(title: listing.shortPrice, snippet: listing.roomTypeName),
          onTap: () => _showDetail(listing.id),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ));
      }
    });
  }

  void _showDetail(String id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListingBottomSheet(listingId: id),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Stack(
        children: [
          // Map
          _locationLoading
              ? _buildMapShimmer()
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _userLocation ?? const LatLng(20.5937, 78.9629),
                    zoom: 14,
                  ),
                  onMapCreated: (ctrl) => _mapController = ctrl,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
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
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 6),
                          const Text('RentNearBy',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                          const Spacer(),
                          _buildCitySelector(),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildRadiusChips(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom counter card
          Obx(() => Positioned(
            bottom: 20, left: 20, right: 20,
            child: _listingCtrl.isLoading.value
                ? const SizedBox()
                : _buildCounterCard(),
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
      return GestureDetector(
        onTap: _showCityPicker,
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
              Text(_selectedCity?.name ?? 'Select City',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
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
            setState(() => _radius = r);
            _loadNearby();
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
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : Colors.white,
                )),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCounterCard() {
    final count = _listingCtrl.nearbyListings.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Text('$count',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(count == 0 ? 'No rooms found' : '$count room${count == 1 ? '' : 's'} nearby',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              Text('within ${_radius.toInt() == _radius ? _radius.toInt() : _radius} km radius',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
        ],
      ),
    );
  }

  Widget _buildLocationFab() {
    return GestureDetector(
      onTap: () {
        if (_userLocation != null) {
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_userLocation!, 15));
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Obx(() => Column(
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          const Text('Select City', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _listingCtrl.cities.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (_, i) {
                final city = _listingCtrl.cities[i];
                final selected = _selectedCity?.id == city.id;
                return ListTile(
                  title: Text(city.name, style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppColors.primary : AppColors.textDark,
                  )),
                  trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                  onTap: () {
                    setState(() => _selectedCity = city);
                    Navigator.pop(context);
                    _loadNearby();
                  },
                );
              },
            ),
          ),
        ],
      )),
    );
  }
}
