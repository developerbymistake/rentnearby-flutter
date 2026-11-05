import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/gradient_button.dart';
import '../../taxi/taxi_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import '../utils/trip_format.dart';
import 'trip_cancel_sheet.dart';
import 'trip_filter_chips.dart';
import 'trip_sheet_frame.dart';
import 'trip_withdraw_sheet.dart';

enum TripOwnKind { stay, taxi }

class TripOwnBookingSheet {
  static Future<bool> show(
    BuildContext context, {
    required int day,
    TripOwnKind kind = TripOwnKind.stay,
    TripStayChoice? existingStay,
    TripTaxiChoice? existingTaxi,
  }) async {
    if (TripPlanController.to.isReadOnly) return false;
    final ok = await TripSheetFrame.show<bool>(
      context,
      _OwnBody(
        day: day,
        kind: kind,
        existingStay: existingStay?.isOwn == true ? existingStay : null,
        existingTaxi: existingTaxi?.isOwn == true ? existingTaxi : null,
      ),
    );
    return ok == true;
  }
}

class _OwnBody extends StatefulWidget {
  const _OwnBody({required this.day, required this.kind, this.existingStay, this.existingTaxi});

  final int day;
  final TripOwnKind kind;
  final TripStayChoice? existingStay;
  final TripTaxiChoice? existingTaxi;

  @override
  State<_OwnBody> createState() => _OwnBodyState();
}

class _OwnBodyState extends State<_OwnBody> {
  static const _nameMax = 80;
  static const _fareDigits = 7;
  static final _phonePattern = RegExp(r'^[6-9]\d{9}$');
  final _c = TripPlanController.to;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _note;
  late final TextEditingController _fare;
  late bool _allNights;
  late Set<int> _days;
  bool _busy = false;
  TripEnquiryModel? _blockedBy;

  bool get _isTaxi => widget.kind == TripOwnKind.taxi;

  int get _day => widget.day;

  int get _laterNights => _c.dayCount - _day;

  int get _runNights => _c.ownStayNights(_day, allNights: true).length;

  @override
  void initState() {
    super.initState();
    final s = widget.existingStay;
    final t = widget.existingTaxi;
    _name = TextEditingController(text: _isTaxi ? (t?.name ?? '') : (s?.name ?? ''));
    _phone = TextEditingController(text: (_isTaxi ? t?.ownPhone : s?.ownPhone) ?? '');
    _note = TextEditingController(text: (_isTaxi ? t?.note : s?.note) ?? '');
    _fare = TextEditingController(text: t?.fare?.toString() ?? '');
    _allNights = _laterNightsFree();
    _days = _initialDays();
  }

  bool _laterNightsFree() {
    final p = _c.plan.value;
    if (p == null || _laterNights < 1) return false;
    return p.days.where((d) => d.day > _day).every((d) => d.stay == null || d.stay!.sameAsDay == _day);
  }

  bool _dayOpen(int d) => !_c.isDayPast(d) && _c.bookedTaxiEnquiryFor(d) == null;

