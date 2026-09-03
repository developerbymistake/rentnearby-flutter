import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../controllers/config_controller.dart';
import '../controllers/plot_controller.dart';
import '../models/go_live_result.dart';
import '../utils/app_toast.dart';
import '../utils/concurrency.dart';
import '../utils/input_formatters.dart';
import '../widgets/app_loading_overlay.dart';
import '../widgets/gradient_button.dart';
import 'add_listing_location_mixin.dart';

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

class _AddPlotScreenState extends State<AddPlotScreen> with AddListingLocationMixin<AddPlotScreen> {
  final _ctrl = Get.find<PlotController>();
  final _areaCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _areaFocusNode = FocusNode();

  String? _selectedPlotType;
  String _selectedUnit = 'sqft';
  bool _isUploading = false;
  bool _isFinalizing = false;
  Set<int> _uploadDone = {};
  int _uploadTotal = 0;
  double _uploadProgress = 0.0;
  final List<File> _photos = [];
  final _picker = ImagePicker();
  int _step = 0;

  static final _locationStyle = LocationStepStyle(
    circleColorHex: AppColors.plotHex,
    userDotColorHex: '#E53935',
    accentColor: AppColors.plot,
    addressSpinnerColor: AppColors.plot,
    addressPrefixIcon: Icons.terrain_rounded,
    pinStepTitle: 'Pin Your Plot Location *',
    pinHintNoun: 'plot',
  );

  bool get _hasChanges =>
      _selectedPlotType != null ||
      _areaCtrl.text.isNotEmpty ||
      _descCtrl.text.isNotEmpty ||
      _photos.isNotEmpty ||
      hasLocationOrAddressChanges;

  @override
  void initState() {
    super.initState();
    initLocationTracking(style: _locationStyle, onLocationStale: _handleLocationStale);
  }

  @override
  void dispose() {
    disposeLocationTracking();
    _areaCtrl.dispose();
    _descCtrl.dispose();
    _areaFocusNode.dispose();
    super.dispose();
  }

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
                    color: AppColors.plot,
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
    if (_step == 3) {
      if (_photos.isEmpty) {
        AppToast.error('Please add at least 1 photo of your plot to continue');
        return;
      }
    }
    if (_step < 3) {
      setState(() => _step++);
      if (_step == 2) resolveAddressIfNeeded();
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_photos.isEmpty) {
      AppToast.error('Please add at least 1 photo of your plot');
      return;
    }
    if (_selectedPlotType == null) {
      AppToast.error('Please select a plot type');
      return;
    }
    if (selectedDistrictId == null) {
      AppToast.error('Please select a district');
      return;
    }
    if (!hasAddressText) {
      AppToast.error('Address is required');
      focusAddressField();
      return;
    }

    final pinLocation = pinnedOrLiveLocation;
    if (pinLocation == null) {
      AppToast.error('Please pin your location on the map');
      return;
    }

    final areaValue = double.tryParse(_areaCtrl.text) ?? 0;
    if (areaValue <= 0) {
      AppToast.error('Area must be greater than 0');
      return;
    }

    final cityId = resolvedCityId;
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
      'address': trimmedAddress,
      'districtId': selectedDistrictId,
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

