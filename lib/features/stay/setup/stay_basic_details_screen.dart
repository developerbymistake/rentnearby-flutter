import 'stay_page_header.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animations/animations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:permission_handler/permission_handler.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../models/city_model.dart';
import '../../../screens/add_listing_location_mixin.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/concurrency.dart';
import '../../../utils/input_formatters.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_stay_owner.dart';
import '../../../widgets/onboarding_closed_dialog.dart';
import '../models/stay_owner_model.dart';
import '../models/stay_registration_type_model.dart';
import '../stay_registration_types_controller.dart';
import '../stay_types_controller.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/plan/soft_lock.dart';
import '../../stay_owner/widgets/stay_widgets.dart';
import '../../stay_owner/strings/stay_gate_strings.dart';
import '../../stay_owner/strings/stay_setup_strings.dart';
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
  const StayBasicDetailsScreen({super.key, this.photosOnly = false});

  final bool photosOnly;
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
  bool _askingRetry = false;
  bool _isFinalizing = false;
  Set<int> _uploadDone = {};
  int _uploadTotal = 0;
  double _uploadProgress = 0.0;
  int _step = 0;
  bool _photosOnly = false;
  String? _photoError;
  static const int _maxBytes = 10 * 1024 * 1024;
  static const _okExt = ['jpg', 'jpeg', 'png', 'webp'];
  int get _maxPhotos => PlanGate.limit(PlanKey.photos);
  static final _tone = ListingTone.forest;

  static final _locationStyle = LocationStepStyle(
    circleColorHex: SetupKit.stayHex,
    userDotColorHex: SetupKit.userDotHex,
    accentColor: DesignColors.primary,
    addressSpinnerColor: DesignColors.primary,
    addressPrefixIcon: Icons.hotel_rounded,
    pinStepTitle: 'Pin Your Location *',
    pinHintNoun: 'stay',
  );

  bool get _hasChanges => _dirty || (!_photosOnly && _step > 0);

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
    final args = Get.arguments;
    if (widget.photosOnly || (args is Map && args['section'] == 'photos')) {
      _photosOnly = true;
      _step = 3;
    } else if (args is Map && args['section'] == 'location') {
      _step = 1;
    }
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

  void _showOnboardingClosed({String? errorType, String? serverMessage}) {
    if (!mounted) return;
    final s = _ctrl.stay.value;
    final canCorrect = (s == null || s.isDraft) && (Get.find<AuthController>().user.value?.canCorrectRole ?? false);
    final percent = s?.setupPercent ?? 0;
    OnboardingClosedDialog.show(context,
        body: StaySetupStrings.notOpenBodyFor(errorType, serverMessage),
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
        art: ListingArt.clipboard,
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
        art: ListingArt.camera,
        onCancel: () => Navigator.pop(context),
        onConfirm: () {
          Navigator.pop(context);
          openAppSettings();
        },
      ),
    );
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= _maxPhotos) return;
    final source = await Sheet3D.show<ImageSource>(
      context,
      builder: (sheetCtx) => Sheet3D(
        tone: _tone,
        art: ListingArt.camera,
        title: 'Add Photo',
        subtitle: 'Camera or Gallery',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetOptionCard(tone: _tone, art: ListingArt.camera, title: 'Take Photo', subtitle: 'Use camera to capture now', onTap: () => Navigator.pop(sheetCtx, ImageSource.camera)),
            SheetOptionCard(tone: _tone, art: ListingArt.sunrise, title: 'Choose from Gallery', subtitle: 'Pick existing photos', onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery)),
            Gap.v(8),
          ],
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
      if (picked != null && mounted && await _acceptPhoto(File(picked.path))) {
        setState(() => _photos.add(_PhotoEntry.local(File(picked.path))));
        _dirty = true;
      }
    } else {
      final remaining = _maxPhotos - _photos.length;
      final picked = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1280, limit: remaining);
      if (picked.isNotEmpty && mounted) {
        final allowed = <_PhotoEntry>[];
        for (final f in picked.take(remaining)) {
          if (await _acceptPhoto(File(f.path))) allowed.add(_PhotoEntry.local(File(f.path)));
        }
        if (!mounted) return;
        setState(() => _photos.addAll(allowed));
        _dirty = true;
        if (allowed.length < picked.length) {
          AppToast.warning('Only $remaining more photo${remaining == 1 ? '' : 's'} allowed. Extra photos were removed.');
        }
      }
    }
  }

  Future<bool> _acceptPhoto(File f) async {
    final ext = f.path.split('.').last.toLowerCase();
    if (!_okExt.contains(ext)) {
      if (mounted) setState(() => _photoError = StaySetupStrings.photoWrongType);
      return false;
    }
    final size = await f.length();
    if (size > _maxBytes) {
      AppToast.error(StaySetupStrings.photoTooLarge);
      return false;
    }
    if (_photoError != null && mounted) setState(() => _photoError = null);
    return true;
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
    if (_photosOnly && _ctrl.stay.value != null) {
      await _finishPhotos();
      return;
    }
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
      if (_ctrl.lastErrorType == 'OnboardingClosed' || _ctrl.lastErrorType == 'StayOutsideDistrict') {
        setState(() => _step = 1);
        _showOnboardingClosed(errorType: _ctrl.lastErrorType, serverMessage: _ctrl.lastErrorMessage);
        return;
      }
      _showServerRegistrationError();
      return;
    }
    await _finishPhotos();
  }

  Future<void> _finishPhotos() async {
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
      setState(() => _askingRetry = true);
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StayConfirmDialog(
          title: 'Upload Failed',
          body: '${failed.length} photo${failed.length > 1 ? 's' : ''} could not be uploaded. Retry?',
          cancelLabel: 'Skip',
          confirmLabel: 'Retry',
          art: ListingArt.camera,
          onCancel: () => Navigator.pop(context, false),
          onConfirm: () => Navigator.pop(context, true),
        ),
      );
      if (mounted) setState(() => _askingRetry = false);
      if (retry == true && mounted) {
        final retryList = failed;
        await runIndexedWithLimit(retryList.length, (j) => uploadOne(retryList[j]));
        failed = [for (var i = 0; i < results.length; i++) if (!results[i]) i];
      }
    }

    if (mounted) setState(() => _isUploading = false);
    if (failed.isNotEmpty) {
      if (_ctrl.lastErrorType == 'PlanPhotoLimit' && mounted) {
        PlanGate.showLimit(context, StayGateStrings.photoGate());
      } else {
        AppToast.error(StaySetupStrings.photoUploadFailed);
      }
    }
    return [for (final i in failed) files[i]];
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
    final overall = _uploadProgress.clamp(0.0, 1.0);
    final percent = (overall * 100).toInt();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _isUploading || _isFinalizing || _ctrl.isSaving.value) return;
        _handleBack();
      },
      child: Stack(children: [
        Scaffold(
          backgroundColor: ListingPalette.forest.page,
          body: Column(children: [
            StayPageHeader(
              title: 'Basic Details',
              subtitle: 'Step 1 of 4',
              onBack: _isUploading ? null : _handleBack,
              asset: SetupAssets.hotel,
            ),
            StepProgressHeader(tone: _tone, labels: const ['Details', 'Location', 'Address', 'Photos'], current: _step),
            Expanded(
              child: PageTransitionSwitcher(
                duration: templateTransitionDuration,
                reverse: reverse,
                layoutBuilder: (entries) => Stack(alignment: Alignment.topCenter, children: entries),
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
                        ? SingleChildScrollView(key: const ValueKey(1), padding: EdgeInsets.only(bottom: DS.s(24)), child: locationStepWidget())
                        : _step == 2
                            ? addressStepWidget()
                            : _photosStep(),
              ),
            ),
          ]),
          bottomNavigationBar: Obx(() {
            final saving = _ctrl.isSaving.value;
            final disabled = saving ||
                _isFinalizing ||
                (_step == 2 && (isResolvingDistrict || selectedDistrictId == null || !hasAddressText));
            return FormFooter(
              tone: _tone,
              primaryLabel: _step == 0
                  ? 'Next: Location'
                  : _step == 1
                      ? 'Next: Address'
                      : _step == 2
                          ? 'Next: Photos'
                          : 'Save',
              onPrimary: disabled ? null : _handleNext,
              primaryLoading: saving || _isFinalizing || (_isUploading && !_askingRetry),
              secondaryLabel: _step > 0 && !_photosOnly ? 'Back' : null,
              onSecondary: _step > 0 && !_photosOnly
                  ? () {
                      if (_step == 1) setLocationStepActive(false);
                      setState(() => _step--);
                    }
                  : null,
            );
          }),
        ),
        if (_isUploading && !_askingRetry)
          StayBusy(
            message: 'Uploading Photos',
            art: SetupAssets.airplane,
            progress: overall,
            caption: percent >= 95 ? 'Almost done!' : '${_uploadDone.length} of $_uploadTotal uploaded',
          ),
        Obx(() => _ctrl.isSaving.value ? const StayBusy(message: 'Saving your stay...') : const SizedBox.shrink()),
        if (_isFinalizing) const StayBusy(message: 'Please wait...'),
        if (_step == 2 && showAddressResolveOverlay) const StayBusy(message: 'Please wait...', art: ListingArt.compass),
      ]),
    );
  }

  Widget _card({required String art, required String title, required Widget child, bool optional = false}) => FormSectionCard(
        tone: _tone,
        art: art,
        title: title,
        tag: optional ? 'Optional' : 'Required',
        tagMuted: optional,
        child: child,
      );

  Widget _detailsStep() => SingleChildScrollView(
        key: const ValueKey(0),
        padding: EdgeInsets.only(bottom: DS.s(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _card(
            art: ListingArt.stay,
            title: 'Stay Name',
            child: PillField(
              tone: _tone,
              controller: _nameCtrl,
              focusNode: _nameFocusNode,
              maxLength: 80,
              inputFormatters: noEmojiInputFormatters,
              textCapitalization: TextCapitalization.words,
              hint: 'e.g. Himalayan Home',
            ),
          ),
          _card(
            art: ListingArt.stay,
            title: 'Stay Type',
            child: Obx(() {
              final types = _types.types;
              if (types.isEmpty) {
                if (_types.isLoading.value) return PillStatusBox.loading(tone: _tone);
                return PillStatusBox.retry(tone: _tone, text: "Couldn't load stay types. Tap to retry.", onTap: _types.load);
              }
              return OptionTileGrid(
                tone: _tone,
                items: [for (var i = 0; i < types.length; i++) OptionTileItem(label: types[i].name, art: StayOwnerArt.stayType(types[i].name, i))],
                isSelected: (i) => _stayTypeId == types[i].id,
                onTap: (i) => setState(() {
                  _stayTypeId = types[i].id;
                  _dirty = true;
                }),
              );
            }),
          ),
          _registrationCard(),
          _gstinCard(),
          _card(
            art: StayOwnerArt.automobile,
            title: 'Vehicle Access',
            child: OptionTileGrid(
              tone: _tone,
              items: [
                for (final o in StayOptionSets.vehicleAccess) OptionTileItem(label: o.label, art: StayOwnerArt.vehicle[o.value] ?? ListingArt.taxi),
              ],
              isSelected: (i) => _vehicleAccess == StayOptionSets.vehicleAccess[i].value,
              onTap: (i) => setState(() {
                _vehicleAccess = StayOptionSets.vehicleAccess[i].value;
                _dirty = true;
              }),
            ),
          ),
          _card(
            art: ListingArt.key,
            title: 'Host Lives Here',
            child: OptionTileGrid(
              tone: _tone,
              columns: 2,
              items: const [OptionTileItem(label: 'Yes', art: ListingArt.key), OptionTileItem(label: 'No', art: ListingArt.luggage)],
              isSelected: (i) => _hostLivesHere == (i == 0),
              onTap: (i) => setState(() {
                _hostLivesHere = i == 0;
                _dirty = true;
              }),
            ),
          ),
          _card(
            art: ListingArt.sunrise,
            title: 'Facilities',
            optional: true,
            child: Wrap(
              spacing: DS.gh(8),
              runSpacing: DS.gv(8),
              children: [
                for (final o in StayOptionSets.facilities)
                  ChoicePill(
                    tone: _tone,
                    label: o.label,
                    check: true,
                    selected: _facilities.contains(o.value),
                    onTap: () => setState(() {
                      if (!_facilities.remove(o.value)) _facilities.add(o.value);
                      _dirty = true;
                    }),
                  ),
              ],
            ),
          ),
          _card(
            art: ListingArt.speechBalloon,
            title: 'Description',
            optional: true,
            child: PillField(
              tone: _tone,
              controller: _descCtrl,
              maxLines: 3,
              maxLength: 300,
              inputFormatters: noEmojiInputFormatters,
              hint: 'Describe amenities, nearby facilities, rules...',
            ),
          ),
        ]),
      );

  void _selectRegType(String? v) => setState(() {
        _regTypeId = v;
        _serverTypeError = null;
        _serverOtherError = null;
        _serverNumberError = null;
        _dirty = true;
      });

  Future<void> _pickRegType(List<StayRegistrationTypeModel> types) async {
    FocusScope.of(context).unfocus();
    final picked = await Sheet3D.show<String>(
      context,
      builder: (sheetCtx) => Sheet3D(
        tone: _tone,
        art: ListingArt.clipboard,
        title: 'Registration type',
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < types.length; i++)
              SheetListRow(
                tone: _tone,
                compact: true,
                title: types[i].name,
                selected: types[i].id == _regTypeId,
                divider: i > 0,
                onTap: () => Navigator.pop(sheetCtx, types[i].id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _selectRegType(picked);
  }

  Widget _registrationCard() => _card(
        art: ListingArt.clipboard,
        title: 'Registration',
        child: Obx(() {
          final types = _regTypes.types;
          if (types.isEmpty) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const FieldLabel('Registration type', first: true),
              if (_regTypes.isLoading.value)
                PillStatusBox.loading(tone: _tone)
              else
                PillStatusBox.retry(tone: _tone, text: "Couldn't load registration types. Tap to retry.", onTap: _regTypes.load),
            ]);
          }
          final type = _selectedRegType;
          final isUdyam = type?.code == StayRegistrationValidators.udyamCode;
          final numberHint = isUdyam ? 'UDYAM-UK-05-0001234' : 'Registration number';
          final keep = _hasStoredNumber && _regNumCtrl.text.isEmpty;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PillPickerField(
              key: ValueKey(type?.id),
              tone: _tone,
              label: 'Registration type',
              value: type?.name,
              hint: 'Select type',
              errorText: _typeFieldError,
              onTap: () => _pickRegType(types),
            ),
            if (type != null) ...[
              if (type.requiresOtherName)
                PillField(
                  tone: _tone,
                  label: 'Document name',
                  firstLabel: false,
                  controller: _regOtherCtrl,
                  focusNode: _regOtherFocus,
                  inputFormatters: StayRegistrationValidators.otherNameInputFormatters,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() => _serverOtherError = null),
                  hint: 'e.g. Gram Panchayat NOC',
                  errorText: _otherNameFieldError,
                ),
              PillField(
                tone: _tone,
                label: 'Registration number',
                firstLabel: false,
                controller: _regNumCtrl,
                focusNode: _regNumFocus,
                inputFormatters: StayRegistrationValidators.registrationInputFormatters,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() => _serverNumberError = null),
                hint: numberHint,
                errorText: _numberFieldError,
                helperText: keep ? StayRegistrationValidators.savedHelp : type.helpText ?? StayRegistrationValidators.registrationHelp,
                suffixText: keep ? 'Saved' : null,
              ),
            ],
          ]);
        }),
      );

  Widget _gstinCard() {
    final hasSaved = (_ctrl.stay.value?.hasGstin ?? false) && _gstinCtrl.text.isEmpty;
    return _card(
      art: ListingArt.moneyBag,
      title: 'GSTIN',
      optional: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PillField(
          tone: _tone,
          controller: _gstinCtrl,
          focusNode: _gstinFocus,
          inputFormatters: StayRegistrationValidators.gstinInputFormatters,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() => _serverGstinError = null),
          hint: '05ABCDE1234F1Z6',
          errorText: _gstinFieldError,
          helperText: StayRegistrationValidators.gstinHelp,
          suffixText: hasSaved && !_clearGstin ? 'Saved' : null,
        ),
        if (hasSaved)
          LinkLine3D(
            text: _clearGstin ? 'Will be removed · Undo' : 'Saved · Remove',
            color: _clearGstin ? Form3D.errorText : _tone.text,
            onTap: () => setState(() {
              _clearGstin = !_clearGstin;
              _serverGstinError = null;
              _dirty = true;
            }),
          ),
      ]),
    );
  }

  Widget _photoTile(int i) {
    final p = _photos[i];
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
    return PhotoTile3D(key: ObjectKey(p), image: image, coverLabel: i == 0 ? StaySetupStrings.cover : null, onRemove: () => _removePhoto(i));
  }

  Widget _photosStep() {
    final max = _maxPhotos;
    final left = max - _photos.length;
    final locked = left <= 0 && PlanGate.canUpgrade;
    final plus = PlanKeys.plusSeed[PlanKey.photos] ?? max;
    final tiles = <Widget>[
      for (var i = 0; i < _photos.length; i++) _photoTile(i),
      if (locked) _lockedPhotoTile() else if (left > 0) PhotoAddTile3D(tone: _tone, label: StaySetupStrings.addPhoto, onTap: _pickPhoto),
    ];
    return SingleChildScrollView(
      key: const ValueKey(3),
      padding: EdgeInsets.only(bottom: DS.s(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _card(
          art: ListingArt.camera,
          title: StaySetupStrings.photosTitle,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(alignment: Alignment.centerRight, child: Text(StaySetupStrings.photoMeter(_photos.length, max), style: Ink3D.text(13, FontWeight.w700, _tone.text))),
            Gap.v(10),
            if (_photos.isEmpty)
              PhotoDropZone3D(tone: _tone, title: 'Add Stay Photos', subtitle: 'Camera or Gallery', onTap: _pickPhoto)
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                clipBehavior: Clip.none,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: DS.gh(10), mainAxisSpacing: DS.gv(10)),
                itemCount: tiles.length,
                itemBuilder: (_, i) => tiles[i],
              ),
            if (_photoError != null)
              Padding(
                padding: EdgeInsets.only(top: DS.gv(6)),
                child: Semantics(liveRegion: true, child: Text(_photoError!, style: Ink3D.text(12, FontWeight.w600, DesignColors.error))),
              ),
            Gap.v(8),
            Text(StayGateStrings.photoHint, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey)),
          ]),
        ),
        if (locked) StayPlusBanner(text: StayGateStrings.photoBanner(max, plus), onTap: () => PlanGate.showLimit(context, StayGateStrings.photoGate())),
      ]),
    );
  }

  Widget _lockedPhotoTile() => Semantics(
        button: true,
        label: '${StaySetupStrings.addPhoto}, needs Plus',
        excludeSemantics: true,
        child: InkWell(
          key: GateKeys.softRow,
          onTap: () => PlanGate.showLimit(context, StayGateStrings.photoGate()),
          borderRadius: DS.circular(14),
          child: DecoratedBox(
            decoration: BoxDecoration(color: OwnerLook.stay.lockFill, borderRadius: DS.circular(14), border: Border.all(color: OwnerLook.stay.lockLine, width: DS.s(1.5))),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Art3D(asset: ListingArt.locked, size: 26),
                Gap.v(4),
                Text(StaySetupStrings.addPhoto, textAlign: TextAlign.center, style: Ink3D.text(11, FontWeight.w700, OwnerLook.stay.lockText, letterSpacing: 0)),
                Gap.v(2),
                const PlusChip(),
              ],
            ),
          ),
        ),
      );
}
