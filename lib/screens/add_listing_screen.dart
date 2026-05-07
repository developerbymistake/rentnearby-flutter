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
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceMonthlyCtrl = TextEditingController();
  final _priceDayCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String? _selectedCityId;
  String? _selectedDistrictId;
  String? _selectedRoomTypeId;
  LatLng? _selectedLocation;
  LatLng? _userLocation;
  bool _mapReady = false;
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

  List<CityModel> get _nearbyCities {
    final all = _ctrl.cities.toList();
    if (_userLocation == null) return all;
    final withDist = all.map((c) => MapEntry(c,
        _haversineKm(_userLocation!.latitude, _userLocation!.longitude, c.latitude ?? 0, c.longitude ?? 0)
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

      // Auto-select nearest city
      if (_selectedCityId == null && _ctrl.cities.isNotEmpty) {
        final nearest = _nearbyCities.first;
        setState(() => _selectedCityId = nearest.id);
        await _ctrl.loadDistricts(nearest.id);
      }

      // Auto-pin at user's GPS location
      if (_selectedLocation == null) {
        setState(() => _selectedLocation = loc);
      }
      if (_mapReady) _animateTo(loc, 15.0);
    } catch (_) {}
  }

  Future<void> _animateTo(LatLng target, double zoom) async {
    if (!_mapReady || !mounted) return;
    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
    const frames = 30;
    for (var i = 1; i <= frames; i++) {
      if (!mounted) return;
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
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceMonthlyCtrl.dispose();
    _priceDayCtrl.dispose();
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

  Future<void> _submit() async {
    if (_selectedRoomTypeId == null) {
      Get.snackbar('Required', 'Please select a room type', snackPosition: SnackPosition.BOTTOM); return;
    }
    if (_selectedCityId == null) {
      Get.snackbar('Required', 'Please select a city', snackPosition: SnackPosition.BOTTOM); return;
    }

    // Auto-use GPS location if user didn't pin manually
    final pinLocation = _selectedLocation ?? _userLocation;
    if (pinLocation == null) {
      Get.snackbar('Required', 'Please pin your location on the map', snackPosition: SnackPosition.BOTTOM); return;
    }

    final data = {
      'roomTypeId': _selectedRoomTypeId,
      'title': _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : null,
      'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'priceMonthly': _priceMonthlyCtrl.text.isNotEmpty ? int.tryParse(_priceMonthlyCtrl.text) : null,
      'pricePerDay': _priceDayCtrl.text.isNotEmpty ? int.tryParse(_priceDayCtrl.text) : null,
      'latitude': pinLocation.latitude,
      'longitude': pinLocation.longitude,
      'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
      'cityId': _selectedCityId,
      'districtId': _selectedDistrictId,
    };

    final listingId = await _ctrl.createListing(data);
    if (listingId == null) return;

    for (final photo in _photos) {
      await _ctrl.uploadPhoto(listingId, photo.path);
    }

    Get.back();
    Get.snackbar('Posted!', 'Your room is now live', snackPosition: SnackPosition.BOTTOM);
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
        // Header
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

        // Step indicator with labels
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

        // Bottom buttons
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
                onPressed: _ctrl.isLoading.value ? null : () {
                  if (_step < 2) setState(() => _step++);
                  else _submit();
                },
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
        title: 'Monthly Rent & Per Day',
        child: Row(children: [
          Expanded(child: TextFormField(
            controller: _priceMonthlyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: _inputDec('e.g. 8000', prefix: '₹ '),
          )),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(
            controller: _priceDayCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: _inputDec('Per day', prefix: '₹ '),
          )),
        ]),
      ),

      _sectionCard(
        title: 'Room Details (Optional)',
        child: Column(children: [
          TextFormField(
            controller: _titleCtrl,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: _inputDec('Title e.g. Spacious 1BHK near market',
                prefixIcon: const Icon(Iconsax.home, color: AppColors.primaryLight, size: 18)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: _inputDec('Describe amenities, nearby facilities, rules...'),
          ),
        ]),
      ),
    ]),
  );

  Widget _locationStep() => SingleChildScrollView(
    key: const ValueKey(1),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionCard(
        title: 'City & District',
        child: Obx(() {
          final cities = _nearbyCities;
          return Column(children: [
            DropdownButtonFormField<String>(
              key: ValueKey('city-${cities.length}'),
              value: _selectedCityId,
              decoration: _inputDec('Select city', prefixIcon: const Icon(Iconsax.location, color: AppColors.primaryLight, size: 18)),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark),
              items: cities.map((c) => DropdownMenuItem(value: c.id,
                  child: Text(c.name, style: const TextStyle(fontFamily: 'Poppins')))).toList(),
              onChanged: (v) {
                setState(() { _selectedCityId = v; _selectedDistrictId = null; });
                if (v != null) _ctrl.loadDistricts(v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('district-$_selectedCityId-${_ctrl.districts.length}'),
              value: _selectedDistrictId,
              decoration: _inputDec('Select district (optional)',
                  prefixIcon: const Icon(Iconsax.map, color: AppColors.primaryLight, size: 18)),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark),
              items: _ctrl.districts.map((d) => DropdownMenuItem(value: d.id,
                  child: Text(d.name, style: const TextStyle(fontFamily: 'Poppins')))).toList(),
              onChanged: (v) => setState(() => _selectedDistrictId = v),
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

      _sectionCard(
        title: 'Pin Location on Map *',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 15),
            const SizedBox(width: 6),
            Expanded(child: Text(
              _selectedLocation != null
                  ? 'Location pinned — tap map to adjust'
                  : 'Tap anywhere on the map to set your pin',
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
                    minZoom: 12.0,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
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
                    onTap: (_, pos) => setState(() => _selectedLocation = pos),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.rentnearby.rentnearby',
                      maxNativeZoom: 19,
                      keepBuffer: 4,
                      panBuffer: 2,
                    ),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                            ],
                          ),
                        ),
                    ]),
                  ],
                ),
              ),
              // My location FAB
              Positioned(
                bottom: 10, right: 10,
                child: GestureDetector(
                  onTap: () {
                    if (_userLocation != null) _animateTo(_userLocation!, 15.0);
                  },
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

