import 'dart:io';
import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:permission_handler/permission_handler.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../design/extra/taxi_setup_kit.dart';
import '../../../design/extra/trip_plan_look.dart';
import '../../../models/city_model.dart';
import '../../../screens/add_listing_location_mixin.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/onboarding_closed_dialog.dart';
import '../taxi_option_sets.dart';
import '../taxi_vehicle_types_controller.dart';
import 'taxi_identity_validators.dart';
import 'taxi_setup_controller.dart';
import 'taxi_vehicle_type_picker_sheet.dart';

import 'package:bakhli/design/tokens/shadow_tokens.dart';
class TaxiVehicleScreen extends StatefulWidget {
  const TaxiVehicleScreen({super.key});
  @override
  State<TaxiVehicleScreen> createState() => _TaxiVehicleScreenState();
}

class _TaxiVehicleScreenState extends State<TaxiVehicleScreen> with AddListingLocationMixin<TaxiVehicleScreen> {
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
  final _picker = ImagePicker();

  String? _vehicleTypeId;
  String? _vehicleTypeName;
  int? _seats;
  String? _remotePhotoUrl;
  File? _localPhoto;
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
    accentColor: FitnessAppTheme.nearlyDarkBlue,
    addressSpinnerColor: FitnessAppTheme.nearlyDarkBlue,
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
    _initPhone = _phoneCtrl.text;
    _initWhatsApp = _effectiveWhatsApp;
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
  late final bool _wasApproved;

  bool get _hasChanges {
    if (_vehicleTypeId != _initTypeId || _seats != _initSeats) return true;
    if (TaxiOptionSets.normalizePlate(_plateCtrl.text) != _initPlate) return true;
    if (_localPhoto != null || _remotePhotoUrl != _initPhotoUrl) return true;
    if (_phone != _initPhone || _effectiveWhatsApp != _initWhatsApp) return true;
    if (_dlTyped.isNotEmpty || _dob != null) return true;
    final pin = selectedLocation, init = _initPin;
    if (init == null) return _step == 2;
    return pin != null &&
        ((pin.latitude - init.latitude).abs() > 1e-6 || (pin.longitude - init.longitude).abs() > 1e-6);
  }

