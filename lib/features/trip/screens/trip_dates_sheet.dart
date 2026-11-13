import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_clock.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
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
    final saved = await Sheet3D.show<SettingsSaveResult>(
      context,
      builder: (_) => _DatesBody(heading: heading, cta: cta ?? TripStringsV2Find.saveDates, clearStart: clearStart),
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
  static final ListingTone _tone = ListingTone.indigo;
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
    final picked = await TemplateCalendarPopup.pickDate(
      context,
      initial: initial,
      first: today,
      last: today.add(const Duration(days: TripDatesSheet._daysAhead)),
      label: TripStringsV2Find.startDate,
      tone: KitTone.brand,
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


  Widget _dateField() {
    final start = _start;
    final days = _c.dayCount;
    final end = start == null || days < 1 ? null : DateTime(start.year, start.month, start.day + days - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PillPickerField(
          tone: _tone,
          label: TripStringsV2Find.startDate,
          raised: true,
          leadingArt: ListingArt.calendar,
          value: start == null ? null : _full(start),
          hint: TripStringsV2Find.startDate,
          trailing: const SizedBox.shrink(),
          onTap: _saving ? null : _pickDate,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 18),
            child: end != null && days > 0
                ? Text(TripStringsV2Find.daysBack(days, _short(end)), style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub))
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _stepper(String label, int value, int min, int max, ValueChanged<int> onChanged) => StepperField(
        tone: _tone,
        label: label,
        value: value,
        min: min,
        max: max,
        onChanged: _saving ? null : onChanged,
      );

  @override
  Widget build(BuildContext context) {
    return Sheet3D(
      tone: _tone,
      art: ListingArt.calendar,
      title: widget.heading,
      subtitle: widget.clearStart ? TripStringsV2Find.datesPassedSub : TripStringsV2Find.datesSub,
      centerTitle: false,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      footer: GradientPillButton(
        tone: _tone,
        label: widget.cta,
        loading: _saving,
        height: 52,
        onTap: _start == null ? null : _save,
      ),
      footnote: TripStringsV2Find.datesNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dateField(),
          const SizedBox(height: 4),
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