      // Upload photos with bounded concurrency (at most 2 at once) rather than
      // all-at-once, to avoid piling up connection/bandwidth contention.
      await runIndexedWithLimit(_photos.length, (i) async {
        final ok = await _ctrl.uploadPhoto(plotId, _photos[i].path,
          onProgress: (sent, total) {
            if (!mounted) return;
            progresses[i] = total > 0 ? sent / total : 0.0;
            setState(() => _uploadProgress =
                progresses.fold(0.0, (a, b) => a + b) / _photos.length);
          });
        uploadResults[i] = ok;
        if (ok && mounted) setState(() => _uploadDone.add(i));
      });

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
          await runIndexedWithLimit(failedIndices.length, (j) async {
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
          });
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
      var successMessage = 'Plot listed successfully!';
      var listReloaded = false;
      final config = Get.find<ConfigController>();
      await config.ensureLoaded();
      if (config.paymentEnabled.value == false) {
        final result = await _ctrl.goLivePlot(plotId);
        switch (result) {
          case GoLiveSuccess():
            successMessage = 'Plot listed & live!';
            listReloaded = true;
          case GoLiveSubmittedForReview():
            successMessage = 'Plot listed — submitted for review!';
            listReloaded = true;
          default:
            successMessage = 'Plot listed successfully!';
        }
      }
      if (!listReloaded) await _ctrl.loadMyPlots(reset: true);
      if (mounted) Get.back();
      Future.delayed(const Duration(milliseconds: 400), _ctrl.notifyPlotPosted);
      AppToast.success(successMessage);
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
                const BorderSide(color: AppColors.plot, width: 1.5)),
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
                  gradient: AppColors.plotGradient,
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
                          ? AppColors.plot
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
                                colors: [AppColors.plot, AppColors.plotDark],
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
                                color: AppColors.plot,
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
                  gradient: AppColors.plotGradient,
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
                  Expanded(child: Container(height: 2, color: _step >= 1 ? AppColors.plot : AppColors.divider)),
                  _stepDot(1, 'Location'),
                  Expanded(child: Container(height: 2, color: _step >= 2 ? AppColors.plot : AppColors.divider)),
                  _stepDot(2, 'Address'),
                  Expanded(child: Container(height: 2, color: _step >= 3 ? AppColors.plot : AppColors.divider)),
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
                  child: _step == 0 ? _detailsStep() : _step == 1 ? locationStepWidget() : _step == 2 ? addressStepWidget() : _photosStep(),
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
                        onPressed: () {
                          if (_step == 1) setLocationStepActive(false);
                          setState(() => _step--);
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          side: const BorderSide(color: AppColors.plot),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Back',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                color: AppColors.plot,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: Obx(() {
                      final isButtonDisabled = _ctrl.isLoading.value || _isFinalizing ||
                          (_step == 2 && (isResolvingDistrict || selectedDistrictId == null || !hasAddressText));
                      return GradientButton(
                        onPressed: isButtonDisabled ? null : _handleNext,
                        isLoading: _ctrl.isLoading.value || _isFinalizing,
                        label: _step == 0 ? 'Next: Location' : _step == 1 ? 'Next: Address' : _step == 2 ? 'Next: Photos' : 'Post Plot',
                        gradient: const LinearGradient(colors: [AppColors.plot, AppColors.plotDark]),
                        shadowColor: AppColors.plot,
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
                  indicatorColor: AppColors.plot,
                )
              : const SizedBox.shrink()),
          if (_isFinalizing) AppLoadingOverlay.stackChild(
            message: 'Saving your plot...',
            indicatorColor: AppColors.plot,
          ),
          if (_step == 2 && showAddressResolveOverlay) AppLoadingOverlay.stackChild(
            message: 'Please wait...',
            indicatorColor: AppColors.plot,
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
            color: (active || done) ? AppColors.plot : AppColors.divider,
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
                    ? AppColors.plot
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
            child: Obx(() {
              final types = _ctrl.plotTypes;
              if (types.isEmpty && _ctrl.plotTypesLoading.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.plot),
                    ),
                  ),
                );
              }
              if (types.isEmpty) {
                return GestureDetector(
                  onTap: _ctrl.loadPlotTypes,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        "Couldn't load plot types. Tap to retry.",
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.plot),
                      ),
                    ),
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 4.2,
                ),
                itemCount: types.length,
                itemBuilder: (_, i) {
                  final type = types[i];
                  final active = _selectedPlotType == type.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPlotType = type.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: active ? AppColors.plot : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: active ? AppColors.plot : AppColors.divider,
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
                  );
                },
              );
            }),
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
                          color: active ? AppColors.plot : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: active ? AppColors.plot : AppColors.divider,
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
              inputFormatters: noEmojiInputFormatters,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: _inputDec('Describe the plot, access road, nearby landmarks...'),
            ),
          ),
        ]),
      );

  Widget _photosStep() => SingleChildScrollView(
        key: const ValueKey(3),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionCard(
            title: 'Plot Photos *',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${_photos.length}/5 photos added',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textLight)),
                const Spacer(),
                const Text('Required',
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
                      color: AppColors.plot)),
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
                          color: AppColors.plot.withValues(alpha: 0.3),
                          width: 1.5),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: AppColors.plot.withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.add_a_photo_rounded,
                                color: AppColors.plot, size: 28),
                          ),
                          const SizedBox(height: 10),
                          const Text('Add Plot Photos',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.plot)),
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
                                    color: AppColors.plot, size: 28),
                                SizedBox(height: 4),
                                Text('Add',
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: AppColors.plot,
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
                              color: AppColors.plot.withValues(alpha: 0.8),
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
                            color: AppColors.plot, size: 16),
                        const SizedBox(width: 6),
                        Text(
                            'Add ${5 - _photos.length} more photo${5 - _photos.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: AppColors.plot,
                                fontWeight: FontWeight.w500)),
                      ]),
                ),
              ],
            ]),
          ),
        ]),
      );
}
