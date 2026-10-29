import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:permission_handler/permission_handler.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../config/app_insets.dart';
import '../../../screens/add_listing_location_mixin.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/concurrency.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/selectable_chip.dart';
import '../models/stay_owner_model.dart';
import '../stay_types_controller.dart';
import 'stay_option_grid.dart';
import 'stay_option_sets.dart';
import 'stay_setup_controller.dart';

class _PhotoEntry {
  final StayPhotoModel? remote;
  final File? local;
  const _PhotoEntry.remote(StayPhotoModel this.remote) : local = null;
  const _PhotoEntry.local(File this.local) : remote = null;
}

class StayBasicDetailsScreen extends StatefulWidget {
  const StayBasicDetailsScreen({super.key});
  @override
  State<StayBasicDetailsScreen> createState() => _StayBasicDetailsScreenState();
}

class _StayBasicDetailsScreenState extends State<StayBasicDetailsScreen>
    with AddListingLocationMixin<StayBasicDetailsScreen> {
  final _ctrl = StaySetupController.ensure();
  final _nameCtrl = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _descCtrl = TextEditingController();
  final _types = StayTypesController.ensure();

  String? _stayTypeId;
  String? _vehicleAccess;
  bool? _hostLivesHere;
  final Set<String> _facilities = {};
  final List<_PhotoEntry> _photos = [];
  final List<String> _removedPhotoIds = [];
  final _picker = ImagePicker();
  bool _dirty = false;
  bool _isUploading = false;
  bool _isFinalizing = false;
  Set<int> _uploadDone = {};
  int _uploadTotal = 0;
  double _uploadProgress = 0.0;
  int _step = 0;

  static const _locationStyle = LocationStepStyle(
    circleColorHex: '#F59E0B',
    userDotColorHex: '#1E88E5',
    accentColor: StayColors.accent,
    addressSpinnerColor: StayColors.accent,
    addressPrefixIcon: Iconsax.building_4,
    pinStepTitle: 'Pin Your Location *',
    pinHintNoun: 'stay',
  );

  bool get _hasChanges => _dirty || _step > 0;

  @override
  void initState() {
    super.initState();
    initLocationTracking(style: _locationStyle, onLocationStale: _handleLocationStale);
    _types.ensureLoaded();
    final s = _ctrl.stay.value;
    if (s != null) {
      _nameCtrl.text = s.name ?? '';
      _descCtrl.text = s.description ?? '';
      _stayTypeId = s.stayTypeId;
      _vehicleAccess = s.vehicleAccess;
      _hostLivesHere = s.hostLivesHere;
      _facilities.addAll(s.facilities);
      _photos.addAll(s.photos.map(_PhotoEntry.remote));
      final lat = s.latitude, lng = s.longitude;
      if (lat != null && lng != null) prefillLocation(LatLng(lat, lng), s.address);
    }
    _nameCtrl.addListener(_markDirty);
    _descCtrl.addListener(_markDirty);
  }

  @override
  void dispose() {
    disposeLocationTracking();
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _markDirty() => _dirty = true;

  void _handleLocationStale() {
    if (!mounted || _step <= 1) return;
    setState(() => _step = 1);
    AppToast.info('Your location may have changed — please recheck your pin.');
  }

  void _confirmDiscard() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard changes?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textDark)),
        content: const Text(
          'Unsaved changes will be lost.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Editing',
                style: TextStyle(fontFamily: 'Poppins', color: StayColors.accentDark, fontWeight: FontWeight.w600)),
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
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: StayColors.accent,
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
    if (_photos.length >= AppConstants.maxPhotos) return;
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
                  decoration: BoxDecoration(color: StayColors.surface, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_rounded, color: StayColors.accent, size: 22),
                ),
                title: const Text('Take Photo', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500, color: AppColors.textDark)),
                subtitle: const Text('Use camera to capture now', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: StayColors.surface, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded, color: StayColors.accent, size: 22),
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
      final picked = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1280);
      if (picked != null && mounted) {
        setState(() => _photos.add(_PhotoEntry.local(File(picked.path))));
        _dirty = true;
      }
    } else {
      final remaining = AppConstants.maxPhotos - _photos.length;
      final picked = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1280, limit: remaining);
      if (picked.isNotEmpty && mounted) {
        final allowed = picked.take(remaining).map((f) => _PhotoEntry.local(File(f.path))).toList();
        setState(() => _photos.addAll(allowed));
        _dirty = true;
        if (allowed.length < picked.length) {
          AppToast.warning('Only $remaining more photo${remaining == 1 ? '' : 's'} allowed. Extra photos were removed.');
        }
      }
    }
  }

  void _removePhoto(int i) {
    final remote = _photos[i].remote;
    if (remote != null) _removedPhotoIds.add(remote.id);
    setState(() => _photos.removeAt(i));
    _dirty = true;
  }

  void _handleNext() {
    if (_step == 0) {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        AppToast.error('Please enter your stay name');
        _nameFocusNode.requestFocus();
        return;
      }
      if (name.length < 2) {
        AppToast.error('Stay name must be 2 to 80 characters');
        _nameFocusNode.requestFocus();
        return;
      }
      if (_stayTypeId == null) {
        AppToast.error('Please select a stay type');
        return;
      }
      if (_vehicleAccess == null) {
        AppToast.error('Please select vehicle access');
        return;
      }
      if (_hostLivesHere == null) {
        AppToast.error('Please tell us if the host lives here');
        return;
      }
    }
    if (_step == 1) {
      if (pinnedOrLiveLocation == null) {
        AppToast.error('Waiting for GPS location. Please enable location and try again.');
        return;
      }
      snapLocationToUserIfUnset();
      setLocationStepActive(false);
    }
    if (_step == 2) {
      if (selectedDistrictId == null) {
        AppToast.error('Please select a district to continue');
        return;
      }
      if (!hasAddressText) {
        AppToast.error('Address is required');
        focusAddressField();
        return;
      }
    }
    if (_step == 3 && _photos.isEmpty) {
      AppToast.error('Please add at least 1 photo of your stay');
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
      if (_step == 2) resolveAddressIfNeeded();
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    final pin = pinnedOrLiveLocation;
    final districtId = selectedDistrictId;
    if (pin == null || districtId == null) {
      AppToast.error('Please pin your location on the map');
      return;
    }
    final desc = _descCtrl.text.trim();
    final ok = await _ctrl.saveBasic({
      'name': _nameCtrl.text.trim(),
      'stayTypeId': _stayTypeId,
      'vehicleAccess': _vehicleAccess,
      'hostLivesHere': _hostLivesHere,
      'facilities': StayOptionSets.facilities.map((o) => o.value).where(_facilities.contains).toList(),
      'description': desc.isNotEmpty ? desc : null,
      'latitude': pin.latitude,
      'longitude': pin.longitude,
      'address': trimmedAddress,
      'districtId': districtId,
      'cityId': resolvedCityId,
    });
    if (!ok || !mounted) return;

    setState(() => _isFinalizing = true);
    for (final id in _removedPhotoIds) {
      await _ctrl.deletePhoto(id);
    }
    _removedPhotoIds.clear();
    if (mounted) setState(() => _isFinalizing = false);

    final files = [for (final p in _photos) if (p.local != null) p.local!];
    if (files.isNotEmpty && mounted) await _uploadAll(files);

    if (mounted) setState(() => _isFinalizing = true);
    await _ctrl.load();
    if (!mounted) return;
    setState(() => _isFinalizing = false);
    Get.back();
    AppToast.success('Basic details saved');
  }

  Future<void> _uploadAll(List<File> files) async {
    setState(() {
      _isUploading = true;
      _uploadTotal = files.length;
      _uploadDone = {};
      _uploadProgress = 0.0;
    });
    final progresses = List<double>.filled(files.length, 0.0);
    final results = List<bool>.filled(files.length, false);

    Future<void> uploadOne(int i) async {
      final ok = await _ctrl.uploadPhoto(files[i].path, onProgress: (sent, total) {
        if (!mounted) return;
        progresses[i] = total > 0 ? sent / total : 0.0;
        setState(() => _uploadProgress = progresses.fold(0.0, (a, b) => a + b) / files.length);
      });
      results[i] = ok;
      if (ok && mounted) setState(() => _uploadDone.add(i));
    }

    await runIndexedWithLimit(files.length, uploadOne);
    var failed = [for (var i = 0; i < results.length; i++) if (!results[i]) i];

    if (failed.isNotEmpty && mounted) {
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Upload Failed', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          content: Text(
            '${failed.length} photo${failed.length > 1 ? 's' : ''} could not be uploaded. Retry?',
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
                backgroundColor: StayColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Retry', style: TextStyle(fontFamily: 'Poppins')),
            ),
          ],
        ),
      );
      if (retry == true && mounted) {
        final retryList = failed;
        await runIndexedWithLimit(retryList.length, (j) => uploadOne(retryList[j]));
        failed = [for (var i = 0; i < results.length; i++) if (!results[i]) i];
      }
    }

    if (mounted) setState(() => _isUploading = false);
    if (failed.isNotEmpty) {
      AppToast.error('${failed.length} photo${failed.length > 1 ? 's' : ''} could not be uploaded.');
    }
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StayColors.accent, width: 1.5)),
      );

  Widget _buildUploadOverlay() {
    final overall = _uploadProgress.clamp(0.0, 1.0);
    final percent = (overall * 100).toInt();
    final statusText = percent >= 95 ? 'Almost done!' : '${_uploadDone.length} of $_uploadTotal uploaded';
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
                decoration: const BoxDecoration(gradient: StayColors.gradient, shape: BoxShape.circle),
                child: const Center(child: Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 32)),
              ),
              const SizedBox(height: 20),
              const Text('Uploading Photos',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark, decoration: TextDecoration.none)),
              const SizedBox(height: 20),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: overall),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, value, _) => Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(children: [
                      Container(height: 10, color: AppColors.divider),
                      FractionallySizedBox(
                        widthFactor: value.clamp(0.0, 1.0),
                        child: Container(height: 10, decoration: const BoxDecoration(gradient: StayColors.gradient)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(statusText,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint, decoration: TextDecoration.none)),
                    Text('${(value * 100).toInt()}%',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: StayColors.accentDark, decoration: TextDecoration.none)),
                  ]),
                ]),
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
        if (didPop || _isUploading || _isFinalizing || _ctrl.isSaving.value) return;
        if (_hasChanges) {
          _confirmDiscard();
        } else {
          Get.back();
        }
      },
      child: Stack(children: [
        Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          body: Column(children: [
            Container(
              decoration: const BoxDecoration(gradient: StayColors.gradient),
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
                      icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                    ),
                    const Text('Basic Details',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                ),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(children: [
                _stepDot(0, 'Details'),
                Expanded(child: Container(height: 2, color: _step >= 1 ? StayColors.accent : AppColors.divider)),
                _stepDot(1, 'Location'),
                Expanded(child: Container(height: 2, color: _step >= 2 ? StayColors.accent : AppColors.divider)),
                _stepDot(2, 'Address'),
                Expanded(child: Container(height: 2, color: _step >= 3 ? StayColors.accent : AppColors.divider)),
                _stepDot(3, 'Photos'),
              ]),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _step == 0
                    ? _detailsStep()
                    : _step == 1
                        ? locationStepWidget()
                        : _step == 2
                            ? addressStepWidget()
                            : _photosStep(),
              ),
            ),
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(20, 12, 20, AppInsets.bottomViewPadding(context) + 12),
              child: Row(children: [
                if (_step > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        if (_step == 1) setLocationStepActive(false);
                        setState(() => _step--);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        side: const BorderSide(color: StayColors.accent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Back',
                          style: TextStyle(fontFamily: 'Poppins', color: StayColors.accentDark, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: Obx(() {
                    final saving = _ctrl.isSaving.value;
                    final disabled = saving ||
                        _isFinalizing ||
                        (_step == 2 && (isResolvingDistrict || selectedDistrictId == null || !hasAddressText));
                    return GradientButton(
                      onPressed: disabled ? null : _handleNext,
                      isLoading: saving || _isFinalizing,
                      label: _step == 0
                          ? 'Next: Location'
                          : _step == 1
                              ? 'Next: Address'
                              : _step == 2
                                  ? 'Next: Photos'
                                  : 'Save',
                      gradient: StayColors.gradient,
                      shadowColor: StayColors.accent,
                    );
                  }),
                ),
              ]),
            ),
          ]),
        ),
        if (_isUploading) _buildUploadOverlay(),
        Obx(() => _ctrl.isSaving.value
            ? AppLoadingOverlay.stackChild(message: 'Saving your stay...')
            : const SizedBox.shrink()),
        if (_isFinalizing) AppLoadingOverlay.stackChild(message: 'Please wait...'),
        if (_step == 2 && showAddressResolveOverlay) AppLoadingOverlay.stackChild(message: 'Please wait...'),
      ]),
    );
  }

  Widget _stepDot(int index, String label) {
    final active = _step == index;
    final done = _step > index;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: (active || done) ? StayColors.accent : AppColors.divider,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
              : Text('${index + 1}',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.textLight)),
        ),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w500,
              color: (active || done) ? StayColors.accentDark : AppColors.textLight)),
    ]);
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
          const SizedBox(height: 10),
          child,
        ]),
      );

  Widget _detailsStep() => SingleChildScrollView(
        key: const ValueKey(0),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionCard(
            title: 'Stay Name *',
            child: TextFormField(
              controller: _nameCtrl,
              focusNode: _nameFocusNode,
              maxLength: 80,
              inputFormatters: noEmojiInputFormatters,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: _inputDec('e.g. Himalayan Home').copyWith(counterText: ''),
            ),
          ),
          _sectionCard(
            title: 'Stay Type *',
            child: Obx(() {
              final types = _types.types;
              if (types.isEmpty) {
                if (_types.isLoading.value) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: StayColors.accent),
                      ),
                    ),
                  );
                }
                return GestureDetector(
                  onTap: _types.load,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text("Couldn't load stay types. Tap to retry.",
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: StayColors.accentDark)),
                    ),
                  ),
                );
              }
              return StayOptionGrid(
                crossAxisCount: 3,
                childAspectRatio: 2.6,
                labels: types.map((t) => t.name).toList(),
                isActive: (i) => _stayTypeId == types[i].id,
                onTap: (i) => setState(() {
                  _stayTypeId = types[i].id;
                  _dirty = true;
                }),
              );
            }),
          ),
          _sectionCard(
            title: 'Vehicle Access *',
            child: StayOptionGrid(
              crossAxisCount: 3,
              childAspectRatio: 2.6,
              labels: StayOptionSets.vehicleAccess.map((o) => o.label).toList(),
              isActive: (i) => _vehicleAccess == StayOptionSets.vehicleAccess[i].value,
              onTap: (i) => setState(() {
                _vehicleAccess = StayOptionSets.vehicleAccess[i].value;
                _dirty = true;
              }),
            ),
          ),
          _sectionCard(
            title: 'Host Lives Here *',
            child: StayOptionGrid(
              crossAxisCount: 2,
              childAspectRatio: 3.9,
              labels: const ['Yes', 'No'],
              isActive: (i) => _hostLivesHere == (i == 0),
              onTap: (i) => setState(() {
                _hostLivesHere = i == 0;
                _dirty = true;
              }),
            ),
          ),
          _sectionCard(
            title: 'Facilities (Optional)',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in StayOptionSets.facilities)
                  SelectableChip(
                    label: o.label,
                    selected: _facilities.contains(o.value),
                    activeColor: StayColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    onTap: () => setState(() {
                      if (!_facilities.remove(o.value)) _facilities.add(o.value);
                      _dirty = true;
                    }),
                  ),
              ],
            ),
          ),
          _sectionCard(
            title: 'Description (Optional)',
            child: TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              maxLength: 300,
              inputFormatters: noEmojiInputFormatters,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: _inputDec('Describe amenities, nearby facilities, rules...'),
            ),
          ),
        ]),
      );

  Widget _photoTile(int i) {
    final p = _photos[i];
    final image = p.local != null
        ? Image.file(p.local!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
        : CachedNetworkImage(
            imageUrl: p.remote!.url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (_, _) => Container(color: AppColors.surface),
            errorWidget: (_, _, _) => Container(color: AppColors.surface),
          );
    return Stack(children: [
      ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
      if (i == 0)
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: StayColors.accentDark.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: const Text('Cover', textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      Positioned(
        top: 4, right: 4,
        child: GestureDetector(
          onTap: () => _removePhoto(i),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 11),
          ),
        ),
      ),
    ]);
  }

  Widget _photosStep() {
    const max = AppConstants.maxPhotos;
    final left = max - _photos.length;
    return SingleChildScrollView(
      key: const ValueKey(3),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionCard(
          title: 'Stay Photos *',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${_photos.length}/$max photos added',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
              const Spacer(),
              const Text('Required', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textHint)),
            ]),
            const SizedBox(height: 4),
            const Text('Good photos get 3x more responses',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: StayColors.accentDark)),
            const SizedBox(height: 16),
            if (_photos.isEmpty)
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: StayColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: StayColors.accent.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: StayColors.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.add_a_photo_rounded, color: StayColors.accent, size: 28),
                    ),
                    const SizedBox(height: 10),
                    const Text('Add Stay Photos',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: StayColors.accentDark)),
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
                itemCount: _photos.length + (left > 0 ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _photos.length) {
                    return GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        decoration: BoxDecoration(
                          color: StayColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_rounded, color: StayColors.accent, size: 28),
                          SizedBox(height: 4),
                          Text('Add', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: StayColors.accentDark, fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    );
                  }
                  return _photoTile(i);
                },
              ),
            if (_photos.isNotEmpty && left > 0) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _pickPhoto,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_a_photo_rounded, color: StayColors.accent, size: 16),
                  const SizedBox(width: 6),
                  Text('Add $left more photo${left == 1 ? '' : 's'}',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: StayColors.accentDark, fontWeight: FontWeight.w500)),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
