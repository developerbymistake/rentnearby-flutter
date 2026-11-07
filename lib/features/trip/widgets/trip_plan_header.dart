import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_strings_v2_plan.dart';
import '../utils/trip_easy_rules.dart';
import '../utils/trip_format.dart';
import 'trip_card.dart';
import 'trip_pace_sheet.dart';
import 'trip_status.dart';

enum TripPlanMenu { saveExit, editDays, editDates, rename, summary, map, mute, complete, delete, easy }

class TripPlanHeader extends StatelessWidget {
  final ValueChanged<TripPlanMenu> onMenu;

  const TripPlanHeader({super.key, required this.onMenu});

  static String subtitleOf(TripPlanController c) {
    final p = c.plan.value;
    if (p == null) return '';
    final s = c.settings;
    final today = c.todayDay;
    final todayDate = today == null ? null : c.dateOf(today);
    if (today != null && todayDate != null) {
      return TripStringsV2Plan.headerRunning(today, c.dayCount, TripFormat.shortDate(todayDate));
    }
    final start = s.startDate;
    final end = s.endDate(c.dayCount);
    if (start == null || end == null) {
      return TripStringsV2Plan.headerSub(c.dayCount, c.spotCount, p.legCount);
    }
    return TripStringsV2Plan.headerDated(c.dayCount, TripFormat.dayMonthRange(start, end), s.peopleSummary);
  }

  static TripBookingState stateOf(TripPlanController c) {
    final t = c.trip.value;
    if (c.isCompleted) return TripBookingState.completed;
    if (t == null) return TripBookingState.draft;
    final s = TripBookingState.parse(t.bookingState);
    return s == TripBookingState.planOnly ? TripBookingState.draft : s;
  }