  Set<int> _initialDays() {
    final p = _c.plan.value;
    if (p == null) return {_day};
    final t = widget.existingTaxi;
    if (t != null) {
      final same = {
        for (final d in p.days)
          if (d.taxi?.isOwn == true && d.taxi!.name == t.name && _dayOpen(d.day)) d.day,
      };
      if (same.isNotEmpty) return same;
    }
    return {
      for (final d in p.days)
        if (_dayOpen(d.day) && (d.day == _day || (d.day > _day && d.taxi == null))) d.day,
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    _fare.dispose();
    super.dispose();
  }

  bool get _valid {
    final phone = _phone.text.trim();
    final fare = _fare.text.trim();
    final fareValue = int.tryParse(fare) ?? 0;
    final fareOk = fare.isEmpty || (fareValue > 0 && fareValue <= TripConstants.maxAmount);
    final daysOk = !_isTaxi || _days.isNotEmpty;
    return _name.text.trim().isNotEmpty && (phone.isEmpty || _phonePattern.hasMatch(phone)) && fareOk && daysOk;
  }

  TripEnquiryModel? _confirmedOnCoveredNights() {
    for (final d in _c.ownStayNights(_day, allNights: _allNights)) {
      for (final e in _c.enquiriesForNight(d)) {
        if (e.isConfirmed) return e;
      }
    }
    return null;
  }

  Future<void> _saveStay() async {
    final allNights = _allNights && _runNights > 1;
    var r = _c.setOwnStay(_day, name: _name.text, phone: _phone.text, note: _note.text, allNights: allNights);
    if (r is OwnNeedsWithdraw) {
      if (!await TripWithdrawSheet.showForRemove(context, open: r.open)) return;
      if (!mounted) return;
      r = _c.setOwnStay(_day, name: _name.text, phone: _phone.text, note: _note.text, allNights: allNights);
    }
    if (!mounted) return;
    if (r is OwnBlockedByConfirmed) {
      setState(() => _blockedBy = _confirmedOnCoveredNights());
      return;
    }
    if (r is OwnSaved) Navigator.pop(context, true);
  }

  void _saveTaxi() {
    final fare = int.tryParse(_fare.text.trim());
    final days = _days.where(_dayOpen).toList()..sort();
    if (days.isEmpty) return;
    _c.setOwnTaxi(days: days, name: _name.text.trim(), phone: _phone.text.trim(), note: _note.text.trim(), farePerDay: fare);
    Navigator.pop(context, true);
  }

  Future<void> _save() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    try {
      if (_isTaxi) {
        _saveTaxi();
      } else {
        await _saveStay();
      }
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

  Future<void> _cancelBooking(TripEnquiryModel e) async {
    final ok = await TripCancelSheet.show(context, enquiry: e, ownerSide: false);
    if (ok && mounted) setState(() => _blockedBy = null);
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _blocked(TripEnquiryModel e) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(TripStrings.cancelBookingFirst,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warningText)),
            const SizedBox(height: 2),
            const Text(TripStringsA2.cancelFirstBody,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.warningText, height: 1.35)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _cancelBooking(e),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44), padding: EdgeInsets.zero),
                child: const Text(TripStringsA2.cancelBooking,
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: AppColors.error)),
              ),
            ),
          ],
        ),
      );

  Widget _dayChips() {
    final n = _c.dayCount;
    final anyOpen = [for (var d = 1; d <= n; d++) d].any(_dayOpen);
    if (!anyOpen) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(TripStringsA2.daysPassed,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textLight)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(TripStringsA2.days,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          children: [
            for (var d = 1; d <= n; d++) _dayChip(d),
          ],
        ),
        if (_days.isEmpty)
          const Text(TripStringsA2.pickADay,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.error)),
      ],
    );
  }

  Widget _dayChip(int d) {
    final open = _dayOpen(d);
    final date = _c.dateOf(d);
    final base = TripStringsA2.dayChip(d);
    final label = !open && _c.bookedTaxiEnquiryFor(d) != null
        ? '$base · ${TripStringsA2.booked}'
        : (date == null ? base : '$base · ${TripFormat.dayMonth(date)}');
    final chip = TripChipView(
      accent: TaxiColors.accent,
      chip: TripFilterChip(
        label: label,
        selected: open && _days.contains(d),
        onTap: () {
          if (!open) return;
          setState(() => _days.contains(d) ? _days.remove(d) : _days.add(d));
        },
      ),
    );
    return open ? chip : Opacity(opacity: 0.45, child: chip);
  }

  @override
  Widget build(BuildContext context) {
    final editing = _isTaxi ? widget.existingTaxi != null : widget.existingStay != null;
    final blocked = _blockedBy;
    return TripSheetFrame(
      title: _isTaxi ? TripStringsA2.haveTaxi : TripStrings.haveStay,
      footer: Text(
        _isTaxi ? TripStringsA2.ownTaxiFooter : TripStrings.ownBookingFooter,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35),
      ),
      children: [
        if (blocked != null) _blocked(blocked),
        TextField(
          controller: _name,
          maxLength: _nameMax,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(_nameMax)],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _decoration(TripStrings.name),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _decoration(TripStrings.phoneOptional).copyWith(prefixText: '+91 '),
        ),
        if (_isTaxi) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _fare,
            keyboardType: TextInputType.number,
            maxLength: _fareDigits,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_fareDigits)],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: _decoration(TripStringsA2.farePerDay).copyWith(prefixText: '₹ '),
          ),
          const SizedBox(height: 12),
          _dayChips(),
        ],
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
        if (!_isTaxi && _runNights > 1)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _allNights,
            activeTrackColor: TripColors.accent,
            onChanged: _busy
                ? null
                : (v) => setState(() {
                      _allNights = v;
                      _blockedBy = null;
                    }),
            secondary: const Icon(Iconsax.moon, size: 20, color: TripColors.accentDark),
            title: Text(TripStringsA2.allNightsOwn(_runNights),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            subtitle: const Text(TripStringsA2.allNightsOwnBody,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ),
        const SizedBox(height: 16),
        GradientButton(
          label: TripStrings.save,
          height: 52,
          isLoading: _busy,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: _valid ? _save : null,
        ),
        if (editing) ...[
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
      ],
    );
  }
}
