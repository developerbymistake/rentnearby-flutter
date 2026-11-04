import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_strings.dart';
import '../../trip/widgets/trip_payment_line.dart';
import 'stay_enquiry_format.dart';
import 'stay_enquiry_strings.dart';

class HostConfirmDialog {
  static Future<bool?> show(BuildContext context, {required bool confirm, required TripEnquiryModel enquiry}) {
    final guest = StayEnquiryFormat.guest(enquiry);
    final total = enquiry.phoneBooking?.agreedTotal ?? enquiry.agreedTotal;
    final body = confirm
        ? StayEnquiryStrings.confirmBookingBody(guest, total == null ? '' : BrowseItem.inr(total), enquiry.datesLabel)
        : StayEnquiryStrings.notYourBookingBody(guest);
    final color = confirm ? AppColors.success : AppColors.error;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          confirm ? StayEnquiryStrings.confirmBookingTitle : StayEnquiryStrings.notYourBookingTitle,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(body, style: const TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.4)),
            const SizedBox(height: 10),
            const TripPaymentLine(text: TripStrings.noPaymentLine),
          ]),
        ),
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(StayEnquiryStrings.cancelAction, style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm ? TripStrings.yesConfirm : TripStrings.notMe),
          ),
        ],
      ),
    );
  }
}
