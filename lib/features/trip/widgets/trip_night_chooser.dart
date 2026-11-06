import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import '../trip_strings_fin_a1.dart';
import '../trip_strings_wizard.dart';
import '../utils/trip_format.dart';
import 'trip_change_request_sheet.dart';
import 'trip_sheet_frame.dart';
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

  static Future<void> askAddNight(BuildContext context, TripPlanController c, int day, TripEnquiryModel e) async {
    final out = e.acceptedOffer?.checkOut ?? e.checkOut;
    if (out == null) return;
    final sent = await TripChangeRequestSheet.show(
      context,
      enquiry: e,
      checkOut: DateTime(out.year, out.month, out.day + 1),
      title: TripStringsFinA1.askHostAddNight(e.listingName, day),
    );
    if (sent) await c.refreshEnquiries();
  }


  static Future<bool> _clearOpen(BuildContext context, TripPlanController c, int day) async {
    final open = c.enquiriesForNight(day).where((e) => e.isUnconfirmed).toList();
    if (open.isEmpty) return true;
    return TripWithdrawSheet.showForRemove(context, open: open);
  }

  static Future<bool> confirmReplaceOwn(BuildContext context, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStringsWizard.keep,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStringsWizard.replace,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: AppColors.error)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  static Future<bool> noStay(BuildContext context, int day) async {
    final c = TripPlanController.to;
    var block = c.canSkipNight(day);
    if (block == NoStayBlock.readOnly) return false;
    if (block == NoStayBlock.hasEnquiry) {
      final open = c.enquiriesForNight(day).where((e) => e.isUnconfirmed).toList();
      if (open.isEmpty) {
        AppToast.warning(TripStringsWizard.nightHasEnquiry(day));
        return false;
      }
      if (!await _clearOpen(context, c, day) || !context.mounted) return false;
      block = c.canSkipNight(day);
      if (block == NoStayBlock.hasEnquiry) {
        AppToast.warning(TripStringsWizard.nightHasEnquiry(day));
        return false;
      }
    }
    var replaceOwn = false;
    if (block == NoStayBlock.hasOwn) {
      final own = c.ownStayOf(day);
      if (!await confirmReplaceOwn(context, TripStringsWizard.replaceOwnStay(own?.name ?? '')) || !context.mounted) return false;
      replaceOwn = true;
    }
    final choice = await _noStaySheet(context, c, day, day == c.dayCount);
    if (choice == null) return false;
    final moved = choice.leave && c.steps.comingBack.leaveOn != TripLeaveOn.lastDayEvening;
    final r = c.setSkippedNight(day, note: choice.note, replaceOwn: replaceOwn, leaveMoved: moved);
    if (r == NoStayBlock.hasEnquiry) {
      AppToast.warning(TripStringsWizard.nightHasEnquiry(day));
      return false;
    }
    if (r != NoStayBlock.none) return false;
    if (choice.leave) unawaited(c.setLeaveOn(TripLeaveOn.lastDayEvening));
    return true;
  }

  static void undoNoStay(int day) {
    final c = TripPlanController.to;
    final moved = c.plan.value?.dayAt(day)?.stay?.leaveMoved ?? false;
    c.clearSkippedNight(day);
    if (moved && c.steps.comingBack.leaveOn == TripLeaveOn.lastDayEvening) unawaited(c.setLeaveOn(TripLeaveOn.checkOut));
  }

  static Future<({String? note, bool leave})?> _noStaySheet(
      BuildContext context, TripPlanController c, int day, bool last) {
    final note = TextEditingController();
    final date = c.dateOf(day);
    return TripSheetFrame.show<({String? note, bool leave})>(
      context,
      Builder(
        builder: (sheetCtx) {
          ({String? note, bool leave}) result(bool leave) {
            final t = note.text.trim();
            return (note: t.isEmpty ? null : t, leave: leave);
          }

          return TripSheetFrame(
            title: TripStringsWizard.noStayTitle(day),
            description: TripStringsWizard.noStayHint,
            children: [
              TextField(
                controller: note,
                maxLength: 120,
                inputFormatters: noEmojiInputFormatters,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: const InputDecoration(hintText: TripStringsWizard.noteHint, counterText: ''),
              ),
              const SizedBox(height: 12),
              _sheetOption(Iconsax.moon, TripStrings.noStayTonight, TripStringsWizard.noStaySleepElsewhere,
                  () => Navigator.pop(sheetCtx, result(false))),
              if (last)
                _sheetOption(
                    Iconsax.home_2,
                    TripStringsWizard.leaveOnDay(day),
                    date == null
                        ? TripStringsWizard.leaveSameEvening
                        : '${TripStringsWizard.leaveSameEvening} · ${TripFormat.shortDate(date)}',
                    () => Navigator.pop(sheetCtx, result(true))),
            ],
          );
        },
      ),
    ).whenComplete(note.dispose);
  }

  static Widget _sheetOption(IconData icon, String label, String hint, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 19, color: StayColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      Text(hint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  static Future<void> pick(BuildContext context, int day, TripNightMode mode) async {
    final c = TripPlanController.to;
    final current = modeOf(c, day);
    if (mode == current) return;
    switch (mode) {
      case TripNightMode.same:
        final change = c.sameStayNeedsChange(day);
        if (change != null) {
          await askAddNight(context, c, day, change);
          return;
        }
        if (baseOf(c, day) == null) {
          AppToast.warning(TripStringsA2.noBaseStay);
          return;
        }
        if (!await _clearOpen(context, c, day)) return;
        if (current == TripNightMode.none) undoNoStay(day);
        if (!c.setSameAsLastNight(day) && c.sameStayNeedsChange(day) == null) AppToast.warning(TripStringsA2.noBaseStay);
      case TripNightMode.none:
        if (!context.mounted) return;
        await noStay(context, day);
      case TripNightMode.nightByNight:
        if (current == TripNightMode.none) {
          undoNoStay(day);
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
        onTap: () => pick(context, day, value),
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
