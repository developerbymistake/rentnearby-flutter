import 'dart:math' as math;

import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_stay_owner.dart';
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
      backgroundColor: ListingPalette.forest.page,
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
      bottomNavigationBar: Obx(() {
        final stay = _ctrl.stay.value;
        if (stay == null && (_ctrl.loadFailed.value || _ctrl.hasLoaded.value)) return const SizedBox.shrink();
        return FormFooter(
          tone: _tone,
          primaryLabel: TripStrings.save,
          onPrimary: stay == null || _saving ? null : _save,
          primaryLoading: _saving,
        );
      }),
    );
  }

  static final _tone = ListingTone.forest;

  Widget _centered(Widget child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child),
      );

  Widget _bone(double top, double height) => Padding(
        padding: EdgeInsets.fromLTRB(18, top, 18, 0),
        child: ClipRRect(borderRadius: StayOwnerShapes.card68, child: SkeletonBox(height: height, radius: 0)),
      );

  Widget _loadingView() => _centered(ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [_bone(40, 132), _bone(46, 136), _bone(46, 166)],
      ));

  Widget _errorView() => LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: StateCard3D(
            tone: _tone,
            layout: StateLayout.tall,
            art: ListingArt.compass,
            title: TripStrings.couldNotLoad,
            message: TripStrings.checkConnection,
            actionLabel: TripStrings.retry,
            onAction: _ctrl.load,
            minHeight: math.max(300, box.maxHeight - 160),
          ),
        ),
      );

  Widget _form() {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + 24;
    return _centered(SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: WorkoutCard(
            tone: _tone,
            art: ListingArt.moneyBag,
            title: TripStrings.advanceDetails,
            subtitle: TripStrings.advanceDetailsSub,
            minHeight: 132,
          ),
        ),
        FormSectionCard(
          tone: _tone,
          art: ListingArt.moneyBag,
          title: TripStrings.yourUpiId,
          tag: 'Optional',
          tagMuted: true,
          child: _field(
            controller: _upi,
            focus: _upiFocus,
            art: ListingArt.moneyBag,
            hint: TripStrings.upiHint,
            error: _upiError,
            formatters: StayEnquiryFormat.upiFormatters,
            keyboard: TextInputType.emailAddress,
            onChanged: (_) {
              if (_upiError != null) setState(() => _upiError = null);
            },
          ),
        ),
        FormSectionCard(
          tone: _tone,
          art: ListingArt.speechBalloon,
          title: TripStrings.whatsAppForProof,
          tag: 'Optional',
          tagMuted: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _field(
              controller: _wa,
              focus: _waFocus,
              art: ListingArt.speechBalloon,
              error: _waError,
              prefix: '+91',
              formatters: StayEnquiryFormat.phoneFormatters,
              keyboard: TextInputType.number,
              onChanged: (_) {
                if (_waError != null) setState(() => _waError = null);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(TripStrings.advanceDetailsFooter, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, height: 1.4)),
            ),
          ]),
        ),
      ]),
    ));
  }

  Widget _field({
    required TextEditingController controller,
    required FocusNode focus,
    required String art,
    required List<TextInputFormatter> formatters,
    required TextInputType keyboard,
    required ValueChanged<String> onChanged,
    String? hint,
    String? error,
    String? prefix,
  }) {
    return PillField(
      tone: _tone,
      controller: controller,
      focusNode: focus,
      enabled: !_saving,
      keyboardType: keyboard,
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: formatters,
      onChanged: onChanged,
      leadingArt: art,
      prefixText: prefix,
      hint: hint,
      errorText: error,
    );
  }
}
