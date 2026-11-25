import 'dart:io';
import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:permission_handler/permission_handler.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_taxi_owner.dart';
import '../../../design/extra/taxi_setup_kit.dart';
import '../../../models/city_model.dart';
import '../../../screens/add_listing_location_mixin.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/onboarding_closed_dialog.dart';
import '../../owner_core/onboarding/onboarding_exit.dart';
import '../models/taxi_owner_model.dart';
import '../taxi_option_sets.dart';
import '../../taxi_driver/hub/taxi_hub_sheets.dart';
import '../taxi_vehicle_types_controller.dart';
import 'taxi_identity_validators.dart';
import 'taxi_photo_pick.dart';
import 'taxi_rate_form.dart';
import 'taxi_routes_form.dart';
import 'taxi_setup_controller.dart';
import 'taxi_vehicle_type_picker_sheet.dart';
import '../../taxi_driver/strings/taxi_photo_strings.dart';
import '../../taxi_driver/strings/taxi_setup_strings.dart';
import '../../taxi_driver/taxi_driver_deps.dart';

abstract final class TaxiPlateDecode {
  static int width(double width, double dpr) => (width * dpr).round().clamp(1, KitPhoto.maxDecodePx);

  // Plate, plate photo, licence or date of birth on a once-approved taxi go back to review.
  static bool needsReview({required String plate, required String initialPlate, required bool newPhoto, required bool licenceTyped, required bool dobPicked}) =>
      TaxiOptionSets.normalizePlate(plate) != initialPlate || newPhoto || licenceTyped || dobPicked;
}

class TaxiVehicleScreen extends StatefulWidget {
  const TaxiVehicleScreen({super.key, this.onboarding = false});
  final bool onboarding;
  @override
  State<TaxiVehicleScreen> createState() => _TaxiVehicleScreenState();
}

enum _Ring { type, seats, plate, photo, phone, whatsApp, base }

class _TaxiVehicleScreenState extends State<TaxiVehicleScreen> with AddListingLocationMixin<TaxiVehicleScreen> {
  static final ListingTone _tone = ListingTone.coral;
  final _ctrl = TaxiSetupController.ensure();
  final _types = TaxiVehicleTypesController.ensure();
  final _plateCtrl = TextEditingController();
  final _plateFocus = FocusNode();
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  final _whatsAppCtrl = TextEditingController();
  final _whatsAppFocus = FocusNode();
  final _dlCtrl = TextEditingController();
  final _dlFocus = FocusNode();
  final _cardKeys = {for (final r in _Ring.values) r: GlobalKey()};
  final _dlKey = GlobalKey();
  final _routes = TaxiRoutesFormController(onboarding: true);
  final _rate = TaxiRateFormController();
  String? _savedRoutesKey;
  bool _submitting = false;

  String? _vehicleTypeId;
  String? _vehicleTypeName;
  int? _seats;
  String? _remotePhotoUrl;
  File? _localPhoto;
  String? _remoteDisplayUrl;
  File? _localDisplay;
  String? _initDisplayUrl;
  bool _same = true;
  int _step = 0;
  int _prevStep = 0;
  bool _isUploading = false;
  bool _isFinalizing = false;
  bool _busy = false;
  LatLng? _resolvedPin;
  String? _savedBasicKey;
  String? _uploadedStatus;
  DateTime? _dob;
  bool _showRequired = false;
  String? _serverDlError;
  String? _serverDobError;
  _Ring? _ring;

  String? _initTypeId;
  int? _initSeats;
  String _initPlate = '';
  String? _initPhotoUrl;
  String _initPhone = '';
  String _initWhatsApp = '';
  LatLng? _initPin;

