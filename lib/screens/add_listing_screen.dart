import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:io';
import '../config/app_colors.dart';
import '../controllers/listing_controller.dart';
import '../widgets/gradient_button.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});
  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _ctrl = Get.find<ListingController>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceMonthlyCtrl = TextEditingController();
  final _priceDayCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String? _selectedCityId;
  String? _selectedDistrictId;
  String? _selectedRoomTypeId;
  LatLng? _selectedLocation;
  final List<File> _photos = [];
  final _picker = ImagePicker();
  int _step = 0;

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose();
    _priceMonthlyCtrl.dispose(); _priceDayCtrl.dispose(); _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 5) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _photos.add(File(picked.path)));
  }

  Future<void> _submit() async {
    if (_selectedLocation == null) {
      Get.snackbar('Required', 'Pick a location on map', snackPosition: SnackPosition.BOTTOM); return;
    }
    if (_selectedCityId == null) {
      Get.snackbar('Required', 'Select a city', snackPosition: SnackPosition.BOTTOM); return;
    }
    if (_selectedRoomTypeId == null) {
      Get.snackbar('Required', 'Select room type', snackPosition: SnackPosition.BOTTOM); return;
    }

    final data = {
      'roomTypeId': _selectedRoomTypeId,
      'title': _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : null,
      'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'priceMonthly': _priceMonthlyCtrl.text.isNotEmpty ? int.tryParse(_priceMonthlyCtrl.text) : null,
      'pricePerDay': _priceDayCtrl.text.isNotEmpty ? int.tryParse(_priceDayCtrl.text) : null,
      'latitude': _selectedLocation!.latitude,
      'longitude': _selectedLocation!.longitude,
      'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
      'cityId': _selectedCityId,
      'districtId': _selectedDistrictId,
    };

    final listingId = await _ctrl.createListing(data);
    if (listingId == null) return;

    // Upload photos after listing created
    if (_photos.isNotEmpty) {
      for (final photo in _photos) {
        await _ctrl.uploadPhoto(listingId, photo.path);
      }
    }

    Get.back();
    Get.snackbar('Success', 'Room listing posted!', snackPosition: SnackPosition.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
              child: Row(children: [
                IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white)),
                const Text('Add Room', style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
            ),
          ),
        ),

        // Step indicator
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: List.generate(3, (i) => Expanded(child: Row(children: [
            Expanded(child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4, decoration: BoxDecoration(
                color: i <= _step ? AppColors.primary : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            if (i < 2) const SizedBox(width: 6),
          ])))),
        ),

        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _step == 0 ? _detailsStep() : _step == 1 ? _locationStep() : _photosStep(),
          ),
        ),

        // Bottom buttons
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                label: _step < 2 ? 'Next' : 'Post Listing',
              )),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _detailsStep() => SingleChildScrollView(
    key: const ValueKey(0),
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Room Details', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      const SizedBox(height: 20),
      _label('Room Type *'),
      Obx(() => Wrap(
        spacing: 8, runSpacing: 8,
        children: _ctrl.roomTypes.map((rt) {
          final active = _selectedRoomTypeId == rt.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedRoomTypeId = rt.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? AppColors.primary : AppColors.divider),
              ),
              child: Text(rt.name, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: active ? Colors.white : AppColors.textMedium)),
            ),
          );
        }).toList(),
      )),
      const SizedBox(height: 20),
      _label('Title (optional)'),
      TextFormField(controller: _titleCtrl, style: const TextStyle(fontFamily: 'Poppins'), decoration: const InputDecoration(hintText: 'e.g. Spacious 1BHK near metro')),
      const SizedBox(height: 16),
      _label('Description (optional)'),
      TextFormField(controller: _descCtrl, maxLines: 3, style: const TextStyle(fontFamily: 'Poppins'), decoration: const InputDecoration(hintText: 'Describe the room, amenities...')),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label('Monthly Rent (₹)'),
          TextFormField(controller: _priceMonthlyCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], style: const TextStyle(fontFamily: 'Poppins'), decoration: const InputDecoration(hintText: '8000')),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label('Per Day (₹)'),
          TextFormField(controller: _priceDayCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], style: const TextStyle(fontFamily: 'Poppins'), decoration: const InputDecoration(hintText: '400')),
        ])),
      ]),
    ]),
  );

  Widget _locationStep() => SingleChildScrollView(
    key: const ValueKey(1),
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Location', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      const SizedBox(height: 16),
      _label('City *'),
      Obx(() => DropdownButtonFormField<String>(
        key: ValueKey('city-${_ctrl.cities.length}'),
        initialValue: _selectedCityId,
        decoration: const InputDecoration(hintText: 'Select city'),
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark),
        items: _ctrl.cities.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontFamily: 'Poppins')))).toList(),
        onChanged: (v) {
          setState(() { _selectedCityId = v; _selectedDistrictId = null; });
          if (v != null) _ctrl.loadDistricts(v);
        },
      )),
      const SizedBox(height: 16),
      _label('District (optional)'),
      Obx(() => DropdownButtonFormField<String>(
        // key changes when city changes → forces rebuild → resets to null
        key: ValueKey('district-$_selectedCityId-${_ctrl.districts.length}'),
        initialValue: _selectedDistrictId,
        decoration: const InputDecoration(hintText: 'Select district'),
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark),
        items: _ctrl.districts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(fontFamily: 'Poppins')))).toList(),
        onChanged: (v) => setState(() => _selectedDistrictId = v),
      )),
      const SizedBox(height: 16),
      _label('Address (optional)'),
      TextFormField(controller: _addressCtrl, style: const TextStyle(fontFamily: 'Poppins'), decoration: const InputDecoration(hintText: 'Street, landmark...')),
      const SizedBox(height: 20),
      _label('Pin on Map *'),
      Container(
        height: 250,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(20.5937, 78.9629), zoom: 5),
            onTap: (pos) => setState(() => _selectedLocation = pos),
            markers: _selectedLocation != null ? {Marker(markerId: const MarkerId('selected'), position: _selectedLocation!)} : {},
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
          ),
        ),
      ),
      if (_selectedLocation != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('📍 ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.success)),
        ),
    ]),
  );

  Widget _photosStep() => SingleChildScrollView(
    key: const ValueKey(2),
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Photos', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      const Text('Add up to 5 photos (optional)', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
      const SizedBox(height: 20),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: _photos.length + (_photos.length < 5 ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _photos.length) {
            return GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
                ),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Iconsax.camera, color: AppColors.primaryLight, size: 28),
                  SizedBox(height: 4),
                  Text('Add', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                ]),
              ),
            );
          }
          return Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_photos[i], fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
            Positioned(top: 4, right: 4, child: GestureDetector(
              onTap: () => setState(() => _photos.removeAt(i)),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            )),
          ]);
        },
      ),
    ]),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
  );
}
