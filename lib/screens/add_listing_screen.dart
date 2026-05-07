import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/listing_controller.dart';
import '../models/city_model.dart';
import '../widgets/gradient_button.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});
  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _ctrl = Get.find<ListingController>();
  final _mapController = MapController();
  final _descCtrl = TextEditingController();
  final _priceMonthlyCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String? _selectedDistrictId;
  String? _selectedCityId;
  String? _selectedRoomTypeId;
  LatLng? _selectedLocation;
  LatLng? _userLocation;
  bool _mapReady = false;
  bool _animateCancelled = false;
  final List<File> _photos = [];
  final _picker = ImagePicker();
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
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
    final all = _ctrl.districts.toList();
    if (_userLocation == null) return all;
    final withDist = all.map((d) => MapEntry(d,
        _haversineKm(_userLocation!.latitude, _userLocation!.longitude, d.latitude ?? 0, d.longitude ?? 0)
    )).toList()..sort((a, b) => a.value.compareTo(b.value));
    final nearby = withDist.where((e) => e.value <= 100).map((e) => e.key).toList();
    return nearby.isNotEmpty ? nearby : (withDist.isNotEmpty ? [withDist.first.key] : all);
  }

  Future<void> _fetchUserLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _userLocation = loc);

      // Auto-detect nearest Uttarakhand district
      if (_selectedDistrictId == null && _ctrl.districts.isNotEmpty) {
        final nearest = _nearbyDistricts.first;
        setState(() => _selectedDistrictId = nearest.id);
        await _ctrl.loadCities(nearest.id);
        // Auto-detect nearest city within that district
        final nearestCity = _nearestCity();
        if (nearestCity != null) {
          setState(() => _selectedCityId = nearestCity.id);
        }
      }

      if (_selectedLocation == null) {
        setState(() => _selectedLocation = loc);
      }
      if (_mapReady) _animateTo(loc, 15.0);
    } catch (_) {}
  }

  CityModel? _nearestCity() {
    if (_userLocation == null || _ctrl.cities.isEmpty) return null;
    CityModel? nearest;
    double minDist = double.infinity;
    for (final c in _ctrl.cities) {
      if (c.latitude == null || c.longitude == null) continue;
      final dist = _haversineKm(
        _userLocation!.latitude, _userLocation!.longitude,
        c.latitude!, c.longitude!,
      );
      if (dist < minDist) { minDist = dist; nearest = c; }
    }
    return nearest;
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
  void dispose() {
    _descCtrl.dispose();
    _priceMonthlyCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 5) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
              const Text('Add Photo', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 22),
                ),
                title: const Text('Take Photo', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500, color: AppColors.textDark)),
                subtitle: const Text('Use camera to capture now', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 22),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500, color: AppColors.textDark)),
                subtitle: const Text('Pick existing photos', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null && mounted) setState(() => _photos.add(File(picked.path)));
  }

  void _handleNext() {
    if (_step == 0) {
      if (_selectedRoomTypeId == null) {
        Get.snackbar('Room Type Required', 'Please select a room type to continue',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.error,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16));
        return;
      }
      if (_priceMonthlyCtrl.text.trim().isEmpty) {
        Get.snackbar('Rent Required', 'Please enter the monthly rent amount',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.error,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16));
        return;
      }
    }
    if (_step == 1) {
      if (_selectedDistrictId == null) {
        Get.snackbar('District Required', 'Please select a district to continue',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.error,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16));
        return;
      }
    }
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_selectedRoomTypeId == null) {
      Get.snackbar('Required', 'Please select a room type', snackPosition: SnackPosition.BOTTOM); return;
    }
    if (_selectedDistrictId == null) {
      Get.snackbar('Required', 'Please select a district', snackPosition: SnackPosition.BOTTOM); return;
    }

    final pinLocation = _selectedLocation ?? _userLocation;
    if (pinLocation == null) {
      Get.snackbar('Required', 'Please pin your location on the map', snackPosition: SnackPosition.BOTTOM); return;
    }

    final data = {
      'roomTypeId': _selectedRoomTypeId,
      'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'priceMonthly': _priceMonthlyCtrl.text.isNotEmpty ? int.tryParse(_priceMonthlyCtrl.text) : null,
      'latitude': pinLocation.latitude,
      'longitude': pinLocation.longitude,
      'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
      'districtId': _selectedDistrictId,
      'cityId': _selectedCityId,
    };

    final listingId = await _ctrl.createListing(data);
    if (listingId == null) return;

    for (final photo in _photos) {
      await _ctrl.uploadPhoto(listingId, photo.path);
    }

    Get.offNamed(AppRoutes.listingDetail, arguments: listingId);
  }

  InputDecoration _inputDec(String hint, {Widget? prefixIcon, String? prefix}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
    prefixIcon: prefixIcon,
    prefixText: prefix,
    prefixStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
              child: Row(children: [
                IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white)),
                const Text('Post Your Room', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
            ),
          ),
        ),

        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(children: [
            _stepDot(0, 'Details'),
            Expanded(child: Container(height: 2, color: _step >= 1 ? AppColors.primary : AppColors.divider)),
            _stepDot(1, 'Location'),
            Expanded(child: Container(height: 2, color: _step >= 2 ? AppColors.primary : AppColors.divider)),
            _stepDot(2, 'Photos'),
          ]),
        ),

        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: _step == 0 ? _detailsStep() : _step == 1 ? _locationStep() : _photosStep(),
          ),
        ),

        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
          child: Row(children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step--),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Back', style: TextStyle(fontFamily: 'Poppins', color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: Obx(() => GradientButton(
                onPressed: _ctrl.isLoading.value ? null : _handleNext,
                isLoading: _ctrl.isLoading.value,
                label: _step == 0 ? 'Next: Location' : _step == 1 ? 'Next: Photos' : 'Post Listing',
              )),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _stepDot(int index, String label) {
    final active = _step == index;
    final done = _step > index;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: (active || done) ? AppColors.primary : AppColors.divider,
            shape: BoxShape.circle,
          ),
          child: Center(child: done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
              : Text('${index + 1}', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.textLight)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w500,
            color: (active || done) ? AppColors.primary : AppColors.textLight)),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      const SizedBox(height: 14),
      child,
    ]),
  );

  Widget _detailsStep() => SingleChildScrollView(
    key: const ValueKey(0),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionCard(
        title: 'Room Type *',
        child: Obx(() => Wrap(
          spacing: 8, runSpacing: 8,
          children: _ctrl.roomTypes.map((rt) {
            final active = _selectedRoomTypeId == rt.id;
            return GestureDetector(
              onTap: () => setState(() => _selectedRoomTypeId = rt.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: active ? AppColors.primary : AppColors.divider, width: 1.5),
                ),
                child: Text(rt.name, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500,
                    color: active ? Colors.white : AppColors.textMedium)),
              ),
            );
          }).toList(),
        )),
      ),

      _sectionCard(
        title: 'Monthly Rent (₹) *',
        child: TextFormField(
          controller: _priceMonthlyCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _inputDec('e.g. 8000', prefix: '₹ '),
        ),
      ),

      _sectionCard(
        title: 'Description (Optional)',
        child: TextFormField(
          controller: _descCtrl,
          maxLines: 3,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _inputDec('Describe amenities, nearby facilities, rules...'),
        ),
      ),
    ]),
  );

  Widget _locationStep() => SingleChildScrollView(
    key: const ValueKey(1),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionCard(
        title: 'Pin Your Location *',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 15),
            const SizedBox(width: 6),
            Expanded(child: Text(
              _userLocation != null
                  ? (_selectedLocation != null
                      ? 'Pinned — tap inside the circle to adjust'
                      : 'Tap inside the blue circle to pin your room')
                  : 'Waiting for your GPS location...',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
            )),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(children: [
              SizedBox(
                height: 280,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _userLocation ?? const LatLng(29.3803, 79.4636),
                    initialZoom: 15.0,
                    minZoom: 13.0,
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
                        _mapController.move(_userLocation!, 15.0);
                        if (_selectedLocation == null) {
                          setState(() => _selectedLocation = _userLocation);
                        }
                      }
                    },
                    onPositionChanged: (_, hasGesture) {
                      if (hasGesture) _animateCancelled = true;
                    },
                    onTap: (_, pos) {
                      if (_userLocation != null) {
                        final dist = _haversineKm(
                          _userLocation!.latitude, _userLocation!.longitude,
                          pos.latitude, pos.longitude,
                        );
                        if (dist > 1.0) {
                          Get.snackbar('Out of Range',
                              'You can only pin within 1km of your current location',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: AppColors.error,
                              colorText: Colors.white,
                              margin: const EdgeInsets.all(16));
                          return;
                        }
                      }
                      setState(() => _selectedLocation = pos);
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
                    if (_userLocation != null)
                      CircleLayer(circles: [
                        CircleMarker(
                          point: _userLocation!,
                          radius: 1000,
                          useRadiusInMeter: true,
                          color: AppColors.primary.withOpacity(0.08),
                          borderColor: AppColors.primary.withOpacity(0.6),
                          borderStrokeWidth: 1.5,
                        ),
                      ]),
                    MarkerLayer(markers: [
                      if (_userLocation != null)
                        Marker(
                          point: _userLocation!,
                          width: 18, height: 18,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [BoxShadow(color: const Color(0xFFE53935).withOpacity(0.4), blurRadius: 6, spreadRadius: 2)],
                            ),
                          ),
                        ),
                      if (_selectedLocation != null)
                        Marker(
                          point: _selectedLocation!,
                          width: 40, height: 48,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))],
                              ),
                              child: const Icon(Icons.home_rounded, color: Colors.white, size: 18),
                            ),
                            Container(width: 2, height: 10, color: AppColors.primary),
                          ]),
                        ),
                    ]),
                  ],
                ),
              ),
              Positioned(
                bottom: 10, right: 10,
                child: GestureDetector(
                  onTap: () { if (_userLocation != null) _animateTo(_userLocation!, 15.0); },
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const Icon(Iconsax.location, color: AppColors.primary, size: 18),
                  ),
                ),
              ),
            ]),
          ),
          if (_selectedLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                ),
              ]),
            ),
        ]),
      ),

      _sectionCard(
        title: 'District & City',
        child: Obx(() {
          final gpsAvailable = _userLocation != null;
          final districtName = _ctrl.districts.firstWhereOrNull((d) => d.id == _selectedDistrictId)?.name;
          final cityName = _ctrl.cities.firstWhereOrNull((c) => c.id == _selectedCityId)?.name;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('District *', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
            const SizedBox(height: 6),
            if (gpsAvailable && districtName != null)
              _readOnlyField(Iconsax.location, districtName)
            else
              DropdownButtonFormField<String>(
                key: ValueKey('district-${_ctrl.districts.length}'),
                value: _selectedDistrictId,
                decoration: _inputDec('Select your district', prefixIcon: const Icon(Iconsax.location, color: AppColors.primaryLight, size: 18)),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark),
                items: _ctrl.districts.map((d) => DropdownMenuItem(value: d.id,
                    child: Text(d.name, style: const TextStyle(fontFamily: 'Poppins')))).toList(),
                onChanged: (v) {
                  setState(() { _selectedDistrictId = v; _selectedCityId = null; });
                  if (v != null) _ctrl.loadCities(v);
                },
              ),
            const SizedBox(height: 16),
            const Text('City / Area (Optional)', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
            const SizedBox(height: 6),
            if (gpsAvailable && cityName != null)
              _readOnlyField(Iconsax.map, cityName)
            else
              DropdownButtonFormField<String>(
                key: ValueKey('city-$_selectedDistrictId-${_ctrl.cities.length}'),
                value: _selectedCityId,
                decoration: _inputDec('Select city or area', prefixIcon: const Icon(Iconsax.map, color: AppColors.primaryLight, size: 18)),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark),
                items: _ctrl.cities.map((c) => DropdownMenuItem(value: c.id,
                    child: Text(c.name, style: const TextStyle(fontFamily: 'Poppins')))).toList(),
                onChanged: (v) => setState(() => _selectedCityId = v),
              ),
          ]);
        }),
      ),

      _sectionCard(
        title: 'Address (Optional)',
        child: TextFormField(
          controller: _addressCtrl,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _inputDec('Street, landmark, nearby place...',
              prefixIcon: const Icon(Iconsax.building, color: AppColors.primaryLight, size: 18)),
        ),
      ),
    ]),
  );

  Widget _readOnlyField(IconData icon, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(children: [
      Icon(icon, color: AppColors.primaryLight, size: 18),
      const SizedBox(width: 10),
      Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark)),
      const Spacer(),
      const Icon(Icons.gps_fixed_rounded, color: AppColors.success, size: 14),
    ]),
  );

  Widget _photosStep() => SingleChildScrollView(
    key: const ValueKey(2),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionCard(
        title: 'Room Photos',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${_photos.length}/5 photos added',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
            const Spacer(),
            const Text('Optional', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textHint)),
          ]),
          const SizedBox(height: 4),
          const Text('Good photos get 3x more enquiries',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.primaryLight)),
          const SizedBox(height: 16),

          if (_photos.isEmpty)
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5,
                      style: BorderStyle.solid),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(height: 10),
                  const Text('Add Room Photos', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(height: 4),
                  const Text('Camera or Gallery', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                ]),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: _photos.length + (_photos.length < 5 ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _photos.length) {
                  return GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_rounded, color: AppColors.primary, size: 28),
                        SizedBox(height: 4),
                        Text('Add', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  );
                }
                return Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_photos[i], fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  ),
                  if (i == 0)
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.8),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        ),
                        child: const Text('Cover', textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  Positioned(top: 4, right: 4, child: GestureDetector(
                    onTap: () => setState(() => _photos.removeAt(i)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 11),
                    ),
                  )),
                ]);
              },
            ),

          if (_photos.isNotEmpty && _photos.length < 5) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _pickPhoto,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text('Add ${5 - _photos.length} more photo${5 - _photos.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
              ]),
            ),
          ],
        ]),
      ),
    ]),
  );
}