  static String? hintOf(TripPlanController c, List<TripEasyRowInfo> rows) {
    if (c.offline.value || c.saveFailed.value) return TripStringsV2Plan.hintSavedOnPhone;
    final changed = c.settingsChangedAt.value;
    if (changed != null && DateTime.now().difference(changed).inMinutes < 10) return TripStringsV2Plan.hintDatesChanged;
    if (rows.isEmpty) return null;
    final bad = rows.where((r) => r.state == TripRowState.attention).firstOrNull;
    if (bad != null) return TripStringsV2Plan.hintAttention;
    final offer = rows.where((r) => r.state == TripRowState.offer).firstOrNull;
    if (offer != null) return TripStringsV2Plan.hintOffer;
    final asked = TripEasyRules.firstInProgress(rows);
    if (asked != null) {
      return switch (asked.key.kind) {
        TripEasyRowKind.stay => TripStringsV2Plan.hintStayWaiting,
        TripEasyRowKind.taxi => TripStringsV2Plan.hintTaxiWaiting,
        _ => TripStringsV2Plan.hintWaiting,
      };
    }
    final progress = c.easyProgress;
    if (progress.total > 0 && progress.done >= progress.total) return TripStringsV2Plan.hintAllSet;
    return TripStringsV2Plan.hintMakeItEasy;
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: TripColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(4, top + 6, 4, 12),
      child: Obx(() {
        final plan = c.plan.value;
        c.trip.value;
        c.needsUpdate.value;
        c.result.value;
        c.enquiryList.length;
        c.offline.value;
        c.saveFailed.value;
        c.settingsChangedAt.value;
        c.isOpening.value;
        final off = c.plannerOff.value;
        final ready = plan != null && !off;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        plan == null ? TripStringsV2Plan.trip : c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      if (ready)
                        Text(
                          subtitleOf(c),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                    ],
                  ),
                ),
                if (ready) ...[
                  if (c.editMode.value)
                    TextButton(
                      onPressed: () => c.editMode.value = false,
                      style: TextButton.styleFrom(minimumSize: const Size(56, 44), foregroundColor: Colors.white),
                      child: const Text(TripStringsV2Plan.done,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700)),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => onMenu(TripPlanMenu.map),
                      style: TextButton.styleFrom(minimumSize: const Size(56, 44), foregroundColor: Colors.white),
                      icon: const Icon(Iconsax.map, size: 17, color: Colors.white),
                      label: const Text(TripStringsV2Plan.map,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  _menu(c),
                ],
              ],
            ),
            if (ready) _statusRow(context, c),
          ],
        );
      }),
    );
  }

  Widget _statusRow(BuildContext context, TripPlanController c) {
    final rows = c.easyRows;
    final progress = c.stepProgress;
    final step = c.isCompleted ? 2 : c.planStep.value;
    final hint = hintOf(c, rows);
    final state = stateOf(c);
    final editable = !c.isReadOnly && !c.needsUpdate.value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onMenu(TripPlanMenu.easy),
      child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          TripProgressRing(
            percent: progress.percent,
            size: 44,
            stroke: 4,
            color: Colors.white,
            track: Colors.white.withValues(alpha: 0.28),
            textColor: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  step == 1
                      ? TripStringsV2Plan.stepAddPlaces()
                      : '${TripStringsV2Plan.stepLabel(2)} · ${progress.total == 0 ? TripStringsV2Plan.nothingToArrange : TripStringsV2Plan.arranged(progress.done, progress.total)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                if (hint != null && step == 2)
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.percent.clamp(0, 100) / 100,
                    minHeight: 4,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TripBookingStatePill(state),
              const SizedBox(height: 6),
              _paceChip(context, c, editable),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _paceChip(BuildContext context, TripPlanController c, bool editable) {
    final label = c.settings.isRelaxed ? TripStringsV2Plan.paceRelaxed : TripStringsV2Plan.paceNormal;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: editable
          ? () async {
              final picked = await TripPaceSheet.show(context);
              if (picked != null) await c.setPace(picked);
            }
          : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.timer_1, size: 13, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              if (editable) const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menu(TripPlanController c) {
    return PopupMenuButton<TripPlanMenu>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onMenu,
      itemBuilder: (_) {
        final saved = c.trip.value != null;
        final editable = !c.isReadOnly && !c.needsUpdate.value;
        return [
          if (editable) _item(TripPlanMenu.saveExit, Iconsax.tick_square, TripStringsV2Plan.menuSaveExit),
          if (editable) _item(TripPlanMenu.editDays, Iconsax.calendar_edit, TripStringsV2Plan.menuEditDays),
          if (editable) _item(TripPlanMenu.editDates, Iconsax.calendar_1, TripStringsV2Plan.menuEditDates),
          if (editable) _item(TripPlanMenu.rename, Iconsax.edit_2, TripStringsV2Plan.menuRename),
          if (saved) _item(TripPlanMenu.summary, Iconsax.receipt_text, TripStringsV2Plan.menuSummary),
          _item(TripPlanMenu.map, Iconsax.map, TripStringsV2Plan.menuMap),
          if (saved) _muteItem(c),
          if (saved && c.canComplete) _item(TripPlanMenu.complete, Iconsax.tick_circle, TripStringsV2Plan.menuComplete),
          if (saved) _item(TripPlanMenu.delete, Iconsax.trash, TripStringsV2Plan.menuDelete, color: AppColors.error),
        ];
      },
    );
  }

  PopupMenuItem<TripPlanMenu> _item(TripPlanMenu value, IconData icon, String label, {Color color = AppColors.textDark}) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: color)),
          ],
        ),
      );

  PopupMenuItem<TripPlanMenu> _muteItem(TripPlanController c) {
    final muted = c.trip.value?.isMuted ?? false;
    return PopupMenuItem(
      value: TripPlanMenu.mute,
      height: 52,
      child: Row(
        children: [
          const Icon(Iconsax.notification, size: 18, color: AppColors.textDark),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  TripStringsV2Plan.menuMute,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textDark),
                ),
                Text(
                  TripStringsV2Plan.menuMuteSub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          IgnorePointer(child: Switch(value: muted, activeThumbColor: TripColors.accent, onChanged: (_) {})),
        ],
      ),
    );
  }
}
