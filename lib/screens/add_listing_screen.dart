import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart' as http_dio;
import 'dart:io';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/listing_controller.dart';
import '../utils/app_toast.dart';
import '../widgets/gradient_button.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});
  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _ctrl = Get.find<ListingController>();
  MapLibreMapController? _mapController;
  Fill?   _nativeCircle;
  Line?   _nativeCircleGlow;
  Line?   _nativeCircleLine;
  Circle? _nativeUserDot;
  LatLng? _cameraCenter;
  double  _currentZoom = 15.0;
  Size    _mapSize = Size.zero;
  final _descCtrl = TextEditingController();
  final _priceMonthlyCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _priceFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();

  String? _selectedDistrictId;
  String? _selectedCityId;
  String? _selectedRoomTypeId;
  LatLng? _selectedLocation;
  LatLng? _userLocation;
  bool _locationBlocked = false; // permission denied forever OR GPS service off
  bool _mapReady = false;
  bool _isGeocoding = false;
  bool _isUploading = false;
  int _uploadCurrent = 0;
  int _uploadTotal = 0;
  double _uploadProgress = 0.0;
  final List<File> _photos = [];
  final _picker = ImagePicker();
  int _step = 0;
  Timer? _nominatimTimer;

  bool get _hasChanges =>
      _selectedRoomTypeId != null ||
      _priceMonthlyCtrl.text.isNotEmpty ||
      _descCtrl.text.isNotEmpty ||
      _photos.isNotEmpty ||
      _addressCtrl.text.isNotEmpty ||
      _selectedLocation != null;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }


  Future<void> _fetchUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationBlocked = true);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationBlocked = true);
        return;
      }

      bool contextLoaded = false; // Flag to prevent duplicate context load

      // Step 1: lastKnown se turant map + district/city load karo (Step 1 background mein)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        final lastLoc = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() {
          _userLocation = lastLoc;
          _selectedLocation ??= lastLoc;
        });
        // District/city Step 1 mein hi load karo — Step 2 instantly ready milega
        if (_selectedDistrictId == null) {
          final ctx = await _ctrl.loadContext(lastLoc.latitude, lastLoc.longitude);
          if (mounted && ctx != null) {
            await _ctrl.loadCities(ctx.district.id);
            if (mounted) {
              setState(() {
                _selectedDistrictId = ctx.district.id;
                _selectedCityId = ctx.nearestCity?.id;
              });
              contextLoaded = true; // Mark as loaded
            }
          }
        }
      }

      // Step 2: Accurate GPS fix — pin update karo (district already set hai toh skip)
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      final addressWasEmpty = _addressCtrl.text.trim().isEmpty;
      setState(() {
        _userLocation = loc;
        if (_selectedLocation == null ||
            (_selectedLocation!.latitude == lastKnown?.latitude &&
             _selectedLocation!.longitude == lastKnown?.longitude)) {
          _selectedLocation = loc;
        }
      });
      if (_mapReady) {
        if (_nativeUserDot == null) _initNativeUserDot();
        else _updateNativeUserDot();
      }

      // Auto-fetch address from accurate GPS if not already filled
      if (addressWasEmpty && _selectedLocation != null) {
        _reverseGeocode(_selectedLocation!);
      }

      // Accurate GPS se district reload sirf tab jab lastKnown nahi tha aur contextLoaded nahi hai
      if (!contextLoaded && _selectedDistrictId == null) {
        final ctx = await _ctrl.loadContext(loc.latitude, loc.longitude);
        if (mounted && ctx != null) {
          await _ctrl.loadCities(ctx.district.id);
          if (mounted) setState(() {
            _selectedDistrictId = ctx.district.id;
            _selectedCityId = ctx.nearestCity?.id;
          });
        }
      }

      if (_mapReady) _animateTo(loc, 15.0);
    } catch (_) {}
  }

  void _animateTo(LatLng target, double zoom) {
    if (!_mapReady || _mapController == null || !mounted) return;
    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  void _onStyleLoaded() {
    _mapReady = true;
    if (!mounted) return;
    _initNativeCircle();
    _initNativeUserDot();
    if (_userLocation != null) _animateTo(_userLocation!, 15.0);
    setState(() {});
  }

  Future<void> _initNativeCircle() async {
    final ctrl = _mapController;
    final loc = _userLocation;
    if (ctrl == null || loc == null || !mounted) return;
    final points = _circlePolygonPoints(loc, 0.5);
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

  Offset? _latLngToScreen(LatLng pos) {
    final center = _cameraCenter;
    if (center == null || _mapSize == Size.zero) return null;
    final scale = 512.0 * pow(2.0, _currentZoom);
    final px = (pos.longitude + 180) / 360 * scale;
    final py = _mercatorY(pos.latitude) * scale;
    final cx = (center.longitude + 180) / 360 * scale;
    final cy = _mercatorY(center.latitude) * scale;
    return Offset(
      _mapSize.width / 2 + (px - cx),
      _mapSize.height / 2 + (py - cy),
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
    return List.generate(steps + 1, (i) {
      final angle = 2 * pi * i / steps;
      final dLat = (radiusKm * 1000 * cos(angle)) / earthRadius * (180 / pi);
      final dLng = (radiusKm * 1000 * sin(angle)) / (earthRadius * cos(latRad)) * (180 / pi);
      return LatLng(center.latitude + dLat, center.longitude + dLng);
    });
  }

  @override
  void dispose() {
    _nominatimTimer?.cancel();
    _descCtrl.dispose();
    _priceMonthlyCtrl.dispose();
    _addressCtrl.dispose();
    _priceFocusNode.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    _nominatimTimer?.cancel();
    _nominatimTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _isGeocoding = true);
      try {
        final dio = http_dio.Dio();
        final res = await dio.get<Map<String, dynamic>>(
          'https://nominatim.openstreetmap.org/reverse',
          queryParameters: {
            'format': 'jsonv2',
            'lat': pos.latitude.toStringAsFixed(6),
            'lon': pos.longitude.toStringAsFixed(6),
          },
          options: http_dio.Options(
            headers: {'User-Agent': 'Bakhli/1.0 (bakhli.app)'},
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
        if (!mounted) return;
        final displayName = res.data?['display_name'] as String? ?? '';
        if (displayName.isNotEmpty) {
          final parts = displayName.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          _addressCtrl.text = parts.take(3).join(', ');
        }
      } catch (_) {
        // Ignore geocoding failures silently — user can type manually
      } finally {
        if (mounted) setState(() => _isGeocoding = false);
      }
    });
  }

  void _confirmDiscard() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard Listing?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textDark)),
        content: const Text(
          'You have unsaved changes. Going back will discard everything.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Editing',
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Get.back();
            },
            child: const Text('Discard', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog(String type) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$type Permission Required',
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textDark)),
        content: Text(
          'Please enable $type access in your device Settings to add photos.',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
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

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (status.isPermanentlyDenied && mounted) _showPermissionDeniedDialog('Camera');
        return;
      }
    }

    if (source == ImageSource.camera) {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null && mounted) setState(() => _photos.add(File(picked.path)));
    } else {
      final remaining = 5 - _photos.length;
      final picked = await _picker.pickMultiImage(imageQuality: 85, limit: remaining);
      if (picked.isNotEmpty && mounted) {
        final allowed = picked.take(remaining).map((f) => File(f.path)).toList();
        setState(() => _photos.addAll(allowed));
        if (allowed.length < picked.length) {
          AppToast.warning('Only $remaining more photo${remaining == 1 ? '' : 's'} allowed. Extra photos were removed.');
        }
      }
    }
  }

  void _handleNext() {
    if (_step == 0) {
      if (_selectedRoomTypeId == null) {
        AppToast.error('Please select a room type to continue');
        return;
      }
      if (_priceMonthlyCtrl.text.trim().isEmpty) {
        AppToast.error('Please enter the monthly rent amount');
        _priceFocusNode.requestFocus();
        return;
      }
      final rent = int.tryParse(_priceMonthlyCtrl.text) ?? 0;
      if (rent <= 0) {
        AppToast.error('Monthly rent must be greater than 0');
        _priceFocusNode.requestFocus();
        return;
      }
      if (rent > 9900000) {
        AppToast.error('Monthly rent cannot exceed ₹99,00,000');
        _priceFocusNode.requestFocus();
        return;
      }
    }
    if (_step == 1) {
      if (_selectedDistrictId == null) {
        AppToast.error('Please select a district to continue');
        return;
      }
      if (_addressCtrl.text.trim().isEmpty) {
        AppToast.error('Address is required');
        _addressFocusNode.requestFocus();
        return;
      }
    }
    if (_step < 2) {
      setState(() => _step++);
      // Auto-fetch address when entering Step 1 (location step)
      if (_step == 1 && _addressCtrl.text.trim().isEmpty && _selectedLocation != null) {
        _reverseGeocode(_selectedLocation!);
      }
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_selectedRoomTypeId == null) {
      AppToast.error('Please select a room type'); return;
    }
    if (_selectedDistrictId == null) {
      AppToast.error('Please select a district'); return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      AppToast.error('Address is required');
      _addressFocusNode.requestFocus();
      return;
    }

    final pinLocation = _selectedLocation ?? _userLocation;
    if (pinLocation == null) {
      AppToast.error('Please pin your location on the map'); return;
    }

    final data = {
      'roomTypeId': _selectedRoomTypeId,
      'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'priceMonthly': _priceMonthlyCtrl.text.isNotEmpty ? int.tryParse(_priceMonthlyCtrl.text) : null,
      'latitude': pinLocation.latitude,
      'longitude': pinLocation.longitude,
      'address': _addressCtrl.text.trim(),
      'districtId': _selectedDistrictId,
      'cityId': _selectedCityId,
    };

    final listingId = await _ctrl.createListing(data);
    if (listingId == null) return;

    if (_photos.isNotEmpty) {
      setState(() {
        _isUploading = true;
        _uploadTotal = _photos.length;
        _uploadCurrent = 1;
        _uploadProgress = 0.0;
      });
      int failed = 0;
      for (int i = 0; i < _photos.length; i++) {
        setState(() {
          _uploadCurrent = i + 1;
          _uploadProgress = 0.0;
        });
        final success = await _ctrl.uploadPhoto(listingId, _photos[i].path, onProgress: (sent, total) {
          if (!mounted) return;
          setState(() => _uploadProgress = total > 0 ? sent / total : 0.0);
        });
        if (!success) {
          failed++;
          // Ask user: skip or retry this photo
          if (!mounted) break;
          final retry = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Upload Failed',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              content: Text(
                'Photo ${i + 1} could not be uploaded after 3 attempts. What would you like to do?',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Skip',
                      style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Retry', style: TextStyle(fontFamily: 'Poppins')),
                ),
              ],
            ),
          );
          if (retry == true) {
            // One more full attempt (controller internally retries 3x again)
            final retrySuccess = await _ctrl.uploadPhoto(listingId, _photos[i].path, onProgress: (sent, total) {
              if (!mounted) return;
              setState(() => _uploadProgress = total > 0 ? sent / total : 0.0);
            });
            if (retrySuccess) failed--;
          }
        }
      }
      if (mounted) setState(() => _isUploading = false);
      if (failed > 0 && mounted) {
        AppToast.error('$failed photo${failed > 1 ? 's' : ''} could not be uploaded.');
      }
      // Notify explore page after all photos are uploaded
      _ctrl.notifyListingPosted();
    } else {
      // Case 2: No photos selected (photo upload is optional)
      // Still notify explore page so pin appears
      _ctrl.notifyListingPosted();
    }

    await _ctrl.loadMyListings();

    // If user is on a free (price=0) plan and at capacity, go straight to paid payment
    try {
      final results = await Future.wait([
        _ctrl.getMembershipStatus(),
        _ctrl.getPlans(),
      ]);
      final membership = results[0] as Map<String, dynamic>?;
      final plans = results[1] as Map<String, Map<String, dynamic>>;
      final hasMembership = membership != null && (membership['hasMembership'] == true);
      final planType = membership?['planType'] as String? ?? '';
      final maxRooms = (membership?['maxRooms'] as num?)?.toInt() ?? 0;
      final activeRooms = (membership?['activeRooms'] as num?)?.toInt() ?? 0;
      final currentPlanIsFree = (plans[planType]?['price'] as num? ?? 0) == 0;

      if (hasMembership && currentPlanIsFree && activeRooms >= maxRooms) {
        final _paidMatches = plans.values.cast<Map<String, dynamic>>().where((p) => (p['price'] as num? ?? 0) > 0);
        final paidPlan = _paidMatches.isEmpty ? {'planType': 'PAID', 'price': 99, 'days': 30, 'roomLimit': 2} : _paidMatches.first;
        Get.offNamed(AppRoutes.paymentScreen, arguments: {
          'listingId': listingId,
          'plan': paidPlan,
        });
        return;
      }
    } catch (_) {}

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

  Widget _buildUploadOverlay() {
    final overall = _uploadTotal > 0
        ? ((_uploadCurrent - 1) + _uploadProgress) / _uploadTotal
        : 0.0;
    final percent = (overall * 100).toInt();
    final String statusText;
    if (percent >= 95) {
      statusText = 'Almost done!';
    } else if (_uploadCurrent == _uploadTotal) {
      statusText = 'Last photo…';
    } else {
      statusText = 'Please wait…';
    }
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 40, offset: const Offset(0, 12))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
                child: const Center(child: Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 32)),
              ),
              const SizedBox(height: 20),
              const Text('Uploading Photos',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark, decoration: TextDecoration.none)),
              const SizedBox(height: 6),
              Text(
                'Photo $_uploadCurrent of $_uploadTotal',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight, decoration: TextDecoration.none),
              ),
              const SizedBox(height: 20),
              // Step dots — one per photo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_uploadTotal, (i) {
                  final isDone = i < _uploadCurrent - 1;
                  final isCurrent = i == _uploadCurrent - 1;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isCurrent ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDone || isCurrent ? AppColors.primary : AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              // Animated gradient progress bar
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: overall),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, value, _) {
                  return Column(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          Container(height: 10, color: AppColors.divider),
                          FractionallySizedBox(
                            widthFactor: value.clamp(0.0, 1.0),
                            child: Container(
                              height: 10,
                              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          statusText,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint, decoration: TextDecoration.none),
                        ),
                        Text(
                          '${(value * 100).toInt()}%',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary, decoration: TextDecoration.none),
                        ),
                      ],
                    ),
                  ]);
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isUploading) return;
        if (_hasChanges) {
          _confirmDiscard();
        } else {
          Get.back();
        }
      },
      child: Stack(
        children: [
      Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
              child: Row(children: [
                IconButton(
                  onPressed: _isUploading ? null : () {
                    if (_hasChanges) {
                      _confirmDiscard();
                    } else {
                      Get.back();
                    }
                  },
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                ),
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
              child: Obx(() {
                final isButtonDisabled = _ctrl.isLoading.value ||
                    (_step == 1 && (_isGeocoding || _addressCtrl.text.trim().isEmpty));
                return GradientButton(
                  onPressed: isButtonDisabled ? null : _handleNext,
                  isLoading: _ctrl.isLoading.value,
                  label: _step == 0 ? 'Next: Location' : _step == 1 ? 'Next: Photos' : 'Post Listing',
                );
              }),
            ),
          ]),
        ),
      ]),
      ),
          if (_isUploading) _buildUploadOverlay(),
        ],
      ),
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
        child: Obx(() {
          final types = _ctrl.roomTypes;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types.map((rt) {
              final active = _selectedRoomTypeId == rt.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedRoomTypeId = rt.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: (MediaQuery.of(context).size.width - 40 - 32 - 16) / 3,
                  height: 38,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: active ? AppColors.primary : AppColors.divider,
                        width: 1.5),
                  ),
                  child: Center(
                    child: Text(rt.name,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : AppColors.textMedium)),
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ),

      _sectionCard(
        title: 'Monthly Rent (₹) *',
        child: TextFormField(
          controller: _priceMonthlyCtrl,
          focusNode: _priceFocusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(7),
          ],
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _inputDec('e.g. 8000', prefix: '₹ '),
        ),
      ),

      _sectionCard(
        title: 'Description (Optional)',
        child: TextFormField(
          controller: _descCtrl,
          maxLines: 3,
          maxLength: 300,
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
          if (_locationBlocked) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.location_off_rounded, color: AppColors.error, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Location access required',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error)),
                    const SizedBox(height: 4),
                    const Text('Please enable GPS and grant location permission to pin your room.',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium, height: 1.5)),
                    const SizedBox(height: 10),
                    Row(children: [
                      GestureDetector(
                        onTap: () async {
                          await Geolocator.openLocationSettings();
                          if (mounted) setState(() => _locationBlocked = false);
                          _fetchUserLocation();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Enable GPS',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () async {
                          await Geolocator.openAppSettings();
                          if (mounted) setState(() => _locationBlocked = false);
                          _fetchUserLocation();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('App Settings',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ] else
          Row(children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 15),
            const SizedBox(width: 6),
            Expanded(child: Text(
              _userLocation != null
                  ? (_selectedLocation != null
                      ? 'Pinned — tap inside the circle to adjust'
                      : 'Tap inside the 500 m circle to pin your room')
                  : 'Waiting for your GPS location...',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
            )),
          ]),
          const SizedBox(height: 12),
          if (_userLocation == null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 280,
                color: AppColors.surface,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                      SizedBox(height: 14),
                      Text('Getting your location...', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
                    ],
                  ),
                ),
              ),
            ),
          ] else
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                _mapSize = Size(constraints.maxWidth, 280);
                return SizedBox(
                  height: 280,
                  child: Stack(children: [
                    MapLibreMap(
                      styleString: 'assets/map_style.json',
                      initialCameraPosition: CameraPosition(
                        target: _userLocation ?? const LatLng(30.3165, 78.0322),
                        zoom: 15.0,
                      ),
                      minMaxZoomPreference: const MinMaxZoomPreference(10, 18),
                      compassEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      myLocationEnabled: false,
                      trackCameraPosition: true,
                      attributionButtonMargins: const Point(-200.0, 0.0),
                      onMapCreated: (ctrl) => _mapController = ctrl,
                      onStyleLoadedCallback: _onStyleLoaded,
                      onCameraMove: (pos) {
                        _currentZoom = pos.zoom;
                        _cameraCenter = pos.target;
                        if (mounted && _selectedLocation != null) setState(() {});
                      },
                      onCameraIdle: () {
                        if (mounted) setState(() {});
                      },
                      onMapClick: (_, latLng) {
                        if (_userLocation != null) {
                          final distM = Geolocator.distanceBetween(
                            _userLocation!.latitude, _userLocation!.longitude,
                            latLng.latitude, latLng.longitude,
                          );
                          if (distM > 500) {
                            AppToast.warning('You can only pin within 500 m of your current location');
                            return;
                          }
                        }
                        setState(() => _selectedLocation = latLng);
                        _reverseGeocode(latLng);
                      },
                    ),
                    if (_selectedLocation != null)
                      Builder(builder: (_) {
                        final screen = _latLngToScreen(_selectedLocation!);
                        if (screen == null) return const SizedBox.shrink();
                        return Positioned(
                          left: screen.dx - 20,
                          top:  screen.dy - 46,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 3))],
                              ),
                              child: const Icon(Icons.home_rounded, color: Colors.white, size: 18),
                            ),
                            Container(width: 2, height: 10, color: AppColors.primary),
                          ]),
                        );
                      }),
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
                );
              },
            ),
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
                initialValue: _selectedDistrictId,
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
                initialValue: _selectedCityId,
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
        title: 'Address *',
        child: TextFormField(
          controller: _addressCtrl,
          focusNode: _addressFocusNode,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _inputDec(
            'Street, landmark, nearby place...',
            prefixIcon: const Icon(Iconsax.building, color: AppColors.primaryLight, size: 18),
          ).copyWith(
            suffixIcon: _isGeocoding
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                    ),
                  )
                : null,
          ),
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
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5,
                      style: BorderStyle.solid),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
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
                          color: AppColors.primary.withValues(alpha: 0.8),
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
