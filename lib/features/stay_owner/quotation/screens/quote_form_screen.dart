import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../design/design.dart';
import '../../../../design/extra/tone_segment_control.dart';
import '../../../../utils/app_toast.dart';
import '../../../../utils/input_formatters.dart';
import '../../../owner_core/look/owner_look.dart';
import '../../calendar/widgets/stay_calendar_widgets.dart';
import '../../strings/stay_quote_strings.dart';
import '../../widgets/stay_widgets.dart';
import '../controllers/quote_form_controller.dart';
import '../data/quote_models.dart';
import '../model/quote_draft.dart';
import '../model/quote_money.dart';
import '../model/quote_source.dart';
import '../model/quote_words.dart';
import '../pdf/quote_engine.dart';
import '../pdf/quote_templates.dart';
import '../widgets/quote_enquiry_pick_sheet.dart';
import '../widgets/quote_line_card.dart';
import '../widgets/quote_line_sheet.dart';

// Q4: document type first, then dates, guest, stay, items, totals, payments (proforma), note, terms.
class QuoteFormScreen extends StatefulWidget {
  const QuoteFormScreen({super.key, required this.args, this.source, this.engine});

  final Map<String, dynamic> args;
  final QuoteSource? source;
  final QuoteEngineApi? engine;

  @override
  State<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends State<QuoteFormScreen> with WidgetsBindingObserver {
  late final QuoteSource _source = widget.source ?? AppQuoteSource();
  late final QuoteEngineApi _engine = widget.engine ?? QuoteEngine.instance;
  QuoteFormController? _c;
  Timer? _warm;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _booked = TextEditingController();
  final _discount = TextEditingController();
  final _gst = TextEditingController();
  final _note = TextEditingController();
  final _terms = TextEditingController();
  final _cancel = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final ok = await _source.ensureReady(context, appTemplateVersion: QuoteTemplates.version);
    if (!mounted) return;
    if (!ok) {
      Get.back<void>();
      return;
    }
    final c = await QuoteFormController.open(widget.args, _source);
    if (!mounted) return;
    if (c == null) {
      AppToast.info(StayQuoteStrings.firstOpenOffline);
      Get.back<void>();
      return;
    }
    final d = c.draft.value;
    _name.text = d.guestName;
    _phone.text = d.guestPhone;
    _booked.text = d.bookedBy;
    _discount.text = d.discount == 0 ? '' : '${d.discount}';
    _gst.text = d.gstBp == 0 ? '' : QuoteMoney.bpText(d.gstBp);
    _note.text = d.note;
    _terms.text = d.termsText;
    _cancel.text = d.cancellationText;
    setState(() => _c = c);
    _warm = Timer(const Duration(milliseconds: 300), () => _engine.warmUp(QuoteTemplates.safe(d.template)).catchError((_) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _c?.flush().ignore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _warm?.cancel();
    for (final t in [_name, _phone, _booked, _discount, _gst, _note, _terms, _cancel]) {
      t.dispose();
    }
    final c = _c;
    if (c != null) {
      c.flush().ignore();
      if (identical(QuoteFormController.maybe, c)) Get.delete<QuoteFormController>(tag: QuoteFormController.tag, force: true);
    }
    _engine.dispose().ignore();
    super.dispose();
  }

  Future<void> _pickEnquiry(QuoteFormController c) async {
    final p = await QuoteEnquiryPickSheet.pick(context);
    if (p == null || !mounted) return;
    c.applyPrefill(p);
    final d = c.draft.value;
    _name.text = d.guestName;
    _phone.text = d.guestPhone;
  }

  Future<void> _pickStay(QuoteFormController c) async {
    final d = c.draft.value;
    final r = await TemplateCalendarPopup.pickRange(context, initialStart: d.checkIn, initialEnd: d.checkOut, tone: StayCalKit.green);
    if (r != null && mounted) c.setDates(r.start, r.end);
  }

  Future<void> _pickDate(QuoteFormController c, {required bool valid}) async {
    final d = c.draft.value;
    final picked = await TemplateCalendarPopup.pickDate(
      context,
      initial: valid ? d.validTill : d.date,
      first: valid ? d.date : null,
      label: valid ? StayQuoteStrings.validTill : StayQuoteStrings.date,
      tone: StayCalKit.green,
    );
    if (picked == null || !mounted) return;
    valid ? c.setValidTill(picked) : c.setDate(picked);
  }

  Future<void> _line(QuoteFormController c, {QuoteLine? line, String? preset}) async {
    if (line == null && !c.canAddLine) return;
    final r = await QuoteLineSheet.show(context, line: line, defaultNights: c.defaultNights, preset: preset);
    if (r == null) return;
    if (line == null) {
      c.addLine(description: r.description, rate: r.rate, qty: r.qty, nights: r.nights);
    } else {
      c.updateLine(line.id, description: r.description, rate: r.rate, qty: r.qty, nights: r.nights);
    }
  }

  Future<void> _payment(QuoteFormController c, QuotePayment p) async {
    final r = await QuotePaymentSheet.show(context, p);
    if (r != null) c.updatePayment(p.id, label: r.label, date: r.date, amount: r.amount);
  }

  Future<void> _next(QuoteFormController c) async {
    if (!c.validate()) {
      AppToast.info(StayQuoteStrings.fixForm);
      return;
    }
    await c.saveNow();
    await Get.toNamed<dynamic>(AppRoutes.stayQuotationTemplate, arguments: {'documentId': c.draft.value.documentId});
  }

  String _subtitle(QuoteFormController c) {
    final d = c.draft.value;
    final from = c.fromEnquiryGuest.value;
    if (from != null && d.reservation == null) return StayQuoteStrings.fromEnquiry(from);
    return d.guestName.isEmpty ? c.numberHint : '${c.numberHint} · ${d.guestName}';
  }

  String _title(QuoteDraft d) {
    final isNew = d.reservations.isEmpty;
    if (d.kind == QuoteKind.proforma) return isNew ? StayQuoteStrings.newProforma : StayQuoteStrings.editProforma;
    return isNew ? StayQuoteStrings.newQuotation : StayQuoteStrings.editQuotation;
  }

  Widget _err(String? text) => text == null ? const SizedBox.shrink() : Padding(padding: DS.insets(t: 4), child: Text(text, style: QuoteText.error));

  Widget _typeBlock(QuoteFormController c, QuoteDraft d) => Padding(
        padding: DS.insets(l: 18, t: 14, r: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FieldLabel(StayQuoteStrings.documentType, first: true),
          ToneSegmentControl(
            labels: const [StayQuoteStrings.typeQuotation, StayQuoteStrings.typeProforma],
            selected: d.kind == QuoteKind.proforma ? 1 : 0,
            tone: ListingTone.forest,
            onTap: (i) => c.setKind(i == 1 ? QuoteKind.proforma : QuoteKind.quotation),
          ),
          Gap.v(5),
          Text(
            c.kindNeedsOwnNumber ? StayQuoteStrings.proformaOwnNumber : StayQuoteStrings.titleOnPdf(d.kind == QuoteKind.proforma ? StayQuoteStrings.typeProforma : StayQuoteStrings.typeQuotation, c.numberHint),
            style: QuoteText.small,
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: PillPickerField(
                tone: ListingTone.forest,
                label: StayQuoteStrings.number,
                value: c.numberHint,
                helperText: d.reservation == null ? StayQuoteStrings.givenOnDownload : null,
                enabled: false,
                onTap: null,
              ),
            ),
            Gap.h(8),
            Expanded(
              child: PillPickerField(tone: ListingTone.forest, label: StayQuoteStrings.date, value: StayQuoteStrings.dayMonth(d.date), onTap: () => _pickDate(c, valid: false)),
            ),
            if (d.kind == QuoteKind.quotation) ...[
              Gap.h(8),
              Expanded(
                child: PillPickerField(
                  tone: ListingTone.forest,
                  label: StayQuoteStrings.validTill,
                  value: StayQuoteStrings.dayMonth(d.validTill),
                  errorText: c.errors[QuoteFieldKeys.validTill],
                  onTap: () => _pickDate(c, valid: true),
                ),
              ),
            ],
          ]),
        ]),
      );

  Widget _guest(QuoteFormController c) => QuoteCard(
        title: StayQuoteStrings.guest,
        chip: QuoteChipTap(label: StayQuoteStrings.fromEnquiryChip, on: c.draft.value.enquiryId != null, onTap: () => _pickEnquiry(c)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PillField(
            tone: ListingTone.forest,
            controller: _name,
            label: StayQuoteStrings.guestName,
            requiredMark: true,
            maxLength: QuoteLimits.guestName,
            counterText: '',
            errorText: c.errors[QuoteFieldKeys.guestName],
            textCapitalization: TextCapitalization.words,
            inputFormatters: noEmojiInputFormatters,
            onChanged: c.setGuestName,
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: PillField(
                tone: ListingTone.forest,
                controller: _phone,
                label: StayQuoteStrings.phone,
                hint: StayQuoteStrings.optional,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(QuoteLimits.guestPhone)],
                onChanged: c.setGuestPhone,
              ),
            ),
            Gap.h(8),
            Expanded(
              child: PillField(
                tone: ListingTone.forest,
                controller: _booked,
                label: StayQuoteStrings.bookedBy,
                hint: StayQuoteStrings.optional,
                maxLength: QuoteLimits.bookedBy,
                counterText: '',
                inputFormatters: noEmojiInputFormatters,
                onChanged: c.setBookedBy,
              ),
            ),
          ]),
        ]),
      );

  static String _mealSub(QuoteMeal m) => switch (m) {
        QuoteMeal.ep => StayQuoteStrings.mealEpSub,
        QuoteMeal.cp => StayQuoteStrings.mealCpSub,
        QuoteMeal.map => StayQuoteStrings.mealMapSub,
        QuoteMeal.ap => StayQuoteStrings.mealApSub,
        QuoteMeal.none => '',
      };

  Widget _stay(QuoteFormController c, QuoteDraft d) {
    const meals = [QuoteMeal.ep, QuoteMeal.cp, QuoteMeal.map, QuoteMeal.ap];
    final n = d.nights;
    final a = d.checkIn;
    final b = d.checkOut;
    return QuoteCard(
      title: StayQuoteStrings.stay,
      chip: n > 0 ? StaySoftChip(label: StayQuoteStrings.nights(n), bg: StayLook.indigoSoft, fg: StayLook.indigoText) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: PillPickerField(
              tone: ListingTone.forest,
              label: StayQuoteStrings.checkIn,
              value: a == null ? null : StayQuoteStrings.weekdayDayMonth(a),
              hint: StayQuoteStrings.pickDates,
              errorRing: c.errors.containsKey(QuoteFieldKeys.dates),
              onTap: () => _pickStay(c),
            ),
          ),
          Gap.h(8),
          Expanded(
            child: PillPickerField(
              tone: ListingTone.forest,
              label: StayQuoteStrings.checkOut,
              value: b == null ? null : StayQuoteStrings.weekdayDayMonth(b),
              hint: StayQuoteStrings.pickDates,
              errorRing: c.errors.containsKey(QuoteFieldKeys.dates),
              onTap: () => _pickStay(c),
            ),
          ),
        ]),
        _err(c.errors[QuoteFieldKeys.dates]),
        Gap.v(6),
        Row(children: [
          Expanded(child: StepperField(tone: ListingTone.forest, label: StayQuoteStrings.adults, value: d.adults, min: 1, max: QuoteLimits.maxPeople, onChanged: c.setAdults)),
          Gap.h(8),
          Expanded(child: StepperField(tone: ListingTone.forest, label: StayQuoteStrings.kids, value: d.kids, min: 0, max: QuoteLimits.maxPeople, onChanged: c.setKids)),
        ]),
        Gap.v(6),
        StepperField(tone: ListingTone.forest, label: StayQuoteStrings.rooms, value: d.rooms, min: 0, max: QuoteLimits.maxPeople, onChanged: c.setRooms),
        FieldLabel(StayQuoteStrings.mealPlan),
        SegmentPills(
          tone: ListingTone.forest,
          columns: 4,
          height: 44,
          labels: const [StayQuoteStrings.mealEp, StayQuoteStrings.mealCp, StayQuoteStrings.mealMap, StayQuoteStrings.mealAp],
          selected: d.meal == QuoteMeal.none ? null : meals.indexOf(d.meal),
          onTap: (i) => c.setMeal(meals[i]),
        ),
        if (d.meal != QuoteMeal.none) Padding(padding: DS.insets(t: 4), child: Text(_mealSub(d.meal), style: QuoteText.small)),
      ]),
    );
  }

  Widget _items(QuoteFormController c, QuoteDraft d) {
    final t = c.totals;
    return QuoteCard(
      title: StayQuoteStrings.items,
      chip: Text(StayQuoteStrings.lines(d.lines.length), style: QuoteText.small),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final l in d.lines) QuoteLineCard(line: l, onEdit: () => _line(c, line: l), onRemove: () => c.removeLine(l.id)),
        if (c.canAddLine) ...[
          Gap.v(8),
          StayPill(label: StayQuoteStrings.addLine, kind: StayPillKind.outline, expand: true, onTap: () => _line(c)),
        ],
        _err(c.errors[QuoteFieldKeys.lines]),
        if (c.canAddLine) ...[
          Gap.v(10),
          Text(StayQuoteStrings.quickAdd, style: QuoteText.label.copyWith(color: Ink3D.grey)),
          Gap.v(4),
          Wrap(spacing: DS.s(6), runSpacing: DS.s(6), children: [
            QuoteChipTap(label: StayQuoteStrings.quickRoom, onTap: () => _line(c, preset: StayQuoteStrings.quickRoomText)),
            QuoteChipTap(label: StayQuoteStrings.quickExtra, onTap: () => _line(c, preset: StayQuoteStrings.quickExtra)),
            QuoteChipTap(label: StayQuoteStrings.quickBreakfast, onTap: () => _line(c, preset: StayQuoteStrings.quickBreakfast)),
            QuoteChipTap(label: StayQuoteStrings.quickPackage, onTap: () => _line(c, preset: StayQuoteStrings.quickPackage)),
          ]),
        ],
        Divider(height: DS.s(20), thickness: DS.s(1), color: StayLook.rowLine),
        QuoteSumRow(label: StayQuoteStrings.subtotal, value: QuoteMoney.inr(t.subtotal)),
      ]),
    );
  }

  Widget _totals(QuoteFormController c, QuoteDraft d) {
    final t = c.totals;
    return QuoteCard(
      title: StayQuoteStrings.totals,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        QuoteSumRow(label: StayQuoteStrings.subtotalLines(d.lines.length), value: QuoteMoney.inr(t.subtotal)),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: PillField(
              tone: ListingTone.forest,
              controller: _discount,
              label: StayQuoteStrings.discount,
              prefixText: '₹ ',
              keyboardType: TextInputType.number,
              errorText: c.errors[QuoteFieldKeys.discount],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              onChanged: (v) => c.setDiscount(int.tryParse(v) ?? 0),
            ),
          ),
          if (c.gstAllowed) ...[
            Gap.h(8),
            Expanded(
              child: PillField(
                tone: ListingTone.forest,
                controller: _gst,
                label: StayQuoteStrings.gst,
                hint: StayQuoteStrings.yourRate,
                suffixText: '%',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                errorText: c.errors[QuoteFieldKeys.gst],
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(5)],
                onChanged: c.setGstText,
              ),
            ),
          ],
        ]),
        if (!c.gstAllowed)
          InkWell(
            onTap: () => Get.toNamed(AppRoutes.stayQuotationBusiness),
            child: Padding(padding: DS.sym(v: 8), child: Text(StayQuoteStrings.gstHint, style: QuoteText.hint)),
          ),
        Gap.v(6),
        if (t.discount > 0) QuoteSumRow(label: StayQuoteStrings.discount, value: '-${QuoteMoney.inr(t.discount)}'),
        if (t.hasGst) ...[
          QuoteSumRow(label: StayQuoteStrings.taxable, value: QuoteMoney.inr(t.taxable)),
          QuoteSumRow(label: StayQuoteStrings.gstPercent(QuoteMoney.bpText(t.gstBp)), value: '₹${QuoteMoney.paise(t.gstPaise)}'),
        ],
        if (t.roundOffPaise != 0) QuoteSumRow(label: StayQuoteStrings.roundOff, value: QuoteMoney.signedPaise(t.roundOffPaise)),
        QuoteSumRow(label: StayQuoteStrings.total, value: QuoteMoney.inr(t.total), strong: true),
        Text(QuoteWords.rupees(t.total), style: QuoteText.small),
        _err(c.errors[QuoteFieldKeys.total]),
      ]),
    );
  }

  Widget _payments(QuoteFormController c, QuoteDraft d) {
    final t = c.totals;
    return QuoteCard(
      title: StayQuoteStrings.paymentsReceived,
      chip: StaySoftChip(label: StayQuoteStrings.optional, bg: StayLook.rowLine, fg: Ink3D.sub),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final p in d.payments)
          InkWell(
            onTap: () => _payment(c, p),
            child: Padding(
              padding: DS.sym(v: 6),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.label, style: QuoteText.head),
                    Text(StayQuoteStrings.dayMonthYear(p.date), style: QuoteText.small),
                  ]),
                ),
                Text(QuoteMoney.inr(p.amount), style: QuoteText.amount),
                QuoteIconTap(icon: Icons.close_rounded, label: StayQuoteStrings.remove, onTap: () => c.removePayment(p.id)),
              ]),
            ),
          ),
        if (c.canAddPayment)
          Wrap(spacing: DS.s(6), runSpacing: DS.s(6), children: [
            for (final (k, label) in const [
              (QuotePayKind.advance, StayQuoteStrings.payAdvance),
              (QuotePayKind.bank, StayQuoteStrings.payBank),
              (QuotePayKind.cash, StayQuoteStrings.payCash),
              (QuotePayKind.upi, StayQuoteStrings.payUpi),
            ])
              QuoteChipTap(
                label: label,
                onTap: () async {
                  final p = c.addPayment(k);
                  if (p != null) await _payment(c, p);
                },
              ),
          ]),
        Gap.v(8),
        QuoteSumRow(label: StayQuoteStrings.received, value: QuoteMoney.inr(t.received)),
        QuoteSumRow(label: StayQuoteStrings.balance, value: QuoteMoney.inr(t.balance), strong: true),
        Text(QuoteWords.rupees(t.balance < 0 ? 0 : t.balance), style: QuoteText.small),
        _err(c.errors[QuoteFieldKeys.payments]),
      ]),
    );
  }

  Widget _noteCard(QuoteFormController c) => QuoteCard(
        child: PillField(
          tone: ListingTone.forest,
          controller: _note,
          label: StayQuoteStrings.noteForGuest,
          hint: StayQuoteStrings.optional,
          maxLines: 4,
          minLines: 2,
          maxLength: QuoteLimits.note,
          inputFormatters: noEmojiInputFormatters,
          onChanged: c.setNote,
        ),
      );

  Widget _termsCard(QuoteFormController c, QuoteDraft d) {
    final b = c.business.value;
    Widget block({required String toggle, required bool on, required ValueChanged<bool> set, required String saved, required String fieldLabel, required TextEditingController ctl, required int max, required ValueChanged<String> onText}) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ToggleRow(tone: ListingTone.forest, label: toggle, value: on, onChanged: set),
          if (on)
            Text(saved.isEmpty ? StayQuoteStrings.noSavedText : saved.replaceAll('\n', ' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: QuoteText.small)
          else ...[
            PillField(tone: ListingTone.forest, controller: ctl, label: fieldLabel, maxLines: 6, minLines: 3, maxLength: max, inputFormatters: noEmojiInputFormatters, onChanged: onText),
            Text(StayQuoteStrings.docOnly, style: QuoteText.small),
          ],
        ]);
    return QuoteCard(
      title: StayQuoteStrings.termsTitle,
      chip: StaySoftChip(label: StayQuoteStrings.fromBusiness, bg: StayLook.rowLine, fg: Ink3D.sub),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        block(
          toggle: StayQuoteStrings.useSavedTerms,
          on: d.useSavedTerms,
          set: (v) {
            c.setUseSavedTerms(v);
            _terms.text = c.draft.value.termsText;
          },
          saved: b.termsText,
          fieldLabel: StayQuoteStrings.termsForDoc,
          ctl: _terms,
          max: QuoteLimits.terms,
          onText: c.setTermsText,
        ),
        Divider(height: DS.s(24), thickness: DS.s(1), color: StayLook.rowLine),
        block(
          toggle: StayQuoteStrings.useSavedCancellation,
          on: d.useSavedCancellation,
          set: (v) {
            c.setUseSavedCancellation(v);
            _cancel.text = c.draft.value.cancellationText;
          },
          saved: b.cancellationText,
          fieldLabel: StayQuoteStrings.cancellationForDoc,
          ctl: _cancel,
          max: QuoteLimits.cancellation,
          onText: c.setCancellationText,
        ),
      ]),
    );
  }

  Widget _bar(QuoteFormController c) {
    final d = c.draft.value;
    final t = c.totals;
    final proforma = d.kind == QuoteKind.proforma;
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(22))),
        boxShadow: DS.shadows(Ink3D.topEdge),
      ),
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(10), DS.s(14), MediaQuery.viewPaddingOf(context).bottom + DS.s(12)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(proforma ? StayQuoteStrings.balance : StayQuoteStrings.total, style: QuoteText.small),
            Text(QuoteMoney.inr(proforma ? t.balance : t.total), style: QuoteText.total),
          ]),
        ),
        Expanded(child: PrimaryButton(label: StayQuoteStrings.chooseTemplate, tone: StayCalKit.green, compact: true, onPressed: () => _next(c))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return Scaffold(
        backgroundColor: OwnerLook.stay.page,
        body: Column(children: [
          const StayCalHeader(title: StayQuoteStrings.newQuotation),
          Expanded(child: Padding(padding: DS.all(18), child: const Align(alignment: Alignment.topCenter, child: SkeletonFormCard()))),
        ]),
      );
    }
    return Obx(() {
      final d = c.draft.value;
      c.errors.length;
      c.business.value;
      return Scaffold(
        backgroundColor: OwnerLook.stay.page,
        body: Column(children: [
          StayCalHeader(title: _title(d), subtitle: _subtitle(c)),
          Expanded(
            child: ListView(
              padding: DS.insets(b: 24),
              children: [
                _typeBlock(c, d),
                _guest(c),
                _stay(c, d),
                _items(c, d),
                _totals(c, d),
                if (d.kind == QuoteKind.proforma) _payments(c, d),
                _noteCard(c),
                _termsCard(c, d),
              ],
            ),
          ),
          _bar(c),
        ]),
      );
    });
  }
}
