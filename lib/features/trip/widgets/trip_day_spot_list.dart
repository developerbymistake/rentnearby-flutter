import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_plan_result_model.dart';
import '../screens/trip_edit_spot_sheet.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../trip_strings_wizard.dart';
import '../utils/trip_format.dart';
import 'trip_leg_menu_sheet.dart';
import 'trip_sheet_frame.dart';

class TripDaySpotList extends StatelessWidget {
  final int day;

  const TripDaySpotList(this.day, {super.key});

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
      final readOnly = c.isReadOnly || c.needsUpdate.value || c.isDayPast(day);
      final total = c.dayLoadMinutes(day);
      final over = c.isOverLimit(day);
      final closed = c
          .warningsFor(day)
          .where((w) => w.code == TripWarningCodes.closedDay)
          .map((w) => _closedText(plan, w))
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (d.spots.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: d.spots.length,
              onReorder: (oldIndex, newIndex) {
                if (!readOnly) c.reorder(day, oldIndex, newIndex);
              },
              itemBuilder: (context, i) {
                final s = d.spots[i];
                final isLast = i == d.spots.length - 1;
                return _StopItem(
                  key: ValueKey(s.id),
                  index: i,
                  spot: s,
                  color: color,
                  driveMinutes: isLast ? null : c.legFrom(day, s.id)?.minutes,
                  showDrive: !isLast,
                  readOnly: readOnly,
                  onTap: readOnly ? null : () => _spotMenu(context, c, s),
                );
              },
            ),
          if (d.spots.isNotEmpty) ...[
            const SizedBox(height: 8),
            _loadLine(total, over, c.isEstimate(day), c.dayLimitMinutes),
          ],
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
        ],
      );
    });
  }

  static Future<void> replace(TripPlanController c, String spotId, int day) async {
    final legIndex = c.plan.value?.legIndexOf(day) ?? 1;
    await TripLegMenuSheet.addPlaces(legIndex, pickDay: day, replaceSpotId: spotId);
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
        c.removeSpot(s.id, keepEmptyDays: true);
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

  Widget _loadLine(int total, bool over, bool estimate, int limit) {
    final text = estimate
        ? '${TripFormat.duration(total)} · ${TripStrings.estimate}'
        : TripStringsWizard.dayLoad(TripFormat.duration(total), TripFormat.duration(limit));
    return Row(
      children: [
        Icon(over ? Iconsax.warning_2 : Iconsax.timer_1, size: 14, color: over ? AppColors.warningText : AppColors.textLight),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            over ? '$text · ${TripStringsWizard.overDayLimit}' : text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: over ? AppColors.warningText : AppColors.textMedium,
            ),
          ),
        ),
      ],
    );
  }

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
  final int? driveMinutes;
  final bool showDrive;
  final bool readOnly;
  final VoidCallback? onTap;

  const _StopItem({
    super.key,
    required this.index,
    required this.spot,
    required this.color,
    required this.driveMinutes,
    required this.showDrive,
    required this.readOnly,
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
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        spot.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      TripFormat.visit(spot.visitMinutes),
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
                    ),
                    if (!readOnly)
                      ReorderableDelayedDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.drag_indicator_rounded, size: 20, color: AppColors.textHint),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (showDrive)
            Padding(
              padding: const EdgeInsets.only(left: 11),
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