  static final _locationStyle = LocationStepStyle(
    circleColorHex: TaxiSetupKit.hexAccent,
    userDotColorHex: TaxiSetupKit.hexUser,
    accentColor: ListingPalette.coral.text,
    addressSpinnerColor: ListingPalette.coral.text,
    addressPrefixIcon: Icons.local_taxi_rounded,
    pinStepTitle: 'Pin Your Base *',
    pinHintNoun: 'taxi',
  );

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
    final t = _ctrl.taxi.value;
    _wasApproved = t?.isApproved ?? false;
    final loginPhone = TaxiOptionSets.tenDigits(Get.find<AuthController>().user.value?.phoneNumber ?? '');
    if (t != null) {
      _vehicleTypeId = t.vehicleTypeId;
      _vehicleTypeName = t.vehicleTypeName;
      _seats = t.seats;
      _plateCtrl.text = t.plateDisplay ?? t.numberPlate ?? '';
      _remotePhotoUrl = t.platePhotoUrl;
      _remoteDisplayUrl = t.displayPhotoUrl;
      final phone = t.contactPhone ?? '';
      _phoneCtrl.text = phone.isNotEmpty ? phone : loginPhone;
      final wa = t.whatsAppNumber ?? '';
      _same = wa.isEmpty || wa == _phone;
      if (!_same) _whatsAppCtrl.text = wa;
      final lat = t.latitude, lng = t.longitude;
      if (lat != null && lng != null) {
        _initPin = LatLng(lat, lng);
        prefillLocation(_initPin!, null);
      }
    } else {
      _phoneCtrl.text = loginPhone;
    }
    _initTypeId = _vehicleTypeId;
    _initSeats = _seats;
    _initPlate = TaxiOptionSets.normalizePlate(_plateCtrl.text);
    _initPhotoUrl = _remotePhotoUrl;
    _initDisplayUrl = _remoteDisplayUrl;
    _initPhone = _phoneCtrl.text;
    _initWhatsApp = _effectiveWhatsApp;
    if (widget.onboarding) {
      _routes.seed(t);
      _rate.seed(t);
      if (t != null && t.routesDone) _savedRoutesKey = _routes.key;
      _step = _startStep(t);
      _prevStep = _step;
    }
  }

  static int _startStep(TaxiOwnerModel? t) {
    if (t == null || t.isRejected || !t.step1Done || !t.identityDone) return 0;
    return t.routesDone ? 4 : 3;
  }

  @override
  void dispose() {
    disposeLocationTracking();
    _plateCtrl.dispose();
    _plateFocus.dispose();
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    _whatsAppCtrl.dispose();
    _whatsAppFocus.dispose();
    _dlCtrl.dispose();
    _dlFocus.dispose();
    _routes.dispose();
    _rate.dispose();
    super.dispose();
  }

  String get _phone => _phoneCtrl.text.trim();
  String get _effectiveWhatsApp => _same ? _phone : _whatsAppCtrl.text.trim();
  bool get _hasPhoto => _localPhoto != null || (_remotePhotoUrl != null && _remotePhotoUrl!.isNotEmpty);
  bool get _hasSavedDl => _ctrl.taxi.value?.hasDrivingLicence ?? false;
  bool get _hasSavedDob => _ctrl.taxi.value?.hasDateOfBirth ?? false;
  String get _dlTyped => TaxiIdentityValidators.normalizeDl(_dlCtrl.text);

  String? get _dlError {
    final dl = _dlTyped;
    if (dl.isEmpty) {
      if (_showRequired && !_hasSavedDl) return TaxiIdentityValidators.dlRequiredMessage;
      return _serverDlError;
    }
    if (!TaxiIdentityValidators.isValidDl(dl)) return TaxiIdentityValidators.dlInvalidMessage;
    final dob = _dob;
    if (dob != null && !TaxiIdentityValidators.dlYearMatchesDob(TaxiIdentityValidators.dlIssueYear(dl), dob)) {
      return TaxiIdentityValidators.dlYearMessage;
    }
    return _serverDlError;
  }

  String? get _dobError {
    final dob = _dob;
    if (dob == null) {
      if (_showRequired && !_hasSavedDob) return TaxiIdentityValidators.dobRequiredMessage;
      return _serverDobError;
    }
    final status = TaxiIdentityValidators.dobStatus(dob, TaxiIdentityValidators.todayIst());
    return status == DobStatus.ok ? _serverDobError : TaxiIdentityValidators.dobMessage(status);
  }

  bool get _isApproved => _ctrl.taxi.value?.isApproved ?? false;
  bool get _proofLocked => _ctrl.taxi.value?.proofLocked ?? false;
  bool get _proofFrozen => _ctrl.taxi.value?.proofFrozen ?? false;
  late final bool _wasApproved;

  bool get _hasChanges {
    if (_vehicleTypeId != _initTypeId || _seats != _initSeats) return true;
    if (TaxiOptionSets.normalizePlate(_plateCtrl.text) != _initPlate) return true;
    if (_localPhoto != null || _remotePhotoUrl != _initPhotoUrl) return true;
    if (_localDisplay != null || _remoteDisplayUrl != _initDisplayUrl) return true;
    if (_phone != _initPhone || _effectiveWhatsApp != _initWhatsApp) return true;
    if (_dlTyped.isNotEmpty || _dob != null) return true;
    final pin = selectedLocation, init = _initPin;
    if (init == null) return _step == 2;
    return pin != null &&
        ((pin.latitude - init.latitude).abs() > 1e-6 || (pin.longitude - init.longitude).abs() > 1e-6);
  }

  bool get _needsReview => TaxiPlateDecode.needsReview(
        plate: _plateCtrl.text,
        initialPlate: _initPlate,
        newPhoto: _localPhoto != null,
        licenceTyped: _dlTyped.isNotEmpty,
        dobPicked: _dob != null,
      );

  bool get _blocked => _isUploading || _isFinalizing || _busy || _ctrl.isSaving.value;

  void _mark(_Ring r) {
    setState(() => _ring = r);
    _reveal(_cardKeys[r]!);
  }

  void _reveal(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null && mounted) Scrollable.ensureVisible(ctx, alignment: 0.1, duration: const Duration(milliseconds: 250));
    });
  }

  void _unmark(_Ring r) {
    if (_ring == r) _ring = null;
  }

  void _handleLocationStale() {
    if (!mounted || _step != 2) return;
    _resolvedPin = null;
    AppToast.info('Your location may have changed — please recheck your pin.');
  }

  bool _onboardingGrandfathered(DistrictModel d) {
    final t = _ctrl.taxi.value;
    return t != null && t.everApproved && t.districtId == d.id;
  }

  // Keeps _resolvedPin: clearing it makes build() re-resolve the same pin and reopen this dialog.
  void _showOnboardingClosed() {
    if (!mounted) return;
    final t = _ctrl.taxi.value;
    final canCorrect = (t == null || t.isDraft) && OnboardingExit.canCorrectRole;
    OnboardingClosedDialog.show(context, onChangeRole: canCorrect ? () => OnboardingExit.openRoleCorrection(hasDraft: t != null) : null);
  }

  void _onResolveOnboardingClosed() {
    if (_step != 2) return;
    _showOnboardingClosed();
  }

  void _scheduleBaseResolve() {
    if (_step != 2 || isResolvingDistrict) return;
    final pin = pinnedOrLiveLocation;
    if (pin == null) return;
    final last = _resolvedPin;
    if (last != null &&
        TaxiOptionSets.distanceMeters(last.latitude, last.longitude, pin.latitude, pin.longitude) < 20) {
      return;
    }
    _resolvedPin = pin;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _step != 2) return;
      snapLocationToUserIfUnset();
      resolveAddressIfNeeded();
    });
  }

  void _onBack() {
    if (_blocked) return;
    if (widget.onboarding && _step > 0) {
      _goTo(_step - 1);
      return;
    }
    if (widget.onboarding && !_ctrl.mainBelow) {
      final t = _ctrl.taxi.value;
      OnboardingExit.onBackFromFirstPage(isDraft: t == null || t.isDraft, hasDraft: t != null);
      return;
    }
    final pin = pinnedOrLiveLocation;
    final basicSaved = widget.onboarding &&
        _localPhoto == null &&
        _localDisplay == null &&
        pin != null &&
        _savedBasicKey == _basicBody(pin).toString();
    if ((_hasChanges && !basicSaved) || (widget.onboarding && (_routes.dirty || _rate.dirty))) {
      _confirmDiscard();
    } else {
      Get.back();
    }
  }

  Future<void> _confirmDiscard() async {
    final ok = await showTaxiOwnerDialog(
      context,
      art: ListingArt.clipboard,
      title: 'Discard changes?',
      body: 'Unsaved changes will be lost.',
      cancelLabel: 'Keep Editing',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (ok == true) Get.back();
  }

  Future<void> _showPermissionDeniedDialog(String type) async {
    final ok = await showTaxiOwnerDialog(
      context,
      art: ListingArt.camera,
      title: '$type Permission Required',
      body: 'Please enable $type access in your device Settings to add photos.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Open Settings',
    );
    if (ok == true) openAppSettings();
  }

  Future<void> _pickPhoto() async {
    if (_proofFrozen) return;
    final file = await TaxiPhotoPick.pick(context, onDenied: _showPermissionDeniedDialog);
    if (file == null || !mounted) return;
    final bad = await TaxiPhotoPick.reject(file);
    if (!mounted) return;
    if (bad != null) {
      AppToast.error(bad);
      return;
    }
    setState(() {
      _localPhoto = file;
      _unmark(_Ring.photo);
    });
  }

  Future<void> _pickDisplay() async {
    final file = await TaxiPhotoPick.pick(context, onDenied: _showPermissionDeniedDialog);
    if (file == null || !mounted) return;
    final bad = await TaxiPhotoPick.reject(file);
    if (!mounted) return;
    if (bad != null) {
      AppToast.error(bad);
      return;
    }
    setState(() => _localDisplay = file);
  }

  void _removeLocalDisplay() => setState(() => _localDisplay = null);

  void _removePhoto() => setState(() {
        if (_localPhoto != null) {
          _localPhoto = null;
        } else {
          _remotePhotoUrl = null;
        }
      });

  Future<void> _pickType() async {
    FocusScope.of(context).unfocus();
    final picked = await TaxiVehicleTypePickerSheet.show(context, selectedId: _vehicleTypeId);
    if (picked == null || !mounted) return;
    setState(() {
      _vehicleTypeId = picked.id;
      _vehicleTypeName = picked.name;
      final d = picked.defaultSeats;
      if (_seats == null && d != null && TaxiOptionSets.seats.contains(d)) _seats = d;
      _unmark(_Ring.type);
      if (_seats != null) _unmark(_Ring.seats);
    });
  }

  bool _validateVehicle() {
    if (_vehicleTypeId == null) {
      AppToast.error('Pick a vehicle type');
      _mark(_Ring.type);
      return false;
    }
    if (_seats == null) {
      AppToast.error('Pick the number of seats');
      _mark(_Ring.seats);
      return false;
    }
    final plate = TaxiOptionSets.normalizePlate(_plateCtrl.text);
    if (plate.isEmpty) {
      AppToast.error('Enter your number plate');
      _mark(_Ring.plate);
      _plateFocus.requestFocus();
      return false;
    }
    if (!TaxiOptionSets.isValidPlate(plate)) {
      AppToast.error(TaxiOptionSets.plateHelp);
      _mark(_Ring.plate);
      _plateFocus.requestFocus();
      return false;
    }
    if (!_proofFrozen && !_hasPhoto) {
      AppToast.error('Add a photo that shows the plate');
      _mark(_Ring.photo);
      return false;
    }
    return true;
  }

  bool _validateContact() {
    if ((_dlTyped.isEmpty && !_hasSavedDl) || (_dob == null && !_hasSavedDob)) {
      setState(() => _showRequired = true);
    }
    final dlError = _dlError;
    if (dlError != null) {
      AppToast.error(dlError);
      _reveal(_dlKey);
      _dlFocus.requestFocus();
      return false;
    }
    final dobError = _dobError;
    if (dobError != null) {
      AppToast.error(dobError);
      return false;
    }
    if (!TaxiOptionSets.isValidMobile(_phone)) {
      AppToast.error('Enter a valid 10-digit mobile number');
      _mark(_Ring.phone);
      _phoneFocus.requestFocus();
      return false;
    }
    if (!TaxiOptionSets.isValidMobile(_effectiveWhatsApp)) {
      if (_same) setState(() => _same = false);
      AppToast.error('Enter a valid 10-digit WhatsApp number');
      _mark(_Ring.whatsApp);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _whatsAppFocus.requestFocus();
      });
      return false;
    }
    return true;
  }

  bool _validateBase() {
    if (pinnedOrLiveLocation == null) {
      AppToast.error('Waiting for GPS location. Please enable location and try again.');
      return false;
    }
    if (isResolvingDistrict) return false;
    if (selectedDistrictId == null) {
      if (lastResolveOnboardingClosed) {
        _showOnboardingClosed();
        return false;
      }
      AppToast.error('Pin your base inside a served district');
      _resolvedPin = null;
      _mark(_Ring.base);
      return false;
    }
    return true;
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    if (_step == 2 && step != 2) setLocationStepActive(false);
    setState(() => _step = step);
  }

  void _handleNext() {
    if (_blocked) return;
    if (_step == 0) {
      if (_validateVehicle()) _goTo(1);
      return;
    }
    if (_step == 1) {
      if (_validateContact()) _goTo(2);
      return;
    }
    if (_step == 2) {
      _save();
    } else if (_step == 3) {
      if (_routes.formOpen) {
        FocusScope.of(context).unfocus();
        _routes.saveForm();
      } else {
        _saveRoutes();
      }
    } else {
      _submit();
    }
  }

  Future<void> _recoverStep() async {
    await _ctrl.load();
    if (!mounted) return;
    final t = _ctrl.taxi.value;
    if (t == null || !t.step1Done) {
      _goTo(0);
    } else if (!t.routesDone) {
      _goTo(3);
    }
  }

  Future<void> _saveRoutes() async {
    if (_blocked) return;
    FocusScope.of(context).unfocus();
    if (!_routes.validate()) return;
    if (_routes.key != _savedRoutesKey) {
      _busy = true;
      try {
        final ok = await _ctrl.saveRoutes(_routes.payload(), quietLimit: true);
        if (!mounted) return;
        if (!ok) {
          final type = _ctrl.lastErrorType;
          if (type == TaxiSetupController.routeLimitType) {
            AppToast.info(TaxiSetupStrings.oneRouteOnly);
          } else if (type == 'TaxiStepLocked') {
            await _recoverStep();
          }
          return;
        }
        _routes.seed(_ctrl.taxi.value);
        _savedRoutesKey = _routes.key;
      } finally {
        _busy = false;
      }
    }
    if (mounted) _goTo(4);
  }

  Future<void> _submit() async {
    if (_blocked) return;
    FocusScope.of(context).unfocus();
    final rateError = _rate.check();
    if (rateError != null) {
      AppToast.error(rateError);
      return;
    }
    _busy = true;
    try {
      if (_rate.dirty || !_rate.stored) {
        final saved = await _ctrl.saveLocalRate(dayRate: _rate.dayRate, kmPerDay: _rate.kmPerDay);
        if (!mounted) return;
        if (!saved) {
          if (_ctrl.lastErrorType == 'TaxiStepLocked') await _recoverStep();
          return;
        }
        _rate.seed(_ctrl.taxi.value);
      }
      final t = _ctrl.taxi.value;
      if (t == null || !t.step1Done) {
        AppToast.warning(TaxiSetupStrings.completeVehicle);
        _goTo(0);
        return;
      }
      if (!t.identityDone) {
        AppToast.warning(TaxiSetupStrings.addLicenceFirst);
        _goTo(1);
        return;
      }
      if (!t.routesDone) {
        AppToast.warning(TaxiSetupStrings.addOneRoute);
        _goTo(3);
        return;
      }
      setState(() => _submitting = true);
      final ok = await _ctrl.submit();
      if (!mounted) return;
      setState(() => _submitting = false);
      void done() {
        final auth = Get.find<AuthController>();
        AppToast.success(TaxiSetupStrings.submittedToast);
        if (_ctrl.mainBelow) {
          Get.until((r) => r.settings.name == AppRoutes.main);
          auth.switchToTab(AppTabs.home);
          return;
        }
        Get.offAllNamed(AppRoutes.main);
        WidgetsBinding.instance.addPostFrameCallback((_) => auth.switchToTab(AppTabs.home));
      }
      if (!ok) {
        final type = _ctrl.lastErrorType;
        if (type == 'TaxiLocked') {
          await _ctrl.load();
          if (!mounted || !(_ctrl.taxi.value?.isPendingReview ?? false)) return;
          await Get.find<AuthController>().refreshProfile();
          if (mounted) done();
        } else if (type == 'OnboardingClosed') {
          _showOnboardingClosed();
        } else if (type == 'TaxiBaseOutsideDistrict') {
          _resolvedPin = null;
          _goTo(2);
        } else if (type == 'TaxiIdentityRequired') {
          _goTo(1);
        } else if (type == 'TaxiStepLocked') {
          await _recoverStep();
        }
        return;
      }
      done();
    } finally {
      _busy = false;
      if (mounted && _submitting) setState(() => _submitting = false);
    }
  }

  Map<String, dynamic> _basicBody(LatLng pin) => {
        'vehicleTypeId': _vehicleTypeId,
        'seats': _seats,
        'numberPlate': TaxiOptionSets.normalizePlate(_plateCtrl.text),
        'contactPhone': _phone,
        'whatsAppNumber': _effectiveWhatsApp,
        'latitude': pin.latitude,
        'longitude': pin.longitude,
        'districtId': selectedDistrictId,
        'cityId': resolvedCityId,
        'drivingLicenceNumber': _dlTyped.isEmpty ? null : _dlTyped,
        'dateOfBirth': _dob == null ? null : TaxiIdentityValidators.isoDate(_dob!),
      };

  Future<bool> _uploadPendingPhoto() async {
    while (true) {
      final file = _localPhoto;
      if (file == null) return true;
      setState(() => _isUploading = true);
      final res = await _ctrl.uploadPlatePhoto(file.path);
      if (!mounted) return false;
      setState(() => _isUploading = false);
      if (res != null) {
        setState(() {
          _localPhoto = null;
          _remotePhotoUrl = res.photoUrl ?? _remotePhotoUrl;
        });
        _uploadedStatus = res.status ?? _uploadedStatus;
        return true;
      }
      if (_ctrl.lastErrorType == TaxiSetupController.proofLockedType) {
        setState(() => _localPhoto = null);
        AppToast.info(TaxiPhotoStrings.plateLockedToast);
        return true;
      }
      final retry = await showTaxiOwnerDialog(
        context,
        art: ListingArt.camera,
        title: TaxiPhotoStrings.uploadFailedTitle,
        body: TaxiPhotoStrings.plateUploadFailedBody,
        cancelLabel: TaxiPhotoStrings.skip,
        confirmLabel: TaxiPhotoStrings.retry,
        barrierDismissible: false,
      );
      if (retry != true || !mounted) {
        if (mounted) _goTo(0);
        return false;
      }
    }
  }

  Future<bool> _uploadPendingDisplay() async {
    while (true) {
      final file = _localDisplay;
      if (file == null) return true;
      setState(() => _isUploading = true);
      final res = await _ctrl.uploadDisplayPhoto(file.path, reload: false);
      if (!mounted) return false;
      setState(() => _isUploading = false);
      if (res != null) {
        setState(() {
          _localDisplay = null;
          _remoteDisplayUrl = res.photoUrl ?? _remoteDisplayUrl;
        });
        return true;
      }
      final retry = await showTaxiOwnerDialog(
        context,
        art: ListingArt.camera,
        title: TaxiPhotoStrings.uploadFailedTitle,
        body: TaxiPhotoStrings.displayUploadFailedBody,
        cancelLabel: TaxiPhotoStrings.skip,
        confirmLabel: TaxiPhotoStrings.retry,
        barrierDismissible: false,
      );
      if (!mounted) return false;
      if (retry != true) {
        setState(() => _localDisplay = null);
        return true;
      }
    }
  }

  Future<void> _save() async {
    if (_blocked) return;
    if (!_validateVehicle()) {
      _goTo(0);
      return;
    }
    if (!_validateContact()) {
      _goTo(1);
      return;
    }
    if (!_validateBase()) return;
    if (widget.onboarding &&
        _localPhoto == null &&
        _localDisplay == null &&
        (_ctrl.taxi.value?.step1Done ?? false) &&
        _savedBasicKey == _basicBody(pinnedOrLiveLocation!).toString()) {
      _goTo(3);
      return;
    }
    final review = _wasApproved && _needsReview;
    if (review && !await TaxiReviewSheet.ask(context)) return;
    if (!mounted) return;
    final pin = pinnedOrLiveLocation!;
    _busy = true;
    try {
      final existing = _ctrl.taxi.value;
      // On an Approved taxi the upload flips it to review, which locks basic, so basic goes first there.
      if (_localPhoto != null && existing != null && !existing.isApproved) {
        if (!await _uploadPendingPhoto()) return;
      }
      final body = _basicBody(pin);
      final key = body.toString();
      if (_savedBasicKey != key) {
        final ok = await _ctrl.saveBasic(body);
        if (!mounted) return;
        if (!ok) {
          final type = _ctrl.lastErrorType;
          final message = _ctrl.lastErrorMessage;
          if (type == 'TaxiPlateTaken') {
            _goTo(0);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _plateFocus.requestFocus();
            });
          } else if (TaxiIdentityValidators.dobServerMessages.contains(message)) {
            _serverDobError = message;
            _goTo(1);
          } else if (TaxiIdentityValidators.dlServerMessages.contains(message) || type == 'TaxiIdentityRequired') {
            if (message != null && TaxiIdentityValidators.dlServerMessages.contains(message)) _serverDlError = message;
            _goTo(1);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _dlFocus.requestFocus();
            });
          } else if (type == 'OnboardingClosed') {
            _showOnboardingClosed();
          } else if (type == 'TaxiBaseOutsideDistrict') {
            _resolvedPin = null;
            setState(() {});
          }
          return;
        }
        _savedBasicKey = key;
      }
      if (_localPhoto != null && !await _uploadPendingPhoto()) return;
      if (_localDisplay != null && !await _uploadPendingDisplay()) return;

      setState(() => _isFinalizing = true);
      await _ctrl.load();
      if (!mounted) return;
      setState(() => _isFinalizing = false);
      final status = _ctrl.taxi.value?.status ?? _uploadedStatus;
      TaxiDriverDeps.refreshHome().ignore();
      if (widget.onboarding) {
        _routes.refreshDefaultFrom();
        _goTo(3);
        return;
      }
      Get.back();
      if (review && status == TaxiStatus.pendingReview) {
        AppToast.info('Sent back for review');
      } else {
        AppToast.success('Taxi details saved');
      }
    } finally {
      _busy = false;
      if (mounted && (_isUploading || _isFinalizing)) {
        setState(() {
          _isUploading = false;
          _isFinalizing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 2) _scheduleBaseResolve();
    final reverse = _step < _prevStep;
    _prevStep = _step;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Stack(children: [
        Scaffold(
          backgroundColor: ListingPalette.coral.page,
          body: KitStatusBar(
            lightIcons: false,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                _header(),
                StepProgressHeader(tone: _tone, labels: widget.onboarding ? TaxiSetupStrings.wizardLabels : TaxiSetupStrings.progressLabels, current: _step),
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
                    child: switch (_step) {
                      0 => _vehicleStep(),
                      1 => _contactStep(),
                      2 => _baseStep(),
                      3 => _scroll(3, [TaxiRoutesForm(controller: _routes, tone: _tone)]),
                      _ => _scroll(4, [TaxiLocalRateCard(controller: _rate, tone: _tone)]),
                    },
                  ),
                ),
              ]),
            ),
          ),
          bottomNavigationBar: _footer(),
        ),
        if (_isUploading) const SetupBusy(message: TaxiPhotoStrings.uploadingPhoto, tone: KitTone.taxi, art: ListingArt.camera),
        Obx(() => _ctrl.isSaving.value
            ? (_submitting
                ? const SetupBusy(message: TaxiSetupStrings.submitting, tone: KitTone.taxi, art: ListingArt.key)
                : const SetupBusy(message: 'Saving your taxi...', tone: KitTone.taxi, art: ListingArt.taxi))
            : const SizedBox.shrink()),
        if (_isFinalizing) const SetupBusy(message: 'Please wait...', tone: KitTone.taxi, art: ListingArt.taxi),
      ]),
    );
  }

  Widget _header() {
    if (!widget.onboarding) {
      return PageHeader3D(
        tone: _tone,
        title: TaxiSetupStrings.step1Title,
        subtitle: const [TaxiSetupStrings.step1Vehicle, TaxiSetupStrings.step1Licence, TaxiSetupStrings.step1Contact][_step],
        art: ListingArt.taxi,
        inlineTitle: true,
        onBack: _onBack,
      );
    }
    final menu = _step == 0 && !_ctrl.mainBelow;
    final t = _ctrl.taxi.value;
    return PageHeader3D(
      tone: _tone,
      title: switch (_step) { 3 => TaxiSetupStrings.routeTitleOne, 4 => TaxiSetupStrings.rateTitle, _ => TaxiSetupStrings.step1Title },
      subtitle: TaxiSetupStrings.wizardSteps[_step],
      art: _step == 3 ? ListingArt.compass : ListingArt.taxi,
      inlineTitle: true,
      onBack: menu ? null : _onBack,
      leadingIcon: menu ? Icons.more_vert_rounded : null,
      leadingSemantics: menu ? 'Menu' : null,
      onLeading: menu ? () => OnboardingExit.openMenu(context, isDraft: t == null || t.isDraft, hasDraft: t != null) : null,
    );
  }

  String get _primaryLabel {
    if (!widget.onboarding) return _step < 2 ? TaxiSetupStrings.next : TaxiSetupStrings.save;
    if (_step == 3 && _routes.formOpen) return TaxiSetupStrings.save;
    return _step < 4 ? TaxiSetupStrings.next : TaxiSetupStrings.submit;
  }

  Widget _footer() => ListenableBuilder(
        listenable: _routes,
        builder: (context, _) => Obx(() {
          final saving = _ctrl.isSaving.value;
          final disabled = saving || _isFinalizing || _isUploading || (_step == 2 && isResolvingDistrict);
          return FormFooter(
            tone: _tone,
            top: const ToastDock(),
            primaryLabel: _primaryLabel,
            onPrimary: disabled ? null : _handleNext,
            primaryLoading: saving || _isFinalizing,
            secondaryLabel: _step > 0 ? 'Back' : null,
            onSecondary: _blocked ? null : () => _goTo(_step - 1),
          );
        }),
      );

  Widget _section({required _Ring? ring, required String art, required String title, String? hint, bool required = true, required Widget child}) => FormSectionCard(
        key: ring == null ? null : _cardKeys[ring],
        tone: _tone,
        art: art,
        artSide: FormArtSide.right,
        title: title,
        requiredMark: required,
        hint: hint,
        child: child,
      );

  Widget _note(String text, {bool accent = false, double top = 6}) => Padding(
        padding: EdgeInsets.only(top: DS.gv(top), left: DS.s(4)),
        child: Text(text, style: accent ? Ink3D.text(11.5, FontWeight.w600, _tone.text, height: 1.4, letterSpacing: 0) : FieldMessage.helperStyle),
      );

  Widget _scroll(int key, List<Widget> children) => SingleChildScrollView(
        key: ValueKey(key),
        padding: EdgeInsets.only(bottom: DS.s(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _vehicleStep() => _scroll(0, [
        if (widget.onboarding && (_ctrl.taxi.value?.isRejected ?? false))
          FormNoteCard(
            tone: ListingTone.cC,
            art: ListingArt.warning,
            title: TaxiSetupStrings.notApproved,
            body: _ctrl.taxi.value?.rejectedReason,
            titleColor: Form3D.errorText,
          ),
        _section(
          ring: _Ring.type,
          art: TaxiOwnerArt.car,
          title: TaxiSetupStrings.vehicleType,
          child: PillPickerField(
            tone: _tone,
            value: _vehicleTypeId == null ? null : (_vehicleTypeName ?? _types.nameOf(_vehicleTypeId)),
            hint: 'Select',
            errorRing: _ring == _Ring.type,
            helperText: 'Pick from the list. Admin keeps the list updated.',
            onTap: _pickType,
          ),
        ),
        _section(
          ring: _Ring.seats,
          art: ListingArt.bus,
          title: 'Seats',
          child: SegmentPills(
            tone: _tone,
            labels: [for (final s in TaxiOptionSets.seats) TaxiOptionSets.seatsLabel(s)],
            selected: _seats == null ? null : TaxiOptionSets.seats.indexOf(_seats!),
            errorRing: _ring == _Ring.seats,
            onTap: (i) => setState(() {
              _seats = TaxiOptionSets.seats[i];
              _unmark(_Ring.seats);
            }),
          ),
        ),
        _section(
          ring: _Ring.plate,
          art: ListingArt.key,
          title: TaxiSetupStrings.plateNumber,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _plateCtrl,
              focusNode: _plateFocus,
              readOnly: _proofLocked,
              cursorColor: _tone.g2,
              inputFormatters: TaxiOptionSets.plateInputFormatters,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) {
                if (_ring == _Ring.plate) setState(() => _ring = null);
              },
              style: PillField.textStyle.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w600),
              decoration: _ring == _Ring.plate
                  ? PillField.decoration(tone: _tone, hint: 'e.g. UK 07 TA 1234').copyWith(error: const SizedBox.shrink())
                  : PillField.decoration(tone: _tone, hint: 'e.g. UK 07 TA 1234'),
            ),
            if (_proofLocked)
              _note(TaxiPhotoStrings.plateNumberLockedNote, accent: true)
            else if (_isApproved)
              _note(TaxiPhotoStrings.plateReviewNote, accent: true),
          ]),
        ),
        _section(
          ring: _Ring.photo,
          art: ListingArt.camera,
          title: TaxiPhotoStrings.plateTitle,
          hint: TaxiPhotoStrings.plateHint,
          child: _proofBlock(),
        ),
        _section(
          ring: null,
          art: ListingArt.taxi,
          title: TaxiPhotoStrings.displayTitle,
          hint: TaxiPhotoStrings.displayHint,
          required: false,
          child: _displayBlock(),
        ),
      ]);

  Widget _grid(List<Widget> tiles) => GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: DS.gh(10),
        mainAxisSpacing: DS.gv(10),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: tiles,
      );

  Widget _proofBlock() {
    final locked = _proofLocked;
    final frozen = _proofFrozen;
    final remote = _remotePhotoUrl;
    final tiles = <Widget>[
      if (frozen) ...[
        if (remote != null && remote.isNotEmpty)
          TaxiPlateTile(
            tone: _tone,
            label: locked ? TaxiPhotoStrings.verifiedBand : TaxiPhotoStrings.plateBand,
            verified: true,
            onRemove: null,
            photo: _photoTile(url: remote, memoryOnly: true),
          ),
      ] else ...[
        if (_hasPhoto)
          TaxiPlateTile(tone: _tone, label: TaxiPhotoStrings.plateBand, onRemove: _blocked ? null : _removePhoto, photo: _photoTile(local: _localPhoto, url: remote, memoryOnly: true)),
        TaxiAddPhotoTile(tone: _tone, label: TaxiPhotoStrings.add, error: _ring == _Ring.photo, onTap: _blocked ? null : _pickPhoto),
      ],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (tiles.isNotEmpty) _grid(tiles),
      locked ? _note(TaxiPhotoStrings.plateLockedNote, accent: true) : _note(TaxiSetupStrings.plateMustShow),
    ]);
  }

  Widget _displayBlock() {
    final local = _localDisplay;
    final remote = _remoteDisplayUrl;
    final has = local != null || remote != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _grid([
        if (has)
          TaxiPlateTile(
            tone: _tone,
            label: TaxiPhotoStrings.taxiBand,
            verified: local == null,
            onRemove: local != null && !_blocked ? _removeLocalDisplay : null,
            photo: _photoTile(local: local, url: remote),
          ),
        TaxiAddPhotoTile(tone: _tone, label: has ? TaxiPhotoStrings.change : TaxiPhotoStrings.add, onTap: _blocked ? null : _pickDisplay),
      ]),
      _note(TaxiPhotoStrings.displayNote),
    ]);
  }

  Widget _photoTile({File? local, String? url, bool memoryOnly = false}) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth.isFinite ? box.maxWidth : MediaQuery.sizeOf(context).width / 3;
        final decode = TaxiPlateDecode.width(w, MediaQuery.devicePixelRatioOf(context));
        final fallback = Container(color: _tone.tint, padding: DS.all(16), child: Image.asset(ListingArt.taxi));
        if (local != null) return Image.file(local, fit: BoxFit.cover, cacheWidth: decode, width: double.infinity, height: double.infinity);
        if (url == null || url.isEmpty) return fallback;
        if (memoryOnly) {
          return Image.network(
            url,
            cacheWidth: decode,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null ? child : ColoredBox(color: _tone.tint),
            errorBuilder: (_, _, _) => fallback,
          );
        }
        return CachedNetworkImage(
          imageUrl: url,
          memCacheWidth: decode,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, _) => ColoredBox(color: _tone.tint),
          errorWidget: (_, _, _) => fallback,
        );
      });

  Future<void> _pickDob() async {
    FocusScope.of(context).unfocus();
    final today = TaxiIdentityValidators.todayIst();
    final last = TaxiIdentityValidators.yearsBefore(today, TaxiIdentityValidators.minAgeYears);
    final first = TaxiIdentityValidators.yearsBefore(today, TaxiIdentityValidators.maxAgeYears);
    var initial = _dob ?? TaxiIdentityValidators.yearsBefore(today, 25);
    if (initial.isAfter(last)) initial = last;
    if (initial.isBefore(first)) initial = first;
    final picked = await TemplateCalendarPopup.pickDate(
      context,
      initial: initial,
      first: first,
      last: last,
      label: 'Date of birth',
      tone: KitTone.taxi,
    );
    if (picked != null && mounted) {
      setState(() {
        _dob = TaxiIdentityValidators.dateOnly(picked);
        _serverDobError = null;
        if (_serverDlError == TaxiIdentityValidators.dlYearMessage) _serverDlError = null;
      });
    }
  }

  Widget _contactStep() {
    final savedDl = _hasSavedDl && _dlCtrl.text.isEmpty;
    final dlError = _dlError;
    return _scroll(1, [
      FormSectionCard(
        key: _dlKey,
        tone: _tone,
        art: ListingArt.clipboard,
        artSide: FormArtSide.right,
        title: TaxiSetupStrings.licenceNumber,
        requiredMark: true,
        hint: TaxiSetupStrings.adminOnly,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _dlCtrl,
            focusNode: _dlFocus,
            cursorColor: _tone.g2,
            inputFormatters: TaxiIdentityValidators.dlInputFormatters,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() => _serverDlError = null),
            style: PillField.textStyle.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w600),
            decoration: PillField.decoration(
              tone: _tone,
              hint: 'UK07 20150012345',
              errorText: dlError,
              suffix: savedDl ? Text('Saved', style: Ink3D.text(12, FontWeight.w700, _tone.text, letterSpacing: 0)) : null,
            ),
          ),
          if (savedDl && dlError == null) _note(TaxiIdentityValidators.savedHelp, accent: true),
          _note(TaxiIdentityValidators.dlHelp),
          _note(TaxiIdentityValidators.dlOldHelp, top: 0),
          if (_isApproved) _note('Changing the licence or date of birth sends your taxi back to review.', accent: true),
        ]),
      ),
      FormSectionCard(
        tone: _tone,
        art: ListingArt.calendar,
        artSide: FormArtSide.right,
        title: TaxiSetupStrings.dateOfBirth,
        requiredMark: true,
        hint: TaxiSetupStrings.keptForChecks,
        child: PillPickerField(
          tone: _tone,
          value: _dob != null
              ? TaxiIdentityValidators.displayDate(_dob!)
              : _hasSavedDob
                  ? 'Saved · Tap to change'
                  : null,
          hint: 'Select date',
          errorText: _dobError,
          onTap: _pickDob,
        ),
      ),
      _section(
        ring: _Ring.phone,
        art: ListingArt.speechBalloon,
        title: 'Contact',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PillField(
            tone: _tone,
            label: TaxiSetupStrings.phone,
            controller: _phoneCtrl,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            inputFormatters: TaxiOptionSets.phoneInputFormatters,
            prefixText: '+91',
            hint: '10-digit mobile',
            errorRing: _ring == _Ring.phone,
            onChanged: (_) {
              if (_ring == _Ring.phone) setState(() => _ring = null);
            },
          ),
          PillField(
            key: _cardKeys[_Ring.whatsApp],
            tone: _tone,
            label: 'WhatsApp Number',
            firstLabel: false,
            fieldKey: ValueKey(_same),
            controller: _same ? _phoneCtrl : _whatsAppCtrl,
            focusNode: _same ? null : _whatsAppFocus,
            enabled: !_same,
            keyboardType: TextInputType.phone,
            inputFormatters: TaxiOptionSets.phoneInputFormatters,
            prefixText: '+91',
            hint: '10-digit WhatsApp',
            errorRing: _ring == _Ring.whatsApp,
            onChanged: (_) {
              if (_ring == _Ring.whatsApp) setState(() => _ring = null);
            },
          ),
          Gap.v(8),
          ToggleRow(
            tone: _tone,
            label: 'Same as my login number',
            value: _same,
            onChanged: (v) => setState(() {
              _same = v;
              if (!v && _whatsAppCtrl.text.isEmpty) _whatsAppCtrl.text = _phone;
            }),
          ),
        ]),
      ),
      FormNoteCard(
        tone: _tone,
        art: ListingArt.clipboard,
        body: 'Travellers call or message you on these numbers. Bakhli takes no booking and no payment.',
      ),
    ]);
  }

  Widget _baseStep() {
    final resolving = isResolvingDistrict;
    final district = resolvedDistrictName;
    final city = resolvedCityName;
    final value = district != null
        ? [city, district].where((e) => e != null && e.isNotEmpty).toSet().join(', ')
        : resolving
            ? 'Detecting…'
            : 'Pin inside a served district';
    final ring = _ring == _Ring.base && district == null && !resolving;
    // Scrolls only when the content is taller than the screen, so on most phones map drags still reach the map.
    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: EdgeInsets.only(bottom: DS.s(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        locationStepWidget(),
        FormSectionCard(
          key: _cardKeys[_Ring.base],
          tone: _tone,
          art: ListingArt.roundPushpin,
          artSide: FormArtSide.right,
          title: TaxiSetupStrings.base,
          hint: TaxiSetupStrings.pinNear,
          child: Container(
            constraints: BoxConstraints(minHeight: DS.s(52)),
            padding: DS.insets(l: 18, t: 8, r: 18, b: 8),
            decoration: BoxDecoration(
              color: ring ? Form3D.fillError : Form3D.fill,
              borderRadius: DS.circular(26),
              border: Border.all(color: ring ? Form3D.error : Colors.transparent, width: 1.5),
            ),
            child: Row(children: [
              Expanded(
                child: Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(15, FontWeight.w400, district != null ? Ink3D.body : Form3D.hint, letterSpacing: 0)),
              ),
              Gap.h(8),
              if (resolving)
                SizedBox(width: DS.s(16), height: DS.s(16), child: CircularProgressIndicator(strokeWidth: DS.s(2.5), color: _tone.g2))
              else if (district != null)
                Image.asset(ListingArt.pushpin, width: DS.s(26), height: DS.s(26)),
            ]),
          ),
        ),
      ]),
    );
  }
}
