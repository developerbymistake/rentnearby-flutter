import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/sheets/owner_sheet.dart';
import '../../owner_core/sheets/sheet_disposables.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../availability/taxi_availability_api.dart';
import '../availability/taxi_availability_models.dart';
import '../availability/taxi_availability_store.dart';
import '../strings/taxi_availability_strings.dart';
import '../strings/taxi_calendar_strings.dart';
import '../taxi_driver_deps.dart';
import '../widgets/taxi_widgets.dart';
import 'taxi_calendar_controller.dart';
import 'taxi_calendar_widgets.dart';
import 'taxi_trip_sheet.dart';

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

enum TaxiDayOffAction { save, remove, toBooked }

typedef TaxiDayOffPick = ({TaxiDayOffAction action, String? reason});

enum _Choice { booked, dayOff }

abstract final class TaxiDayFlow {
  static TaxiAvailabilityStore get _store => TaxiAvailabilityStore.ensureRegistered();

  static bool canBook(TaxiCalendarController c, DateTime day) => c.canAddOn(day) && PlanGate.addEnabled(c.entriesFull);

  static Future<void> choose(BuildContext context, {required TaxiCalendarController controller, required DateTime day}) async {
    final d = OwnerDates.only(day);
    if (_store.isOff(d)) return dayOff(context, controller: controller, day: d);
    final book = canBook(controller, d);
    final pick = await OwnerSheet.show<_Choice>(
      context,
      look: TaxiCal.look,
      title: TaxiCalendarStrings.daySheetTitle(d),
      subtitle: TaxiAvailabilityStrings.choiceSub,
      size: SheetSize.hug,
      child: (c) => TaxiRowsCard(
        margin: DS.insets(b: 8),
        rows: [
          TaxiRowData(
            art: ListingArt.taxi,
            title: TaxiAvailabilityStrings.booked,
            sub: TaxiAvailabilityStrings.bookedSub,
            locked: !book,
            semantics: TaxiAvailabilityStrings.booked,
            onTap: book ? () => Navigator.of(c).pop(_Choice.booked) : null,
          ),
          TaxiRowData(
            art: ListingArt.sunrise,
            title: TaxiAvailabilityStrings.dayOff,
            sub: TaxiAvailabilityStrings.dayOffSub,
            semantics: TaxiAvailabilityStrings.dayOff,
            onTap: () => Navigator.of(c).pop(_Choice.dayOff),
          ),
        ],
      ),
    );
    if (pick == null || !context.mounted) return;
    switch (pick) {
      case _Choice.booked:
        await TaxiTripSheet.show(context, controller: controller, date: d);
      case _Choice.dayOff:
        if (!_store.inWindow(d)) {
          if (PlanGate.canUpgrade) {
            PlanGate.seePlus();
          } else {
            AppToast.info(TaxiAvailabilityStrings.outsideWindow);
          }
          return;
        }
        await dayOff(context, controller: controller, day: d);
    }
  }

  static Future<void> dayOff(BuildContext context, {required TaxiCalendarController controller, required DateTime day}) async {
    final store = _store;
    final d = OwnerDates.only(day);
    final off = store.isOff(d);
    final reason = off ? store.value.value?.daysOff[OwnerDates.dayText(d)]?.reason : null;
    final pick = await TaxiDayOffSheet.show(context, day: d, off: off, reason: reason, canBook: off && canBook(controller, d));
    if (pick == null || !context.mounted) return;
    if (pick.action == TaxiDayOffAction.toBooked) {
      await TaxiTripSheet.show(context, controller: controller, date: d);
      return;
    }
    final setOff = pick.action == TaxiDayOffAction.save;
    final r = await store.saveDay(d, off: setOff, reason: pick.reason);
    switch (r) {
      case OwnerOk<TaxiAvailability>():
        AppToast.success(setOff ? TaxiAvailabilityStrings.toastSaved : TaxiAvailabilityStrings.toastRemoved);
        TaxiDriverDeps.refreshHome().ignore();
      case OwnerRefused<TaxiAvailability>():
        _refused(r, store, controller);
      case OwnerOffline<TaxiAvailability>():
      case OwnerFailed<TaxiAvailability>():
        AppToast.error(TaxiAvailabilityStrings.toastFailed);
    }
  }

  static void _refused(OwnerRefused<TaxiAvailability> r, TaxiAvailabilityStore store, TaxiCalendarController controller) {
    if (TaxiHourlyLimit.toastIfLimited(r)) return;
    if (r.statusCode == 429) {
      AppToast.error(OwnerSharedStrings.tooManyTries);
      return;
    }
    switch (r.type) {
      case OwnerErrorTypes.dayOffBooked:
        AppToast.error(TaxiAvailabilityStrings.toastBooked);
        store.refresh(force: true).ignore();
        controller.reload().ignore();
      case OwnerErrorTypes.dayOffPast:
      case OwnerErrorTypes.planFeatureLocked:
      case OwnerErrorTypes.calendarOutsideWindow:
        AppToast.error(TaxiAvailabilityStrings.toastFailed);
        store.refresh(force: true).ignore();
      default:
        AppToast.error(TaxiAvailabilityStrings.toastFailed);
    }
  }
}

abstract final class TaxiDayOffSheet {
  static Future<TaxiDayOffPick?> show(BuildContext context, {required DateTime day, required bool off, String? reason, bool canBook = false}) {
    final text = TextEditingController(text: reason == null ? '' : TaxiReasonText.cut(reason));
    String? typed() => TaxiReasonText.clean(text.text);
    return OwnerSheet.show<TaxiDayOffPick>(
      context,
      look: TaxiCal.look,
      title: TaxiAvailabilityStrings.sheetTitle(day),
      subtitle: TaxiAvailabilityStrings.sheetSub,
      child: (_) => SheetDisposables(notifiers: [text], child: TaxiReasonField(controller: text)),
      footer: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: TaxiAvailabilityStrings.save,
            tone: TaxiCal.kit,
            onPressed: () => Navigator.of(c).pop((action: TaxiDayOffAction.save, reason: typed())),
          ),
          if (canBook) ...[
            Gap.v(8),
            SecondaryButton(
              label: TaxiAvailabilityStrings.changeToBooked,
              tone: TaxiCal.kit,
              onPressed: () => Navigator.of(c).pop((action: TaxiDayOffAction.toBooked, reason: null)),
            ),
          ],
          if (off)
            Padding(
              padding: DS.insets(t: 6),
              child: Center(
                child: InkWell(
                  onTap: () => Navigator.of(c).pop((action: TaxiDayOffAction.remove, reason: null)),
                  child: Padding(
                    padding: DS.sym(h: 6, v: 8),
                    child: Text(TaxiAvailabilityStrings.removeDayOff, style: Ink3D.text(12.5, FontWeight.w600, TaxiCal.accent, letterSpacing: 0)),
                  ),
                ),
              ),
            ),
        ],
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
