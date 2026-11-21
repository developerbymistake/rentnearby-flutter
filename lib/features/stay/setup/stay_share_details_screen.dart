import 'dart:math' as math;

import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_stay_owner.dart';
import '../../../utils/app_toast.dart';
import '../../owner_core/sheets/owner_confirm.dart';
import '../../stay_owner/strings/stay_work_strings.dart';
import '../../trip/trip_strings.dart';
import '../enquiries/stay_enquiry_format.dart';
import '../models/stay_owner_model.dart';
import '../stay_share_strings.dart';
import 'stay_setup_controller.dart';

abstract final class StayShareDetailsScreenValidators {
  static final _upiShape = RegExp(r'^[A-Za-z0-9._-]+@[A-Za-z][A-Za-z0-9.-]*$');
  static final _tenDigits = RegExp(r'^\d{10}$');

  static String? upi(String v) =>
      v.isEmpty || (v.length >= 5 && v.length <= 60 && _upiShape.hasMatch(v)) ? null : StayWorkStrings.upiInvalid;

  static String? whatsApp(String v) => v.isEmpty || _tenDigits.hasMatch(v) ? null : StayWorkStrings.whatsAppInvalid;
}

const double _removeFont = 13;

class StayShareDetailsScreen extends StatefulWidget {
  const StayShareDetailsScreen({super.key});

  @override
  State<StayShareDetailsScreen> createState() => _StayShareDetailsScreenState();
}

class _StayShareDetailsScreenState extends State<StayShareDetailsScreen> {
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
      if (!_upiFocus.hasFocus && mounted) setState(() => _upiError = upiError(_upi.text.trim()));
    });
    _waFocus.addListener(() {
      if (!_waFocus.hasFocus && mounted) setState(() => _waError = whatsAppError(_wa.text.trim()));
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

  static String? upiError(String v) => StayShareDetailsScreenValidators.upi(v);

  static String? whatsAppError(String v) => StayShareDetailsScreenValidators.whatsApp(v);

  String _savedUpi = '';
  String _savedWa = '';

  bool get _dirty => _seeded && (_upi.text.trim() != _savedUpi || _wa.text.trim() != _savedWa);

  void _seed(StayOwnerModel? s) {
    if (_seeded || s == null) return;
    _seeded = true;
    _upi.text = s.upiId ?? '';
    final stored = s.whatsAppNumber ?? '';
    _wa.text = stored.isNotEmpty ? stored : StayEnquiryFormat.accountPhone();
    _savedUpi = _upi.text;
    _savedWa = _wa.text;
  }

  Future<void> _remove() async {
    if (_saving) return;
    _upi.clear();
    _wa.clear();
    setState(() {
      _upiError = null;
      _waError = null;
    });
    await _save();
  }

  Future<void> _back() async {
    if (_saving) return;
    if (_dirty && !await OwnerConfirm.discard(context)) return;
    if (mounted) Get.back();
  }

  Future<void> _save() async {
    if (_saving) return;
    final upi = _upi.text.trim();
    final wa = _wa.text.trim();
    final upiErr = upiError(upi);
    final waErr = whatsAppError(wa);
    setState(() {
      _upiError = upiErr;
      _waError = waErr;
    });
    if (upiErr != null || waErr != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final ok = await _ctrl.saveShareDetails(upiId: upi, whatsAppNumber: wa);
    if (!mounted) return;
    if (ok) {
      _savedUpi = upi;
      _savedWa = wa;
      AppToast.success(StayShareStrings.saved);
      Get.back();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
      backgroundColor: ListingPalette.forest.page,
      body: Column(children: [
        StayPageHeader(
          title: StayShareStrings.title,
          subtitle: StayWorkStrings.shareHeaderSub,
          onBack: _back,
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
          primaryLabel: StayWorkStrings.save,
          onPrimary: stay == null || _saving ? null : _save,
          primaryLoading: _saving,
        );
      }),
    ),
    );
  }

  static final _tone = ListingTone.forest;

  Widget _centered(Widget child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: DS.s(560)), child: child),
      );

  Widget _bone(double top, double height) => Padding(
        padding: DS.gapInsets(l: 18, t: top, r: 18),
        child: ClipRRect(borderRadius: DS.br(StayOwnerShapes.card68), child: SkeletonBox(height: DS.s(height), radius: 0)),
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
            minHeight: math.max(DS.s(300), box.maxHeight - DS.s(160)),
          ),
        ),
      );

  Widget _form() {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + DS.s(24);
    return _centered(SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          margin: DS.gapInsets(l: 14, t: 14, r: 14),
          padding: DS.insets(l: 16, t: 16, r: 16, b: 16),
          decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.tile), boxShadow: DS.shadows(Ink3D.softShadow)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              ExcludeSemantics(child: Art3D(asset: ListingArt.key, size: 44)),
              Gap.h(12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(StayWorkStrings.shareCardTitle, style: Ink3D.text(18, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                  Text(StayShareStrings.sub, style: Ink3D.text(12, FontWeight.w500, Ink3D.body, height: 1.35, letterSpacing: 0)),
                ]),
              ),
            ]),
            Gap.v(14),
            _label(StayShareStrings.upiLabel),
            _field(
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
            Gap.v(10),
            _label(StayShareStrings.whatsAppNumber),
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
          ]),
        ),
        _info(ListingArt.shield, StayWorkStrings.shareLine1, ListingTone.teal),
        _info(ListingArt.bulb, StayWorkStrings.shareLine2, ListingTone.indigo),
        Padding(
          padding: DS.gapInsets(l: 14, t: 18, r: 14),
          child: WhitePillButton(tone: _tone, label: StayWorkStrings.removeMyDetails, danger: true, height: 46, fontSize: _removeFont, onTap: _saving ? null : _remove),
        ),
      ]),
    ));
  }

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(bottom: DS.gv(6)),
        child: Row(children: [
          Expanded(child: Text(text, style: Ink3D.text(12, FontWeight.w700, Ink3D.title, letterSpacing: 0))),
          Text(StayShareStrings.optional, style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
        ]),
      );

  Widget _info(String art, String text, ListingTone tone) => Container(
        margin: DS.gapInsets(l: 14, t: 14, r: 14),
        padding: DS.sym(h: 16, v: 14),
        decoration: BoxDecoration(color: tone.tint, borderRadius: DS.circular(14)),
        child: Row(children: [
          ExcludeSemantics(child: Art3D(asset: art, size: 32)),
          Gap.h(12),
          Expanded(child: Text(text, style: Ink3D.text(12, FontWeight.w600, tone.text, height: 1.4, letterSpacing: 0))),
        ]),
      );

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
