import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import 'trip_cancel_sheet.dart';
import 'trip_sheet_frame.dart';
import 'trip_withdraw_sheet.dart';

enum TripOwnKind { stay, taxi }

class _Copy {
  static const String nameOptional = 'Name (optional)';
  static const String allOptional = 'All optional';
  static const String phoneHint = 'Needs a 10 digit number';
  static const String cantChange = "This day can't be changed.";
}

class TripOwnBookingSheet {
  // One tap marks the day or night as your own; the sheet that follows only adds optional details.
  static Future<bool> show(
    BuildContext context, {
    required int day,
    TripOwnKind kind = TripOwnKind.stay,
    TripStayChoice? existingStay,
    TripTaxiChoice? existingTaxi,
  }) async {
    final c = TripPlanController.to;
    if (c.isReadOnly) return false;
    final editing = kind == TripOwnKind.taxi ? existingTaxi?.isOwn == true : existingStay?.isOwn == true;
    if (!editing && !await _mark(context, c, day, kind)) return false;
    if (!context.mounted) return true;
    await TripSheetFrame.show<bool>(context, _OwnBody(day: day, kind: kind));
    return true;
  }

  static bool _sameCity(TripPlanController c, int a, int b) => c.legIndexOf(a) == c.legIndexOf(b);

  static bool _dayOpen(TripPlanController c, int d) => !c.isDayPast(d) && c.bookedTaxiEnquiryFor(d) == null;

  static List<int> defaultTaxiDays(TripPlanController c, int day) {
    final p = c.plan.value;
    if (p == null) return [day];
    final days = [
      for (final d in p.days)
        if (_dayOpen(c, d.day) && _sameCity(c, d.day, day) && (d.day == day || (d.day > day && d.taxi == null))) d.day,
    ];
    return days.isEmpty ? [day] : days;
  }

  static bool _sameOwn(TripTaxiChoice? a, TripTaxiChoice b) =>
      a != null && a.isOwn && a.name == b.name && a.ownPhone == b.ownPhone && a.note == b.note;

  static List<int> ownTaxiDays(TripPlanController c, int day) {
    final p = c.plan.value;
    final mine = p?.dayAt(day)?.taxi;
    if (p == null || mine == null || !mine.isOwn) return [day];
    final days = [
      for (final d in p.days)
        if (d.day == day || (_sameOwn(d.taxi, mine) && _dayOpen(c, d.day) && _sameCity(c, d.day, day))) d.day,
    ];
    return days..sort();
  }

  static bool ownStayAllNights(TripPlanController c, int day) =>
      c.plan.value?.days.any((d) => d.day > day && d.stay?.sameAsDay == day) ?? false;

  static Future<bool> _mark(BuildContext context, TripPlanController c, int day, TripOwnKind kind) async {
    final taxi = kind == TripOwnKind.taxi;
    final days = taxi ? defaultTaxiDays(c, day) : const <int>[];
    final allNights = !taxi && c.ownStayNights(day, allNights: true).length > 1;
    OwnSaveResult run({bool close = false}) => taxi
        ? c.setOwnTaxi(days: days, name: '', legDay: day, closeOpen: close)
        : c.setOwnStay(day, name: '', allNights: allNights, closeOpen: close);
    var r = run();
    if (r is OwnNeedsWithdraw) {
      if (!await TripWithdrawSheet.confirmInline(context) || !context.mounted) return false;
      r = run(close: true);
    }
    if (r is OwnBlockedByConfirmed) {
      if (!context.mounted) return false;
      final cancelled = await TripSheetFrame.show<bool>(context, _BlockedBody(enquiry: r.e));
      if (cancelled != true || !context.mounted) return false;
      r = run();
    }
    if (r is OwnNothingToSave) {
      AppToast.warning(_Copy.cantChange);
      return false;
    }
    return r is OwnSaved;
  }
}

class _BlockedBody extends StatelessWidget {
  const _BlockedBody({required this.enquiry});

  final TripEnquiryModel enquiry;

