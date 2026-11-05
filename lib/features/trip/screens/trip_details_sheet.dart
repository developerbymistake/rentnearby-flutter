import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_shadows.dart';
import '../../../config/module_palette.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../../../widgets/selectable_chip.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';
import '../trip_strings_g3.dart';
import '../trip_strings_steps_a2.dart';
import '../utils/trip_format.dart';
import '../utils/trip_clock.dart';
import '../widgets/trip_change_request_sheet.dart';
import '../widgets/trip_step_card.dart';
import '../widgets/trip_status.dart';

class TripDetailsSheet {
  static Future<TripSettings?> collect(
    BuildContext context, {
    required TripSettings initial,
    required int dayCount,
    int spotCount = 0,
    bool allowSkip = true,
  }) async {
    final r = await _show(context, initial: initial, dayCount: dayCount, spotCount: spotCount, endKnown: false, allowSkip: allowSkip);
    return r?.settings;
  }

  static Future<bool> edit(BuildContext context, {String? heading, String? description}) async {
    final c = TripPlanController.to;
    if (c.plan.value == null || c.isReadOnly) return false;
    final old = c.settings;
    final result = await _show(
      context,
      initial: old,
      dayCount: c.dayCount,
      spotCount: c.spotCount,
      endKnown: true,
      allowSkip: false,
      heading: heading,
      description: description,
      startLocked: c.isRunning,
      showStartFrom: true,
      initialStart: c.startFrom,
      showDays: !c.isMultiCity,
    );
    if (result == null) return false;
    final moved = result.startFromTouched && await c.setStartFrom(result.startFrom);
    if (!context.mounted) return false;
    final saved = await _saveSettings(context, c, old, result.settings);
    if (moved && context.mounted) await TripStepCard.askSearchAgain(context);
    return saved;
  }

  static Future<bool> _saveSettings(BuildContext context, TripPlanController c, TripSettings old, TripSettings result) async {
    final newStart = result.startDate;
    final daysCut = result.maxDays != old.maxDays && c.daysAfterLimit(result.maxDays) < c.dayCount;
    if (newStart != null && (newStart != old.startDate || daysCut)) {
      final impact = c.dateChangeImpact(newStart, days: c.daysAfterLimit(result.maxDays));
      if (!impact.isEmpty) {
        if (!context.mounted) return false;
        final change = await _confirmDates(context, impact);
        if (change != true) return false;
      }
    }
    final res = await c.saveSettings(result);
    if (!res.saved) return false;
    if (res.openAffected.isNotEmpty) AppToast.info(TripStringsA4.openSentOld);
    if (res.confirmedAffected.isNotEmpty && context.mounted) {
      await _askChangeRequest(context, old, result, res.confirmedAffected);
    }
    return true;
  }

  static Future<void> _askChangeRequest(
    BuildContext context,
    TripSettings old,
    TripSettings next,
    List<TripEnquiryModel> affected,
  ) async {
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          TripStringsA4.hostsStillHave(old.peopleSummary ?? TripStringsA4.notSet, old.roomsSummary ?? ''),
          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17),
        ),
        content: const Text(
          TripStringsA4.sendChangeQ,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(
              TripStringsA4.later,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textLight),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(
              TripStringsA4.sendChangeRequest,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark),
            ),
          ),
        ],
      ),
    );
    if (send != true || !context.mounted) return;
    var target = affected.first;
    if (affected.length > 1) {
      final picked = await showDialog<TripEnquiryModel>(
        context: context,
        builder: (ctx) => SimpleDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            TripStringsA4.whichBooking,
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17),
          ),
          children: [
            for (final e in affected)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, e),
                child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44), child: _BookingLine(e)),
              ),
          ],
        ),
      );
      if (picked == null || !context.mounted) return;
      target = picked;
    }
    await TripChangeRequestSheet.show(context, enquiry: target, prefill: next);
  }

  static Future<bool?> _confirmDates(BuildContext context, DateChangeImpact impact) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            impact.booked.isEmpty ? TripStringsG3.asksCloseTitle : TripStringsA4.datesTitle,
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
              minWidth: double.maxFinite,
              maxWidth: double.maxFinite,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in [
                    (impact.booked, TripStringsG3.bookedKeep(impact.booked.length)),
                    (impact.open, TripStringsG3.asksClose(impact.open.length)),
                  ])
                    if (group.$1.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          group.$2,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium),
                        ),
                      ),
                      for (final e in group.$1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _BookingLine(e),
                        ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 4,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
              child: const Text(
                TripStrings.keepDates,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textLight),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
              child: const Text(
                TripStrings.changeDates,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark),
              ),
            ),
          ],
        ),
      );

  static Future<_DetailsResult?> _show(
    BuildContext context, {
    required TripSettings initial,
    required int dayCount,
    required int spotCount,
    required bool endKnown,
    required bool allowSkip,
    String? heading,
    String? description,
    bool startLocked = false,
    bool showStartFrom = false,
    TripStartFrom? initialStart,
    bool showDays = true,
  }) =>
      showModalBottomSheet<_DetailsResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _DetailsBody(
          initial: initial,
          dayCount: dayCount,
          spotCount: spotCount,
          endKnown: endKnown,
          allowSkip: allowSkip,
          heading: heading,
          description: description,
          startLocked: startLocked,
          showStartFrom: showStartFrom,
          initialStart: initialStart,
          showDays: showDays,
        ),
      );
}

