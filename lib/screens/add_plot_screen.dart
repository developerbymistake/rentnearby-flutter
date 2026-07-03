import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:get/get.dart';
import '../controllers/location_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import 'dart:io';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/plot_controller.dart';
import '../utils/app_toast.dart';
import '../widgets/app_loading_overlay.dart';
import '../widgets/gradient_button.dart';

// Per-unit config: hint text and whether decimal input is allowed
const _unitConfig = {
  'sqft':  (hint: 'e.g., 1200',  decimal: false),
  'bigha': (hint: 'e.g., 1.5',   decimal: true),
  'acre':  (hint: 'e.g., 0.5',   decimal: true),
  'nali':  (hint: 'e.g., 4.0',   decimal: true),
};

const _units = ['sqft', 'bigha', 'acre', 'nali'];


class AddPlotScreen extends StatefulWidget {
  const AddPlotScreen({super.key});
  @override
  State<AddPlotScreen> createState() => _AddPlotScreenState();
}

class _AddPlotScreenState extends State<AddPlotScreen> {
  final _ctrl = Get.find<PlotController>();
  MapLibreMapController? _mapController;
  Symbol? _nativePin;
  double  _currentZoom = 14.0;
  Size    _mapSize = Size.zero;
  double  _minZoom = 13.0;
  final _areaCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _areaFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();

  String? _selectedPlotType;
  String _selectedUnit = 'sqft';
  String? _selectedDistrictId;
  String? _selectedCityId;
  LatLng? _selectedLocation;
  LatLng? _userLocation;
  final _locationCtrl = Get.find<LocationController>();
  bool _mapReady = false;
  bool _cameraInitialized = false;
  bool _isGeocoding = false;
  bool _isUploading = false;
  bool _isFinalizing = false;
  Set<int> _uploadDone = {};
  int _uploadTotal = 0;
  double _uploadProgress = 0.0;
  final List<File> _photos = [];
  final _picker = ImagePicker();
  int _step = 0;
  Timer? _nominatimTimer;

  bool get _hasChanges =>
      _selectedPlotType != null ||
      _areaCtrl.text.isNotEmpty ||
      _descCtrl.text.isNotEmpty ||
      _photos.isNotEmpty ||
      _addressCtrl.text.isNotEmpty ||
      _selectedLocation != null;

  @override
  void initState() {
    super.initState();
    _addressCtrl.addListener(_onAddressChanged);
    _userLocation = _locationCtrl.userLocation.value;
    _selectedLocation = _locationCtrl.userLocation.value;
    _selectedDistrictId = _locationCtrl.selectedDistrict.value?.id;
    _selectedCityId = _locationCtrl.autoCity.value?.id;
  }

  void _onAddressChanged() {
    if (mounted) setState(() {});
  }

