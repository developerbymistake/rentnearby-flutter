import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import 'trip_withdraw_sheet.dart';

enum TripNightMode { same, nightByNight, none }

class TripNightChooser extends StatelessWidget {
  const TripNightChooser({super.key, required this.day});

  final int day;

  static TripStayChoice? baseOf(TripPlanController c, int day) {
    final p = c.plan.value;
    if (day <= 1 || p == null || p.legIndexOf(day - 1) != p.legIndexOf(day)) return null;
    final prev = p.dayAt(day - 1)?.stay;
    if (prev == null || prev.isSkipped) return null;
    return prev;
  }

  static TripNightMode modeOf(TripPlanController c, int day) {
    final cur = c.plan.value?.dayAt(day)?.stay;
    if (cur == null) return TripNightMode.nightByNight;
    if (cur.isSkipped) return TripNightMode.none;
    final same = cur.sameAsDay;
    if (same != null && same < day) return TripNightMode.same;
    return TripNightMode.nightByNight;
  }

  static bool isBooked(TripPlanController c, int day) =>
      c.enquiriesForNight(day).any((e) => e.isConfirmed);

  static bool visible(TripPlanController c, int day) =>
      !c.isReadOnly && !c.isDayPast(day) && c.plan.value?.dayAt(day) != null && !isBooked(c, day);

  Future<bool> _clearOpen(BuildContext context, TripPlanController c) async {
    final open = c.enquiriesForNight(day).where((e) => e.isUnconfirmed).toList();
    if (open.isEmpty) return true;
    return TripWithdrawSheet.showForRemove(context, open: open);
  }

  Future<void> _pick(BuildContext context, TripNightMode mode) async {
    final c = TripPlanController.to;
    final current = modeOf(c, day);
    if (mode == current) return;
    switch (mode) {
      case TripNightMode.same:
        if (baseOf(c, day) == null) {
          AppToast.warning(TripStringsA2.noBaseStay);
          return;
        }
        if (!await _clearOpen(context, c)) return;
        if (current == TripNightMode.none) c.clearSkippedNight(day);
        if (!c.setSameAsLastNight(day)) AppToast.warning(TripStringsA2.noBaseStay);
      case TripNightMode.none:
        if (!await _clearOpen(context, c)) return;
        c.setSkippedNight(day);
      case TripNightMode.nightByNight:
        if (current == TripNightMode.none) {
          c.clearSkippedNight(day);
        } else {
          c.clearStay(day);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.plan.value;
      c.enquiryList.length;
      if (!visible(c, day)) return const SizedBox.shrink();
      final mode = modeOf(c, day);
      final base = baseOf(c, day);
      final segments = <Widget>[
        if (base != null)
          _segment(context, TripNightMode.same, TripStrings.sameAsLastNight, base.name, mode),
        _segment(context, TripNightMode.nightByNight, TripStrings.nightByNight, null, mode),
        _segment(context, TripNightMode.none, TripStrings.noStayTonight, null, mode),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(TripStringsA2.forThisNight,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
          const SizedBox(height: 6),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < segments.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: segments[i]),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _segment(BuildContext context, TripNightMode value, String label, String? sub, TripNightMode mode) {
    final on = value == mode;
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(context, value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: on ? StayColors.surface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? StayColors.accent : AppColors.divider, width: on ? 1.5 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: on ? StayColors.accentDark : AppColors.textMedium)),
              if (sub != null && sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: AppColors.textLight)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