typedef _DetailsResult = ({TripSettings settings, TripStartFrom? startFrom, bool startFromTouched});

class _BookingLine extends StatelessWidget {
  final TripEnquiryModel e;

  const _BookingLine(this.e);

  @override
  Widget build(BuildContext context) {
    final name = e.listingName.isEmpty ? (e.isTaxi ? TripStrings.driver : TripStrings.stay) : e.listingName;
    return Row(
      children: [
        Icon(e.isTaxi ? Iconsax.car : Iconsax.building_4, size: 16, color: AppColors.textMedium),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              Text(
                e.datesLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(child: TripStatusPill(e.display, taxi: e.isTaxi)),
      ],
    );
  }
}

class _DetailsBody extends StatefulWidget {
  final TripSettings initial;
  final int dayCount;
  final int spotCount;
  final bool endKnown;
  final bool allowSkip;
  final String? heading;
  final String? description;
  final bool startLocked;
  final bool showStartFrom;
  final TripStartFrom? initialStart;
  final bool showDays;

  const _DetailsBody({
    required this.initial,
    required this.dayCount,
    required this.spotCount,
    required this.endKnown,
    required this.allowSkip,
    this.heading,
    this.description,
    this.startLocked = false,
    this.showStartFrom = false,
    this.initialStart,
    this.showDays = true,
  });

  @override
  State<_DetailsBody> createState() => _DetailsBodyState();
}

class _DetailsBodyState extends State<_DetailsBody> {
  late DateTime? _start = widget.initial.startDate;
  late int? _adults = widget.initial.adults;
  late int? _kids = widget.initial.kids;
  late int? _rooms = widget.initial.rooms;
  late int? _maxDays = widget.initial.maxDays;
  late int _pace = widget.initial.dayLimitMinutes == TripPace.relaxed ? TripPace.relaxed : TripPace.normal;
  late final Set<String> _needs = widget.initial.needs.toSet();
  late TripStartFrom? _startFrom = widget.initialStart;
  bool _startTouched = false;
  String? _error;

  bool get _datesRequired => widget.heading != null;

  DateTime get _today => TripClock.today();

