import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import '../../../models/browse_item.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_strings_mcc_a3.dart';
import '../utils/trip_enquiry_rules.dart';
import '../widgets/trip_cancel_sheet.dart';
import '../widgets/trip_leg_menu_sheet.dart';
import '../widgets/trip_withdraw_sheet.dart';
import '../widgets/trip_wrong_city_strip.dart';
import 'trip_dates_sheet.dart';

class TripRepliesLegParts {
  static String? legLine(TripPlanController c, int day) {
    if (!c.isMultiCity) return null;
    final days = c.legDays(c.legIndexOf(day));
    if (days.isEmpty) return null;
    return TripStringsMccA3.legLine(c.legOf(day).cityName, days.first, days.last);
  }

  static Widget? wrongCityStrip(BuildContext context, TripPlanController c, TripEnquiryModel e) {
    if (!e.isOpen) return null;
    final info = c.wrongCityOf(e);
    if (info == null) return null;
    final live = !c.isReadOnly;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TripWrongCityStrip(
        enquiry: e,
        info: info,
        dense: true,
        onCancel: live
            ? () => e.isBooked
                ? TripCancelSheet.show(context, enquiry: e, ownerSide: false)
                : TripWithdrawSheet.show(context, enquiry: e)
            : null,
        onChangeDays: live
            ? () => c.isMultiCity
                ? TripLegMenuSheet.changeDays(context, c.wrongCityHomeLeg(info) ?? c.legIndexOf(info.firstWrongDay))
                : TripDatesSheet.edit(context)
            : null,
      ),
    );
  }

  static Widget? oldDatesCard(TripPlanController c, TripEnquiryModel e) {
    final plan = c.plan.value;
    if (plan == null || !e.isOpen) return null;
    if (!TripEnquiryRules.isOutsideTrip(e, c.settings, plan.days.length)) return null;
    final fare = e.isTaxi ? e.taxi?.agreedFare : e.agreedTotal;
    final text = TripStringsMccA3.oldDatesLine(e.datesLabel, price: fare == null ? '' : BrowseItem.inr(fare));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: RepliesTone.warnSurface, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            const TravelIcon(TravelIcon.calendar, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w600, color: RepliesTone.warn)),
            ),
          ],
        ),
      ),
    );
  }

  static Widget legLineText(String text) => Text(text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: DesignColors.whiteHigh));
}
