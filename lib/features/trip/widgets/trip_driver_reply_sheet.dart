import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../taxi/leads/trip_lead_format.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../screens/trip_dates_sheet.dart';
import '../trip_strings.dart';
import 'trip_sheet_frame.dart';
import 'trip_taxi_booking_sheet.dart';

class TripDriverReplySheet {
  static Future<void> show(BuildContext context, {required TripEnquiryModel enquiry}) async {
    final book = await TripSheetFrame.show<bool>(context, _ReplyBody(enquiry: enquiry));
    if (book != true || !context.mounted) return;
    final plan = TripPlanController.to;
    if (!plan.hasDates) {
      await TripDatesSheet.ensure(context, heading: TripStrings.addYourDates);
      if (!context.mounted || !plan.hasDates) return;
    }
    await TripTaxiBookingSheet.show(
      context,
      taxi: null,
      day: plan.firstPlanDayOf(enquiry) ?? (enquiry.days.isNotEmpty ? enquiry.days.first : 1),
      enquiry: enquiry,
      initialFare: enquiry.taxi?.driverFare,
    );
  }
}

class _ReplyBody extends StatelessWidget {
  const _ReplyBody({required this.enquiry});

  final TripEnquiryModel enquiry;

  String? get _phone {
    final p = enquiry.owner.phone;
    return p != null && ContactLauncher.tenDigits(p).isNotEmpty ? p : null;
  }

  @override
  Widget build(BuildContext context) {
    final e = enquiry;
    final t = e.taxi;
    final name = TripLeadFormat.driver(e);
    final phone = _phone;
    final rate = t?.listedRate;
    final total = TripLeadFormat.listedTotal(e);
    final note = t?.driverNote?.trim() ?? '';
    final fare = t?.driverFare;
    final tone = ListingTone.coral;
    return TripSheetFrame(
      tone: tone,
      art: ListingArt.taxi,
      size: SheetSize.confirm,
      title: TripStrings.driverReplied(name),
      description: TripLeadFormat.dates(e),
      footnote: TripStrings.driverReplyFooter,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientPillButton(tone: tone, label: TripStrings.iBooked, onTap: () => Navigator.pop(context, true)),
          const SizedBox(height: 10),
          WhitePillButton(tone: tone, label: TripStrings.call, onTap: phone == null ? null : () => ContactLauncher.call(phone)),
        ],
      ),
      children: [
        KeyValueRow(label: TripStrings.driversFare, value: fare == null ? '' : BrowseItem.inr(fare), big: true),
        if (rate != null && total != null)
          KeyValueRow(label: TripStrings.listedRate, value: TripStrings.listedTimes(BrowseItem.inr(rate), TripLeadFormat.dayCount(e), BrowseItem.inr(total))),
        if (note.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.only(top: 16, bottom: 4), child: Text(TripStrings.noteFromDriver.toUpperCase(), style: RepliesLook.section)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: Text(note, style: Ink3D.text(14, FontWeight.w500, Ink3D.body, height: 1.4))),
        ],
      ],
    );
  }
}
