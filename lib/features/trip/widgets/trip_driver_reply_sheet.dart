import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../taxi/leads/trip_lead_format.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../screens/trip_details_sheet.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import 'trip_payment_line.dart';
import 'trip_sheet_frame.dart';
import 'trip_taxi_booking_sheet.dart';

class TripDriverReplySheet {
  static Future<void> show(BuildContext context, {required TripEnquiryModel enquiry}) async {
    final book = await TripSheetFrame.show<bool>(context, _ReplyBody(enquiry: enquiry));
    if (book != true || !context.mounted) return;
    final plan = TripPlanController.to;
    if (!plan.hasDates) {
      await TripDetailsSheet.edit(context, heading: TripStrings.addYourDates, description: TripStrings.datesNeededBooking);
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
    final whatsApp = e.owner.whatsApp ?? phone;
    final rate = t?.listedRate;
    final total = TripLeadFormat.listedTotal(e);
    final note = t?.driverNote?.trim() ?? '';
    final day = TripPlanController.to.firstPlanDayOf(e) ?? (e.days.isNotEmpty ? e.days.first : 1);
    return TripSheetFrame(
      title: TripStrings.driverReplied(name),
      description: TripLeadFormat.dates(e),
      footer: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(TripStrings.driverReplyFooter,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35)),
          SizedBox(height: 4),
          TripPaymentLine(text: TripStrings.taxiPayLine),
        ],
      ),
      children: [
        _fareBox(t?.driverFare, rate, total, e),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(TripStrings.noteFromDriver,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textLight)),
          const SizedBox(height: 4),
          Text(note, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textDark, height: 1.4)),
        ],
        const SizedBox(height: 16),
        if (phone != null)
          LayoutBuilder(builder: (context, c) {
            final callBtn = _outlined(Iconsax.call, TripStrings.call, TripColors.accentDark, () => ContactLauncher.call(phone));
            final waBtn = _outlined(Iconsax.message, TripStrings.whatsApp, AppColors.whatsApp,
                () => ContactLauncher.whatsApp(whatsApp!, message: _message(day, name)));
            if (c.maxWidth >= 340) {
              return Row(children: [Expanded(child: callBtn), const SizedBox(width: 10), Expanded(child: waBtn)]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [callBtn, const SizedBox(height: 8), waBtn]);
          }),
        if (phone != null) const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TripColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(TripStrings.iBooked,
                  maxLines: 1, style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  String _message(int day, String name) {
    try {
      return TripPlanController.to.whatsAppMessage(day, name);
    } catch (_) {
      return '';
    }
  }

  Widget _fareBox(int? fare, int? rate, int? total, TripEnquiryModel e) {
    Widget cell(String label, Widget value, CrossAxisAlignment align) => Column(
          crossAxisAlignment: align,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
            const SizedBox(height: 2),
            value,
          ],
        );
    final fareText = fare == null ? '' : BrowseItem.inr(fare);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(14)),
      child: LayoutBuilder(builder: (context, c) {
        final fareCell = cell(
          TripStrings.driversFare,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(fareText,
                maxLines: 1,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          ),
          CrossAxisAlignment.start,
        );
        final listedCell = rate == null || total == null
            ? null
            : cell(
                TripStrings.listedRate,
                Text(TripStrings.listedTimes(BrowseItem.inr(rate), TripLeadFormat.dayCount(e), BrowseItem.inr(total)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                CrossAxisAlignment.start,
              );
        if (listedCell == null) return fareCell;
        if (c.maxWidth >= 300) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: fareCell),
            const SizedBox(width: 12),
            Expanded(child: listedCell),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [fareCell, const SizedBox(height: 10), listedCell]);
      }),
    );
  }

  Widget _outlined(IconData icon, String label, Color color, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: color.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ),
        ]),
      );
}
