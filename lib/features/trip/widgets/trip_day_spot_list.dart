import 'package:flutter/material.dart';
import 'trip_update_ask_sheet.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_plan_result_model.dart';
import '../models/trip_spot_category.dart';
import '../screens/trip_edit_spot_sheet.dart';
import '../trip_colors.dart';
import '../trip_strings_v2_plan.dart';
import '../trip_strings_wizard.dart';
import '../utils/trip_day_load.dart';
import '../utils/trip_day_timeline.dart';
import '../utils/trip_days_rules.dart';
import '../utils/trip_format.dart';
import 'trip_leg_menu_sheet.dart';
import 'trip_sheet_frame.dart';

class TripDaySpotList extends StatelessWidget {
  final int day;

  const TripDaySpotList(this.day, {super.key});

  static Future<void> replace(TripPlanController c, String spotId, int day) async {
    final legIndex = c.plan.value?.legIndexOf(day) ?? 1;
    await TripLegMenuSheet.addPlaces(legIndex, pickDay: day, replaceSpotId: spotId);
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    final color = TripColors.dayColor(day);
    return Obx(() {
      final plan = c.plan.value;
      c.result.value;
      c.trip.value;
      final d = plan?.dayAt(day);
      if (plan == null || d == null) return const SizedBox.shrink();
      final locked = c.isReadOnly || c.needsUpdate.value || c.isDayPast(day);
      final editing = c.editMode.value && !locked;
      final closed = [
        for (final w in c.warningsFor(day))
          if (w.code == TripWarningCodes.closedDay) _closedText(plan, w),
      ];
      final full = !TripDaysRules.canAddOnDay(plan, day);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: locked || c.editMode.value ? null : () => c.editMode.value = true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(c, plan, d, color, editing),
              const SizedBox(height: 4),
              if (d.spots.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    d.restDay ? TripStringsV2Plan.restDay : TripStringsV2Plan.noPlacesThisDay,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight),
                  ),
                )
              else
                _spots(context, c, plan, d, color, locked, editing),
              for (final text in closed)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Iconsax.warning_2, size: 14, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(text,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.warningText)),
                      ),
                    ],
                  ),
                ),
              if (editing) _editFooter(context, c, plan, d, full),
            ],
          ),
        ),
      );
    });
  }

  Widget _header(TripPlanController c, TripPlan plan, TripDay d, Color color, bool editing) {
    final date = c.dateOf(day);
    final dateText = date == null ? null : TripFormat.shortDate(date);
    final load = c.dayLoadMinutes(day);
    final over = d.spots.isNotEmpty && TripDayLoad.isOver(load, c.settings.dayLimitMinutes);
    final title = d.spots.isEmpty
        ? TripStringsV2Plan.dayHeaderEmpty(day, dateText)
        : TripStringsV2Plan.dayHeader(day, dateText, TripFormat.duration(load));
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: over ? AppColors.warningText : AppColors.textDark),
          ),
        ),
        if (over)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(20)),
            child: const Text(
              TripStringsV2Plan.longDay,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warningText),
            ),
          ),
        if (editing && plan.legDayCount(d.leg) > 1)
          GestureDetector(
            onTap: () => _removeDay(c),
            behavior: HitTestBehavior.opaque,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                margin: const EdgeInsets.only(left: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.errorSurface, borderRadius: BorderRadius.circular(20)),
                  child: const Text(
                    TripStringsV2Plan.removeDay,
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.errorText),
                  ),
                ),
              ),
            ),
          ),
        if (plan.isMultiCity)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                c.cityNameOf(day),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textLight),
              ),
            ),
          ),
      ],
    );
  }

  Widget _spots(
    BuildContext context,
    TripPlanController c,
    TripPlan plan,
    TripDay d,
    Color color,
    bool locked,
    bool editing,
  ) {
    final roads = <int?>[
      for (var i = 0; i < d.spots.length; i++) i == d.spots.length - 1 ? null : c.legFrom(day, d.spots[i].id)?.minutes,
    ];
    final reserved = c.dayReservedMinutes(day);
    final starts = TripDayTimeline.starts(
      visits: [for (final s in d.spots) s.visitMinutes],
      roads: roads,
      reserved: reserved,
    );
    final travel = reserved > 0 && plan.legIndexOf(day) >= 2 && plan.legStart(plan.legIndexOf(day)) == day;
    final k = plan.legIndexOf(day);
    final prev = travel ? plan.legAt(k - 1)?.cityName : null;
    Widget item(int i) {
      final s = d.spots[i];
      return _StopItem(
        key: ValueKey(s.id),
        index: i,
        spot: s,
        color: color,
        time: TripDayTimeline.clock(starts[i]),
        driveMinutes: roads[i],
        showDrive: i != d.spots.length - 1,
        editing: editing,
        onRemove: () => _remove(context, c, d, i),
        onTap: editing ? () => _spotMenu(context, c, s) : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (travel && prev != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Iconsax.car, size: 13, color: AppColors.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    TripStringsV2Plan.travelRow(prev, plan.legAt(k)?.cityName ?? '', TripFormat.duration(reserved)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                  ),
                ),
              ],
            ),
          ),
        if (editing)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: d.spots.length,
            onReorder: (o, n) => c.reorder(day, o, n),
            itemBuilder: (_, i) => item(i),
          )
        else
          for (var i = 0; i < d.spots.length; i++) item(i),
      ],
    );
  }

  void _remove(BuildContext context, TripPlanController c, TripDay d, int index) {
    final spot = d.spots[index];
    c.removeSpot(spot.id, keepEmptyDays: true);
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(
      SnackBar(
        content: const Text(TripStringsV2Plan.placeRemoved, style: TextStyle(fontFamily: 'Poppins')),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: TripStringsV2Plan.undo, onPressed: () => c.insertSpotAt(spot, day, index)),
      ),
    );
  }

  Widget _editFooter(BuildContext context, TripPlanController c, TripPlan plan, TripDay d, bool full) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            _action(
              Iconsax.add_circle,
              TripStringsV2Plan.addPlace,
              full ? null : () => TripLegMenuSheet.addPlaces(d.leg, pickDay: day),
            ),
            if (d.spots.isEmpty)
              _action(
                Iconsax.moon,
                d.restDay ? TripStringsV2Plan.undoRestDay : TripStringsV2Plan.makeRestDay,
                () => c.setRestDay(day, !d.restDay),
              ),
          ],
        ),
        if (full)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    TripStringsV2Plan.dayFull,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.warningText),
                  ),
                ),
                TextButton(
                  onPressed: c.canAddDay
                      ? () {
                          c.addDay(afterDay: day);
                          TripUpdateAskSheet.afterDaysEdit();
                        }
                      : null,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: const Text(
                    TripStringsV2Plan.addDay,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: TripColors.accentDark),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _removeDay(TripPlanController c) {
    final r = c.removeDay(day);
    final text = switch (r) {
      TripDayRemoveBlock.none => null,
      TripDayRemoveBlock.placesDontFit => TripStringsV2Plan.removePlacesFirst,
      TripDayRemoveBlock.lastDay => TripStringsV2Plan.lastDay,
      TripDayRemoveBlock.readOnly => TripStringsV2Plan.readOnlyDay,
    };
    if (text != null) {
      _toast(text);
    } else {
      TripUpdateAskSheet.afterDaysEdit();
    }
  }

  void _toast(String text) {
    final m = Get.context == null ? null : ScaffoldMessenger.maybeOf(Get.context!);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(text, style: const TextStyle(fontFamily: 'Poppins'))));
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap, {Color color = TripColors.accentDark}) {
    final fg = onTap == null ? AppColors.textHint : color;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
      icon: Icon(icon, size: 17, color: fg),
      label: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Future<void> _spotMenu(BuildContext context, TripPlanController c, TripSpotRef s) async {
    final choice = await TripSheetFrame.show<String>(
      context,
      Builder(
        builder: (sheetCtx) => TripSheetFrame(
          title: s.name,
          children: [
            _menuRow(sheetCtx, Iconsax.refresh, TripStringsWizard.replacePlace, 'replace'),
            _menuRow(sheetCtx, Iconsax.calendar_edit, TripStringsWizard.moveToDay, 'move'),
            _menuRow(sheetCtx, Iconsax.trash, TripStringsWizard.removePlace, 'remove', color: AppColors.error),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'replace':
        await replace(c, s.id, day);
      case 'move':
        await TripEditSpotSheet.show(context, s.id);
      case 'remove':
        final i = c.plan.value?.dayAt(day)?.spots.indexWhere((x) => x.id == s.id) ?? -1;
        if (i >= 0) _remove(context, c, c.plan.value!.dayAt(day)!, i);
    }
  }

  Widget _menuRow(BuildContext ctx, IconData icon, String label, String value, {Color color = AppColors.textDark}) =>
      InkWell(
        onTap: () => Navigator.pop(ctx, value),
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: color)),
              ),
            ],
          ),
        ),
      );

  String _closedText(TripPlan plan, TripWarning w) {
    final id = w.spotId;
    final name = id == null ? null : plan.spotById(id)?.name;
    return name == null ? w.message : TripStringsWizard.closedThatDay(name);
  }
}

