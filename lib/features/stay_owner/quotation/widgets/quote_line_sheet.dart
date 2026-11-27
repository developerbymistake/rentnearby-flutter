import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../calendar/widgets/stay_calendar_widgets.dart';
import '../../strings/stay_quote_strings.dart';
import '../../widgets/stay_widgets.dart';
import '../controllers/quote_form_controller.dart';
import '../model/quote_draft.dart';
import '../model/quote_money.dart';
import 'quote_line_card.dart';

class QuoteLineInput {
  const QuoteLineInput({required this.description, required this.rate, required this.qty, required this.nights});

  final String description;
  final int rate;
  final int qty;
  final int nights;
}

// Add / edit one line (mock Q4b): description with suggestions, rate, qty, nights and the live amount.
class QuoteLineSheet extends StatefulWidget {
  const QuoteLineSheet({super.key, this.line, required this.defaultNights, this.preset});

  final QuoteLine? line;
  final int defaultNights;
  final String? preset;

  static Future<QuoteLineInput?> show(BuildContext context, {QuoteLine? line, required int defaultNights, String? preset}) =>
      SheetFrame.show<QuoteLineInput>(context, builder: (_) => QuoteLineSheet(line: line, defaultNights: defaultNights, preset: preset));

  @override
  State<QuoteLineSheet> createState() => _QuoteLineSheetState();
}

class _QuoteLineSheetState extends State<QuoteLineSheet> {
  late final TextEditingController _desc = TextEditingController(text: widget.line?.description ?? widget.preset ?? '');
  late final TextEditingController _rate = TextEditingController(text: widget.line == null ? '' : '${widget.line!.rate}');
  late int _qty = widget.line?.qty ?? 1;
  late int _nights = widget.line?.nights ?? widget.defaultNights;
  String? _error;

  int get _rateValue => int.tryParse(_rate.text.trim()) ?? 0;

  @override
  void dispose() {
    _desc.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _save() {
    final err = QuoteFormController.lineError(description: _desc.text, rate: _rateValue, qty: _qty, nights: _nights);
    if (err != null || _rate.text.trim().isEmpty) {
      setState(() => _error = err ?? StayQuoteStrings.errRate);
      return;
    }
    Navigator.of(context).pop(QuoteLineInput(description: _desc.text.trim(), rate: _rateValue, qty: _qty, nights: _nights));
  }

  @override
  Widget build(BuildContext context) {
    final amount = QuoteMoney.line(_rateValue, _qty, _nights);
    return SheetFrame(
      tone: ListingTone.forest,
      title: widget.line == null ? StayQuoteStrings.addLine : StayQuoteStrings.editLine,
      footer: PrimaryButton(label: widget.line == null ? StayQuoteStrings.add : StayQuoteStrings.save, tone: StayCalKit.green, onPressed: _save),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillField(
            tone: ListingTone.forest,
            controller: _desc,
            label: StayQuoteStrings.description,
            maxLength: QuoteLimits.description,
            counterText: '',
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: noEmojiInputFormatters,
            onChanged: (_) => setState(() => _error = null),
          ),
          Gap.v(8),
          Wrap(spacing: DS.s(6), runSpacing: DS.s(6), children: [
            for (final s in StayQuoteStrings.descriptionSuggestions)
              QuoteChipTap(
                label: s,
                on: _desc.text == s,
                onTap: () => setState(() {
                  _desc.text = s;
                  _error = null;
                }),
              ),
          ]),
          PillField(
            tone: ListingTone.forest,
            controller: _rate,
            label: StayQuoteStrings.rate,
            helperText: StayQuoteStrings.perNight,
            prefixText: QuoteMoney.fieldPrefix,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            onChanged: (_) => setState(() => _error = null),
          ),
          Gap.v(6),
          Row(children: [
            Expanded(
              child: StepperField(
                tone: ListingTone.forest,
                label: StayQuoteStrings.qty,
                value: _qty,
                min: 1,
                max: QuoteLimits.maxQty,
                onChanged: (v) => setState(() => _qty = v),
              ),
            ),
            Gap.h(12),
            Expanded(
              child: StepperField(
                tone: ListingTone.forest,
                label: StayQuoteStrings.nightsLabel,
                value: _nights,
                min: 1,
                max: QuoteLimits.maxNights,
                onChanged: (v) => setState(() => _nights = v),
              ),
            ),
          ]),
          Container(
            margin: DS.insets(t: 14),
            padding: DS.sym(h: 14, v: 10),
            decoration: BoxDecoration(color: StayLook.greenSoft, borderRadius: DS.circular(12)),
            child: Row(children: [
              Expanded(child: Text(StayQuoteStrings.lineMath(QuoteMoney.group(_rateValue), _qty, _nights), style: QuoteText.small.copyWith(color: Ink3D.sub))),
              Text(QuoteMoney.inr(amount), style: QuoteText.total),
            ]),
          ),
          if (_error != null) Padding(padding: DS.insets(t: 8), child: Text(_error!, style: QuoteText.error)),
          Gap.v(8),
        ],
      ),
    );
  }
}

class QuotePaymentInput {
  const QuotePaymentInput({required this.label, required this.date, required this.amount});

  final String label;
  final DateTime date;
  final int amount;
}

class QuotePaymentSheet extends StatefulWidget {
  const QuotePaymentSheet({super.key, required this.payment});

  final QuotePayment payment;

  static Future<QuotePaymentInput?> show(BuildContext context, QuotePayment p) =>
      SheetFrame.show<QuotePaymentInput>(context, builder: (_) => QuotePaymentSheet(payment: p));

  @override
  State<QuotePaymentSheet> createState() => _QuotePaymentSheetState();
}

class _QuotePaymentSheetState extends State<QuotePaymentSheet> {
  late final TextEditingController _label = TextEditingController(text: widget.payment.label);
  late final TextEditingController _amount = TextEditingController(text: widget.payment.amount == 0 ? '' : '${widget.payment.amount}');
  late DateTime _date = widget.payment.date;

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await TemplateCalendarPopup.pickDate(context, initial: _date, label: StayQuoteStrings.date, tone: StayCalKit.green);
    if (d != null && mounted) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      tone: ListingTone.forest,
      title: StayQuoteStrings.payment,
      footer: PrimaryButton(
        label: StayQuoteStrings.save,
        tone: StayCalKit.green,
        onPressed: () => Navigator.of(context).pop(QuotePaymentInput(
          label: _label.text.trim().isEmpty ? widget.payment.label : _label.text.trim(),
          date: _date,
          amount: int.tryParse(_amount.text.trim()) ?? 0,
        )),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillField(
            tone: ListingTone.forest,
            controller: _label,
            label: StayQuoteStrings.label,
            maxLength: QuoteLimits.payLabel,
            counterText: '',
            inputFormatters: noEmojiInputFormatters,
          ),
          PillPickerField(tone: ListingTone.forest, label: StayQuoteStrings.date, value: StayQuoteStrings.dayMonthYear(_date), onTap: _pickDate),
          PillField(
            tone: ListingTone.forest,
            controller: _amount,
            label: StayQuoteStrings.amount,
            prefixText: QuoteMoney.fieldPrefix,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          ),
          Gap.v(8),
        ],
      ),
    );
  }
}
