import 'stay_page_header.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animations/animations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:permission_handler/permission_handler.dart';
import '../../../config/app_constants.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../models/city_model.dart';
import '../../../screens/add_listing_location_mixin.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/concurrency.dart';
import '../../../utils/input_formatters.dart';
import '../../../design/design.dart';
import '../../../widgets/onboarding_closed_dialog.dart';
import '../models/stay_owner_model.dart';
import '../models/stay_registration_type_model.dart';
import '../stay_registration_types_controller.dart';
import '../stay_types_controller.dart';
import 'stay_option_grid.dart';
import 'stay_option_sets.dart';
import 'stay_registration_validators.dart';
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
    with AddListingLocationMixin<StayBasicDetailsScreen>, TickerProviderStateMixin {
  int _prevStep = 0;
  final _ctrl = StaySetupController.ensure();
  final _nameCtrl = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _descCtrl = TextEditingController();
  final _types = StayTypesController.ensure();
  final _regTypes = StayRegistrationTypesController.ensure();
  final _regNumCtrl = TextEditingController();
  final _regNumFocus = FocusNode();
  final _regOtherCtrl = TextEditingController();
  final _regOtherFocus = FocusNode();
  final _gstinCtrl = TextEditingController();
  final _gstinFocus = FocusNode();

  String? _stayTypeId;
  String? _regTypeId;
  bool _clearGstin = false;
  bool _showRegRequired = false;
  String? _serverTypeError;
  String? _serverOtherError;
  String? _serverNumberError;
  String? _serverGstinError;
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

  static final _locationStyle = LocationStepStyle(
    circleColorHex: SetupKit.stayHex,
    userDotColorHex: SetupKit.userDotHex,
    accentColor: DesignColors.primary,
    addressSpinnerColor: DesignColors.primary,
    addressPrefixIcon: Icons.hotel_rounded,
    pinStepTitle: 'Pin Your Location *',
    pinHintNoun: 'stay',
  );

  bool get _hasChanges => _dirty || _step > 0;

  @override
  void initState() {
    super.initState();
    initLocationTracking(
      style: _locationStyle,
      onLocationStale: _handleLocationStale,
      onOnboardingClosed: _onResolveOnboardingClosed,
      onboardingGrandfathered: _onboardingGrandfathered,
    );
    _types.ensureLoaded();
    _regTypes.ensureLoaded();
    final s = _ctrl.stay.value;
    if (s != null) {
      _nameCtrl.text = s.name ?? '';
      _descCtrl.text = s.description ?? '';
      _stayTypeId = s.stayTypeId;
      _regTypeId = s.registrationTypeId;
      _regOtherCtrl.text = s.registrationOtherName ?? '';
      _vehicleAccess = s.vehicleAccess;
      _hostLivesHere = s.hostLivesHere;
      _facilities.addAll(s.facilities);
      _photos.addAll(s.photos.map(_PhotoEntry.remote));
      final lat = s.latitude, lng = s.longitude;
      if (lat != null && lng != null) prefillLocation(LatLng(lat, lng), s.address);
    }
    _nameCtrl.addListener(_markDirty);
    _descCtrl.addListener(_markDirty);
    _regNumCtrl.addListener(_markDirty);
    _regOtherCtrl.addListener(_markDirty);
    _gstinCtrl.addListener(_markDirty);
  }

  @override
  void dispose() {
    disposeLocationTracking();
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    _descCtrl.dispose();
    _regNumCtrl.dispose();
    _regNumFocus.dispose();
    _regOtherCtrl.dispose();
    _regOtherFocus.dispose();
    _gstinCtrl.dispose();
    _gstinFocus.dispose();
    super.dispose();
  }

  void _markDirty() => _dirty = true;

  StayRegistrationTypeModel? get _selectedRegType {
    for (final t in _regTypes.types) {
      if (t.id == _regTypeId) return t;
    }
    return null;
  }

  bool get _regTypeChanged => _regTypeId != _ctrl.stay.value?.registrationTypeId;

  bool get _hasStoredNumber => (_ctrl.stay.value?.hasRegistrationNumber ?? false) && !_regTypeChanged;

  String? get _numberError {
    final type = _selectedRegType;
    final raw = _regNumCtrl.text;
    if (type == null || raw.trim().isEmpty) return null;
    final n = StayRegistrationValidators.normalizeForType(type.code, raw);
    return StayRegistrationValidators.isValidForType(type.code, n)
        ? null
        : StayRegistrationValidators.messageForType(type.code);
  }

  String? get _gstinError {
    final raw = _gstinCtrl.text;
    if (raw.trim().isEmpty) return null;
    return StayRegistrationValidators.isValidGstin(StayRegistrationValidators.normalizeGstin(raw))
        ? null
        : StayRegistrationValidators.gstinInvalidMessage;
  }

  String? get _typeFieldError =>
      (_showRegRequired && _selectedRegType == null ? StayRegistrationValidators.typeRequiredMessage : null) ??
      _serverTypeError;

  String? get _otherNameFieldError =>
      (_showRegRequired ? StayRegistrationValidators.otherNameError(_regOtherCtrl.text) : null) ?? _serverOtherError;

  String? get _numberFieldError {
    if (_regNumCtrl.text.trim().isEmpty) {
      if (_showRegRequired && !_hasStoredNumber) return StayRegistrationValidators.numberRequiredMessage;
      return _serverNumberError;
    }
    return _numberError ?? _serverNumberError;
  }

  String? get _gstinFieldError => _gstinError ?? _serverGstinError;

  String? get _typesUnavailableMessage {
    if (_regTypes.types.isNotEmpty) return null;
    return _regTypes.isLoading.value
        ? StayRegistrationValidators.typesLoadingMessage
        : StayRegistrationValidators.typesNotLoadedMessage;
  }

  String? _validateRegistration() {
    final unavailable = _typesUnavailableMessage;
    if (unavailable != null) return unavailable;
    final type = _selectedRegType;
    if (type == null) return _typeFieldError ?? StayRegistrationValidators.typeRequiredMessage;
    if (_serverTypeError != null) return _serverTypeError;
    if (type.requiresOtherName) {
      final err = _otherNameFieldError;
      if (err != null) {
        _regOtherFocus.requestFocus();
        return err;
      }
    }
    final numberErr = _numberFieldError;
    if (numberErr != null) {
      _regNumFocus.requestFocus();
      return numberErr;
    }
    final gstinErr = _gstinFieldError;
    if (gstinErr != null) {
      _gstinFocus.requestFocus();
      return gstinErr;
    }
    return null;
  }

  void _showServerRegistrationError() {
    final msg = _ctrl.lastErrorMessage;
    FocusNode? focus;
    if (StayRegistrationValidators.typeServerMessages.contains(msg)) {
      _serverTypeError = msg;
      _regTypes.load();
    } else if (StayRegistrationValidators.otherNameServerMessages.contains(msg)) {
      _serverOtherError = msg;
      focus = _regOtherFocus;
    } else if (StayRegistrationValidators.numberServerMessages.contains(msg)) {
      _serverNumberError = msg;
      focus = _regNumFocus;
    } else if (StayRegistrationValidators.gstinServerMessages.contains(msg)) {
      _serverGstinError = msg;
      focus = _gstinFocus;
    } else if (_ctrl.lastErrorType != 'StayRegistrationRequired') {
      return;
    }
    setState(() => _step = 0);
    if (focus != null) {
      final f = focus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) f.requestFocus();
      });
    }
  }

  bool _onboardingGrandfathered(DistrictModel d) {
    final s = _ctrl.stay.value;
    return s != null && s.everApproved && s.districtId == d.id;
  }

  void _onResolveOnboardingClosed() {
    if (_step < 1) return;
    _showOnboardingClosed();
  }

  void _showOnboardingClosed() {
    if (!mounted) return;
    final s = _ctrl.stay.value;
    final canCorrect = (s == null || s.isDraft) && (Get.find<AuthController>().user.value?.canCorrectRole ?? false);
    final percent = s?.setupPercent ?? 0;
    OnboardingClosedDialog.show(context,
        onChangeRole: canCorrect
            ? () => Get.toNamed(AppRoutes.roleSelect, arguments: {'correction': true, 'percent': percent})
            : null);
  }

  void _handleLocationStale() {
    if (!mounted || _step <= 1) return;
    setState(() => _step = 1);
    AppToast.info('Your location may have changed — please recheck your pin.');
  }

  void _confirmDiscard() {
    showDialog(
      context: context,
      builder: (_) => StayConfirmDialog(
        title: 'Discard changes?',
        body: 'Unsaved changes will be lost.',
        cancelLabel: 'Keep Editing',
        confirmLabel: 'Discard',
        destructive: true,
        onCancel: () => Navigator.pop(context),
        onConfirm: () {
          Navigator.pop(context);
          Get.back();
        },
      ),
    );
  }

  void _showPermissionDeniedDialog(String type) {
    showDialog(
      context: context,
      builder: (_) => StayConfirmDialog(
        title: '$type Permission Required',
        body: 'Please enable $type access in your device Settings to add photos.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Open Settings',
        onCancel: () => Navigator.pop(context),
        onConfirm: () {
          Navigator.pop(context);
          openAppSettings();
        },
      ),
    );
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= AppConstants.maxPhotos) return;
    final source = await SetupKit.sheet<ImageSource>(
      context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SetupKit.grabber(),
              Text('Add Photo', style: TripKit.text(18)),
              const SizedBox(height: 8),
              TemplateStagger(
                children: [
                  _sourceRow(SetupAssets.camera, 'Take Photo', 'Use camera to capture now', ImageSource.camera),
                  _sourceRow(SetupAssets.luggage, 'Choose from Gallery', 'Pick existing photos', ImageSource.gallery),
                ],
              ),
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
      setState(() => _showRegRequired = true);
      final regError = _validateRegistration();
      if (regError != null) {
        AppToast.error(regError);
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
    final regType = _selectedRegType;
    if (regType == null) {
      AppToast.error(_typesUnavailableMessage ?? StayRegistrationValidators.typeRequiredMessage);
      setState(() {
        _showRegRequired = true;
        _step = 0;
      });
      return;
    }
    final regNumber = _regNumCtrl.text.trim();
    final gstin = _gstinCtrl.text.trim();
    final ok = await _ctrl.saveBasic({
      'name': _nameCtrl.text.trim(),
      'stayTypeId': _stayTypeId,
      'registrationTypeId': regType.id,
      'registrationOtherName':
          regType.requiresOtherName ? StayRegistrationValidators.normalizeOtherName(_regOtherCtrl.text) : null,
      'registrationNumber':
          regNumber.isEmpty ? null : StayRegistrationValidators.normalizeForType(regType.code, regNumber),
      'gstin': gstin.isNotEmpty
          ? StayRegistrationValidators.normalizeGstin(gstin)
          : (_clearGstin ? '' : null),
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
    if (!mounted) return;
    if (!ok) {
      if (_ctrl.lastErrorType == 'OnboardingClosed') {
        setState(() => _step = 1);
        _showOnboardingClosed();
        return;
      }
      _showServerRegistrationError();
      return;
    }

    setState(() => _isFinalizing = true);
    for (final id in _removedPhotoIds) {
      await _ctrl.deletePhoto(id);
    }
    _removedPhotoIds.clear();
    if (mounted) setState(() => _isFinalizing = false);

    final files = [for (final p in _photos) if (p.local != null) p.local!];
    final failedFiles = files.isNotEmpty && mounted ? await _uploadAll(files) : const <File>[];

    if (mounted) setState(() => _isFinalizing = true);
    final loaded = await _ctrl.load();
    if (!mounted) return;
    final serverPhotos = loaded ? _ctrl.stay.value?.photos : null;
    if (failedFiles.isNotEmpty || (serverPhotos != null && serverPhotos.isEmpty)) {
      final kept = serverPhotos != null
          ? serverPhotos.map(_PhotoEntry.remote).toList()
          : _photos.where((p) => p.remote != null).toList();
      setState(() {
        _isFinalizing = false;
        _photos
          ..clear()
          ..addAll(kept)
          ..addAll(failedFiles.map(_PhotoEntry.local));
      });
      if (failedFiles.isEmpty) AppToast.error('Please add at least 1 photo of your stay');
      return;
    }
    setState(() => _isFinalizing = false);
    Get.back();
    AppToast.success('Basic details saved');
  }

  Future<List<File>> _uploadAll(List<File> files) async {
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
        builder: (_) => StayConfirmDialog(
          title: 'Upload Failed',
          body: '${failed.length} photo${failed.length > 1 ? 's' : ''} could not be uploaded. Retry?',
          cancelLabel: 'Skip',
          confirmLabel: 'Retry',
          onCancel: () => Navigator.pop(context, false),
          onConfirm: () => Navigator.pop(context, true),
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
    return [for (final i in failed) files[i]];
  }

  Widget _sourceRow(String asset, String title, String subtitle, ImageSource source) => SizedBox(
        width: double.infinity,
        child: InkWell(
          onTap: () => Navigator.pop(context, source),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: PickKit.stayTint, borderRadius: BorderRadius.circular(12)),
                child: Image.asset(asset),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TripKit.text(14)),
                  Text(subtitle, style: TripKit.text(12, color: DesignColors.textSecondary)),
                ]),
              ),
            ]),
          ),
        ),
      );

  InputDecoration _inputDec(String hint) => SetupKit.input(hint: hint);

  Widget _buildUploadOverlay() {
    final overall = _uploadProgress.clamp(0.0, 1.0);
    final percent = (overall * 100).toInt();
    final statusText = percent >= 95 ? 'Almost done!' : '${_uploadDone.length} of $_uploadTotal uploaded';
    return Positioned.fill(
      child: Material(
        color: DesignColors.textInk.withValues(alpha: Alpha.strong),
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              borderRadius: TripKit.cardRadiusSmall,
              boxShadow: ShadowTokens.elev1,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: PickKit.stayGradient,
                  shape: BoxShape.circle,
                  boxShadow: ShadowTokens.elev2,
                ),
                child: Image.asset(SetupAssets.airplane),
              ),
              const SizedBox(height: 16),
              Text('Uploading Photos',
                  style: TripKit.text(16, weight: FontWeight.w700).copyWith(decoration: TextDecoration.none)),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: overall),
                duration: const Duration(milliseconds: 350),
                curve: Curves.fastOutSlowIn,
                builder: (context, value, _) => Column(children: [
                  Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: DesignColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(width: 4, color: DesignColors.primary.withValues(alpha: Alpha.soft)),
                      ),
                      alignment: Alignment.center,
                      child: Text('${(value * 100).toInt()}%',
                          style: TripKit.text(24, weight: FontWeight.normal, color: DesignColors.primary)
                              .copyWith(decoration: TextDecoration.none)),
                    ),
                    CustomPaint(
                      painter: CurvePainter(
                        colors: const <Color>[
                          DesignColors.primary,
                          TravelPalette.ringLight,
                          TravelPalette.ringLight,
                        ],
                        angle: 5 + 360 * value.clamp(0.0, 1.0),
                      ),
                      child: const SizedBox(width: 108, height: 108),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(statusText,
                      style: TripKit.text(12, color: DesignColors.textMuted)
                          .copyWith(decoration: TextDecoration.none)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _handleBack() {
    if (_hasChanges) {
      _confirmDiscard();
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reverse = _step < _prevStep;
    _prevStep = _step;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _isUploading || _isFinalizing || _ctrl.isSaving.value) return;
        _handleBack();
      },
      child: Stack(children: [
        Scaffold(
          backgroundColor: DesignColors.scaffold,
          body: Column(children: [
            StayPageHeader(
              title: 'Basic Details',
              onBack: _isUploading ? null : _handleBack,
              asset: SetupAssets.hotel,
            ),
            Container(
              decoration: BoxDecoration(
                color: DesignColors.surface,
                boxShadow: ShadowTokens.elev3Up,
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(children: [
                _StepDot(index: 0, step: _step, label: 'Details'),
                _line(1),
                _StepDot(index: 1, step: _step, label: 'Location'),
                _line(2),
                _StepDot(index: 2, step: _step, label: 'Address'),
                _line(3),
                _StepDot(index: 3, step: _step, label: 'Photos'),
              ]),
            ),
            Expanded(
              child: PageTransitionSwitcher(
                duration: templateTransitionDuration,
                reverse: reverse,
                transitionBuilder: (child, animation, secondaryAnimation) => SharedAxisTransition(
                  fillColor: Colors.transparent,
                  animation: animation,
                  secondaryAnimation: secondaryAnimation,
                  transitionType: SharedAxisTransitionType.horizontal,
                  child: child,
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
            StayFooter(
              child: Row(children: [
                if (_step > 0) ...[
                  Expanded(
                    child: SecondaryButton(
                      tone: KitTone.stay,
                      label: 'Back',
                      onPressed: () {
                        if (_step == 1) setLocationStepActive(false);
                        setState(() => _step--);
                      },
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
                    return PrimaryButton(
 tone: KitTone.stay,
                      onPressed: disabled ? null : _handleNext,
                      loading: saving || _isFinalizing,
                      label: _step == 0
                          ? 'Next: Location'
                          : _step == 1
                              ? 'Next: Address'
                              : _step == 2
                                  ? 'Next: Photos'
                                  : 'Save',
                    );
                  }),
                ),
              ]),
            ),
          ]),
        ),
        if (_isUploading) _buildUploadOverlay(),
        Obx(() => _ctrl.isSaving.value ? const StayBusy(message: 'Saving your stay...') : const SizedBox.shrink()),
        if (_isFinalizing) const StayBusy(message: 'Please wait...'),
        if (_step == 2 && showAddressResolveOverlay) const StayBusy(message: 'Please wait...'),
      ]),
    );
  }

  Widget _line(int reachedAt) => Expanded(
        child: Container(
          height: 2,
          alignment: Alignment.centerLeft,
          color: DesignColors.dividerSoft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 2,
            width: _step >= reachedAt ? 400 : 0,
            color: DesignColors.primary,
          ),
        ),
      );

  Widget _sectionCard({required String title, required Widget child}) => SectionTile(tone: KitTone.stay, title: title, margin: const EdgeInsets.only(bottom: 16), child: child);

  Widget _detailsStep() => SingleChildScrollView(
        key: const ValueKey(0),
        padding: const EdgeInsets.all(16),
        child: TemplateStagger(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionCard(
            title: 'Stay Name *',
            child: TextFormField(
              controller: _nameCtrl,
              focusNode: _nameFocusNode,
              maxLength: 80,
              inputFormatters: noEmojiInputFormatters,
              textCapitalization: TextCapitalization.words,
              cursorColor: DesignColors.primary,
              style: SetupKit.fieldText(),
              decoration: _inputDec('e.g. Himalayan Home'),
            ),
          ),
          _sectionCard(
            title: 'Stay Type *',
            child: Obx(() {
              final types = _types.types;
              if (types.isEmpty) {
                if (_types.isLoading.value) return _spinner();
                return _retry("Couldn't load stay types. Tap to retry.", _types.load);
              }
              return StayOptionGrid(
                crossAxisCount: 3,
                childAspectRatio: 2.6,
                labels: types.map((t) => t.name).toList(),
                accent: PickKit.stay,
                isActive: (i) => _stayTypeId == types[i].id,
                onTap: (i) => setState(() {
                  _stayTypeId = types[i].id;
                  _dirty = true;
                }),
              );
            }),
          ),
          _registrationCard(),
          _gstinCard(),
          _sectionCard(
            title: 'Vehicle Access *',
            child: StayOptionGrid(
              crossAxisCount: 3,
              childAspectRatio: 2.6,
              labels: StayOptionSets.vehicleAccess.map((o) => o.label).toList(),
              accent: PickKit.stay,
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
              accent: PickKit.stay,
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
                  PickChip(
                    label: o.label,
                    selected: _facilities.contains(o.value),
                    activeColor: PickKit.stay,
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
              cursorColor: DesignColors.primary,
              style: SetupKit.fieldText(),
              decoration: _inputDec('Describe amenities, nearby facilities, rules...'),
            ),
          ),
        ]),
      );

  Widget _spinner() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: KitDots(color: DesignColors.primary)),
      );

  Widget _retry(String text, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(text, style: TripKit.text(12, weight: FontWeight.w600, color: DesignColors.primary)),
          ),
        ),
      );

  InputDecoration _fieldDec(String hint, {String? errorText, String? helperText, String? suffixText}) =>
      SetupKit.input(hint: hint, error: errorText, helper: helperText, errorMaxLines: 2).copyWith(
        helperMaxLines: 2,
        suffixText: suffixText,
        suffixStyle: TripKit.text(12, color: DesignColors.primary),
      );

  Widget _registrationCard() => _sectionCard(
        title: 'Registration *',
        child: Obx(() {
          final types = _regTypes.types;
          if (types.isEmpty) {
            if (_regTypes.isLoading.value) return _spinner();
            return _retry("Couldn't load registration types. Tap to retry.", _regTypes.load);
          }
          final type = _selectedRegType;
          final isUdyam = type?.code == StayRegistrationValidators.udyamCode;
          final numberHint = isUdyam ? 'UDYAM-UK-05-0001234' : 'Registration number';
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButtonFormField<String>(
              key: ValueKey(type?.id),
              initialValue: type?.id,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              dropdownColor: DesignColors.surface,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              decoration: _fieldDec('Select type', errorText: _typeFieldError),
              style: SetupKit.fieldText(),
              items: [
                for (final t in types)
                  DropdownMenuItem<String>(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() {
                _regTypeId = v;
                _serverTypeError = null;
                _serverOtherError = null;
                _serverNumberError = null;
                _dirty = true;
              }),
            ),
            if (type != null) ...[
              if (type.requiresOtherName) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _regOtherCtrl,
                  focusNode: _regOtherFocus,
                  inputFormatters: StayRegistrationValidators.otherNameInputFormatters,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() => _serverOtherError = null),
                  cursorColor: DesignColors.primary,
                  style: SetupKit.fieldText(),
                  decoration: _fieldDec('e.g. Gram Panchayat NOC', errorText: _otherNameFieldError)
                      .copyWith(labelText: 'Document name'),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _regNumCtrl,
                focusNode: _regNumFocus,
                inputFormatters: StayRegistrationValidators.registrationInputFormatters,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() => _serverNumberError = null),
                cursorColor: DesignColors.primary,
                style: SetupKit.fieldText(),
                decoration: _fieldDec(
                  numberHint,
                  errorText: _numberFieldError,
                  helperText: _hasStoredNumber && _regNumCtrl.text.isEmpty
                      ? StayRegistrationValidators.savedHelp
                      : type.helpText ?? StayRegistrationValidators.registrationHelp,
                  suffixText: _hasStoredNumber && _regNumCtrl.text.isEmpty ? 'Saved' : null,
                ).copyWith(labelText: 'Registration number'),
              ),
            ],
          ]);
        }),
      );

  Widget _gstinCard() {
    final hasSaved = (_ctrl.stay.value?.hasGstin ?? false) && _gstinCtrl.text.isEmpty;
    return _sectionCard(
      title: 'GSTIN (Optional)',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFormField(
          controller: _gstinCtrl,
          focusNode: _gstinFocus,
          inputFormatters: StayRegistrationValidators.gstinInputFormatters,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() => _serverGstinError = null),
          cursorColor: DesignColors.primary,
          style: SetupKit.fieldText(),
          decoration: _fieldDec(
            '05ABCDE1234F1Z6',
            errorText: _gstinFieldError,
            helperText: StayRegistrationValidators.gstinHelp,
            suffixText: hasSaved && !_clearGstin ? 'Saved' : null,
          ),
        ),
        if (hasSaved)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                _clearGstin = !_clearGstin;
                _serverGstinError = null;
                _dirty = true;
              }),
              child: Text(_clearGstin ? 'Will be removed · Undo' : 'Saved · Remove',
                  style: TripKit.text(12, weight: FontWeight.w600, color: DesignColors.primary)),
            ),
          ),
      ]),
    );
  }

  Widget _photoTile(int i) {
    final p = _photos[i];
    const tileRadius = BorderRadius.only(
      topLeft: Radius.circular(8),
      topRight: Radius.circular(24),
      bottomLeft: Radius.circular(8),
      bottomRight: Radius.circular(8),
    );
    final image = p.local != null
        ? Image.file(p.local!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
        : CachedNetworkImage(
            imageUrl: p.remote!.url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (_, _) => const TemplatePlaceholder(radius: 0, height: double.infinity),
            errorWidget: (_, _, _) => const TemplatePlaceholder(radius: 0, height: double.infinity),
          );
    return TemplateEntranceOnce(
      key: ObjectKey(p),
      child: Stack(children: [
        Positioned.fill(child: ClipRRect(borderRadius: tileRadius, child: image)),
        if (i == 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
              decoration: const BoxDecoration(
                gradient: TripKit.scrimShort,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
              ),
              child: Text('Cover',
                  textAlign: TextAlign.center,
                  style: TripKit.text(10, weight: FontWeight.w600, color: DesignColors.onPrimary)),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(i),
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(gradient: SetupKit.rose, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, color: DesignColors.onPrimary, size: 12),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _photosStep() {
    const max = AppConstants.maxPhotos;
    final left = max - _photos.length;
    return SingleChildScrollView(
      key: const ValueKey(3),
      padding: const EdgeInsets.all(16),
      child: TemplateStagger(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionCard(
          title: 'Stay Photos *',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${_photos.length}/$max photos added', style: TripKit.text(13, color: DesignColors.textSecondary)),
              const Spacer(),
              Text('Required', style: TripKit.text(11, color: DesignColors.textMuted)),
            ]),
            const SizedBox(height: 4),
            Text('Good photos get 3x more responses', style: TripKit.text(12, color: DesignColors.primary)),
            const SizedBox(height: 16),
            if (_photos.isEmpty)
              Material(
                color: DesignColors.scaffold,
                shape: RoundedRectangleBorder(
                  borderRadius: TripKit.cardRadiusSmall,
                  side: BorderSide(color: DesignColors.primary.withValues(alpha: Alpha.scrim), width: 1.5),
                ),
                child: InkWell(
                  borderRadius: TripKit.cardRadiusSmall,
                  onTap: _pickPhoto,
                  child: SizedBox(
                    width: double.infinity,
                    height: 150,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: PickKit.stayTint, shape: BoxShape.circle),
                        child: Image.asset(SetupAssets.camera),
                      ),
                      const SizedBox(height: 8),
                      Text('Add Stay Photos',
                          style: TripKit.text(14, weight: FontWeight.w600, color: DesignColors.primary)),
                      const SizedBox(height: 2),
                      Text('Camera or Gallery', style: TripKit.text(12, color: DesignColors.textSecondary)),
                    ]),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: _photos.length + (left > 0 ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _photos.length) {
                    return Material(
                      color: PickKit.stayTint,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      child: InkWell(
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                        onTap: _pickPhoto,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.add_rounded, color: DesignColors.primary, size: 28),
                          const SizedBox(height: 4),
                          Text('Add', style: TripKit.text(11, color: DesignColors.primary)),
                        ]),
                      ),
                    );
                  }
                  return _photoTile(i);
                },
              ),
            if (_photos.isNotEmpty && left > 0) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickPhoto,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Image.asset(SetupAssets.camera, width: 20, height: 20),
                    const SizedBox(width: 6),
                    Text('Add $left more photo${left == 1 ? '' : 's'}',
                        style: TripKit.text(13, color: DesignColors.primary)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _StepDot extends StatefulWidget {
  const _StepDot({required this.index, required this.step, required this.label});
  final int index;
  final int step;
  final String label;

  @override
  State<_StepDot> createState() => _StepDotState();
}

class _StepDotState extends State<_StepDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(duration: const Duration(milliseconds: 400), vsync: this)
    ..value = 1;
  late final Animation<double> _scale =
      Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.fastOutSlowIn));

  @override
  void didUpdateWidget(_StepDot old) {
    super.didUpdateWidget(old);
    final was = old.step >= widget.index;
    final now = widget.step >= widget.index;
    if (now && !was && !MediaQuery.of(context).disableAnimations) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.step == widget.index;
    final done = widget.step > widget.index;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: (active || done) ? PickKit.stayGradient : null,
            color: (active || done) ? null : DesignColors.dividerSoft,
            shape: BoxShape.circle,
            boxShadow: (active || done) ? ShadowTokens.elev2 : const [],
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, color: DesignColors.onPrimary, size: 16)
                : Text('${widget.index + 1}',
                    style: TripKit.text(13,
                        weight: FontWeight.w700,
                        color: active ? DesignColors.surface : DesignColors.textSecondary)),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(widget.label,
          style: TripKit.text(11,
              color: (active || done) ? DesignColors.primary : DesignColors.textSecondary)),
    ]);
  }
}
