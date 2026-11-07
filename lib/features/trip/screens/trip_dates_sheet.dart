import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_clock.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_sheet_frame.dart';
import '../widgets/trip_update_ask_sheet.dart';

class TripDatesSheet {
  static const int _maxAdults = 30;
  static const int _maxKids = 20;
  static const int _daysAhead = 365;

  static Future<bool> ensure(BuildContext context, {required String heading, String? cta}) async {
    final c = TripPlanController.to;
    if (c.plan.value == null || c.isReadOnly) return false;
    final s = c.settings;
    if (s.hasDates && s.hasPeople) {
      final stale = TripDatesRules.isStale(s.startDate, TripClock.today(), c.enquiryList.any((e) => e.isOpen));
      if (!stale) return true;
      return _show(context, heading: TripStringsV2Find.pickNewDates, cta: cta, clearStart: true);
    }
    return _show(context, heading: heading, cta: cta);
  }

  static Future<bool> edit(BuildContext context) async {
    final c = TripPlanController.to;
    if (c.plan.value == null || c.isReadOnly) return false;
    return _show(context, heading: TripStringsV2Find.datesTitle, cta: TripStringsV2Find.saveDates);
  }

  static Future<bool> _show(BuildContext context, {required String heading, String? cta, bool clearStart = false}) async {
    final saved = await TripSheetFrame.show<SettingsSaveResult>(
      context,
      _DatesBody(heading: heading, cta: cta ?? TripStringsV2Find.saveDates, clearStart: clearStart),
    );
    if (saved == null || !saved.saved) return false;
    if (saved.hasAffected && context.mounted) await TripUpdateAskSheet.show(context, saved);
    return true;
  }
}

class _DatesBody extends StatefulWidget {
  const _DatesBody({required this.heading, required this.cta, this.clearStart = false});

  final String heading;
  final String cta;
  final bool clearStart;

  @override
  State<_DatesBody> createState() => _DatesBodyState();
}

class _DatesBodyState extends State<_DatesBody> {
  final _c = TripPlanController.to;
  late DateTime? _start;
  late int _adults;
  late int _kids;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = _c.settings;
    _start = widget.clearStart ? null : s.startDate;
    _adults = s.adults ?? 2;
    _kids = s.kids ?? 0;
  }

  Future<void> _pickDate() async {
    final today = TripClock.today();
    final initial = _start == null || _start!.isBefore(today) ? today : _start!;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: TripDatesSheet._daysAhead)),
    );
    if (picked != null && mounted) setState(() => _start = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _save() async {
    final start = _start;
    if (start == null || _saving) return;
    setState(() => _saving = true);
    final res = await _c.saveSettings(_c.settings.copyWith(startDate: start, adults: _adults, kids: _kids));
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, res);
  }

  static String _short(DateTime d) => TripFormat.shortDate(d).replaceFirst(' ', ', ');

  static String _full(DateTime d) => '${_short(d)} ${d.year}';

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
      );

  Widget _dateField() {
    final start = _start;
    final days = _c.dayCount;
    final end = start == null || days < 1 ? null : DateTime(start.year, start.month, start.day + days - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(TripStringsV2Find.startDate),
        InkWell(
          onTap: _saving ? null : _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.calendar_1, size: 16, color: TripColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(start == null ? TripStringsV2Find.startDate : _full(start),
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: start == null ? AppColors.textHint : AppColors.textDark)),
                ),
              ],
            ),
          ),
        ),
        if (end != null && days > 0) ...[
          const SizedBox(height: 6),
          Text(TripStringsV2Find.daysBack(days, _short(end)),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
        ],
      ],
    );
  }

  Widget _stepper(String label, int value, int min, int max, ValueChanged<int> onChanged) {
    Widget btn(IconData icon, bool enabled, VoidCallback onTap) => SizedBox(
          width: 40,
          height: 44,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: enabled && !_saving ? onTap : null,
            icon: Icon(icon, size: 22, color: enabled ? TripColors.accentDark : AppColors.textHint),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        Container(
          decoration: BoxDecoration(
            color: AppColors.scaffoldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              btn(Icons.remove_circle_outline, value > min, () => onChanged(value - 1)),
              Text('$value',
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              btn(Icons.add_circle_outline, value < max, () => onChanged(value + 1)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return TripSheetFrame(
      title: widget.heading,
      description: widget.clearStart ? TripStringsV2Find.datesPassedSub : TripStringsV2Find.datesSub,
      children: [
        _dateField(),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _stepper(
                  TripStringsV2Find.adults, _adults, 1, TripDatesSheet._maxAdults, (v) => setState(() => _adults = v)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _stepper(
                  TripStringsV2Find.children, _kids, 0, TripDatesSheet._maxKids, (v) => setState(() => _kids = v)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GradientButton(
          label: widget.cta,
          height: 52,
          isLoading: _saving,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: _start == null ? null : _save,
        ),
        const SizedBox(height: 8),
        const Text(TripStringsV2Find.datesNote,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
      ],
    );
  }
}
