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
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/plan_controller.dart';
import '../../../models/city_model.dart';
import '../../../screens/add_listing_location_mixin.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/concurrency.dart';
import '../../../utils/input_formatters.dart';
import '../../../utils/photo_upload/app_photo_pick.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_stay_owner.dart';
import '../../../widgets/onboarding_closed_dialog.dart';
import '../models/stay_owner_model.dart';
import '../models/stay_registration_type_model.dart';
import '../stay_registration_types_controller.dart';
import '../stay_types_controller.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/onboarding/onboarding_exit.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/plan_bindings.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/plan/soft_lock.dart';
import '../../stay_owner/stay_owner_deps.dart';
import '../../stay_owner/widgets/stay_widgets.dart';
import '../../stay_owner/strings/stay_gate_strings.dart';
import '../../stay_owner/strings/stay_setup_strings.dart';
import 'stay_option_sets.dart';
import 'stay_option_tiles.dart';
import 'stay_registration_validators.dart';
import 'stay_rooms_form.dart';
import 'stay_rules_form.dart';
import 'stay_setup_controller.dart';

class _PhotoEntry {
  final StayPhotoModel? remote;
  final File? local;
  const _PhotoEntry.remote(StayPhotoModel this.remote) : local = null;
  const _PhotoEntry.local(File this.local) : remote = null;
  const _PhotoEntry.replacing(StayPhotoModel this.remote, File this.local);

  bool get isReplace => remote != null && local != null;
}

typedef _PhotoJob = ({File file, String? replaceId, String? oldUrl});

class StayBasicDetailsScreen extends StatefulWidget {
  const StayBasicDetailsScreen({super.key, this.photosOnly = false, this.onboarding = false});

  final bool photosOnly;
  final bool onboarding;
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
  final Set<String> _sentPaths = {};
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
  late final StayRoomsFormController _rooms = StayRoomsFormController(onboarding: true, ctrl: _ctrl);
  final _rules = StayRulesFormController();
  String? _savedBasicKey;
  String? _savedRoomsKey;
  String? _savedRulesKey;
  bool _submitting = false;

  @override
  int? get addressMaxLength => 500;

  bool get _onboarding => widget.onboarding;
  int get _lastStep => _onboarding ? 5 : 3;
  bool get _busy => _isUploading || _isFinalizing || _submitting || _ctrl.isSaving.value;

  static void _planTick() {
    if (Get.isRegistered<PlanController>()) Get.find<PlanController>().myPlan.value;
  }

  int get _maxPhotos {
    if (_onboarding) return PlanKeys.freeSeed[PlanKey.photos]!;
    final m = _ctrl.stay.value?.meter('Photos')?.limit;
    if (m != null && m > 0) return m;
    if (!PlanGate.loaded) return PlanKeys.plusSeed[PlanKey.photos] ?? PlanGate.limit(PlanKey.photos);
    return PlanGate.limit(PlanKey.photos);
  }
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

  bool get _hasChanges =>
      _dirty ||
      (!_photosOnly && _step > 0) ||
      (_onboarding && (_rooms.changedSince(_savedRoomsKey) || _rules.changedSince(_savedRulesKey)));

