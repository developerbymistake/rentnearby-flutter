import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_shadows.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../utils/trip_format.dart';

class TripDetailsSheet {
  static Future<TripSettings?> collect(
    BuildContext context, {
    required TripSettings initial,
    required int dayCount,
    bool allowSkip = true,
  }) =>
      _show(context, initial: initial, dayCount: dayCount, endKnown: false, allowSkip: allowSkip);

  static Future<bool> edit(BuildContext context, {String? heading, String? description}) async {
    final c = TripPlanController.to;
    if (c.plan.value == null) return false;
    final result = await _show(
      context,
      initial: c.settings,
      dayCount: c.dayCount,
      endKnown: true,
      allowSkip: false,
      heading: heading,
      description: description,
      startLocked: c.isRunning,
    );
    if (result == null) return false;
    final oldStart = c.settings.startDate;
    final newStart = result.startDate;
    if (oldStart != null && newStart != null && newStart != oldStart) {
      final stale = c.bookingsOutsideDates(newStart);
      if (stale.isNotEmpty) {
        if (!context.mounted) return false;
        final change = await _confirmDates(context, stale.length, TripFormat.dayMonthRange(oldStart, c.settings.endDate(c.dayCount) ?? oldStart));
        if (change != true) return false;
      }
    }
    return c.saveSettings(result);
  }

  static Future<bool?> _confirmDates(BuildContext context, int count, String range) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            TripStrings.bookingsKeepDates,
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17),
          ),
          content: Text(
            TripStrings.bookingsStillSay(count, range),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium),
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

  static Future<TripSettings?> _show(
    BuildContext context, {
    required TripSettings initial,
    required int dayCount,
    required bool endKnown,
    required bool allowSkip,
    String? heading,
    String? description,
    bool startLocked = false,
  }) =>
      showModalBottomSheet<TripSettings>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _DetailsBody(
          initial: initial,
          dayCount: dayCount,
          endKnown: endKnown,
          allowSkip: allowSkip,
          heading: heading,
          description: description,
          startLocked: startLocked,
        ),
      );
}

class _DetailsBody extends StatefulWidget {
  final TripSettings initial;
  final int dayCount;
  final bool endKnown;
  final bool allowSkip;
  final String? heading;
  final String? description;
  final bool startLocked;

  const _DetailsBody({
    required this.initial,
    required this.dayCount,
    required this.endKnown,
    required this.allowSkip,
    this.heading,
    this.description,
    this.startLocked = false,
  });

  @override
  State<_DetailsBody> createState() => _DetailsBodyState();
}

class _DetailsBodyState extends State<_DetailsBody> {
  late DateTime? _start = widget.initial.startDate;
  late int _adults = widget.initial.adults ?? TripConstants.defaultAdults;
  late int _kids = widget.initial.kids ?? 0;
  late int _rooms = widget.initial.rooms ?? TripConstants.defaultRooms;
  late int _pace = widget.initial.dayLimitMinutes == TripPace.relaxed ? TripPace.relaxed : TripPace.normal;
  late final Set<String> _needs = widget.initial.needs.toSet();
  String? _error;

  bool get _datesRequired => widget.heading != null;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

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
    Navigator.pop(
      context,
      TripSettings(
        dayLimitMinutes: _pace,
        startDate: start,
        adults: _adults,
        kids: _kids,
        rooms: _rooms,
        needs: needs,
        pickupTime: base.pickupTime,
        pickupPlace: base.pickupPlace,
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
              const SizedBox(height: 14),
              _card(children: [
                _stepperRow(TripStrings.adults, _adults, 1, TripConstants.maxAdults, (v) => setState(() => _adults = v)),
                const Divider(height: 1, color: AppColors.divider),
                _stepperRow(TripStrings.kids, _kids, 0, TripConstants.maxKids, (v) => setState(() => _kids = v)),
                const Divider(height: 1, color: AppColors.divider),
                _stepperRow(TripStrings.rooms, _rooms, 1, TripConstants.maxRooms, (v) => setState(() => _rooms = v)),
              ]),
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

  Widget _stepperRow(String label, int value, int min, int max, ValueChanged<int> onChanged) {
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
          _stepButton(Icons.remove_rounded, value > min ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
            ),
          ),
          _stepButton(Icons.add_rounded, value < max ? () => onChanged(value + 1) : null),
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
