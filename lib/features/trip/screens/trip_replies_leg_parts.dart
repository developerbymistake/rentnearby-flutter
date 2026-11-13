import 'package:flutter/material.dart';
import '../../../models/browse_item.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_strings_mcc_a2.dart';
import '../trip_strings_mcc_a3.dart';
import '../utils/trip_enquiry_rules.dart';
import '../widgets/trip_leg_menu_sheet.dart';
import '../widgets/trip_wrong_city_strip.dart';
import 'trip_dates_sheet.dart';

class ReplyNote {
  const ReplyNote(this.text, {this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class TripRepliesLegParts {
  static String? legLine(TripPlanController c, int day) {
    if (!c.isMultiCity) return null;
    final days = c.legDays(c.legIndexOf(day));
    if (days.isEmpty) return null;
    return TripStringsMccA3.legLine(c.legOf(day).cityName, days.first, days.last);
  }

  static ReplyNote? wrongCityNote(BuildContext context, TripPlanController c, TripEnquiryModel e) {
    if (!e.isOpen) return null;
    final info = c.wrongCityOf(e);
    if (info == null) return null;
    final live = !c.isReadOnly;
    return ReplyNote(
      '${TripWrongCityStrip.lineOf(e, info)} · ${TripStringsMccA2.wrongCityNow}',
      actionLabel: live ? TripStringsMccA2.changeDays : null,
      onAction: live
          ? () => c.isMultiCity
              ? TripLegMenuSheet.changeDays(context, c.wrongCityHomeLeg(info) ?? c.legIndexOf(info.firstWrongDay))
              : TripDatesSheet.edit(context)
          : null,
    );
  }

  static ReplyNote? oldDatesNote(TripPlanController c, TripEnquiryModel e) {
    final plan = c.plan.value;
    if (plan == null || !e.isOpen) return null;
    if (!TripEnquiryRules.isOutsideTrip(e, c.settings, plan.days.length)) return null;
    final fare = e.isTaxi ? e.taxi?.agreedFare : e.agreedTotal;
    return ReplyNote(TripStringsMccA3.oldDatesLine(e.datesLabel, price: fare == null ? '' : BrowseItem.inr(fare)));
  }
}