  @override
  void initState() {
    super.initState();
    // Reached from /stay-setup before MainScreen: the plan must exist before its limits are read.
    if (!widget.onboarding) PlanBindings.ensure();
    initLocationTracking(
      style: _locationStyle,
      onLocationStale: _handleLocationStale,
      onOnboardingClosed: _onResolveOnboardingClosed,
      onboardingGrandfathered: _onboardingGrandfathered,
    );
    _types.ensureLoaded();
    _regTypes.ensureLoaded();
    final args = _onboarding ? null : Get.arguments;
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
    if (_onboarding) {
      _rooms.seed(s);
      _rules.seed(s);
      if (s != null && s.roomsDone) _savedRoomsKey = _rooms.key;
      if (s != null && s.rulesDone) _savedRulesKey = _rules.key;
      if (s != null && s.isDraft && s.step1Done) {
        _step = s.rooms.length >= _rooms.max ? 5 : 4;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) resolveAddressIfNeeded();
        });
      }
      _prevStep = _step;
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
    _rooms.dispose();
    _rules.dispose();
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
    if (_step < 1 || (_onboarding && _step > 3)) return;
    _showOnboardingClosed();
  }

  void _showOnboardingClosed({String? errorType, String? serverMessage}) {
    if (!mounted) return;
    final s = _ctrl.stay.value;
    final canCorrect = (s == null || s.isDraft) && OnboardingExit.canCorrectRole;
    OnboardingClosedDialog.show(context,
        body: StaySetupStrings.notOpenBodyFor(errorType, serverMessage),
        onChangeRole: canCorrect ? () => OnboardingExit.openRoleCorrection(hasDraft: s != null) : null);
  }

  void _handleLocationStale() {
    if (!mounted || _step <= 1) return;
    if (_onboarding && _step > 3) return;
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
      final shot = await AppPhotoPick.pickOne(source, onFailed: _pickFailed);
      if (shot != null && mounted && await _acceptPhoto(File(shot.path))) {
        setState(() => _photos.add(_PhotoEntry.local(File(shot.path))));
        _dirty = true;
      }
    } else {
      final remaining = _maxPhotos - _photos.length;
      final picked = await AppPhotoPick.pickGallery(remaining, onFailed: _pickFailed);
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

  static void _pickFailed() => AppToast.error(StaySetupStrings.photoPickFailed);

  Future<bool> _acceptPhoto(File f) async {
    switch (await AppPhotoPick.accept(f)) {
      case PhotoReject.wrongType:
        if (mounted) setState(() => _photoError = StaySetupStrings.photoWrongType);
        return false;
      case PhotoReject.tooLarge:
        AppToast.error(StaySetupStrings.photoTooLarge);
        return false;
      case null:
        break;
    }
    if (_photoError != null && mounted) setState(() => _photoError = null);
    return true;
  }

  Future<void> _changePhoto(int i) async {
    final current = _photos[i].remote;
    if (current == null) return;
    final source = await Sheet3D.show<ImageSource>(
      context,
      builder: (sheetCtx) => Sheet3D(
        tone: _tone,
        art: ListingArt.camera,
        title: StaySetupStrings.changePhotoTitle,
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
    }
    final shot = await AppPhotoPick.pickOne(source, onFailed: _pickFailed);
    if (shot == null || !mounted) return;
    final file = File(shot.path);
    if (!await _acceptPhoto(file) || !mounted) return;
    if (i >= _photos.length || _photos[i].remote?.id != current.id) return;
    setState(() => _photos[i] = _PhotoEntry.replacing(current, file));
    _dirty = true;
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
    } else if (_step == 3) {
      _save();
    } else if (_step == 4) {
      _roomsPrimary();
    } else {
      _submit();
    }
  }

  Future<void> _afterLateLock() async {
    if (_ctrl.lastErrorType != 'StayStepLocked') return;
    await _ctrl.load();
    if (!mounted) return;
    final s = _ctrl.stay.value;
    if (s == null || !s.step1Done) {
      setState(() => _step = 3);
    } else if (!s.roomsDone) {
      setState(() => _step = 4);
    }
  }

  void _roomsPrimary() {
    switch (_rooms.action) {
      case StayRoomsAction.add:
        _rooms.openForm();
      case StayRoomsAction.save:
        FocusScope.of(context).unfocus();
        _rooms.commitForm();
      case StayRoomsAction.next:
        _saveRoomsPage();
    }
  }

  Future<void> _saveRoomsPage() async {
    if (_busy || !_rooms.validate()) return;
    if (_rooms.key != _savedRoomsKey) {
      final ok = await _ctrl.saveRooms(_rooms.payload());
      if (!mounted) return;
      if (!ok) {
        if (_ctrl.lastErrorType == 'PlanRoomTypeLimit') {
          AppToast.info(StayRoomsFormController.onboardingLimit);
        } else {
          await _afterLateLock();
        }
        return;
      }
      _rooms.seed(_ctrl.stay.value);
      _savedRoomsKey = _rooms.key;
    }
    setState(() => _step = 5);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final err = _rules.validate();
    if (err != null) {
      AppToast.error(err);
      return;
    }
    final s = _ctrl.stay.value;
    if (s != null && !s.registrationDone) {
      AppToast.warning('Add your registration details.');
      setState(() {
        _showRegRequired = true;
        _step = 0;
      });
      return;
    }
    setState(() => _submitting = true);
    try {
      if (_rules.key != _savedRulesKey) {
        final ok = await _ctrl.saveRules(_rules.payload());
        if (!mounted) return;
        if (!ok) {
          await _afterLateLock();
          return;
        }
        _savedRulesKey = _rules.key;
      }
      final ok = await _ctrl.submit();
      if (!mounted) return;
      final auth = Get.find<AuthController>();
      if (!ok) {
        final type = _ctrl.lastErrorType;
        if (type == 'OnboardingClosed' || type == 'StayOutsideDistrict') {
          _showOnboardingClosed(errorType: type, serverMessage: _ctrl.lastErrorMessage);
          return;
        } else if (type == 'StayRegistrationRequired') {
          _showServerRegistrationError();
          return;
        } else if (type == 'StayLocked') {
          // A retry after a lost Submit response: the stay is already under review.
          final loaded = await _ctrl.load();
          if (!mounted || !loaded || !(_ctrl.stay.value?.isPendingReview ?? false)) return;
          await auth.refreshProfile();
          if (!mounted) return;
        } else {
          await _afterLateLock();
          return;
        }
      }
      AppToast.success(StaySetupStrings.submittedToast);
      if (_ctrl.mainBelow) {
        StayOwnerDeps.refreshHome().ignore();
        Get.until((r) => r.settings.name == AppRoutes.main);
        auth.switchToTab(AppTabs.home);
        return;
      }
      Get.offAllNamed(AppRoutes.main);
      WidgetsBinding.instance.addPostFrameCallback((_) => auth.switchToTab(AppTabs.home));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
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
    final body = <String, dynamic>{
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
    };
    final bodyKey = body.toString();
    if (_onboarding &&
        bodyKey == _savedBasicKey &&
        _removedPhotoIds.isEmpty &&
        _photos.every((p) => p.local == null) &&
        (_ctrl.stay.value?.step1Done ?? false)) {
      _dirty = false;
      setState(() => _step = 4);
      return;
    }
    final ok = await _ctrl.saveBasic(body);
    if (!mounted) return;
    if (ok) _savedBasicKey = bodyKey;
    if (!ok) {
      if (_ctrl.lastErrorType == 'OnboardingClosed' || _ctrl.lastErrorType == 'StayOutsideDistrict') {
        setState(() => _step = 1);
        _showOnboardingClosed(errorType: _ctrl.lastErrorType, serverMessage: _ctrl.lastErrorMessage);
        return;
      }
      if (_ctrl.lastErrorType == OwnerErrorTypes.phoneNotAllowed) {
        setState(() => _step = 0);
        return;
      }
      _showServerRegistrationError();
      return;
    }
    await _finishPhotos();
  }

  Future<void> _finishPhotos() async {
    setState(() => _isFinalizing = true);
    final failedIds = <String>[];
    for (final id in _removedPhotoIds) {
      if (!await _ctrl.deletePhoto(id) && _ctrl.lastNetwork) failedIds.add(id);
    }
    _removedPhotoIds
      ..clear()
      ..addAll(failedIds);
    if (mounted) setState(() => _isFinalizing = false);
    if (failedIds.isNotEmpty || !mounted) return;

    final jobs = <_PhotoJob>[
      for (final p in _photos)
        if (p.local != null && !_sentPaths.contains(p.local!.path))
          (file: p.local!, replaceId: p.remote?.id, oldUrl: p.remote?.url),
    ];
    final failed = jobs.isNotEmpty && mounted ? await _uploadAll(jobs) : const <_PhotoJob>[];
    for (final j in jobs) {
      if (failed.contains(j)) continue;
      _sentPaths.add(j.file.path);
      final old = j.oldUrl;
      if (j.replaceId != null && old != null) {
        CachedNetworkImage.evictFromCache(old).catchError((_) => false);
      }
    }

    if (mounted) setState(() => _isFinalizing = true);
    final loaded = await _ctrl.load();
    if (!mounted) return;
    final serverPhotos = loaded ? _ctrl.stay.value?.photos : null;
    if (failed.isNotEmpty || (serverPhotos != null && serverPhotos.isEmpty)) {
      final kept = serverPhotos != null
          ? serverPhotos.map(_PhotoEntry.remote).toList()
          : [for (final p in _photos) if (p.remote != null) _PhotoEntry.remote(p.remote!)];
      final added = <_PhotoEntry>[];
      final full = serverPhotos != null && serverPhotos.length >= _maxPhotos;
      for (final j in failed) {
        final id = j.replaceId;
        if (id == null) {
          if (!full) added.add(_PhotoEntry.local(j.file));
          continue;
        }
        final at = kept.indexWhere((e) => e.remote?.id == id);
        if (at >= 0) kept[at] = _PhotoEntry.replacing(kept[at].remote!, j.file);
      }
      setState(() {
        _isFinalizing = false;
        _photos
          ..clear()
          ..addAll(kept)
          ..addAll(added);
        if (serverPhotos != null) _sentPaths.clear();
      });
      if (failed.isEmpty) AppToast.error('Please add at least 1 photo of your stay');
      return;
    }
    if (_onboarding) {
      if (serverPhotos == null) {
        setState(() => _isFinalizing = false);
        return;
      }
      setState(() {
        _isFinalizing = false;
        _photos
          ..clear()
          ..addAll(serverPhotos.map(_PhotoEntry.remote));
        _sentPaths.clear();
        _dirty = false;
        _step = 4;
      });
      return;
    }
    setState(() => _isFinalizing = false);
    Get.back();
    AppToast.success('Basic details saved');
  }

  Future<List<_PhotoJob>> _uploadAll(List<_PhotoJob> files) async {
    setState(() {
      _isUploading = true;
      _uploadTotal = files.length;
      _uploadDone = {};
      _uploadProgress = 0.0;
    });
    final progresses = List<double>.filled(files.length, 0.0);
    final results = List<bool>.filled(files.length, false);

    Future<void> uploadOne(int i) async {
      void onProgress(int sent, int total) {
        if (!mounted) return;
        progresses[i] = total > 0 ? sent / total : 0.0;
        setState(() => _uploadProgress = progresses.fold(0.0, (a, b) => a + b) / files.length);
      }

      final job = files[i];
      final id = job.replaceId;
      final ok = id != null
          ? await _ctrl.replacePhoto(id, job.file.path, onProgress: onProgress)
          : await _ctrl.uploadPhoto(job.file.path, onProgress: onProgress);
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
    if (failed.isNotEmpty && mounted) {
      if (_ctrl.lastErrorType == OwnerErrorTypes.planPhotoLimit && _onboarding) {
        AppToast.info('You can add up to $_maxPhotos photos.');
      } else if (_ctrl.lastErrorType == OwnerErrorTypes.planPhotoLimit) {
        await _ctrl.showLimitRefusal(context, StayGateStrings.photoGate);
      } else {
        AppToast.error(_ctrl.lastNetwork ? StaySetupStrings.noConnection : StaySetupStrings.photoUploadFailed);
      }
    }
    return [for (final i in failed) files[i]];
  }

  void _goBackPage() {
    if (_step == 1) setLocationStepActive(false);
    setState(() => _step--);
  }

  void _handleBack() {
    if (_onboarding) {
      if (_busy) return;
      if (_step > 0) {
        _goBackPage();
        return;
      }
      if (!_ctrl.mainBelow) {
        final s = _ctrl.stay.value;
        OnboardingExit.onBackFromFirstPage(isDraft: s == null || s.isDraft, hasDraft: s != null);
        return;
      }
    }
    if (_hasChanges) {
      _confirmDiscard();
    } else {
      Get.back();
    }
  }

  bool get _gatedFirstPage => _onboarding && _step == 0 && !_ctrl.mainBelow;

  void _openMenu() {
    final s = _ctrl.stay.value;
    OnboardingExit.openMenu(context, isDraft: s == null || s.isDraft, hasDraft: s != null);
  }

  String get _title => !_onboarding || _step < 4 ? 'Basic Details' : (_step == 4 ? 'Rooms' : 'Rules');

  String get _asset => !_onboarding || _step < 4 ? SetupAssets.hotel : (_step == 4 ? SetupAssets.bed : SetupAssets.clipboard);

  String get _primaryLabel => switch (_step) {
        0 => 'Next: Location',
        1 => 'Next: Address',
        2 => 'Next: Photos',
        3 => _onboarding ? 'Next: Rooms' : 'Save',
        4 => switch (_rooms.action) {
            StayRoomsAction.add => StayRoomsFormController.addLabel,
            StayRoomsAction.save => StayRoomsFormController.saveLabel,
            StayRoomsAction.next => 'Next: Rules',
          },
        _ => StaySetupStrings.submit,
      };

  Widget _pageScroll(int step, Widget child) => SingleChildScrollView(
        key: ValueKey(step),
        padding: EdgeInsets.only(bottom: DS.s(24)),
        child: child,
      );

  Widget _page() => switch (_step) {
        0 => _detailsStep(),
        1 => _pageScroll(1, locationStepWidget()),
        2 => addressStepWidget(),
        3 => Obx(key: const ValueKey(3), () => _photosStep()),
        4 => _pageScroll(4, StayRoomsForm(controller: _rooms, tone: _tone)),
        _ => _pageScroll(5, StayRulesForm(controller: _rules, tone: _tone)),
      };

  StayBusy _savingBusy() => switch (_step) {
        4 => const StayBusy(message: 'Saving rooms...', art: SetupAssets.bed),
        5 => const StayBusy(message: 'Submitting...', art: SetupAssets.key),
        _ => const StayBusy(message: 'Saving your stay...'),
      };

  @override
  Widget build(BuildContext context) {
    final reverse = _step < _prevStep;
    _prevStep = _step;
    final overall = _uploadProgress.clamp(0.0, 1.0);
    final percent = (overall * 100).toInt();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _busy) return;
        _handleBack();
      },
      child: Stack(children: [
        Scaffold(
          backgroundColor: ListingPalette.forest.page,
          body: Column(children: [
            StayPageHeader(
              title: _title,
              subtitle: _onboarding ? 'Step ${_step + 1} of 6' : 'Step 1 of 4',
              onBack: _isUploading ? null : _handleBack,
              asset: _asset,
              leadingIcon: _gatedFirstPage ? Icons.more_vert_rounded : null,
              onLeading: _gatedFirstPage ? _openMenu : null,
              leadingSemantics: _gatedFirstPage ? StaySetupStrings.menuLabel : null,
            ),
            StepProgressHeader(
              tone: _tone,
              labels: _onboarding ? const ['Details', 'Location', 'Address', 'Photos', 'Rooms', 'Rules'] : const ['Details', 'Location', 'Address', 'Photos'],
              current: _step,
            ),
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
                child: _page(),
              ),
            ),
          ]),
          bottomNavigationBar: ListenableBuilder(
            listenable: _rooms,
            builder: (context, _) => Obx(() {
              final saving = _ctrl.isSaving.value;
              final disabled = saving ||
                  _isFinalizing ||
                  _isUploading ||
                  _submitting ||
                  (_step == 2 && (isResolvingDistrict || selectedDistrictId == null || !hasAddressText));
              return FormFooter(
                tone: _tone,
                primaryLabel: _primaryLabel,
                onPrimary: disabled ? null : _handleNext,
                primaryLoading: saving || _isFinalizing || _submitting || (_isUploading && !_askingRetry),
                note: _onboarding && _step == _lastStep ? StaySetupStrings.dashboardOpens : null,
                secondaryLabel: _step > 0 && !_photosOnly ? 'Back' : null,
                onSecondary: _step > 0 && !_photosOnly && !_submitting ? _goBackPage : null,
              );
            }),
          ),
        ),
        if (_isUploading && !_askingRetry)
          StayBusy(
            message: 'Uploading Photos',
            art: SetupAssets.airplane,
            progress: overall,
            caption: percent >= 95 ? 'Almost done!' : '${_uploadDone.length} of $_uploadTotal uploaded',
          ),
        Obx(() => _ctrl.isSaving.value || _submitting ? _savingBusy() : const SizedBox.shrink()),
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
          if (_onboarding && (_ctrl.stay.value?.isRejected ?? false))
            StayStrip(
              art: ListingArt.warning,
              text: StaySetupStrings.notApproved(_ctrl.stay.value?.rejectedReason),
              fill: StayLook.redSoft,
              ink: StayLook.redText,
              margin: DS.insets(l: 18, t: 14, r: 18),
            ),
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
                items: StayOptionTiles.stayTypes([for (final t in types) t.name]),
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
              items: StayOptionTiles.vehicleAccess,
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
              items: StayOptionTiles.hostLivesHere,
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
    final decode = (MediaQuery.sizeOf(context).width / 3 * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, KitPhoto.maxDecodePx);
    final image = p.local != null
        ? Image.file(p.local!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, cacheWidth: decode)
        : CachedNetworkImage(
            imageUrl: p.remote!.url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: decode,
            placeholder: (_, _) => const TemplatePlaceholder(radius: 0, height: double.infinity),
            errorWidget: (_, _, _) => const TemplatePlaceholder(radius: 0, height: double.infinity),
          );
    return PhotoTile3D(
      key: ObjectKey(p),
      image: image,
      coverLabel: i == 0 ? StaySetupStrings.cover : null,
      onRemove: () => _removePhoto(i),
      onChange: p.remote != null ? () => _changePhoto(i) : null,
      changeLabel: StaySetupStrings.changePhoto,
    );
  }

  Widget _photosStep() {
    _ctrl.stay.value;
    if (!_onboarding) _planTick();
    final max = _maxPhotos;
    final left = max - _photos.length;
    final locked = !_onboarding && left <= 0 && PlanGate.loaded && PlanGate.canUpgrade;
    final plus = PlanKeys.plusSeed[PlanKey.photos] ?? max;
    final tiles = <Widget>[
      for (var i = 0; i < _photos.length; i++) _photoTile(i),
      if (locked) _lockedPhotoTile() else if (left > 0) PhotoAddTile3D(tone: _tone, label: StaySetupStrings.addPhoto, onTap: _pickPhoto),
    ];
    return SingleChildScrollView(
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
            child: Padding(
              padding: DS.all(4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
          ),
        ),
      );
}
