import 'package:flutter/material.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_strings_wizard.dart';
import 'trip_night_chooser.dart';
import 'trip_sheet_frame.dart';
import 'trip_withdraw_sheet.dart';

class TripNoTaxiFlow {
  const TripNoTaxiFlow._();

  // Open asks are withdrawn first, an own taxi is replaced only after a confirm, then an optional note. True when saved.
  static Future<bool> run(BuildContext context, int d) async {
    final c = TripPlanController.to;
    var block = c.canSkipTaxiDay(d);
    if (block == NoTaxiBlock.readOnly) return false;
    if (block == NoTaxiBlock.hasEnquiry) {
      final open = c.taxiEnquiriesForDay(d).where((e) => e.isWithdrawable).toList();
      if (open.isEmpty) {
        AppToast.warning(TripStringsWizard.dayHasDriver(d));
        return false;
      }
      if (!await TripWithdrawSheet.showForRemove(context, open: open) || !context.mounted) return false;
      block = c.canSkipTaxiDay(d);
      if (block == NoTaxiBlock.hasEnquiry) {
        AppToast.warning(TripStringsWizard.dayHasDriver(d));
        return false;
      }
    }
    var replaceOwn = false;
    if (block == NoTaxiBlock.hasOwn) {
      final own = c.ownTaxiOf(d);
      if (!await TripNightChooser.confirmReplaceOwn(context, TripStringsWizard.replaceOwnTaxi(own?.name ?? '')) ||
          !context.mounted) {
        return false;
      }
      replaceOwn = true;
    }
    final note = await noteSheet(context, TripStringsWizard.noTaxiTitle(d));
    if (note == null) return false;
    final r = c.setSkippedTaxiDay(d, note: note.isEmpty ? null : note, replaceOwn: replaceOwn);
    if (r == NoTaxiBlock.hasEnquiry) {
      AppToast.warning(TripStringsWizard.dayHasDriver(d));
      return false;
    }
    return r == NoTaxiBlock.none;
  }

  static Future<String?> noteSheet(BuildContext context, String title) {
    final note = TextEditingController();
    return TripSheetFrame.show<String>(
      context,
      Builder(
        builder: (sheetCtx) => TripSheetFrame(
          title: title,
          children: [
            TextField(
              controller: note,
              maxLength: 120,
              inputFormatters: noEmojiInputFormatters,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: const InputDecoration(hintText: TripStringsWizard.noteHint, counterText: ''),
            ),
            const SizedBox(height: 12),
            GradientButton(
              label: TripStringsWizard.save,
              height: 48,
              gradient: TripColors.gradient,
              shadowColor: TripColors.accent,
              onPressed: () => Navigator.pop(sheetCtx, note.text.trim()),
            ),
          ],
        ),
      ),
    ).whenComplete(note.dispose);
  }
}