  Future<void> _pickStart() async {
    FocusScope.of(context).unfocus();
    final today = _today;
    final current = _start;
    final first = current != null && current.isBefore(today) ? current : today;
    final last = today.add(const Duration(days: TripConstants.maxStartDaysAhead));
    var initial = current ?? today;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last.isBefore(initial) ? initial : last,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: TripColors.accent)),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _start = DateTime(picked.year, picked.month, picked.day);
      _error = null;
    });
  }

  String? _validate() {
    final start = _start;
    if (start == null) return _datesRequired ? TripStrings.errPickStart : null;
    final changed = start != widget.initial.startDate;
    if (!changed) return null;
    final today = _today;
    if (start.isBefore(today)) return TripStrings.errStartPast;
    if (start.isAfter(today.add(const Duration(days: TripConstants.maxStartDaysAhead)))) return TripStrings.errStartFar;
    return null;
  }

  void _save() {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final start = _start;
    final needs = [for (final n in TripNeeds.all) if (_needs.contains(n)) n];
    final base = widget.initial;
    final _DetailsResult result = (
      settings: TripSettings(
        dayLimitMinutes: _pace,
        startDate: start,
        adults: _adults,
        kids: _kids,
        rooms: _rooms,
        needs: needs,
        pickupTime: base.pickupTime,
        pickupPlace: base.pickupPlace,
        maxDays: _maxDays,
      ),
      startFrom: _startFrom,
      startFromTouched: _startTouched,
    );
    Navigator.pop(context, result);
  }

  Future<void> _pickStartFrom() async {
    FocusScope.of(context).unfocus();
    final p = await LocationSwitchSheet.pick(context, palette: ModulePalette.trip, title: TripStringsStepsA2.pickCity);
    if (p == null || !mounted) return;
    setState(() {
      _startFrom = TripStartFrom(name: p.name, lat: p.latitude, lon: p.longitude);
      _startTouched = true;
    });
  }

  Widget _startFromRow() {
    final start = _startFrom;
    return Material(
      color: TripColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _pickStartFrom,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TripColors.accentLight.withValues(alpha: 0.7), width: 1.3),
          ),
          child: Row(
            children: [
              const Icon(Iconsax.location, size: 20, color: TripColors.accentDark),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      TripStringsStepsA2.startingFrom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.warningText,
                      ),
                    ),
                    Text(
                      start?.name ?? TripStringsStepsA2.notSet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: start == null ? AppColors.textLight : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      start == null ? TripStringsStepsA2.pickCity : TripStringsStepsA2.change,
                      maxLines: 1,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripColors.accentDark),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime? get _end {
    final s = _start;
    if (s == null || !widget.endKnown) return null;
    final n = widget.dayCount < 1 ? 1 : widget.dayCount;
    return DateTime(s.year, s.month, s.day + n - 1);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, media.viewInsets.bottom + AppInsets.bottomViewPadding(context) + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.heading ?? TripStrings.tripDetails,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              if (widget.description != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.description!,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                ),
              ],
              const SizedBox(height: 16),
              _datesRow(),
              if (widget.startLocked) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Iconsax.lock, size: 14, color: AppColors.textLight),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        TripStrings.tripRunning,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                      ),
                    ),
                  ],
                ),
              ],
              if (widget.showStartFrom) ...[
                const SizedBox(height: 10),
                _startFromRow(),
                const SizedBox(height: 6),
                const Text(
                  TripStringsStepsA2.startFromHelp,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
                ),
              ],
              const SizedBox(height: 14),
              _card(children: [
                _stepperRow(TripStrings.adults, _adults, 1, TripConstants.maxAdults, (v) => setState(() => _adults = v)),
                const Divider(height: 1, color: AppColors.divider),
                _stepperRow(TripStrings.kids, _kids, 0, TripConstants.maxKids, (v) => setState(() => _kids = v),
                    unsetShowsMin: true),
                const Divider(height: 1, color: AppColors.divider),
                _stepperRow(TripStrings.rooms, _rooms, 1, TripConstants.maxRooms, (v) => setState(() => _rooms = v)),
              ]),
              const SizedBox(height: 6),
              const Text(
                TripStringsA4.peopleHelp,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
              ),
              if (widget.showDays && widget.spotCount > 0) ...[
                const SizedBox(height: 16),
                _label(TripStringsA4.days),
                const SizedBox(height: 2),
                const Text(
                  TripStringsA4.daysHelp,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                ),
                const SizedBox(height: 8),
                _daysRow(),
              ],
              const SizedBox(height: 16),
              _label(TripStrings.pace),
              const SizedBox(height: 8),
              _paceRow(),
              const SizedBox(height: 16),
              _label(TripStrings.needs),
              const SizedBox(height: 4),
              for (final key in TripNeeds.all) _needRow(key),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Iconsax.info_circle, size: 14, color: AppColors.error),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              GradientButton(
                label: TripStrings.saveDetails,
                height: 52,
                gradient: TripColors.gradient,
                shadowColor: TripColors.accent,
                onPressed: _save,
              ),
              if (widget.allowSkip)
                Align(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text(
                      TripStrings.skipForNow,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textLight),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                TripStrings.detailsFooter,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
      );

  Widget _card({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.06, blur: 10, offset: const Offset(0, 3)),
        ),
        child: Column(children: children),
      );

  Widget _datesRow() {
    final start = _start;
    final end = _end;
    final startTile = _dateTile(
      label: TripStrings.start,
      value: start == null ? TripStrings.pickDate : TripFormat.shortDate(start),
      muted: start == null,
      onTap: widget.startLocked ? null : _pickStart,
      icon: Iconsax.calendar_1,
    );
    final endTile = _dateTile(
      label: TripStrings.end,
      value: end == null ? TripStrings.followsDays : TripFormat.shortDate(end),
      muted: true,
      icon: Iconsax.calendar_tick,
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 340) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Expanded(child: startTile), const SizedBox(width: 12), Expanded(child: endTile)],
            ),
          );
        }
        return Column(children: [startTile, const SizedBox(height: 10), endTile]);
      },
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required bool muted,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final active = onTap != null;
    return Material(
      color: active ? TripColors.surface : AppColors.neutralChip,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: active ? TripColors.accentDark : AppColors.textHint),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
                      ),
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: muted ? AppColors.textLight : AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _daysRow() {
    final top = widget.spotCount < TripConstants.maxDaysCap ? widget.spotCount : TripConstants.maxDaysCap;
    final locked = widget.startLocked;
    Widget chip(String label, int? value) => SelectableChip(
          label: label,
          selected: _maxDays == value,
          onTap: locked ? () {} : () => setState(() => _maxDays = value),
          activeColor: TripColors.accent,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(TripStringsA4.auto, null),
        for (var n = 1; n <= top; n++) chip('$n', n),
      ],
    );
  }

  Widget _stepperRow(String label, int? value, int min, int max, ValueChanged<int> onChanged,
      {bool unsetShowsMin = false}) {
    final shown = value ?? (unsetShowsMin ? min : null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ),
          _stepButton(Icons.remove_rounded, shown != null && shown > min ? () => onChanged(shown - 1) : null),
          SizedBox(
            width: 56,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                shown == null ? TripStringsA4.notSet : '$shown',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: shown == null ? 12 : 16,
                  fontWeight: FontWeight.w700,
                  color: shown == null ? AppColors.textHint : AppColors.textDark,
                ),
              ),
            ),
          ),
          _stepButton(
            Icons.add_rounded,
            shown == null ? () => onChanged(min) : (shown < max ? () => onChanged(shown + 1) : null),
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return SizedBox(
      width: 44,
      height: 44,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? TripColors.surface : AppColors.neutralChip,
              border: Border.all(color: enabled ? TripColors.accent.withValues(alpha: 0.5) : AppColors.divider),
            ),
            child: Icon(icon, size: 18, color: enabled ? TripColors.accentDark : AppColors.textHint),
          ),
        ),
      ),
    );
  }

  Widget _paceRow() {
    final normal = _paceTile(TripStrings.paceNormalOption, TripPace.normal);
    final relaxed = _paceTile(TripStrings.paceRelaxedOption, TripPace.relaxed);
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 340) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Expanded(child: normal), const SizedBox(width: 12), Expanded(child: relaxed)],
            ),
          );
        }
        return Column(children: [normal, const SizedBox(height: 10), relaxed]);
      },
    );
  }

  Widget _paceTile(String label, int value) {
    final selected = _pace == value;
    return Material(
      color: selected ? TripColors.surface : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => setState(() => _pace = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? TripColors.accent : AppColors.divider, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? TripColors.accentDark : AppColors.textDark,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                const Icon(Iconsax.tick_circle5, size: 18, color: TripColors.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _needRow(String key) {
    final on = _needs.contains(key);
    return InkWell(
      onTap: () => setState(() => on ? _needs.remove(key) : _needs.add(key)),
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Checkbox(
                value: on,
                activeColor: TripColors.accent,
                onChanged: (v) => setState(() => v == true ? _needs.add(key) : _needs.remove(key)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                TripNeeds.label(key),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