  bool get _blocked => _isUploading || _isFinalizing || _busy || _ctrl.isSaving.value;

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
    final canCorrect = (t == null || t.isDraft) && (Get.find<AuthController>().user.value?.canCorrectRole ?? false);
    final percent = t?.percent ?? 0;
    OnboardingClosedDialog.show(context,
        onChangeRole: canCorrect
            ? () => Get.toNamed(AppRoutes.roleSelect, arguments: {'correction': true, 'percent': percent})
            : null);
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
    if (_hasChanges) {
      _confirmDiscard();
    } else {
      Get.back();
    }
  }

  Future<void> _confirmDiscard() async {
    final ok = await showTaxiDialog(
      context,
      title: 'Discard changes?',
      body: 'Unsaved changes will be lost.',
      cancelLabel: 'Keep Editing',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (ok == true) Get.back();
  }

  Future<void> _showPermissionDeniedDialog(String type) async {
    final ok = await showTaxiDialog(
      context,
      title: '$type Permission Required',
      body: 'Please enable $type access in your device Settings to add photos.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Open Settings',
    );
    if (ok == true) openAppSettings();
  }

  Future<void> _pickPhoto() async {
    final source = await SetupKit.sheet<ImageSource>(
      context,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SetupKit.grabber(),
            Text('Add Photo', style: TripKit.text(18, weight: FontWeight.w700).copyWith(letterSpacing: 0.27)),
            const SizedBox(height: 8),
            _sourceTile(sheetCtx, TravelIcon.photo, null, 'Take Photo', 'Use camera to capture now', ImageSource.camera),
            _sourceTile(sheetCtx, null, Icons.photo_library_outlined, 'Choose from Gallery', 'Pick an existing photo',
                ImageSource.gallery),
            const SizedBox(height: 8),
          ]),
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
    final picked = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
    if (picked != null && mounted) setState(() => _localPhoto = File(picked.path));
  }

  Widget _sourceTile(
          BuildContext sheetCtx, String? asset, IconData? icon, String title, String subtitle, ImageSource source) =>
      ListTile(
        leading: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: PickKit.taxiTint, shape: BoxShape.circle),
          child: asset != null
              ? Image.asset(asset)
              : Icon(icon, color: FitnessAppTheme.nearlyDarkBlue, size: 22),
        ),
        title: Text(title, style: TripKit.text(14)),
        subtitle: Text(subtitle, style: TripKit.text(12, color: FitnessAppTheme.lightText)),
        onTap: () => Navigator.pop(sheetCtx, source),
      );

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
    });
  }

  bool _validateVehicle() {
    if (_vehicleTypeId == null) {
      AppToast.error('Pick a vehicle type');
      return false;
    }
    if (_seats == null) {
      AppToast.error('Pick the number of seats');
      return false;
    }
    final plate = TaxiOptionSets.normalizePlate(_plateCtrl.text);
    if (plate.isEmpty) {
      AppToast.error('Enter your number plate');
      _plateFocus.requestFocus();
      return false;
    }
    if (!TaxiOptionSets.isValidPlate(plate)) {
      AppToast.error(TaxiOptionSets.plateHelp);
      _plateFocus.requestFocus();
      return false;
    }
    if (!_hasPhoto) {
      AppToast.error('Add a photo that shows the plate');
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
      _phoneFocus.requestFocus();
      return false;
    }
    if (!TaxiOptionSets.isValidMobile(_effectiveWhatsApp)) {
      if (_same) setState(() => _same = false);
      AppToast.error('Enter a valid 10-digit WhatsApp number');
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
      setState(() {});
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
    _save();
  }

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
      final retry = await showTaxiDialog(
        context,
        title: 'Upload Failed',
        body: 'The plate photo could not be uploaded. Retry?',
        cancelLabel: 'Skip',
        confirmLabel: 'Retry',
        barrierDismissible: false,
      );
      if (retry != true || !mounted) {
        if (mounted) _goTo(0);
        return false;
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
    final pin = pinnedOrLiveLocation!;
    _busy = true;
    try {
      final existing = _ctrl.taxi.value;
      // On an Approved taxi the upload flips it to review, which locks basic, so basic goes first there.
      if (_localPhoto != null && existing != null && !existing.isApproved) {
        if (!await _uploadPendingPhoto()) return;
      }
      final body = <String, dynamic>{
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

      setState(() => _isFinalizing = true);
      await _ctrl.load();
      if (!mounted) return;
      setState(() => _isFinalizing = false);
      final status = _ctrl.taxi.value?.status ?? _uploadedStatus;
      Get.back();
      if (_wasApproved && status == TaxiStatus.pendingReview) {
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
          backgroundColor: FitnessAppTheme.background,
          body: Column(children: [
            ModuleHeader(
              title: const ['Vehicle', 'Driver', 'Base'][_step],
              tone: KitTone.taxi,
              onBack: _onBack,
              leadingAsset: TravelIcon.taxi,
            ),
            Container(
              decoration: BoxDecoration(
                color: FitnessAppTheme.white,
                boxShadow: [
                  ShadowTokens.tint(FitnessAppTheme.grey, ShadowSpec.restTight),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(children: [
                TaxiStepDot(index: 0, step: _step, label: 'Vehicle'),
                _line(1),
                TaxiStepDot(index: 1, step: _step, label: 'Driver'),
                _line(2),
                TaxiStepDot(index: 2, step: _step, label: 'Base'),
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
                    ? _vehicleStep()
                    : _step == 1
                        ? _contactStep()
                        : _baseStep(),
              ),
            ),
            _footer(),
          ]),
        ),
        if (_isUploading) const SetupBusy(message: 'Uploading photo'),
        Obx(() => _ctrl.isSaving.value ? const SetupBusy(message: 'Saving your taxi...') : const SizedBox.shrink()),
        if (_isFinalizing) const SetupBusy(message: 'Please wait...'),
      ]),
    );
  }

  Widget _line(int reachedAt) => Expanded(
        child: Container(
          height: 2,
          alignment: Alignment.centerLeft,
          color: FitnessAppTheme.spacer,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 2,
            width: _step >= reachedAt ? 400 : 0,
            color: FitnessAppTheme.nearlyDarkBlue,
          ),
        ),
      );

  Widget _footer() => SetupFooter(
        child: Row(children: [
          if (_step > 0) ...[
            Expanded(
              child: SetupOutlineButton(label: 'Back', onPressed: _blocked ? null : () => _goTo(_step - 1)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: Obx(() {
              final saving = _ctrl.isSaving.value;
              final disabled = saving || _isFinalizing || _isUploading || (_step == 2 && isResolvingDistrict);
              return PickButton(
                onPressed: disabled ? null : _handleNext,
                isLoading: saving || _isFinalizing,
                label: _step == 0
                    ? 'Next: Driver'
                    : _step == 1
                        ? 'Next: Base'
                        : 'Save',
                gradient: PickKit.taxiGradient,
                shadowColor: PickKit.taxiDark,
              );
            }),
          ),
        ]),
      );

  Widget _sectionCard({required String title, String? hint, required Widget child}) => SetupCard(
        title: title,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hint != null) ...[
            Text(hint, style: TripKit.text(12, weight: FontWeight.w600, color: TripLook.warning)),
            const SizedBox(height: 10),
          ],
          child,
        ]),
      );

  InputDecoration _inputDec(String hint, {String? prefix}) => SetupKit.input(hint: hint, prefix: prefix);

  Widget _note(String text, {bool accent = false}) =>
      Text(text, style: TripKit.text(12, color: accent ? FitnessAppTheme.nearlyDarkBlue : FitnessAppTheme.lightText));

  Widget _selectRow({
    required String asset,
    required String text,
    required bool placeholder,
    required VoidCallback onTap,
    bool error = false,
  }) =>
      Material(
        color: FitnessAppTheme.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: error ? Border.all(color: TripLook.error, width: 1.5) : null,
            ),
            child: Row(children: [
              Image.asset(asset, width: 24, height: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TripKit.text(14, color: placeholder ? FitnessAppTheme.deactivatedText : FitnessAppTheme.darkerText)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: FitnessAppTheme.nearlyDarkBlue),
            ]),
          ),
        ),
      );

  Widget _vehicleStep() => SingleChildScrollView(
        key: const ValueKey(0),
        padding: const EdgeInsets.all(16),
        child: TemplateStagger(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionCard(
            title: 'Vehicle Type *',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _selectRow(
                asset: TravelIcon.taxi,
                text: _vehicleTypeName ?? _types.nameOf(_vehicleTypeId) ?? 'Select',
                placeholder: _vehicleTypeId == null,
                onTap: _pickType,
              ),
              const SizedBox(height: 6),
              _note('Pick from the list. Admin keeps the list updated.'),
            ]),
          ),
          _sectionCard(
            title: 'Seats *',
            child: Row(children: [
              for (var i = 0; i < TaxiOptionSets.seats.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: PickChip(
                    label: TaxiOptionSets.seatsLabel(TaxiOptionSets.seats[i]),
                    selected: _seats == TaxiOptionSets.seats[i],
                    activeColor: PickKit.taxi,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    onTap: () => setState(() => _seats = TaxiOptionSets.seats[i]),
                  ),
                ),
              ],
            ]),
          ),
          _sectionCard(
            title: 'Number Plate *',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(
                controller: _plateCtrl,
                focusNode: _plateFocus,
                cursorColor: FitnessAppTheme.nearlyDarkBlue,
                inputFormatters: TaxiOptionSets.plateInputFormatters,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                style: SetupKit.fieldText().copyWith(letterSpacing: 1),
                decoration: _inputDec('e.g. UK 07 TA 1234'),
              ),
              if (_isApproved) ...[
                const SizedBox(height: 6),
                _note('Changing the plate or photo sends your taxi back to review.', accent: true),
              ],
            ]),
          ),
          _sectionCard(
            title: 'Vehicle Photo *',
            hint: 'Number plate must be clearly visible in the photo',
            child: _photoBlock(),
          ),
        ]),
      );

  Widget _photoBlock() => GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (_hasPhoto) _plateTile(),
          _addPhotoTile(),
        ],
      );

  Widget _plateTile() {
    final local = _localPhoto;
    return Stack(children: [
      Positioned.fill(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: local != null
              ? Image.file(local, fit: BoxFit.cover)
              : CachedNetworkImage(
                  imageUrl: _remotePhotoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: FitnessAppTheme.background),
                  errorWidget: (_, _, _) => Container(
                    color: FitnessAppTheme.background,
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(TravelIcon.taxi),
                  ),
                ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: PickKit.taxi.withValues(alpha: Alpha.high),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: Text('Plate',
              textAlign: TextAlign.center,
              style: TripKit.text(10, weight: FontWeight.w600, color: FitnessAppTheme.white)),
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: GestureDetector(
          onTap: _blocked ? null : _removePhoto,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: FitnessAppTheme.white, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, color: TripLook.error, size: 16),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _addPhotoTile() => Material(
        color: PickKit.taxiTint,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _blocked ? null : _pickPhoto,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PickKit.taxi.withValues(alpha: Alpha.half), width: 1.5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Image.asset(TravelIcon.photo, width: 28, height: 28),
              const SizedBox(height: 4),
              Text('Add',
                  maxLines: 1, style: TripKit.text(11, weight: FontWeight.w600, color: FitnessAppTheme.nearlyDarkBlue)),
            ]),
          ),
        ),
      );

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: SetupKit.label()),
      );

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

  Widget _contactStep() => SingleChildScrollView(
        key: const ValueKey(1),
        padding: const EdgeInsets.all(16),
        child: TemplateStagger(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionCard(
            title: 'Driving Licence *',
            hint: 'Only Bakhli admin sees this',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(
                controller: _dlCtrl,
                focusNode: _dlFocus,
                cursorColor: FitnessAppTheme.nearlyDarkBlue,
                inputFormatters: TaxiIdentityValidators.dlInputFormatters,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() => _serverDlError = null),
                style: SetupKit.fieldText().copyWith(letterSpacing: 1),
                decoration: SetupKit.input(
                  hint: 'UK07 20150012345',
                  error: _dlError,
                  errorMaxLines: 2,
                  suffix: _hasSavedDl && _dlCtrl.text.isEmpty
                      ? Text('Saved', style: TripKit.text(12, color: FitnessAppTheme.nearlyDarkBlue))
                      : null,
                ),
              ),
              if (_hasSavedDl && _dlCtrl.text.isEmpty && _dlError == null) ...[
                const SizedBox(height: 6),
                _note(TaxiIdentityValidators.savedHelp, accent: true),
              ],
              const SizedBox(height: 6),
              _note(TaxiIdentityValidators.dlHelp),
              _note(TaxiIdentityValidators.dlOldHelp),
              if (_isApproved) ...[
                const SizedBox(height: 6),
                _note('Changing the licence or date of birth sends your taxi back to review.', accent: true),
              ],
            ]),
          ),
          _sectionCard(
            title: 'Date of Birth *',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _selectRow(
                asset: TravelIcon.calendar,
                text: _dob != null
                    ? TaxiIdentityValidators.displayDate(_dob!)
                    : _hasSavedDob
                        ? 'Saved · Tap to change'
                        : 'Select date',
                placeholder: _dob == null && !_hasSavedDob,
                error: _dobError != null,
                onTap: _pickDob,
              ),
              if (_dobError != null) ...[
                const SizedBox(height: 6),
                Text(_dobError!, style: TripKit.text(12, color: TripLook.error)),
              ],
            ]),
          ),
          _sectionCard(
            title: 'Contact *',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _fieldLabel('Phone Number'),
              TextField(
                controller: _phoneCtrl,
                focusNode: _phoneFocus,
                cursorColor: FitnessAppTheme.nearlyDarkBlue,
                keyboardType: TextInputType.phone,
                inputFormatters: TaxiOptionSets.phoneInputFormatters,
                style: SetupKit.fieldText(),
                decoration: _inputDec('10-digit mobile', prefix: '+91 '),
              ),
              const SizedBox(height: 12),
              _fieldLabel('WhatsApp Number'),
              TextField(
                key: ValueKey(_same),
                controller: _same ? _phoneCtrl : _whatsAppCtrl,
                focusNode: _same ? null : _whatsAppFocus,
                enabled: !_same,
                cursorColor: FitnessAppTheme.nearlyDarkBlue,
                keyboardType: TextInputType.phone,
                inputFormatters: TaxiOptionSets.phoneInputFormatters,
                style: SetupKit.fieldText().copyWith(color: _same ? FitnessAppTheme.grey : FitnessAppTheme.darkerText),
                decoration: _inputDec('10-digit WhatsApp', prefix: '+91 '),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text('Same as my login number', style: TripKit.text(13, weight: FontWeight.w600))),
                const SizedBox(width: 8),
                SetupSwitch(
                  value: _same,
                  onChanged: (v) => setState(() {
                    _same = v;
                    if (!v && _whatsAppCtrl.text.isEmpty) _whatsAppCtrl.text = _phone;
                  }),
                ),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FitnessAppTheme.white,
              borderRadius: PickKit.cardRadius,
              boxShadow: PickKit.greyShadow(),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Image.asset(TravelIcon.note, width: 22, height: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Travellers call or message you on these numbers. Bakhli takes no booking and no payment.',
                    style: TripKit.text(11, color: FitnessAppTheme.lightText)),
              ),
            ]),
          ),
        ]),
      );

  Widget _baseStep() {
    final resolving = isResolvingDistrict;
    final district = resolvedDistrictName;
    final city = resolvedCityName;
    final value = district != null
        ? [city, district].where((e) => e != null && e.isNotEmpty).toSet().join(', ')
        : resolving
            ? 'Detecting…'
            : 'Pin inside a served district';
    // Scrolls only when the content is taller than the screen, so on most phones map drags still reach the map.
    return SingleChildScrollView(
      key: const ValueKey(2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        locationStepWidget(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: TemplateEntranceOnce(
            child: _sectionCard(
              title: 'District and City',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: const BoxConstraints(minHeight: 50),
                decoration: BoxDecoration(color: FitnessAppTheme.background, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Image.asset(TravelIcon.place, width: 24, height: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TripKit.text(14,
                            color: district != null ? FitnessAppTheme.darkerText : FitnessAppTheme.deactivatedText)),
                  ),
                  const SizedBox(width: 8),
                  if (resolving)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: FitnessAppTheme.nearlyDarkBlue),
                    )
                  else if (district != null)
                    Image.asset(TravelIcon.pin, width: 20, height: 20),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
