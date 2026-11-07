import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../widgets/gradient_button.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../../stay/setup/stay_option_sets.dart';
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
import '../widgets/trip_payment_line.dart';
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

  Widget _limitCard(int minutes) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Iconsax.timer_1, size: 16, color: AppColors.warningText),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(TripStrings.askLimitTitle,
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.warningText)),
                  const SizedBox(height: 2),
                  Text(TripStrings.askLimitBody(minutes),
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.warningText, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _row(String label, String value, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                ),
                Expanded(
                  child: Text(value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                ),
                if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = _c.plan.value;
      final s = _c.settings;
      final checkIn = _c.dateOf(widget.day);
      if (p == null || checkIn == null) {
        return TripSheetFrame(
          title: TripStrings.enquiryTitle,
          children: [
            const Text(TripStringsA2.addDatesToSend,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.4)),
            const SizedBox(height: 16),
            GradientButton(
              onPressed: () => TripDatesSheet.edit(context),
              label: TripStringsA2.addDates,
              gradient: StayColors.gradient,
              shadowColor: StayColors.accent,
            ),
          ],
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
        title: TripStrings.enquiryTitle,
        description: widget.stay.title,
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TripPaymentLine(text: TripStrings.noPaymentLine),
            const SizedBox(height: 4),
            Text(reply,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35)),
            if (asksLeft != null) ...[
              const SizedBox(height: 4),
              Text(TripStrings.asksLeft(asksLeft),
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
            ],
          ],
        ),
        children: [
          _row(TripStrings.checkIn, TripFormat.shortDate(checkIn)),
          _row(TripStrings.checkOut, TripFormat.shortDate(checkOut)),
          _row(TripStrings.people, s.peopleSummary ?? TripStrings.addPeople, onTap: () => TripDatesSheet.edit(context)),
          if (nights > 1) _row(TripStringsV2Find.nightsLabel, TripStringsV2Find.nightsText(nights)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: StayColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(TripStrings.sentToOwners,
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textLight)),
                const SizedBox(height: 4),
                Text(preview,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textDark, height: 1.4)),
              ],
            ),
          ),
          if (short) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Iconsax.warning_2, size: 16, color: AppColors.warningText),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(TripStrings.veryShortNotice,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warningText)),
                  ),
                ],
              ),
            ),
          ],
          if (limit != null) _limitCard(limit),
          const SizedBox(height: 16),
          GradientButton(
            label: TripStrings.sendToStays(1),
            height: 52,
            isLoading: _sending,
            gradient: StayColors.gradient,
            shadowColor: StayColors.accent,
            onPressed: limit != null ? null : _send,
          ),
        ],
      );
    });
  }
}
