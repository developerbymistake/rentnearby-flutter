import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/gradient_button.dart';
import '../../trip/trip_strings.dart';
import '../../trip/widgets/trip_shimmers.dart';
import '../enquiries/stay_enquiry_format.dart';
import '../models/stay_owner_model.dart';
import 'stay_option_sets.dart';
import 'stay_setup_controller.dart';

class StayAdvanceDetailsScreen extends StatefulWidget {
  const StayAdvanceDetailsScreen({super.key});

  @override
  State<StayAdvanceDetailsScreen> createState() => _StayAdvanceDetailsScreenState();
}

class _StayAdvanceDetailsScreenState extends State<StayAdvanceDetailsScreen> {
  final _ctrl = StaySetupController.ensure();
  final _upi = TextEditingController();
  final _wa = TextEditingController();
  final _upiFocus = FocusNode();
  final _waFocus = FocusNode();
  Worker? _worker;
  bool _seeded = false;
  bool _saving = false;
  String? _upiError;
  String? _waError;

  @override
  void initState() {
    super.initState();
    _upiFocus.addListener(() {
      if (!_upiFocus.hasFocus) setState(() => _upiError = StayEnquiryFormat.upiError(_upi.text.trim()));
    });
    _waFocus.addListener(() {
      if (!_waFocus.hasFocus) setState(() => _waError = StayEnquiryFormat.phoneError(_wa.text.trim()));
    });
    _worker = ever<StayOwnerModel?>(_ctrl.stay, _seed);
    _seed(_ctrl.stay.value);
    _ctrl.load();
  }

  @override
  void dispose() {
    _worker?.dispose();
    _upi.dispose();
    _wa.dispose();
    _upiFocus.dispose();
    _waFocus.dispose();
    super.dispose();
  }

  void _seed(StayOwnerModel? s) {
    if (_seeded || s == null) return;
    _seeded = true;
    _upi.text = s.upiId ?? '';
    final stored = s.whatsAppNumber ?? '';
    _wa.text = stored.isNotEmpty ? stored : StayEnquiryFormat.accountPhone();
  }

  Future<void> _save() async {
    if (_saving) return;
    final upi = _upi.text.trim();
    final wa = _wa.text.trim();
    final upiError = StayEnquiryFormat.upiError(upi);
    final waError = StayEnquiryFormat.phoneError(wa);
    setState(() {
      _upiError = upiError;
      _waError = waError;
    });
    if (upiError != null || waError != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final ok = await _ctrl.saveAdvanceDetails(upiId: upi, whatsAppNumber: wa);
    if (!mounted) return;
    if (ok) {
      AppToast.success(TripStrings.advanceDetailsSaved);
      Get.back();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(children: [
        _header(),
        Expanded(
          child: Obx(() {
            final stay = _ctrl.stay.value;
            if (stay == null && _ctrl.loadFailed.value) return _errorView();
            if (stay == null && _ctrl.hasLoaded.value) return _errorView();
            if (stay == null) return _loadingView();
            return _form();
          }),
        ),
      ]),
    );
  }

  Widget _header() => Container(
        decoration: const BoxDecoration(gradient: StayColors.gradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 20, 18),
            child: Row(children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(TripStrings.advanceDetails,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(TripStrings.staySetupOptional,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.white70)),
                ]),
              ),
            ]),
          ),
        ),
      );

  Widget _centered(Widget child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child),
      );

  Widget _loadingView() => _centered(Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TripShimmers.rowBox(height: 56, radius: 14),
          const SizedBox(height: 12),
          TripShimmers.rowBox(height: 56, radius: 14),
          const SizedBox(height: 12),
          TripShimmers.rowBox(height: 56, radius: 14),
        ]),
      ));

  Widget _errorView() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(TripStrings.couldNotLoad,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 4),
            const Text(TripStrings.checkConnection,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textLight)),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(88, 44)),
              onPressed: _ctrl.load,
              child: const Text(TripStrings.retry,
                  style: TextStyle(fontWeight: FontWeight.w600, color: StayColors.accentDark)),
            ),
          ]),
        ),
      );

  Widget _form() {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + AppInsets.bottomViewPadding(context) + 24;
    return _centered(SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: StayColors.surface, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Iconsax.wallet_3, size: 20, color: StayColors.accentDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(TripStrings.advanceDetails,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const Text(TripStrings.advanceDetailsSub,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.4)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          _field(
            controller: _upi,
            focus: _upiFocus,
            label: TripStrings.yourUpiId,
            hint: TripStrings.upiHint,
            error: _upiError,
            formatters: StayEnquiryFormat.upiFormatters,
            keyboard: TextInputType.emailAddress,
            onChanged: (_) {
              if (_upiError != null) setState(() => _upiError = null);
            },
          ),
          const SizedBox(height: 12),
          _field(
            controller: _wa,
            focus: _waFocus,
            label: TripStrings.whatsAppForProof,
            error: _waError,
            prefix: '+91 ',
            formatters: StayEnquiryFormat.phoneFormatters,
            keyboard: TextInputType.number,
            onChanged: (_) {
              if (_waError != null) setState(() => _waError = null);
            },
          ),
          const SizedBox(height: 12),
          const Text(TripStrings.advanceDetailsFooter,
              style: TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.4)),
          const SizedBox(height: 16),
          GradientButton(
            onPressed: _saving ? null : _save,
            isLoading: _saving,
            label: TripStrings.save,
            gradient: StayColors.gradient,
            shadowColor: StayColors.accent,
          ),
        ]),
      ),
    ));
  }

  Widget _field({
    required TextEditingController controller,
    required FocusNode focus,
    required String label,
    required List<TextInputFormatter> formatters,
    required TextInputType keyboard,
    required ValueChanged<String> onChanged,
    String? hint,
    String? error,
    String? prefix,
  }) {
    return TextField(
      controller: controller,
      focusNode: focus,
      enabled: !_saving,
      keyboardType: keyboard,
      inputFormatters: formatters,
      onChanged: onChanged,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        errorText: error,
        errorMaxLines: 2,
        counterText: '',
        filled: true,
        fillColor: StayColors.surface,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: StayColors.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
      ),
    );
  }
}