  @override
  Widget build(BuildContext context) => TripSheetFrame(
        title: TripStrings.cancelBookingFirst,
        description: TripStringsA2.cancelFirstBody,
        children: [
          GradientButton(
            label: TripStringsA2.cancelBooking,
            height: 52,
            gradient: TripColors.gradient,
            shadowColor: TripColors.accent,
            onPressed: () async {
              final ok = await TripCancelSheet.show(context, enquiry: enquiry, ownerSide: false);
              if (ok && context.mounted) Navigator.pop(context, true);
            },
          ),
        ],
      );
}

class _OwnBody extends StatefulWidget {
  const _OwnBody({required this.day, required this.kind});

  final int day;
  final TripOwnKind kind;

  @override
  State<_OwnBody> createState() => _OwnBodyState();
}

class _OwnBodyState extends State<_OwnBody> {
  static const _nameMax = 80;
  final _c = TripPlanController.to;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _note;
  bool _busy = false;

  bool get _isTaxi => widget.kind == TripOwnKind.taxi;

  int get _day => widget.day;

  @override
  void initState() {
    super.initState();
    final d = _c.plan.value?.dayAt(_day);
    final t = d?.taxi?.isOwn == true ? d!.taxi : null;
    final s = d?.stay?.isOwn == true ? d!.stay : null;
    _name = TextEditingController(text: (_isTaxi ? t?.name : s?.name) ?? '');
    _phone = TextEditingController(text: (_isTaxi ? t?.ownPhone : s?.ownPhone) ?? '');
    _note = TextEditingController(text: (_isTaxi ? t?.note : s?.note) ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _phoneHint => _phone.text.trim().isNotEmpty && TripOwnPhone.normalise(_phone.text) == null;

  OwnSaveResult _write() {
    final name = _name.text.trim();
    final phone = TripOwnPhone.normalise(_phone.text);
    final note = _note.text.trim();
    OwnSaveResult run() => _isTaxi
        ? _c.setOwnTaxi(
            days: TripOwnBookingSheet.ownTaxiDays(_c, _day),
            name: name,
            phone: phone,
            note: note,
            legDay: _day,
            closeOpen: true,
          )
        : _c.setOwnStay(
            _day,
            name: name,
            phone: phone,
            note: note,
            allNights: TripOwnBookingSheet.ownStayAllNights(_c, _day),
            closeOpen: true,
          );
    return run();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = _write();
      if (!mounted) return;
      if (r is OwnBlockedByConfirmed) {
        AppToast.warning(TripStringsA2.cancelFirstBody);
        return;
      }
      if (r is OwnNothingToSave) {
        AppToast.warning(_Copy.cantChange);
        return;
      }
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove() {
    if (_isTaxi) {
      _c.clearOwnTaxi(_day);
    } else {
      _c.clearOwnStay(_day);
    }
    Navigator.pop(context, true);
  }

  InputDecoration _decoration(String label, {String? helper, String? prefix}) => InputDecoration(
        labelText: label,
        counterText: '',
        helperText: helper,
        prefixText: prefix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    return TripSheetFrame(
      title: _isTaxi ? TripStringsA2.haveTaxi : TripStrings.haveStay,
      description: _Copy.allOptional,
      children: [
        TextField(
          controller: _name,
          maxLength: _nameMax,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(_nameMax)],
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _decoration(_Copy.nameOptional),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 12,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _decoration(TripStrings.phoneOptional, prefix: '+91 ', helper: _phoneHint ? _Copy.phoneHint : null),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLength: TripConstants.noteMax,
          minLines: 1,
          maxLines: 3,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.noteMax)],
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _decoration(TripStrings.note),
        ),
        const SizedBox(height: 16),
        GradientButton(
          label: TripStrings.save,
          height: 52,
          isLoading: _busy,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: _busy ? null : _save,
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _remove,
            style: TextButton.styleFrom(minimumSize: const Size(88, 44)),
            child: const Text(TripStrings.remove,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.error)),
          ),
        ),
      ],
    );
  }
}
