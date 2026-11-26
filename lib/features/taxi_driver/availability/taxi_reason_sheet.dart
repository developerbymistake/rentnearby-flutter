import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/design.dart';
import '../../../utils/input_formatters.dart';
import '../../owner_core/sheets/owner_sheet.dart';
import '../../owner_core/sheets/sheet_disposables.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../calendar/taxi_calendar_widgets.dart';
import '../calendar/taxi_trip_sheet.dart';
import '../strings/taxi_availability_strings.dart';
import '../strings/taxi_calendar_strings.dart';
import 'taxi_availability_controller.dart';
import 'taxi_availability_models.dart';

class TaxiReasonLimit extends TextInputFormatter {
  const TaxiReasonLimit([this.max = TaxiReasonText.max]);

  final int max;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.runes.length <= max) return newValue;
    final cut = String.fromCharCodes(newValue.text.runes.take(max));
    final at = math.min(math.max(newValue.selection.baseOffset, 0), cut.length);
    return TextEditingValue(text: cut, selection: TextSelection.collapsed(offset: at));
  }
}

abstract final class TaxiReasonSheet {
  static Future<TaxiReasonAction?> show(BuildContext context, {required DateTime day, required bool off, String? reason}) {
    final text = TextEditingController(text: reason == null ? '' : TaxiReasonText.cut(reason));
    String? typed() => TaxiReasonText.clean(text.text);
    return OwnerSheet.show<TaxiReasonAction>(
      context,
      look: TaxiCal.look,
      title: TaxiCalendarStrings.daySheetTitle(day),
      subtitle: off ? TaxiAvailabilityStrings.sheetSubOff : TaxiAvailabilityStrings.sheetSubFree,
      child: (_) => SheetDisposables(notifiers: [text], child: TaxiReasonField(controller: text)),
      footer: (c) => off
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  label: TaxiAvailabilityStrings.saveReason,
                  tone: TaxiCal.kit,
                  onPressed: () => Navigator.of(c).pop(TaxiReasonAction.saveReason(typed())),
                ),
                Gap.v(8),
                SecondaryButton(
                  label: TaxiAvailabilityStrings.makeAvailable,
                  tone: TaxiCal.kit,
                  onPressed: () => Navigator.of(c).pop(const TaxiReasonAction.makeAvailable()),
                ),
              ],
            )
          : PrimaryButton(
              label: TaxiAvailabilityStrings.markOff,
              tone: TaxiCal.kit,
              onPressed: () => Navigator.of(c).pop(TaxiReasonAction.mark(typed())),
            ),
    );
  }
}

class TaxiReasonField extends StatelessWidget {
  const TaxiReasonField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final n = TaxiReasonText.length(value.text);
        final full = n >= TaxiReasonText.max;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TaxiTripFields.label(TaxiAvailabilityStrings.reason, caption: TaxiCalendarStrings.optional),
            TaxiInput(
              controller: controller,
              maxLines: 3,
              hintText: TaxiAvailabilityStrings.reasonHint,
              alert: full,
              inputFormatters: [...noEmojiInputFormatters, const TaxiReasonLimit()],
              semanticsLabel: TaxiAvailabilityStrings.reason,
            ),
            Padding(
              padding: EdgeInsets.only(top: DS.gv(6)),
              child: Row(
                children: [
                  Expanded(child: Text(OwnerSharedStrings.onlyYouSee, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0))),
                  Text(
                    full ? TaxiAvailabilityStrings.counterLimit : TaxiAvailabilityStrings.counter(n),
                    style: Ink3D.text(11, FontWeight.w500, full ? DesignColors.error : Ink3D.grey, letterSpacing: 0),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
