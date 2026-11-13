import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:get/get.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../data/trip_enquiry_repository.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_send_result_sheet.dart';
import '../widgets/trip_sheet_frame.dart';
import 'trip_dates_sheet.dart';

class TripStayEnquirySheet {
  static Future<TripEnquiryBatch?> show(
    BuildContext context, {
    required StayNearbyModel stay,
    required int day,
    required int nights,
  }) async {
    final batch = await TripSheetFrame.show<TripEnquiryBatch>(context, _EnquiryBody(stay: stay, day: day, nights: nights));
    if (batch == null) return null;
    final left = batch.asksLeft;
    if (left != null) TripSupplyController.to.asksLeft.value = left;
    if (context.mounted) {
      await TripSendResultSheet.show(context, batch: batch, names: {stay.id: stay.title});
    }
    return batch;
  }
}

class _EnquiryBody extends StatefulWidget {
  const _EnquiryBody({required this.stay, required this.day, required this.nights});

  final StayNearbyModel stay;
  final int day;
  final int nights;

  @override
  State<_EnquiryBody> createState() => _EnquiryBodyState();
}

class _EnquiryBodyState extends State<_EnquiryBody> {
  final _c = TripPlanController.to;
  bool _sending = false;
  int? _limitMinutes;

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _limitMinutes = null;
    });
    final enquiries = TripEnquiryController.to;
    final batch = await enquiries.sendEnquiry(day: widget.day, stayIds: [widget.stay.id], nights: widget.nights);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (batch == null && enquiries.lastErrorType == TripEnquiryErrorTypes.enquiryLimit) {
        _limitMinutes = enquiries.lastRetryAfterMinutes ?? 1;
      }
    });
    if (batch != null) Navigator.pop(context, batch);
  }

  static final ListingTone _tone = ListingTone.forest;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = _c.plan.value;
      final s = _c.settings;
      final checkIn = _c.dateOf(widget.day);
      if (p == null || checkIn == null) {
        return TripSheetFrame(
          tone: _tone,
          art: ListingArt.calendar,
          title: TripStrings.enquiryTitle,
          description: TripStringsA2.addDatesToSend,
          footer: GradientPillButton(tone: _tone, label: TripStringsA2.addDates, onTap: () => TripDatesSheet.edit(context)),
          children: const [],
        );
      }
      final nights = widget.nights < 1 ? 1 : widget.nights;
      final checkOut = DateTime(checkIn.year, checkIn.month, checkIn.day + nights);
      final now = DateTime.now().toUtc();
      final start = s.startDate ?? checkIn;
      final short = TripEnquiryRules.enquiryExpiry(start, checkIn, now).veryShortNotice;
      final daysLeft = TripEnquiryRules.daysUntil(start, now);
      final preview = TripEnquiryRules.previewText(
        city: p.cityNameOf(widget.day),
        checkIn: checkIn,
        checkOut: checkOut,
        allNights: nights > 1,
        adults: s.adults,
        kids: s.kids,
        days: [
          for (var d = widget.day; d < widget.day + nights; d++)
            TripPreviewDay(day: d, spots: p.dayAt(d)?.spots.map((x) => x.name).toList() ?? const []),
        ],
      );
      final asksLeft = TripSupplyController.to.asksLeft.value;
      final limit = _limitMinutes;
      final reply = short
          ? TripStrings.replyExpectedToday('${TripConstants.floorHours} h')
          : (daysLeft <= 0 ? TripStrings.replyExpectedToday('24 h') : TripStrings.replyExpected('24 h', daysLeft));
      return TripSheetFrame(
        tone: _tone,
        art: ListingArt.hotel,
        size: SheetSize.form,
        title: TripStrings.enquiryTitle,
        description: widget.stay.title,
        footnote: asksLeft == null ? TripStrings.noPaymentLine : TripStrings.asksLeft(asksLeft),
        endNote: [reply, if (asksLeft != null) TripStrings.noPaymentLine].join(' '),
        footer: GradientPillButton(tone: _tone, label: TripStrings.sendToStays(1), loading: _sending, enabled: limit == null, onTap: limit != null ? null : _send),
        children: [
          Row(
            children: [
              Expanded(child: PillPickerField(tone: _tone, sublabel: TripStrings.checkIn, value: TripFormat.shortDate(checkIn), leadingArt: ListingArt.calendar, trailing: const SizedBox.shrink(), onTap: null)),
              const SizedBox(width: 10),
              Expanded(child: PillPickerField(tone: _tone, sublabel: TripStrings.checkOut, value: TripFormat.shortDate(checkOut), leadingArt: ListingArt.calendar, trailing: const SizedBox.shrink(), onTap: null)),
            ],
          ),
          const SizedBox(height: 12),
          PillPickerField(
            tone: _tone,
            sublabel: TripStrings.people,
            value: s.peopleSummary,
            hint: TripStrings.addPeople,
            leadingArt: ListingArt.backpack,
            onTap: () => TripDatesSheet.edit(context),
          ),
          if (nights > 1) KeyValueRow(label: TripStringsV2Find.nightsLabel, value: TripStringsV2Find.nightsText(nights), divider: false),
          GreyPillBox(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TripStrings.sentToOwners.toUpperCase(), style: RepliesLook.section),
                const SizedBox(height: 4),
                Text(preview, style: Ink3D.text(13, FontWeight.w500, Ink3D.body, height: 1.4, letterSpacing: 0)),
              ],
            ),
          ),
          if (short) RepliesBanner(art: ListingArt.calendar, text: TripStrings.veryShortNotice, margin: const EdgeInsets.only(top: 12)),
          if (limit != null)
            RepliesBanner(art: ListingArt.clipboard, text: '${TripStrings.askLimitTitle}. ${TripStrings.askLimitBody(limit)}', margin: const EdgeInsets.only(top: 12)),
        ],
      );
    });
  }
}
