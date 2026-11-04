import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../../widgets/trip_report_traveller_sheet.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/models/trip_offer_model.dart';
import '../../trip/trip_strings.dart';
import '../../trip/widgets/trip_cancel_sheet.dart';
import 'host_confirm_dialog.dart';
import 'stay_enquiries_controller.dart';
import 'stay_enquiry_strings.dart';
import 'trip_ask_advance_sheet.dart';
import 'trip_send_offer_sheet.dart';

class StayEnquiryActions {
  static bool _opening = false;

  static Future<bool> sendOffer(BuildContext context, TripEnquiryModel e, {TripOfferModel? counter}) async {
    if (_opening) return false;
    _opening = true;
    try {
      final stay = await StayEnquiriesController.ensure().ensureStay();
      if (!context.mounted) return false;
      if (stay == null) {
        AppToast.error(TripStrings.couldNotLoad);
        return false;
      }
      return await TripSendOfferSheet.show(context, enquiry: e, stay: stay, counter: counter);
    } finally {
      _opening = false;
    }
  }

  static Future<bool> revisedOffer(BuildContext context, TripEnquiryModel e, {TripOfferModel? changeRequest}) async {
    if (_opening) return false;
    _opening = true;
    try {
      final stay = await StayEnquiriesController.ensure().ensureStay();
      if (!context.mounted) return false;
      if (stay == null) {
        AppToast.error(TripStrings.couldNotLoad);
        return false;
      }
      return await TripSendOfferSheet.show(context, enquiry: e, stay: stay, changeRequest: changeRequest, revised: true);
    } finally {
      _opening = false;
    }
  }

  static Future<bool> acceptChange(BuildContext context, TripEnquiryModel e, String offerId) async {
    final change = e.pendingChange;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(TripStrings.acceptChange, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text(change == null ? StayEnquiryStrings.changeBodyFallback : TripStrings.acceptKeepsPrice(BrowseItem.inr(change.total)),
            style: const TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.4)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(StayEnquiryStrings.cancelAction, style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(TripStrings.acceptChange),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    return StayEnquiriesController.ensure().acceptChange(e.id, offerId);
  }

  static Future<void> reportTraveller(BuildContext context, TripEnquiryModel e) =>
      TripReportTravellerSheet.show(context, enquiry: e);

  static Future<bool> askAdvance(BuildContext context, TripEnquiryModel e) async {
    if (_opening) return false;
    _opening = true;
    try {
      final stay = await StayEnquiriesController.ensure().ensureStay();
      if (!context.mounted) return false;
      if (stay == null) {
        AppToast.error(TripStrings.couldNotLoad);
        return false;
      }
      return await TripAskAdvanceSheet.show(context, enquiry: e, stay: stay);
    } finally {
      _opening = false;
    }
  }

  static Future<bool> markReceived(BuildContext context, TripEnquiryModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(TripStrings.markAdvanceReceived, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        content: const Text(TripStrings.checkAmountFirst,
            style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.4)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(StayEnquiryStrings.cancelAction, style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(TripStrings.markAdvanceReceived),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    return StayEnquiriesController.ensure().markReceived(e.id);
  }

  static Future<bool> notYet(BuildContext context, TripEnquiryModel e) =>
      StayEnquiriesController.ensure().notYet(e.id);

  static Future<void> callGuest(TripEnquiryModel e) async {
    final phone = e.traveller.phone;
    if (phone == null || phone.isEmpty) {
      AppToast.info(TripStrings.couldNotLoad);
      return;
    }
    await ContactLauncher.call(phone);
  }

  static Future<bool> notAvailable(BuildContext context, TripEnquiryModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(StayEnquiryStrings.notAvailableTitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        content: const Text(StayEnquiryStrings.notAvailableBody,
            style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.4)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(StayEnquiryStrings.cancelAction, style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(TripStrings.notAvailableAction),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    return StayEnquiriesController.ensure().notAvailable(e.id);
  }

  static Future<bool> hostConfirm(BuildContext context, TripEnquiryModel e, {required bool confirm}) async {
    final ok = await HostConfirmDialog.show(context, confirm: confirm, enquiry: e);
    if (ok != true) return false;
    return StayEnquiriesController.ensure().hostConfirm(e.id, confirm: confirm);
  }

  static Future<bool> cancel(BuildContext context, TripEnquiryModel e) async {
    final cancelled = await TripCancelSheet.show(context, enquiry: e, ownerSide: true);
    if (cancelled) await StayEnquiriesController.ensure().afterExternalChange(e.id);
    return cancelled;
  }
}
