import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/input_formatters.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_strings_name.dart';
import '../trip_strings_save_trip.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_clock.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
import '../utils/trip_name_rules.dart';
import '../widgets/trip_update_ask_sheet.dart';

class TripDatesSheet {
  static const Key nameKey = ValueKey('save-trip-name');
  static const Key ctaKey = ValueKey('save-trip-cta');
  static const Key startFieldKey = ValueKey('trip-dates-start');
  static const Key saveNoteKey = ValueKey('save-trip-note');
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

  static Future<bool> saveTrip(BuildContext context) async {
    if (!TripPlanController.to.isNewUnsaved) return false;
    final saved = await Sheet3D.show<bool>(context, builder: (_) => const _DatesBody.saveTrip());
    return saved == true;
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
  const _DatesBody({required this.heading, required this.cta, this.clearStart = false}) : saveTrip = false;

  const _DatesBody.saveTrip()
      : heading = TripStringsSaveTrip.title,
        cta = TripStringsSaveTrip.cta,
        clearStart = false,
        saveTrip = true;

  final String heading;
  final String cta;
  final bool clearStart;
  final bool saveTrip;

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
  final _name = TextEditingController();
  bool _serverRefused = false;

  @override
  void initState() {
    super.initState();
    final s = _c.settings;
    _start = widget.clearStart ? null : s.startDate;
    _adults = s.adults ?? 2;
    _kids = s.kids ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _nameValid => TripNameRules.isValid(_name.text);

  String? get _nameError {
    if (_serverRefused) return TripStringsName.invalid;
    if (TripNameRules.clean(_name.text).isEmpty) return null;
    return TripNameRules.problem(_name.text);
  }

  Future<void> _create() async {
    if (_saving || !_nameValid) return;
    setState(() => _saving = true);
    final r = await _c.createNew(name: _name.text, startDate: _start, adults: _adults, kids: _kids);
    if (!mounted) return;
    if (r == TripCreateOutcome.ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = false;
      _serverRefused = r == TripCreateOutcome.nameRejected;
    });
  }

  Widget _nameField() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillField(
            fieldKey: TripDatesSheet.nameKey,
            tone: _tone,
            controller: _name,
            label: TripStringsSaveTrip.nameLabel,
            autofocus: true,
            enabled: !_saving,
            maxLength: TripNameRules.max,
            counterText: '',
            errorRing: _nameError != null,
            textInputAction: TextInputAction.done,
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripNameRules.max)],
            onChanged: (_) => setState(() => _serverRefused = false),
            onSubmitted: (_) => _create(),
          ),
          FieldMessage(error: _nameError, counter: TripStringsName.counter(_name.text.length), reserve: true),
        ],
      );

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
        if (widget.saveTrip)
          PillPickerField(
            key: TripDatesSheet.startFieldKey,
            tone: _tone,
            label: TripStringsV2Find.startDateOptional,
            raised: true,
            value: start == null ? null : _full(start),
            hint: TripStringsV2Find.pickDate,
            onTap: _saving ? null : _pickDate,
          )
        else
          PillPickerField(
            key: TripDatesSheet.startFieldKey,
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
          padding: EdgeInsets.fromLTRB(DS.s(4), DS.gv(8), DS.s(4), 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: DS.s(18)),
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
    final save = widget.saveTrip;
    final mq = MediaQuery.of(context);
    final cramped = mq.size.height - SheetInsets.lift(context) - mq.viewPadding.top < DS.s(480);
    return Sheet3D(
      tone: _tone,
      art: save ? (cramped ? null : ListingArt.luggage) : ListingArt.calendar,
      title: widget.heading,
      subtitle: save ? null : (widget.clearStart ? TripStringsV2Find.datesPassedSub : TripStringsV2Find.datesSub),
      centerTitle: false,
      padding: DS.sym(h: 18),
      footer: GradientPillButton(
        key: save ? TripDatesSheet.ctaKey : null,
        tone: _tone,
        label: widget.cta,
        loading: _saving,
        height: 52,
        onTap: save ? (_nameValid ? _create : null) : (_start == null ? null : _save),
      ),
      footnote: save ? null : TripStringsV2Find.datesNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (save) ...[_nameField(), Gap.v(4)],
          _dateField(),
          Gap.v(4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _stepper(
                    TripStringsV2Find.adults, _adults, 1, TripDatesSheet._maxAdults, (v) => setState(() => _adults = v)),
              ),
              Gap.h(12),
              Expanded(
                child: _stepper(
                    TripStringsV2Find.children, _kids, 0, TripDatesSheet._maxKids, (v) => setState(() => _kids = v)),
              ),
            ],
          ),
          Gap.v(8),
          if (save)
            Text(
              TripStringsV2Find.datesNote,
              key: TripDatesSheet.saveNoteKey,
              style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub),
            ),
        ],
      ),
    );
  }
}
