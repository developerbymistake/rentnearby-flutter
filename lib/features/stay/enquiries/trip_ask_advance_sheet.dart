import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/gradient_button.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_constants.dart';
import '../../trip/trip_strings.dart';
import '../../trip/utils/trip_format.dart';
import '../../trip/widgets/trip_payment_line.dart';
import '../../trip/widgets/trip_sheet_frame.dart';
import '../models/stay_owner_model.dart';
import '../setup/stay_option_sets.dart';
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
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(_hold.year, _hold.month, _hold.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(cap.year, cap.month, cap.day),
      builder: _themed,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_hold),
      builder: _themed,
    );
    if (time == null || !mounted) return;
    setState(() {
      _hold = _clamp(DateTime(date.year, date.month, date.day, time.hour, time.minute));
      _serverError = null;
    });
  }

  Widget _themed(BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: StayColors.accent)),
        child: child ?? const SizedBox.shrink(),
      );

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

  @override
  Widget build(BuildContext context) {
    final bothFromSetup = _upiFromSetup && _waFromSetup;
    return TripSheetFrame(
      title: TripStrings.askForAdvance,
      description: TripStrings.guestAccepted,
      footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_serverError != null) ...[
          Text(_serverError!, style: const TextStyle(fontSize: 12, color: AppColors.errorText, height: 1.4)),
          const SizedBox(height: 8),
        ],
        GradientButton(
          onPressed: _saving || _tooLate ? null : _submit,
          isLoading: _saving,
          label: TripStrings.sendInChat,
          gradient: StayColors.gradient,
          shadowColor: StayColors.accent,
        ),
        const SizedBox(height: 10),
        Text(bothFromSetup ? TripStrings.askFooter : TripStrings.askFooterEmpty,
            style: const TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.4)),
        const SizedBox(height: 6),
        const TripPaymentLine(),
      ]),
      children: [
        if (_tooLate) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
            child: const Text(TripStrings.holdTooLate,
                style: TextStyle(fontSize: 12, color: AppColors.warningText, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(builder: (context, c) {
          final amount = _amountField();
          final hold = _holdField();
          if (c.maxWidth >= 340) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: amount),
              const SizedBox(width: 10),
              Expanded(child: hold),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [amount, const SizedBox(height: 12), hold]);
        }),
        const SizedBox(height: 12),
        _editUpi
            ? _field(
                _upi,
                TripStrings.yourUpiId,
                hint: TripStrings.upiHint,
                error: _upiError,
                formatters: StayEnquiryFormat.upiFormatters,
                keyboard: TextInputType.emailAddress,
              )
            : _fromSetupRow(TripStrings.upiFromSetup, _upi.text.trim(), () => setState(() => _editUpi = true)),
        const SizedBox(height: 12),
        _editWa
            ? _field(
                _wa,
                TripStrings.whatsAppForProof,
                prefix: '+91 ',
                error: _waError,
                formatters: StayEnquiryFormat.phoneFormatters,
                keyboard: TextInputType.number,
              )
            : _fromSetupRow(TripStrings.whatsAppFromSetup, '+91 ${_wa.text.trim()}', () => setState(() => _editWa = true)),
        const SizedBox(height: 8),
      ],
    );
  }

  InputDecoration _dec(String label, {String? prefix, String? hint, String? error, String? helper}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        errorText: error,
        errorMaxLines: 2,
        helperText: helper,
        helperMaxLines: 2,
        counterText: '',
        filled: true,
        fillColor: StayColors.surface,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StayColors.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    required List<TextInputFormatter> formatters,
    required TextInputType keyboard,
    String? prefix,
    String? hint,
    String? error,
  }) =>
      TextField(
        controller: ctrl,
        enabled: !_saving,
        keyboardType: keyboard,
        inputFormatters: formatters,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: (_) => setState(() {
          _serverError = null;
          _upiError = null;
          _waError = null;
        }),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: _dec(label, prefix: prefix, hint: hint, error: error),
      );

  Widget _amountField() => TextField(
        controller: _amount,
        enabled: !_saving,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
        onChanged: (_) => setState(() {
          _amountError = null;
          _serverError = null;
        }),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: _dec(
          TripStrings.amount,
          prefix: '₹ ',
          error: _amountError,
          helper: TripStrings.amountMax(BrowseItem.inr(_maxAmount)),
        ),
      );

  Widget _holdField() => InkWell(
        onTap: _saving || _tooLate ? null : _pickHold,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: _dec(
            TripStrings.holdRoomUntil,
            helper: TripStrings.holdRange(TripFormat.dayTime(_minHold), TripFormat.dayTime(_capHold)),
          ),
          child: Text(TripFormat.dayTime(_hold),
              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _fromSetupRow(String label, String value, VoidCallback onChange) => Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: StayColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ]),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44), foregroundColor: StayColors.accentDark),
            onPressed: _saving ? null : onChange,
            child: const Text(TripStrings.change, style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}