  void _animateTo(LatLng target, double zoom) {
    if (!_mapReady || _mapController == null || !mounted) return;
    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  Future<void> _onStyleLoaded() async {
    _mapReady = true;
    if (!mounted) return;
    final ctrl = _mapController;
    if (ctrl == null) return;
    if (_userLocation != null && _mapSize.width > 0) {
      _minZoom = _calcMinZoom(0.5, _userLocation!.latitude, _mapSize.width);
    }
    final pinBytes = await _buildPinImage();
    await ctrl.addImage('location_pin', pinBytes);
    _initNativeCircle();
    _initNativeUserDot();
    if (_selectedLocation != null) await _setNativePin(_selectedLocation!);
    if (_userLocation != null && !_cameraInitialized) {
      _cameraInitialized = true;
      _animateTo(_userLocation!, 14.0);
    }
    if (_userLocation != null && _addressCtrl.text.trim().isEmpty) {
      _reverseGeocode(_selectedLocation ?? _userLocation!);
    }
  }

  static Future<Uint8List> _buildPinImage() async {
    const double w = 40, h = 52, cx = w / 2, cy = 18, r = 16;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h - 2), width: 14, height: 5),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final body = Paint()..color = const Color(0xFFE53935);
    final path = Path()
      ..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: r))
      ..moveTo(cx - 8, cy + r - 4)
      ..quadraticBezierTo(cx - 5, h - 6, cx, h)
      ..quadraticBezierTo(cx + 5, h - 6, cx + 8, cy + r - 4)
      ..close();
    canvas.drawPath(path, body);

    canvas.drawCircle(
        const Offset(cx, cy), 6.5, Paint()..color = Colors.white);

    final img = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    return bytes.buffer.asUint8List();
  }

  Future<void> _initNativeCircle() async {
    final ctrl = _mapController;
    final loc = _userLocation;
    if (ctrl == null || loc == null || !mounted) return;
    final points = _circlePolygonPoints(loc, 0.5);
    await ctrl.addLine(LineOptions(
      geometry: points,
      lineColor: '#92400E',
      lineWidth: 10.0,
      lineOpacity: 0.20,
      lineBlur: 4.0,
    ));
    await ctrl.addLine(LineOptions(
      geometry: points,
      lineColor: '#92400E',
      lineWidth: 2.5,
      lineOpacity: 0.90,
    ));
  }

  Future<void> _initNativeUserDot() async {
    final ctrl = _mapController;
    final loc = _userLocation;
    if (ctrl == null || loc == null || !mounted) return;
    await ctrl.addCircle(CircleOptions(
      geometry: loc,
      circleRadius: 8.0,
      circleColor: '#E53935',
      circleOpacity: 1.0,
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 2.5,
    ));
  }

  double _calcMinZoom(double radiusKm, double lat, double screenWidthPx) {
    const earthCircumference = 2 * pi * 6378137.0;
    const tileSize = 512.0;
    final metersPerPxAtZ0 = earthCircumference * cos(lat * pi / 180) / tileSize;
    final targetMetersPerPx = (radiusKm * 1000 * 2) / (screenWidthPx * 0.85);
    final zoom = log(metersPerPxAtZ0 / targetMetersPerPx) / log(2);
    return zoom.clamp(11.0, 15.0);
  }

  Future<void> _setNativePin(LatLng latLng) async {
    final ctrl = _mapController;
    if (ctrl == null || !mounted) return;
    if (_nativePin != null) {
      await ctrl.updateSymbol(_nativePin!, SymbolOptions(geometry: latLng));
    } else {
      _nativePin = await ctrl.addSymbol(SymbolOptions(
        geometry: latLng,
        iconImage: 'location_pin',
        iconSize: 1.5,
        iconAnchor: 'bottom',
      ));
    }
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

  static double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    const R = 6378137.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  void dispose() {
    _nominatimTimer?.cancel();
    _addressCtrl.removeListener(_onAddressChanged);
    _areaCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _areaFocusNode.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    _nominatimTimer?.cancel();
    _nominatimTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _isGeocoding = true);
      try {
        final res = await ApiService.reverseGeocode(pos.latitude, pos.longitude);
        if (!mounted) return;
        final displayName = res?['display_name'] as String? ?? '';
        if (displayName.isNotEmpty) {
          final parts = displayName
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          _addressCtrl.text = parts.take(3).join(', ');
        }
      } catch (_) {
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
        title: const Text('Discard Plot?',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: AppColors.textDark)),
        content: const Text(
          'You have unsaved changes. Going back will discard everything.',
          style:
              TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Editing',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600)),
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
            child: const Text('Discard',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
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
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: AppColors.textDark)),
        content: Text(
          'Please enable $type access in your device Settings to add photos.',
          style:
              const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium),
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
            child: const Text('Open Settings',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2))),
              const Text('Add Photo',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.primary, size: 22),
                ),
                title: const Text('Take Photo',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark)),
                subtitle: const Text('Use camera to capture now',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textLight)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded,
                      color: AppColors.primary, size: 22),
                ),
                title: const Text('Choose from Gallery',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark)),
                subtitle: const Text('Pick existing photos',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textLight)),
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
      final picked = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1280);
      if (picked != null && mounted) setState(() => _photos.add(File(picked.path)));
    } else {
      final remaining = 5 - _photos.length;
      final picked = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1280, limit: remaining);
      if (picked.isNotEmpty && mounted) {
        final allowed = picked.take(remaining).map((f) => File(f.path)).toList();
        setState(() => _photos.addAll(allowed));
        if (allowed.length < picked.length) {
          AppToast.warning(
              'Only $remaining more photo${remaining == 1 ? '' : 's'} allowed. Extra photos were removed.');
        }
      }
    }
  }

  void _handleNext() {
    if (_step == 0) {
      if (_selectedPlotType == null) {
        AppToast.error('Please select a plot type');
        return;
      }
      if (_areaCtrl.text.trim().isEmpty) {
        AppToast.error('Please enter the area');
        _areaFocusNode.requestFocus();
        return;
      }
      final area = double.tryParse(_areaCtrl.text) ?? 0;
      if (area <= 0) {
        AppToast.error('Area must be greater than 0');
        _areaFocusNode.requestFocus();
        return;
      }
    }
    if (_step == 1) {
      final loc = _selectedLocation ?? _userLocation;
      if (loc == null) {
        AppToast.error('Waiting for GPS location. Please enable location and try again.');
        return;
      }
      if (_selectedLocation == null) setState(() => _selectedLocation = _userLocation);
    }
    if (_step == 2) {
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
    if (_step < 3) {
      setState(() => _step++);
      if (_step == 2 && _addressCtrl.text.trim().isEmpty && _selectedLocation != null) {
        _reverseGeocode(_selectedLocation!);
      }
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_selectedPlotType == null) {
      AppToast.error('Please select a plot type');
      return;
    }
    if (_selectedDistrictId == null) {
      AppToast.error('Please select a district');
      return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      AppToast.error('Address is required');
      _addressFocusNode.requestFocus();
      return;
    }

    final pinLocation = _selectedLocation ?? _userLocation;
    if (pinLocation == null) {
      AppToast.error('Please pin your location on the map');
      return;
    }

    final areaValue = double.tryParse(_areaCtrl.text) ?? 0;
    if (areaValue <= 0) {
      AppToast.error('Area must be greater than 0');
      return;
    }

    final cityId = _selectedCityId ?? _locationCtrl.autoCity.value?.id;
    if (cityId == null) {
      AppToast.error('City not detected. Please enable GPS and try again.');
      return;
    }

    final data = {
      'areaValue': areaValue,
      'areaUnit': _selectedUnit,
      'plotTypeId': _selectedPlotType,
      'description':
          _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'latitude': pinLocation.latitude,
      'longitude': pinLocation.longitude,
      'address': _addressCtrl.text.trim(),
      'districtId': _selectedDistrictId,
      'cityId': cityId,
    };

    final plotId = await _ctrl.createPlot(data);
    if (plotId == null) return;

    if (_photos.isNotEmpty) {
      setState(() {
        _isUploading    = true;
        _uploadTotal    = _photos.length;
        _uploadDone     = {};
        _uploadProgress = 0.0;
      });
      final progresses = List<double>.filled(_photos.length, 0.0);
      final uploadResults = List<bool>.filled(_photos.length, false);

      // Upload all photos in parallel
      await Future.wait(List.generate(_photos.length, (i) async {
        final ok = await _ctrl.uploadPhoto(plotId, _photos[i].path,
          onProgress: (sent, total) {
            if (!mounted) return;
            progresses[i] = total > 0 ? sent / total : 0.0;
            setState(() => _uploadProgress =
                progresses.fold(0.0, (a, b) => a + b) / _photos.length);
          });
        uploadResults[i] = ok;
        if (ok && mounted) setState(() => _uploadDone.add(i));
      }));

      var failedIndices = [for (var i = 0; i < uploadResults.length; i++) if (!uploadResults[i]) i];

      // Collective retry dialog for all failed photos
      if (failedIndices.isNotEmpty && mounted) {
        final retry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Upload Failed',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            content: Text(
              '${failedIndices.length} photo${failedIndices.length > 1 ? 's' : ''} could not be uploaded after 3 attempts. Retry?',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Skip', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
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
        if (retry == true && mounted) {
          final retryResults = List<bool>.filled(failedIndices.length, false);
          await Future.wait(List.generate(failedIndices.length, (j) async {
            final i = failedIndices[j];
            final ok = await _ctrl.uploadPhoto(plotId, _photos[i].path,
              onProgress: (sent, total) {
                if (!mounted) return;
                progresses[i] = total > 0 ? sent / total : 0.0;
                setState(() => _uploadProgress =
                    progresses.fold(0.0, (a, b) => a + b) / _photos.length);
              });
            retryResults[j] = ok;
            if (ok && mounted) setState(() => _uploadDone.add(i));
          }));
          failedIndices = [for (var j = 0; j < failedIndices.length; j++) if (!retryResults[j]) failedIndices[j]];
        }
      }

      if (mounted) setState(() { _isUploading = false; _isFinalizing = true; });
      if (failedIndices.isNotEmpty && mounted) {
        AppToast.error('${failedIndices.length} photo${failedIndices.length > 1 ? 's' : ''} could not be uploaded.');
      }
    }

    if (mounted) setState(() => _isFinalizing = true);
    try {
      await _ctrl.loadMyPlots(reset: true);

      _ctrl.reloadPlotMembership(); // background refresh — no await, user doesn't wait
      try {
        final membership    = _ctrl.plotMembership.value;
        final plans         = _ctrl.plotPlans.value;
        final hasMembership = membership != null && (membership['hasMembership'] == true);
        final planType      = membership?['planType'] as String? ?? '';
        final maxPlots      = (membership?['maxPlotListings'] as num?)?.toInt() ?? 0;
        final plansMap      = { for (final p in plans) p['planType'] as String: p };
        final currentPlanIsFree = (plansMap[planType]?['originalPrice'] as num? ?? 0) == 0;
        if (hasMembership && currentPlanIsFree && _ctrl.myPlots.length > maxPlots) {
          final paidPlans = plans.where((p) => (p['originalPrice'] as num? ?? 0) > 0).toList();
          if (paidPlans.isNotEmpty) {
            Get.offNamed(AppRoutes.paymentScreen, arguments: {
              'isPlot': true,
              'plotId': plotId,
              'plan': paidPlans.first,
            });
          }
          return;
        }
      } catch (_) {}

      if (mounted) Get.back();
      Future.delayed(const Duration(milliseconds: 400), _ctrl.notifyPlotPosted);
      AppToast.success('Plot listed successfully!');
    } catch (_) {
      if (mounted) Get.back();
    }
  }

  InputDecoration _inputDec(String hint, {Widget? prefixIcon}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF92400E), width: 1.5)),
      );

  Widget _buildUploadOverlay() {
    final overall = _uploadProgress.clamp(0.0, 1.0);
    final percent = (overall * 100).toInt();
    final String statusText;
    if (percent >= 95) {
      statusText = 'Almost done!';
    } else {
      statusText = '${_uploadDone.length} of $_uploadTotal uploaded';
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
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 40,
                    offset: const Offset(0, 12))
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF92400E), Color(0xFF78350F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                    child: Icon(Icons.cloud_upload_rounded,
                        color: Colors.white, size: 32)),
              ),
              const SizedBox(height: 20),
              const Text('Uploading Photos',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      decoration: TextDecoration.none)),
              const SizedBox(height: 6),
              Text(
                'Uploading $_uploadTotal photo${_uploadTotal > 1 ? 's' : ''} in parallel',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textLight,
                    decoration: TextDecoration.none),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_uploadTotal, (i) {
                  final isDone = _uploadDone.contains(i);
                  final isCurrent = !isDone;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isCurrent ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDone || isCurrent
                          ? const Color(0xFF92400E)
                          : AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: overall),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, value, _) {
                  return Column(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(children: [
                        Container(height: 10, color: AppColors.divider),
                        FractionallySizedBox(
                          widthFactor: value.clamp(0.0, 1.0),
                          child: Container(
                            height: 10,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF92400E), Color(0xFF78350F)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(statusText,
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: AppColors.textHint,
                                decoration: TextDecoration.none)),
                        Text('${(value * 100).toInt()}%',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                                decoration: TextDecoration.none)),
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
        if (_isUploading || _isFinalizing) return;
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF92400E), Color(0xFF78350F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
                    child: Row(children: [
                      IconButton(
                        onPressed: _isUploading
                            ? null
                            : () {
                                if (_hasChanges) {
                                  _confirmDiscard();
                                } else {
                                  Get.back();
                                }
                              },
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            color: Colors.white),
                      ),
                      const Text('Post Your Plot',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ]),
                  ),
                ),
              ),

              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(children: [
                  _stepDot(0, 'Details'),
                  Expanded(child: Container(height: 2, color: _step >= 1 ? const Color(0xFF92400E) : AppColors.divider)),
                  _stepDot(1, 'Location'),
                  Expanded(child: Container(height: 2, color: _step >= 2 ? const Color(0xFF92400E) : AppColors.divider)),
                  _stepDot(2, 'Address'),
                  Expanded(child: Container(height: 2, color: _step >= 3 ? const Color(0xFF92400E) : AppColors.divider)),
                  _stepDot(3, 'Photos'),
                ]),
              ),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0.08, 0), end: Offset.zero)
                        .animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: _step == 0 ? _detailsStep() : _step == 1 ? _locationStep() : _step == 2 ? _addressStep() : _photosStep(),
                ),
              ),

              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, AppInsets.bottomViewPadding(context) + 12),
                child: Row(children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          side: const BorderSide(color: Color(0xFF92400E)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Back',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: Obx(() {
                      final isButtonDisabled = _ctrl.isLoading.value || _isFinalizing ||
                          (_step == 2 && (_isGeocoding || _selectedDistrictId == null || _addressCtrl.text.trim().isEmpty));
                      return GradientButton(
                        onPressed: isButtonDisabled ? null : _handleNext,
                        isLoading: _ctrl.isLoading.value || _isFinalizing,
                        label: _step == 0 ? 'Next: Location' : _step == 1 ? 'Next: Address' : _step == 2 ? 'Next: Photos' : 'Post Plot',
                      );
                    }),
                  ),
                ]),
              ),
            ]),
          ),
          if (_isUploading) _buildUploadOverlay(),
          Obx(() => _ctrl.isLoading.value
              ? AppLoadingOverlay.stackChild(
                  message: 'Creating plot...',
                  indicatorColor: const Color(0xFF92400E),
                )
              : const SizedBox.shrink()),
          if (_isFinalizing) AppLoadingOverlay.stackChild(
            message: 'Saving your plot...',
            indicatorColor: const Color(0xFF92400E),
          ),
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: (active || done) ? const Color(0xFF92400E) : AppColors.divider,
            shape: BoxShape.circle,
          ),
          child: Center(
              child: done
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : Text('${index + 1}',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : AppColors.textLight))),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: (active || done)
                    ? const Color(0xFF92400E)
                    : AppColors.textLight)),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          const SizedBox(height: 14),
          child,
        ]),
      );

  Widget _detailsStep() => SingleChildScrollView(
        key: const ValueKey(0),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Plot Type
          _sectionCard(
            title: 'Plot Type *',
            child: Obx(() => Row(
              children: _ctrl.plotTypes.asMap().entries.map((entry) {
                final type = entry.value;
                final active = _selectedPlotType == type.id;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: entry.key == 0 ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPlotType = type.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 38,
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF92400E) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: active ? const Color(0xFF92400E) : AppColors.divider,
                              width: 1.5),
                        ),
                        child: Center(
                          child: Text(type.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: active ? Colors.white : AppColors.textMedium)),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            )),
          ),

          // Area Unit
          _sectionCard(
            title: 'Area Unit *',
            child: Row(
              children: _units.asMap().entries.map((entry) {
                final index = entry.key;
                final unit = entry.value;
                final active = _selectedUnit == unit;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedUnit = unit;
                          _areaCtrl.clear();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF92400E) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: active ? const Color(0xFF92400E) : AppColors.divider,
                              width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            unit,
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: active ? Colors.white : AppColors.textMedium),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Area Input — unit-aware keyboard and hint
          _sectionCard(
            title: 'Area *',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(
                key: ValueKey('area-$_selectedUnit'),
                controller: _areaCtrl,
                focusNode: _areaFocusNode,
                keyboardType: _unitConfig[_selectedUnit]?.decimal == true
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.number,
                inputFormatters: _unitConfig[_selectedUnit]?.decimal == true
                    ? [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                        LengthLimitingTextInputFormatter(10),
                      ]
                    : [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: _inputDec(
                  _unitConfig[_selectedUnit]?.hint ?? 'Enter area',
                  prefixIcon: const Icon(Icons.straighten_rounded,
                      color: AppColors.primaryLight, size: 18),
                ),
              ),
            ]),
          ),

          // Description
          _sectionCard(
            title: 'Description (Optional)',
            child: TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              maxLength: 300,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: _inputDec('Describe the plot, access road, nearby landmarks...'),
            ),
          ),
        ]),
      );

  Widget _locationStep() => Padding(
    key: const ValueKey(1),
    padding: const EdgeInsets.all(16),
    child: _sectionCard(
      title: 'Pin Your Plot Location *',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 15),
          const SizedBox(width: 6),
          Expanded(child: Text(
            _userLocation != null
                ? (_selectedLocation != null
                    ? 'Pinned — tap inside the circle to adjust'
                    : 'Tap inside the 500 m circle to pin your plot')
                : 'Waiting for your GPS location...',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
          )),
        ]),
        const SizedBox(height: 12),
        if (_userLocation == null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 340,
              color: AppColors.surface,
              child: const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: Color(0xFF92400E), strokeWidth: 2),
                  SizedBox(height: 14),
                  Text('Getting your location...', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
                ]),
              ),
            ),
          ),
        ] else
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _mapSize = Size(constraints.maxWidth, 340);
              return SizedBox(
                height: 340,
                child: Stack(children: [
                  MapLibreMap(
                    styleString: 'assets/map_style.json',
                    initialCameraPosition: CameraPosition(
                      target: _userLocation ?? const LatLng(30.3165, 78.0322),
                      zoom: 14.0,
                    ),
                    compassEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    myLocationEnabled: false,
                    trackCameraPosition: true,
                    attributionButtonMargins: const Point(-200.0, 0.0),
                    onMapCreated: (ctrl) => _mapController = ctrl,
                    onStyleLoadedCallback: _onStyleLoaded,
                    onCameraMove: (pos) { _currentZoom = pos.zoom; },
                    onCameraIdle: () {
                      if (_currentZoom < _minZoom && _mapController != null && mounted) {
                        _mapController!.animateCamera(CameraUpdate.zoomTo(_minZoom));
                      }
                    },
                    onMapClick: (_, latLng) {
                      if (_userLocation != null) {
                        final distM = _distanceBetween(
                          _userLocation!.latitude, _userLocation!.longitude,
                          latLng.latitude, latLng.longitude,
                        );
                        if (distM > 500) {
                          AppToast.warning('You can only pin within 500 m of your current location');
                          return;
                        }
                      }
                      setState(() => _selectedLocation = latLng);
                      _setNativePin(latLng);
                      _reverseGeocode(latLng);
                    },
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
                        child: const Icon(Iconsax.location, color: Color(0xFF92400E), size: 18),
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
              const Spacer(),
              const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 9, color: AppColors.textLight),
              ),
            ]),
          ),
      ]),
    ),
  );

  Widget _addressStep() => SingleChildScrollView(
    key: const ValueKey(2),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionCard(
        title: 'District & City',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('District *', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
          const SizedBox(height: 6),
          _readOnlyField(
            Iconsax.location,
            _locationCtrl.selectedDistrict.value?.name ?? '—',
          ),
          const SizedBox(height: 16),
          const Text('City / Area (Optional)', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
          const SizedBox(height: 6),
          _readOnlyField(
            Iconsax.map,
            _locationCtrl.autoCity.value?.name ?? '—',
          ),
        ]),
      ),

      _sectionCard(
        title: 'Address *',
        child: TextFormField(
          controller: _addressCtrl,
          focusNode: _addressFocusNode,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _inputDec(
            'Street, landmark, nearby place...',
            prefixIcon: const Icon(Icons.terrain_rounded, color: AppColors.primaryLight, size: 18),
          ).copyWith(
            suffixIcon: _isGeocoding
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF92400E))),
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
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textDark)),
          const Spacer(),
          const Icon(Icons.gps_fixed_rounded, color: AppColors.success, size: 14),
        ]),
      );

  Widget _photosStep() => SingleChildScrollView(
        key: const ValueKey(3),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionCard(
            title: 'Plot Photos',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${_photos.length}/5 photos added',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textLight)),
                const Spacer(),
                const Text('Optional',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textHint)),
              ]),
              const SizedBox(height: 4),
              const Text('Good photos attract more buyers',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Color(0xFF92400E))),
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
                      border: Border.all(
                          color: const Color(0xFF92400E).withValues(alpha: 0.3),
                          width: 1.5),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: const Color(0xFF92400E).withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.add_a_photo_rounded,
                                color: Color(0xFF92400E), size: 28),
                          ),
                          const SizedBox(height: 10),
                          const Text('Add Plot Photos',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E))),
                          const SizedBox(height: 4),
                          const Text('Camera or Gallery',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.textLight)),
                        ]),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10),
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
                          child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded,
                                    color: Color(0xFF92400E), size: 28),
                                SizedBox(height: 4),
                                Text('Add',
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: Color(0xFF92400E),
                                        fontWeight: FontWeight.w500)),
                              ]),
                        ),
                      );
                    }
                    return Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_photos[i],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity),
                      ),
                      if (i == 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF92400E).withValues(alpha: 0.8),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(12)),
                            ),
                            child: const Text('Cover',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _photos.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 11),
                            ),
                          )),
                    ]);
                  },
                ),
              if (_photos.isNotEmpty && _photos.length < 5) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_rounded,
                            color: Color(0xFF92400E), size: 16),
                        const SizedBox(width: 6),
                        Text(
                            'Add ${5 - _photos.length} more photo${5 - _photos.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w500)),
                      ]),
                ),
              ],
            ]),
          ),
        ]),
      );
}
