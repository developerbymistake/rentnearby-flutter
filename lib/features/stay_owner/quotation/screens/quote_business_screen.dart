import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../utils/app_toast.dart';
import '../../../../utils/input_formatters.dart';
import '../../../owner_core/data/owner_args.dart';
import '../../../owner_core/look/owner_look.dart';
import '../../../owner_core/sheets/owner_confirm.dart';
import '../../../stay/enquiries/stay_enquiry_format.dart';
import '../../../stay/setup/stay_page_header.dart';
import '../../strings/stay_quote_setup_strings.dart';
import '../../widgets/stay_widgets.dart';
import '../controllers/quote_hub_controller.dart';
import '../controllers/quote_image_controller.dart';
import '../controllers/quote_profile_controller.dart';
import '../data/quote_models.dart';
import '../widgets/quote_bank_sheet.dart';
import '../widgets/quote_name_change_sheet.dart';
import '../widgets/quote_terms_sheet.dart';

// Mock Q2 (three frames): Business details, filled once and used on every quotation.
class QuoteBusinessScreen extends StatefulWidget {
  const QuoteBusinessScreen({super.key, required this.args, this.hub, this.images});

  final Map<String, dynamic> args;
  final QuoteHubController? hub;
  final QuoteImageController? images;

  @override
  State<QuoteBusinessScreen> createState() => _QuoteBusinessScreenState();
}

class _QuoteBusinessScreenState extends State<QuoteBusinessScreen> {
  late final QuoteHubController _hub = widget.hub ?? QuoteHubController.ensure();
  late final QuoteProfileController _form = QuoteProfileController(hub: _hub);
  late final QuoteImageController _images = widget.images ?? QuoteImageController(hub: _hub, tell: AppToast.info);
  late final bool _firstRun = OwnerArgs.flag(widget.args, 'firstRun');
  String _initial = '';

  ListingTone get _tone => OwnerLook.stay.tone;

