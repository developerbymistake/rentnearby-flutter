import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_constants.dart';
import '../../trip/trip_strings.dart';
import '../../trip/utils/trip_format.dart';
import '../../trip/widgets/trip_sheet_frame.dart';
import '../models/stay_owner_model.dart';
import 'stay_enquiries_controller.dart';
import 'stay_enquiry_format.dart';
import 'stay_enquiry_strings.dart';

class TripAskAdvanceSheet {
  static Future<bool> show(BuildContext context, {required TripEnquiryModel enquiry, required StayOwnerModel stay}) async {
    final sent = await TripSheetFrame.show<bool>(context, _AskBody(enquiry: enquiry, stay: stay));
    return sent == true;
  }
}

class _AskBody extends StatefulWidget {
  const _AskBody({required this.enquiry, required this.stay});

  final TripEnquiryModel enquiry;
  final StayOwnerModel stay;

  @override
  State<_AskBody> createState() => _AskBodyState();
}

class _AskBodyState extends State<_AskBody> {
  static const _tone = KitTone.stay;

  final _amount = TextEditingController();
  final _upi = TextEditingController();
  final _wa = TextEditingController();
  late DateTime _hold;
  late final bool _upiFromSetup;
  late final bool _waFromSetup;
  late bool _editUpi;
  late bool _editWa;
  bool _saving = false;
  String? _amountError;
  String? _upiError;
  String? _waError;
  String? _serverError;

  int get _maxAmount => widget.enquiry.agreedTotal ?? TripConstants.maxAmount;

  DateTime get _minHold => DateTime.now().add(const Duration(hours: TripConstants.holdMinHours));

  DateTime get _capHold {
    final now = DateTime.now().toUtc();
    final byTime = now.add(const Duration(hours: TripConstants.holdMaxHours));
    final ci = widget.enquiry.checkIn;
    if (ci == null) return byTime.toLocal();
    // 12:00 IST on the check-in date, the same cut-off the server applies
    final cutoff = DateTime.utc(ci.year, ci.month, ci.day, TripConstants.holdCheckInCutoffHour - 6, 30);
    return (cutoff.isBefore(byTime) ? cutoff : byTime).toLocal();
  }

  bool get _tooLate => !_capHold.isAfter(_minHold.add(const Duration(minutes: 2)));

  @override
  void initState() {
    super.initState();
    final e = widget.enquiry;
    final offered = e.acceptedOffer?.advanceAmount;
    if (offered != null && offered > 0) _amount.text = '${offered > _maxAmount ? _maxAmount : offered}';
    final defaultHold = DateTime.now().add(const Duration(hours: TripConstants.holdDefaultHours));
    _hold = _tooLate ? _capHold : (defaultHold.isAfter(_capHold) ? _capHold : defaultHold);
    final upi = widget.stay.upiId ?? '';
    final wa = widget.stay.whatsAppNumber ?? '';
    _upiFromSetup = upi.isNotEmpty;
    _waFromSetup = wa.isNotEmpty;
    _editUpi = !_upiFromSetup;
    _editWa = !_waFromSetup;
    _upi.text = upi;
    _wa.text = wa.isNotEmpty ? wa : StayEnquiryFormat.accountPhone();
  }

  @override
  void dispose() {
    _amount.dispose();
    _upi.dispose();
    _wa.dispose();
    super.dispose();
  }

  DateTime _clamp(DateTime d) {
    final min = _minHold;
    final cap = _capHold;
    if (d.isBefore(min)) return min;
    if (d.isAfter(cap)) return cap;
    return d;
  }

  Future<void> _pickHold() async {
    final cap = _capHold;
    final now = DateTime.now();
    final date = await TemplateCalendarPopup.pickDate(
      context,
      initial: DateTime(_hold.year, _hold.month, _hold.day),
      first: DateTime(now.year, now.month, now.day),
      last: DateTime(cap.year, cap.month, cap.day),
      label: TripStrings.holdRoomUntil,
      tone: _tone,
    );
    if (date == null || !mounted) return;
    final time = await TemplateTimePopup.pick(
      context,
      initial: TimeOfDay.fromDateTime(_hold),
      label: TripStrings.holdRoomUntil,
      tone: _tone,
    );
    if (time == null || !mounted) return;
    setState(() {
      _hold = _clamp(DateTime(date.year, date.month, date.day, time.hour, time.minute));
      _serverError = null;
    });
  }

