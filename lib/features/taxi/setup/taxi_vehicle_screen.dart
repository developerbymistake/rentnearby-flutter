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
import '../../../design/extra/ext_taxi_owner.dart';
import '../../../design/extra/taxi_setup_kit.dart';
import '../../../models/city_model.dart';
import '../../../screens/add_listing_location_mixin.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/onboarding_closed_dialog.dart';
import '../taxi_option_sets.dart';
import '../taxi_vehicle_types_controller.dart';
import 'taxi_identity_validators.dart';
import 'taxi_setup_controller.dart';
import 'taxi_vehicle_type_picker_sheet.dart';

class TaxiVehicleScreen extends StatefulWidget {
  const TaxiVehicleScreen({super.key});
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
  final _picker = ImagePicker();
  final _cardKeys = {for (final r in _Ring.values) r: GlobalKey()};
  final _dlKey = GlobalKey();

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
    final source = await Sheet3D.show<ImageSource>(
      context,
      builder: (sheetCtx) => Sheet3D(
        tone: _tone,
        art: ListingArt.camera,
        title: 'Add Photo',
        centerTitle: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetOptionCard(
            tone: _tone,
            art: ListingArt.camera,
            title: 'Take Photo',
            subtitle: 'Use camera to capture now',
            onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
          ),
          SheetOptionCard(
            tone: ListingTone.indigo,
            art: ListingArt.sunrise,
            title: 'Choose from Gallery',
            subtitle: 'Pick an existing photo',
            onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
          ),
        ]),
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
    if (picked != null && mounted) {
      setState(() {
        _localPhoto = File(picked.path);
        _unmark(_Ring.photo);
      });
    }
  }

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
    if (!_hasPhoto) {
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
      final retry = await showTaxiOwnerDialog(
        context,
        art: ListingArt.camera,
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
          backgroundColor: ListingPalette.coral.page,
          body: KitStatusBar(
            lightIcons: false,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                PageHeader3D(
                  tone: _tone,
                  title: const ['Vehicle', 'Driver', 'Base'][_step],
                  art: ListingArt.taxi,
                  inlineTitle: true,
                  onBack: _onBack,
                ),
                StepProgressHeader(tone: _tone, labels: const ['Vehicle', 'Driver', 'Base'], current: _step),
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
              ]),
            ),
          ),
          bottomNavigationBar: _footer(),
        ),
        if (_isUploading) const SetupBusy(message: 'Uploading photo', tone: KitTone.taxi, art: ListingArt.camera),
        Obx(() => _ctrl.isSaving.value
            ? const SetupBusy(message: 'Saving your taxi...', tone: KitTone.taxi, art: ListingArt.taxi)
            : const SizedBox.shrink()),
        if (_isFinalizing) const SetupBusy(message: 'Please wait...', tone: KitTone.taxi, art: ListingArt.taxi),
      ]),
    );
  }

  Widget _footer() => Obx(() {
        final saving = _ctrl.isSaving.value;
        final disabled = saving || _isFinalizing || _isUploading || (_step == 2 && isResolvingDistrict);
        return FormFooter(
          tone: _tone,
          top: const ToastDock(),
          primaryLabel: _step == 0
              ? 'Next: Driver'
              : _step == 1
                  ? 'Next: Base'
                  : 'Save',
          onPrimary: disabled ? null : _handleNext,
          primaryLoading: saving || _isFinalizing,
          secondaryLabel: _step > 0 ? 'Back' : null,
          onSecondary: _blocked ? null : () => _goTo(_step - 1),
        );
      });

  Widget _section({required _Ring? ring, required String art, required String title, String? hint, required Widget child}) => FormSectionCard(
        key: ring == null ? null : _cardKeys[ring],
        tone: _tone,
        art: art,
        artSide: FormArtSide.right,
        title: title,
        requiredMark: true,
        hint: hint,
        child: child,
      );

  Widget _note(String text, {bool accent = false, double top = 6}) => Padding(
        padding: EdgeInsets.only(top: top, left: 4),
        child: Text(text, style: accent ? Ink3D.text(11.5, FontWeight.w600, _tone.text, height: 1.4, letterSpacing: 0) : FieldMessage.helperStyle),
      );

  Widget _scroll(int key, List<Widget> children) => SingleChildScrollView(
        key: ValueKey(key),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _vehicleStep() => _scroll(0, [
        _section(
          ring: _Ring.type,
          art: TaxiOwnerArt.car,
          title: 'Vehicle Type',
          child: PillPickerField(
            tone: _tone,
            value: _vehicleTypeId == null ? null : (_vehicleTypeName ?? _types.nameOf(_vehicleTypeId)),
            hint: 'Select',
            leadingArt: ListingArt.taxi,
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
          title: 'Number Plate',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _plateCtrl,
              focusNode: _plateFocus,
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
            if (_isApproved) _note('Changing the plate or photo sends your taxi back to review.', accent: true),
          ]),
        ),
        _section(
          ring: _Ring.photo,
          art: ListingArt.camera,
          title: 'Vehicle Photo',
          hint: 'Number plate must be clearly visible in the photo',
          child: _photoBlock(),
        ),
      ]);

  Widget _photoBlock() => GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (_hasPhoto) _plateTile(),
          TaxiAddPhotoTile(tone: _tone, error: _ring == _Ring.photo, onTap: _blocked ? null : _pickPhoto),
        ],
      );

  Widget _plateTile() {
    final local = _localPhoto;
    return TaxiPlateTile(
      tone: _tone,
      onRemove: _blocked ? null : _removePhoto,
      photo: local != null
          ? Image.file(local, fit: BoxFit.cover)
          : CachedNetworkImage(
              imageUrl: _remotePhotoUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => ColoredBox(color: _tone.tint),
              errorWidget: (_, _, _) => Container(
                color: _tone.tint,
                padding: const EdgeInsets.all(16),
                child: Image.asset(ListingArt.taxi),
              ),
            ),
    );
  }

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
        title: 'Driving Licence',
        requiredMark: true,
        hint: 'Only Bakhli admin sees this',
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
        title: 'Date of Birth',
        requiredMark: true,
        child: PillPickerField(
          tone: _tone,
          value: _dob != null
              ? TaxiIdentityValidators.displayDate(_dob!)
              : _hasSavedDob
                  ? 'Saved · Tap to change'
                  : null,
          hint: 'Select date',
          leadingArt: ListingArt.calendar,
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
            label: 'Phone Number',
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
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        locationStepWidget(),
        FormSectionCard(
          key: _cardKeys[_Ring.base],
          tone: _tone,
          art: ListingArt.roundPushpin,
          artSide: FormArtSide.right,
          title: 'District and City',
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.fromLTRB(4, 8, 18, 8),
            decoration: BoxDecoration(
              color: ring ? Form3D.fillError : Form3D.fill,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: ring ? Form3D.error : Colors.transparent, width: 1.5),
            ),
            child: Row(children: [
              PillField.art(ListingArt.roundPushpin),
              Expanded(
                child: Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(15, FontWeight.w400, district != null ? Ink3D.body : Form3D.hint, letterSpacing: 0)),
              ),
              const SizedBox(width: 8),
              if (resolving)
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.5, color: _tone.g2))
              else if (district != null)
                Image.asset(ListingArt.pushpin, width: 26, height: 26),
            ]),
          ),
        ),
      ]),
    );
  }
}