class _StopItem extends StatelessWidget {
  final int index;
  final TripSpotRef spot;
  final Color color;
  final String time;
  final int? driveMinutes;
  final bool showDrive;
  final bool editing;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const _StopItem({
    super.key,
    required this.index,
    required this.spot,
    required this.color,
    required this.time,
    required this.driveMinutes,
    required this.showDrive,
    required this.editing,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final drive = driveMinutes;
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    if (editing)
                      ReorderableDelayedDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.drag_indicator_rounded, size: 22, color: AppColors.textHint),
                        ),
                      ),
                    SizedBox(
                      width: 62,
                      child: Text(
                        time,
                        maxLines: 1,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            spot.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                          ),
                          Text(
                            '${TripSpotCategory.label(spot.category)} · ${TripFormat.visit(spot.visitMinutes)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                    if (editing)
                      IconButton(
                        onPressed: onRemove,
                        tooltip: TripStringsV2Plan.removePlace,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.error),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (showDrive)
            Padding(
              padding: const EdgeInsets.only(left: 73),
              child: Container(
                padding: const EdgeInsets.only(left: 19, top: 2, bottom: 2),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: color.withValues(alpha: 0.35), width: 2)),
                ),
                child: drive == null
                    ? const SizedBox(height: 14)
                    : Row(
                        children: [
                          const Icon(Iconsax.car, size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            TripFormat.duration(drive),
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