  bool _validate() {
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    final upi = _upi.text.trim();
    final wa = _wa.text.trim();
    final upiError = upi.isEmpty ? TripStrings.upiInvalid : StayEnquiryFormat.upiError(upi);
    final waError = wa.isEmpty ? StayEnquiryStrings.phoneInvalid : StayEnquiryFormat.phoneError(wa);
    setState(() {
      _amountError = amount < 1 || amount > _maxAmount ? TripStrings.amountMax(BrowseItem.inr(_maxAmount)) : null;
      _upiError = upiError;
      _waError = waError;
      _serverError = null;
    });
    if (_amountError != null || upiError != null || waError != null) {
      if (_upiFromSetup && !_editUpi && upiError != null) setState(() => _editUpi = true);
      if (_waFromSetup && !_editWa && waError != null) setState(() => _editWa = true);
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (_saving || _tooLate || !_validate()) return;
    var hold = _clamp(_hold);
    // keep a small margin so the server's "now + 1 h" check still passes after the round trip
    final safe = _minHold.add(const Duration(minutes: 2));
    if (hold.isBefore(safe) && !safe.isAfter(_capHold)) hold = safe;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final ctrl = StayEnquiriesController.ensure();
    final ok = await ctrl.askAdvance(
      widget.enquiry.id,
      amount: int.parse(_amount.text.trim()),
      holdUntil: hold,
      upiId: _upi.text.trim(),
      whatsAppNumber: _wa.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      AppToast.success(TripStrings.advanceSent);
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _serverError = ctrl.lastErrorMessage;
      });
    }
  }

  static final ListingTone _look = ListingTone.forest;

  @override
  Widget build(BuildContext context) {
    final bothFromSetup = _upiFromSetup && _waFromSetup;
    return TripSheetFrame(
      tone: _look,
      art: ListingArt.moneyBag,
      title: TripStrings.askForAdvance,
      description: TripStrings.guestAccepted,
      footnote: bothFromSetup ? TripStrings.askFooter : TripStrings.askFooterEmpty,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_serverError != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_serverError!, style: FieldMessage.errorStyle)),
          GradientPillButton(tone: _look, label: TripStrings.sendInChat, loading: _saving, enabled: !_tooLate, onTap: _saving || _tooLate ? null : _submit),
        ],
      ),
      children: [
        PillField(
          tone: _look,
          controller: _amount,
          enabled: !_saving,
          label: TripStrings.amount,
          leadingArt: ListingArt.moneyBag,
          prefixText: '₹ ',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
          errorText: _amountError,
          helperText: TripStrings.amountMax(BrowseItem.inr(_maxAmount)),
          onChanged: (_) => setState(() {
            _amountError = null;
            _serverError = null;
          }),
        ),
        PillPickerField(
          tone: _look,
          label: TripStrings.holdRoomUntil,
          firstLabel: false,
          value: TripFormat.dayTime(_hold),
          leadingArt: ListingArt.calendar,
          trailing: const SizedBox.shrink(),
          errorText: _tooLate ? TripStrings.holdTooLate : null,
          helperText: TripStrings.holdRange(TripFormat.dayTime(_minHold), TripFormat.dayTime(_capHold)),
          enabled: !_saving && !_tooLate,
          onTap: _saving || _tooLate ? null : _pickHold,
        ),
        _editUpi
            ? _field(_upi, TripStrings.yourUpiId, art: ListingArt.key, hint: TripStrings.upiHint, error: _upiError, formatters: StayEnquiryFormat.upiFormatters, keyboard: TextInputType.emailAddress)
            : _fromSetupRow(TripStrings.yourUpiId, TripStrings.upiFromSetup, ListingArt.key, _upi.text.trim(), () => setState(() => _editUpi = true)),
        _editWa
            ? _field(_wa, TripStrings.whatsAppForProof, art: ListingArt.speechBalloon, prefix: '+91 ', error: _waError, formatters: StayEnquiryFormat.phoneFormatters, keyboard: TextInputType.number)
            : _fromSetupRow(TripStrings.whatsAppForProof, TripStrings.whatsAppFromSetup, ListingArt.speechBalloon, '+91 ${_wa.text.trim()}', () => setState(() => _editWa = true)),
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(TripStrings.stayPayLine, style: RepliesLook.foot)),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    required String art,
    required List<TextInputFormatter> formatters,
    required TextInputType keyboard,
    String? prefix,
    String? hint,
    String? error,
  }) =>
      PillField(
        tone: _look,
        controller: ctrl,
        enabled: !_saving,
        label: label,
        firstLabel: false,
        leadingArt: art,
        prefixText: prefix,
        hint: hint,
        errorText: error,
        keyboardType: keyboard,
        inputFormatters: formatters,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: (_) => setState(() {
          _serverError = null;
          _upiError = null;
          _waError = null;
        }),
      );

  Widget _fromSetupRow(String label, String helper, String art, String value, VoidCallback onChange) => PillPickerField(
        tone: _look,
        label: label,
        firstLabel: false,
        value: value,
        leadingArt: art,
        helperText: helper,
        enabled: !_saving,
        onTap: _saving ? null : onChange,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(gradient: _look.gradient, borderRadius: BorderRadius.circular(14)),
          child: Text(TripStrings.change, style: Ink3D.text(12, FontWeight.w700, DesignColors.textInverse, letterSpacing: 0)),
        ),
      );
}
