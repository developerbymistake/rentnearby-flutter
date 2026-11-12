import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../trip/trip_strings.dart';
import '../enquiries/stay_enquiry_format.dart';
import '../models/stay_owner_model.dart';
import 'stay_setup_controller.dart';

class StayAdvanceDetailsScreen extends StatefulWidget {
  const StayAdvanceDetailsScreen({super.key});

  @override
  State<StayAdvanceDetailsScreen> createState() => _StayAdvanceDetailsScreenState();
}

class _StayAdvanceDetailsScreenState extends State<StayAdvanceDetailsScreen> with TickerProviderStateMixin {
  final _ctrl = StaySetupController.ensure();
  final _upi = TextEditingController();
  final _wa = TextEditingController();
  final _upiFocus = FocusNode();
  final _waFocus = FocusNode();
  late final AnimationController _anim = SetupKit.controller(this);
  Worker? _worker;
  bool _seeded = false;
  bool _saving = false;
  bool _played = false;
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
    _anim.dispose();
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
      backgroundColor: DesignColors.scaffold,
      body: Column(children: [
        StayPageHeader(
          title: TripStrings.advanceDetails,
          subtitle: TripStrings.staySetupOptional,
          onBack: () => Get.back(),
          asset: SetupAssets.moneyBag,
        ),
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

  Widget _centered(Widget child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child),
      );

  Widget _loadingView() => _centered(const Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          TemplatePlaceholder(height: 56, radius: 8),
          SizedBox(height: 12),
          TemplatePlaceholder(height: 56, radius: 8),
          SizedBox(height: 12),
          TemplatePlaceholder(height: 56, radius: 8),
        ]),
      ));

  Widget _errorView() => SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: StateCard.error(
            kit: KitTone.stay,
            title: TripStrings.couldNotLoad,
            message: TripStrings.checkConnection,
            actionLabel: TripStrings.retry,
            onAction: _ctrl.load,
          ),
        ),
      );

  Widget _in(int i, Widget child) => SetupEntrance(controller: _anim, index: i, count: 5, child: child);

  Widget _form() {
    if (!_played) {
      _played = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) SetupKit.play(_anim, context);
      });
    }
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.viewPaddingOf(context).bottom + 24;
    return _centered(SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
      child: SectionTile(
        tone: KitTone.stay,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _in(
            0,
            Row(children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SetupKit.sky,
                  boxShadow: ShadowTokens.elev1,
                ),
                child: Image.asset(SetupAssets.moneyBag),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(TripStrings.advanceDetails,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: TripKit.text(16, weight: FontWeight.w600)),
                  Text(TripStrings.advanceDetailsSub,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TripKit.text(12, color: DesignColors.textGrey).copyWith(height: 1.4)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          _in(
            1,
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
          ),
          const SizedBox(height: 12),
          _in(
            2,
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
          ),
          const SizedBox(height: 12),
          _in(
            3,
            Text(TripStrings.advanceDetailsFooter,
                style: TripKit.text(12, color: DesignColors.textSecondary).copyWith(height: 1.4)),
          ),
          const SizedBox(height: 16),
          _in(
            4,
            PrimaryButton(
 tone: KitTone.stay,
              onPressed: _saving ? null : _save,
              loading: _saving,
              label: TripStrings.save,
            ),
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
      cursorColor: DesignColors.primary,
      style: TripKit.text(14, weight: FontWeight.w600),
      decoration: SetupKit.input(label: label, hint: hint, prefix: prefix, error: error, errorMaxLines: 2),
    );
  }
}
