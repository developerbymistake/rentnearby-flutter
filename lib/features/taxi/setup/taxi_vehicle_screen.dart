import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:permission_handler/permission_handler.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../controllers/auth_controller.dart';
import '../../../screens/add_listing_location_mixin.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../../../widgets/gradient_button.dart';
import '../../stay/setup/stay_option_grid.dart';
import '../taxi_option_sets.dart';
import '../taxi_vehicle_types_controller.dart';
import 'taxi_setup_controller.dart';
import 'taxi_vehicle_type_picker_sheet.dart';

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
  final _loginCtrl = TextEditingController();
  final _picker = ImagePicker();

  String? _vehicleTypeId;
  String? _vehicleTypeName;
  int? _seats;
  String? _remotePhotoUrl;
  File? _localPhoto;
  bool _same = true;
  int _step = 0;
  bool _isUploading = false;
  bool _isFinalizing = false;
  bool _busy = false;
  LatLng? _resolvedPin;
  String? _savedBasicKey;

  String? _initTypeId;
  int? _initSeats;
  String _initPlate = '';
  String? _initPhotoUrl;
  String _initPhone = '';
  String _initWhatsApp = '';
  LatLng? _initPin;

  static const _locationStyle = LocationStepStyle(
    circleColorHex: '#0D9488',
    userDotColorHex: '#1E88E5',
    accentColor: TaxiColors.accent,
    addressSpinnerColor: TaxiColors.accent,
    addressPrefixIcon: Iconsax.car,
    pinStepTitle: 'Pin Your Base *',
    pinHintNoun: 'taxi',
  );

  @override
  void initState() {
    super.initState();
    initLocationTracking(style: _locationStyle, onLocationStale: _handleLocationStale);
    _types.ensureLoaded();
    final t = _ctrl.taxi.value;
    _wasApproved = t?.isApproved ?? false;
    final loginPhone = TaxiOptionSets.tenDigits(Get.find<AuthController>().user.value?.phoneNumber ?? '');
    _loginCtrl.text = loginPhone;
    if (t != null) {
      _vehicleTypeId = t.vehicleTypeId;
      _vehicleTypeName = t.vehicleTypeName;
      _seats = t.seats;
      _plateCtrl.text = t.plateDisplay ?? t.numberPlate ?? '';
      _remotePhotoUrl = t.platePhotoUrl;
      final phone = t.contactPhone ?? '';
      _phoneCtrl.text = phone.isNotEmpty ? phone : loginPhone;
      final wa = t.whatsAppNumber ?? '';
      _same = wa.isEmpty || wa == _sameNumber;
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
    _loginCtrl.dispose();
    super.dispose();
  }

  String get _phone => _phoneCtrl.text.trim();
  String get _sameNumber => _loginCtrl.text.isNotEmpty ? _loginCtrl.text : _phone;
  String get _effectiveWhatsApp => _same ? _sameNumber : _whatsAppCtrl.text.trim();
  bool get _hasPhoto => _localPhoto != null || (_remotePhotoUrl != null && _remotePhotoUrl!.isNotEmpty);
  bool get _isApproved => _ctrl.taxi.value?.isApproved ?? false;
  late final bool _wasApproved;

  bool get _hasChanges {
    if (_vehicleTypeId != _initTypeId || _seats != _initSeats) return true;
    if (TaxiOptionSets.normalizePlate(_plateCtrl.text) != _initPlate) return true;
    if (_localPhoto != null || _remotePhotoUrl != _initPhotoUrl) return true;
    if (_phone != _initPhone || _effectiveWhatsApp != _initWhatsApp) return true;
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

  void _confirmDiscard() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard changes?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textDark)),
        content: const Text('Unsaved changes will be lost.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Editing',
                style: TextStyle(fontFamily: 'Poppins', color: TaxiColors.accentDark, fontWeight: FontWeight.w600)),
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
        content: Text('Please enable $type access in your device Settings to add photos.',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TaxiColors.accent,
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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const Text('Add Photo',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 8),
            _sourceTile(sheetCtx, Icons.camera_alt_rounded, 'Take Photo', 'Use camera to capture now', ImageSource.camera),
            _sourceTile(sheetCtx, Icons.photo_library_rounded, 'Choose from Gallery', 'Pick an existing photo',
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

  Widget _sourceTile(BuildContext sheetCtx, IconData icon, String title, String subtitle, ImageSource source) => ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: TaxiColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: TaxiColors.accent, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500, color: AppColors.textDark)),
        subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
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
      };
      final key = body.toString();
      if (_savedBasicKey != key) {
        final ok = await _ctrl.saveBasic(body);
        if (!mounted) return;
        if (!ok) {
          final type = _ctrl.lastErrorType;
          if (type == 'TaxiPlateTaken') {
            _goTo(0);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _plateFocus.requestFocus();
            });
          } else if (type == 'TaxiBaseOutsideDistrict') {
            _resolvedPin = null;
            setState(() {});
          }
          return;
        }
        _savedBasicKey = key;
      }
      var status = _ctrl.taxi.value?.status;

      final file = _localPhoto;
      if (file != null) {
        setState(() => _isUploading = true);
        final res = await _ctrl.uploadPlatePhoto(file.path);
        if (!mounted) return;
        setState(() => _isUploading = false);
        if (res == null) {
          if (_wasApproved) AppToast.warning('Plate saved but photo not uploaded. Tap Save again before leaving.');
          return;
        }
        _localPhoto = null;
        _remotePhotoUrl = res.photoUrl ?? _remotePhotoUrl;
        status = res.status ?? status;
      }

      setState(() => _isFinalizing = true);
      await _ctrl.load();
      if (!mounted) return;
      setState(() => _isFinalizing = false);
      status = _ctrl.taxi.value?.status ?? status;
      Get.back();
      if (_wasApproved && status == TaxiStatus.pendingReview) {
        AppToast.info('Sent back for review');
      } else {
        AppToast.success('Vehicle and contact saved');
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Stack(children: [
        Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          body: Column(children: [
            Container(
              decoration: const BoxDecoration(gradient: TaxiColors.gradient),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
                  child: Row(children: [
                    IconButton(
                      onPressed: _onBack,
                      icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                    ),
                    const Text('Vehicle and contact',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                ),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(children: [
                _stepDot(0, 'Vehicle'),
                Expanded(child: Container(height: 2, color: _step >= 1 ? TaxiColors.accent : AppColors.divider)),
                _stepDot(1, 'Contact'),
                Expanded(child: Container(height: 2, color: _step >= 2 ? TaxiColors.accent : AppColors.divider)),
                _stepDot(2, 'Base'),
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
                    ? _vehicleStep()
                    : _step == 1
                        ? _contactStep()
                        : _baseStep(),
              ),
            ),
            _footer(),
          ]),
        ),
        if (_isUploading) AppLoadingOverlay.stackChild(message: 'Uploading photo', indicatorColor: TaxiColors.accent),
        Obx(() => _ctrl.isSaving.value
            ? AppLoadingOverlay.stackChild(message: 'Saving your taxi...', indicatorColor: TaxiColors.accent)
            : const SizedBox.shrink()),
        if (_isFinalizing) AppLoadingOverlay.stackChild(message: 'Please wait...', indicatorColor: TaxiColors.accent),
      ]),
    );
  }

  Widget _footer() => Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(20, 12, 20, AppInsets.bottomViewPadding(context) + 12),
        child: Row(children: [
          if (_step > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _blocked ? null : () => _goTo(_step - 1),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  side: const BorderSide(color: TaxiColors.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back',
                    style: TextStyle(fontFamily: 'Poppins', color: TaxiColors.accentDark, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: Obx(() {
              final saving = _ctrl.isSaving.value;
              final disabled = saving || _isFinalizing || _isUploading || (_step == 2 && isResolvingDistrict);
              return GradientButton(
                onPressed: disabled ? null : _handleNext,
                isLoading: saving || _isFinalizing,
                label: _step == 0
                    ? 'Next: Contact'
                    : _step == 1
                        ? 'Next: Base'
                        : 'Save',
                gradient: TaxiColors.gradient,
                shadowColor: TaxiColors.accent,
              );
            }),
          ),
        ]),
      );

  Widget _stepDot(int index, String label) {
    final active = _step == index;
    final done = _step > index;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: (active || done) ? TaxiColors.accent : AppColors.divider,
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
                      color: active ? Colors.white : AppColors.textLight)),
        ),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: (active || done) ? TaxiColors.accentDark : AppColors.textLight)),
    ]);
  }

  Widget _sectionCard({required String title, String? hint, required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ],
          const SizedBox(height: 10),
          child,
        ]),
      );

  InputDecoration _inputDec(String hint, {String? prefix}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
        prefixText: prefix,
        prefixStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: AppColors.surface,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TaxiColors.accent, width: 1.5)),
      );

  Widget _vehicleStep() => SingleChildScrollView(
        key: const ValueKey(0),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionCard(
            title: 'Vehicle Type *',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: _pickType,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(children: [
                    const Icon(Iconsax.car, size: 18, color: TaxiColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_vehicleTypeName ?? _types.nameOf(_vehicleTypeId) ?? 'Pick from the list',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: _vehicleTypeId == null ? AppColors.textHint : AppColors.textDark)),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textLight),
                  ]),
                ),
              ),
              const SizedBox(height: 6),
              const Text('Pick from the list. Admin keeps the list updated.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
            ]),
          ),
          _sectionCard(
            title: 'Seats *',
            child: StayOptionGrid(
              crossAxisCount: 4,
              childAspectRatio: 1.9,
              labels: TaxiOptionSets.seats.map(TaxiOptionSets.seatsLabel).toList(),
              isActive: (i) => _seats == TaxiOptionSets.seats[i],
              onTap: (i) => setState(() => _seats = TaxiOptionSets.seats[i]),
            ),
          ),
          _sectionCard(
            title: 'Number Plate *',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(
                controller: _plateCtrl,
                focusNode: _plateFocus,
                inputFormatters: TaxiOptionSets.plateInputFormatters,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, letterSpacing: 1),
                decoration: _inputDec('e.g. UK 07 TA 1234'),
              ),
              if (_isApproved) ...[
                const SizedBox(height: 6),
                const Text('Changing the plate or photo sends your taxi back to review.',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.warning)),
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

  Widget _photoBlock() {
    if (!_hasPhoto) {
      return GestureDetector(
        onTap: _pickPhoto,
        child: Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            color: TaxiColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TaxiColors.accent.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: TaxiColors.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(Icons.add_a_photo_rounded, color: TaxiColors.accent, size: 28),
            ),
            const SizedBox(height: 10),
            const Text('Add Plate Photo',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: TaxiColors.accentDark)),
            const SizedBox(height: 4),
            const Text('Camera or Gallery', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ]),
        ),
      );
    }
    final local = _localPhoto;
    final image = local != null
        ? Image.file(local, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
        : CachedNetworkImage(
            imageUrl: _remotePhotoUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (_, _) => Container(color: AppColors.surface),
            errorWidget: (_, _, _) => Container(color: AppColors.surface),
          );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 180,
        width: double.infinity,
        child: Stack(children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: image)),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: TaxiColors.accentDark.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: const Text('Plate',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: _removePhoto,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: _pickPhoto,
        behavior: HitTestBehavior.opaque,
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_a_photo_rounded, color: TaxiColors.accent, size: 16),
          SizedBox(width: 6),
          Text('Replace photo',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: TaxiColors.accentDark, fontWeight: FontWeight.w500)),
        ]),
      ),
    ]);
  }

  Widget _contactStep() => SingleChildScrollView(
        key: const ValueKey(1),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionCard(
            title: 'Phone Number *',
            hint: 'Your login number, you can change it',
            child: TextField(
              controller: _phoneCtrl,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              inputFormatters: TaxiOptionSets.phoneInputFormatters,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: _inputDec('10-digit mobile', prefix: '+91 '),
            ),
          ),
          _sectionCard(
            title: 'WhatsApp Number *',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                  child: Text('Same as my login number',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                ),
                Switch(
                  value: _same,
                  onChanged: (v) => setState(() {
                    _same = v;
                    if (!v && _whatsAppCtrl.text.isEmpty) _whatsAppCtrl.text = _sameNumber;
                  }),
                  activeThumbColor: TaxiColors.accentDark,
                  activeTrackColor: TaxiColors.accent.withValues(alpha: 0.45),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ]),
              const SizedBox(height: 6),
              TextField(
                key: ValueKey(_same),
                controller: _same ? (_loginCtrl.text.isNotEmpty ? _loginCtrl : _phoneCtrl) : _whatsAppCtrl,
                focusNode: _same ? null : _whatsAppFocus,
                enabled: !_same,
                keyboardType: TextInputType.phone,
                inputFormatters: TaxiOptionSets.phoneInputFormatters,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: _same ? AppColors.textMedium : AppColors.textDark),
                decoration: _inputDec('10-digit WhatsApp', prefix: '+91 '),
              ),
            ]),
          ),
          const Text('Travellers call or message you on these numbers. Bakhli takes no booking and no payment.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
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
    return SingleChildScrollView(
      key: const ValueKey(2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text('Where you usually start from',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium)),
        ),
        locationStepWidget(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _sectionCard(
            title: 'District and City',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(children: [
                const Icon(Iconsax.location, color: TaxiColors.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(value,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: district != null ? AppColors.textDark : AppColors.textLight)),
                ),
                if (resolving)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: TaxiColors.accent),
                  )
                else if (district != null)
                  const Icon(Icons.gps_fixed_rounded, color: AppColors.success, size: 14),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