  @override
  void initState() {
    super.initState();
    _form.fill();
    _initial = _snapshot();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_hub.hub.value == null) await _hub.load();
    if (!mounted) return;
    if (_hub.hub.value == null) {
      AppToast.info(QuoteSetupStrings.connectOnce);
      Get.back<dynamic>();
      return;
    }
    final wasClean = _snapshot() == _initial;
    await _form.loadBank();
    if (wasClean) _initial = _snapshot();
    await _images.refreshPaths();
  }

  String _snapshot() => jsonEncode(_form.input().toJson());

  bool get _dirty => _snapshot() != _initial;

  @override
  void dispose() {
    _form.onClose();
    if (widget.images == null) _images.onClose();
    super.dispose();
  }

  Future<void> _back() async {
    if (_form.saving.value) return;
    if (!_dirty || await OwnerConfirm.discard(context)) Get.back<dynamic>(result: false);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final out = await _form.save(tell: AppToast.error);
    if (!mounted) return;
    if (out == QuoteSaveOutcome.invalid) {
      AppToast.error(QuoteSetupStrings.checkFields);
      return;
    }
    if (out != QuoteSaveOutcome.saved) return;
    if (!_firstRun) AppToast.success(QuoteSetupStrings.saved);
    Get.back<dynamic>(result: true);
  }

  Future<void> _editBank() async {
    final edit = await QuoteBankSheet.show(context, _form.bank.value);
    switch (edit) {
      case QuoteBankSet(:final bank):
        _form.setBankAccount(bank);
      case QuoteBankRemove():
        _form.removeBankAccount();
      case null:
        break;
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
        body: Column(
          children: [
            StayPageHeader(title: QuoteSetupStrings.title, subtitle: QuoteSetupStrings.subtitle, onBack: _back, asset: SetupAssets.hotel),
            Expanded(
              child: Obx(() {
                final h = _hub.hub.value;
                if (h == null) return const SizedBox.shrink();
                return SingleChildScrollView(
                  padding: DS.insets(b: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _imageCard(QuoteImageKind.logo, h),
                      _detailsCard(h),
                      _termsRow(h),
                      _imageCard(QuoteImageKind.signature, h),
                      _gstCard(),
                      _bankCard(h),
                      _textsCard(),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
        bottomNavigationBar: StayFooter(
          child: Obx(() => GradientPillButton(
                tone: _tone,
                label: QuoteSetupStrings.save,
                loading: _form.saving.value,
                enabled: !_form.saving.value && _images.busy.value == null,
                onTap: _save,
              )),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Padding(
        padding: DS.insets(l: 18, t: 14, r: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, borderRadius: DS.br(CardRadius.card), boxShadow: DS.shadows(Ink3D.softShadow)),
          child: Padding(
            padding: DS.insets(l: 14, t: 12, r: 14, b: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      );

  Widget _head(String title, {bool optional = true}) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(child: FieldLabel(title, first: true)),
          if (optional) Padding(padding: DS.insets(b: 7), child: Text(QuoteSetupStrings.optional, style: FieldMessage.helperStyle)),
        ],
      );

  Widget _imageCard(QuoteImageKind kind, QuoteHub h) {
    final logo = kind == QuoteImageKind.logo;
    final has = h.profile?.hasImage(kind) ?? false;
    return _card(children: [
      _head(logo ? QuoteSetupStrings.logo : QuoteSetupStrings.signature),
      Obx(() {
        final path = _images.paths[kind];
        final busy = _images.busy.value == kind;
        return Row(
          children: [
            Container(
              width: DS.s(52),
              height: DS.s(52),
              decoration: BoxDecoration(color: StayLook.lockedRow, borderRadius: DS.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: path == null
                  ? Center(child: ExcludeSemantics(child: Art3D(asset: ListingArt.framedPicture, size: 30)))
                  : Image.file(File(path), fit: BoxFit.contain, cacheWidth: DS.s(156).round(), gaplessPlayback: true),
            ),
            Gap.h(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(busy ? QuoteSetupStrings.uploading : (has ? QuoteSetupStrings.imageAdded : QuoteSetupStrings.noImage), style: TypeTokens.bodyStrong.copyWith(color: Ink3D.title)),
                  Text(logo ? QuoteSetupStrings.logoHint : QuoteSetupStrings.signatureHint, style: FieldMessage.helperStyle),
                ],
              ),
            ),
            Gap.h(8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SecondaryButton(
                  label: has ? QuoteSetupStrings.change : QuoteSetupStrings.add,
                  tone: OwnerLook.stay.kit,
                  compact: true,
                  expand: false,
                  onPressed: busy || _images.busy.value != null ? null : () => _images.change(context, kind),
                ),
                if (has && !busy)
                  TextButton(
                    onPressed: _images.busy.value != null ? null : () => _images.remove(kind),
                    child: Text(QuoteSetupStrings.remove, style: FieldMessage.helperStyle.copyWith(color: Form3D.errorText)),
                  ),
              ],
            ),
          ],
        );
      }),
    ]);
  }

  Widget _detailsCard(QuoteHub h) {
    final pending = h.stay.pendingName;
    final result = h.stay.lastNameResult;
    return _card(children: [
      PillPickerField(
        tone: _tone,
        label: QuoteSetupStrings.businessName,
        value: h.stay.name,
        enabled: false,
        onTap: null,
        trailing: Icon(Icons.lock_outline_rounded, size: DS.s(18), color: Ink3D.grey),
      ),
      Padding(
        padding: DS.insets(l: 8, t: 5, r: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(QuoteSetupStrings.nameLocked, style: FieldMessage.helperStyle)),
            Gap.h(10),
            Semantics(
              button: true,
              child: InkWell(
                onTap: pending != null ? null : () => QuoteNameChangeSheet.show(context, _form, h.stay.name),
                child: Text(QuoteSetupStrings.requestChange, style: FieldMessage.helperStyle.copyWith(color: pending != null ? Ink3D.hint : _tone.text)),
              ),
            ),
          ],
        ),
      ),
      if (pending != null) FieldMessage(helper: QuoteSetupStrings.namePending(pending), accent: StayLook.amberText),
      if (pending == null && result != null)
        FieldMessage(helper: result == 'Approved' ? QuoteSetupStrings.nameApproved : QuoteSetupStrings.nameRejected, accent: result == 'Approved' ? StayLook.greenText : StayLook.redText),
      Obx(() => PillField(
            tone: _tone,
            label: QuoteSetupStrings.slogan,
            hint: QuoteSetupStrings.optional,
            controller: _form.slogan,
            errorText: _form.errors['slogan'],
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(QuoteProfileRules.sloganMax)],
            firstLabel: false,
          )),
      Obx(() => PillField(
            tone: _tone,
            label: QuoteSetupStrings.address,
            controller: _form.address,
            errorText: _form.errors['address'],
            maxLines: QuoteProfileRules.addressMaxLines,
            minLines: 2,
            keyboardType: TextInputType.multiline,
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(QuoteProfileRules.addressMax)],
            firstLabel: false,
          )),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Obx(() => PillField(
                  tone: _tone,
                  label: QuoteSetupStrings.phone,
                  controller: _form.phone,
                  errorText: _form.errors['phone'],
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')), LengthLimitingTextInputFormatter(QuoteProfileRules.phoneMax)],
                  firstLabel: false,
                )),
          ),
          Gap.h(10),
          Expanded(
            child: Obx(() => PillField(
                  tone: _tone,
                  label: QuoteSetupStrings.email,
                  hint: QuoteSetupStrings.optional,
                  controller: _form.email,
                  errorText: _form.errors['email'],
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s')), LengthLimitingTextInputFormatter(QuoteProfileRules.emailMax)],
                  firstLabel: false,
                )),
          ),
        ],
      ),
    ]);
  }

  Widget _termsRow(QuoteHub h) {
    final at = h.terms.acceptedAt;
    return StayRowsCard(rows: [
      StayRowData(
        art: ListingArt.shield,
        title: QuoteSetupStrings.termsRow,
        sub: at == null ? null : QuoteSetupStrings.agreedOn(QuoteTermsSheet.dateText(at)),
        trailing: Icon(Icons.chevron_right_rounded, size: DS.s(24), color: _tone.text),
        onTap: () => QuoteTermsSheet.reRead(context, at),
      ),
    ]);
  }

  Widget _gstCard() => _card(children: [
        Obx(() => PillField(
              tone: _tone,
              label: QuoteSetupStrings.gstin,
              hint: QuoteSetupStrings.optional,
              controller: _form.gstin,
              errorText: _form.errors['gstin'],
              helperText: QuoteSetupStrings.gstinHelp,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')), LengthLimitingTextInputFormatter(15)],
            )),
      ]);

  String? _bankValue(QuoteHub h) {
    final b = _form.bank.value;
    if (_form.bankReady.value) {
      if (!b.hasAccount) return null;
      return [b.bank, b.branch].where((s) => s.isNotEmpty).join(', ');
    }
    final s = h.profile?.bank;
    if (s == null || !s.hasAccount) return null;
    return [s.bank ?? '', s.branch ?? ''].where((v) => v.isNotEmpty).join(', ');
  }

  String? _bankSub(QuoteHub h) {
    final b = _form.bank.value;
    if (_form.bankReady.value) return b.hasAccount ? QuoteSetupStrings.accountLine(b.last4, b.ifsc) : null;
    final s = h.profile?.bank;
    return s?.accountLast4 == null ? null : QuoteSetupStrings.accountLine(s!.accountLast4!, s.ifsc ?? '');
  }

  Widget _bankCard(QuoteHub h) {
    if (!h.bankStorage) {
      return _card(children: [_head(QuoteSetupStrings.bankAndUpi), Text(QuoteSetupStrings.bankOff, style: FieldMessage.helperStyle)]);
    }
    return _card(children: [
      _head(QuoteSetupStrings.bankAndUpi),
      if (h.bankUnreadable) FieldMessage(helper: QuoteSetupStrings.bankUnreadable, accent: StayLook.amberText),
      Obx(() {
        final ready = _form.bankReady.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PillPickerField(
              tone: _tone,
              label: QuoteSetupStrings.bankAccount,
              value: _bankValue(h),
              sublabel: _bankSub(h),
              hint: _form.bankLoading.value ? QuoteSetupStrings.bankLoading : QuoteSetupStrings.addBank,
              errorText: _form.errors['bank'],
              enabled: ready,
              onTap: ready ? _editBank : null,
              firstLabel: false,
            ),
            PillField(
              tone: _tone,
              label: QuoteSetupStrings.upi,
              hint: ready ? QuoteSetupStrings.optional : (h.profile?.bank.upiMasked ?? QuoteSetupStrings.optional),
              controller: _form.upi,
              enabled: ready,
              errorText: _form.errors['upi'],
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              inputFormatters: StayEnquiryFormat.upiFormatters,
              firstLabel: false,
            ),
          ],
        );
      }),
      Padding(
        padding: DS.insets(l: 8, t: 6, r: 8),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: DS.s(14), color: Ink3D.grey),
            Gap.h(6),
            Expanded(child: Text(QuoteSetupStrings.shownOnDocs, style: FieldMessage.helperStyle)),
          ],
        ),
      ),
    ]);
  }

  Widget _textsCard() => _card(children: [
        Obx(() => PillField(
              tone: _tone,
              label: QuoteSetupStrings.defaultTerms,
              hint: QuoteSetupStrings.optional,
              controller: _form.terms,
              errorText: _form.errors['termsText'],
              maxLines: 6,
              minLines: 3,
              keyboardType: TextInputType.multiline,
              inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(QuoteProfileRules.termsMax)],
            )),
        Obx(() => PillField(
              tone: _tone,
              label: QuoteSetupStrings.cancellation,
              hint: QuoteSetupStrings.optional,
              controller: _form.cancellation,
              errorText: _form.errors['cancellationText'],
              maxLines: 6,
              minLines: 3,
              keyboardType: TextInputType.multiline,
              inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(QuoteProfileRules.cancellationMax)],
              firstLabel: false,
            )),
      ]);
}
