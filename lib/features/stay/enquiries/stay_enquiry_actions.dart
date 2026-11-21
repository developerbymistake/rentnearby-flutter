import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import '../../../utils/app_toast.dart';
import '../../../models/browse_item.dart';
import '../../../widgets/trip_report_traveller_sheet.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/models/trip_offer_model.dart';
import '../../trip/trip_strings.dart';
import '../../trip/utils/trip_format.dart';
import 'stay_enquiry_format.dart';
import '../../trip/widgets/trip_cancel_sheet.dart';
import 'stay_enquiries_controller.dart';
import 'stay_enquiry_strings.dart';
import '../stay_share_strings.dart';
import 'trip_send_offer_sheet.dart';

class StayEnquiryActions {
  static bool _opening = false;

  static Widget _summary(TripEnquiryModel e, String? sub, String? value) => ReplySummaryStrip(
        tone: ListingTone.forest,
        title: StayEnquiryFormat.guest(e),
        subtitle: sub,
        value: value ?? '',
        margin: EdgeInsets.zero,
      );

  static String _dates(TripEnquiryModel e) {
    final a = e.checkIn;
    final b = e.checkOut;
    return a != null && b != null ? TripFormat.dayMonthRange(a, b) : e.datesLabel;
  }

  static String? _range(DateTime? a, DateTime? b, int nights) =>
      a == null || b == null ? null : '${TripFormat.dayMonthRange(a, b)} · ${TripStrings.nights(nights)}';

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
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.forest,
        art: ListingArt.calendar,
        title: TripStrings.acceptChange,
        body: change == null ? StayEnquiryStrings.changeBodyFallback : TripStrings.acceptKeepsPrice(BrowseItem.inr(change.total)),
        content: _summary(e, change == null ? null : _range(change.checkIn, change.checkOut, change.nights), change == null ? null : BrowseItem.inr(change.total)),
        secondaryLabel: StayEnquiryStrings.cancelAction,
        onSecondary: () => Navigator.pop(ctx, false),
        primaryLabel: TripStrings.acceptChange,
        primaryDanger: false,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    if (ok != true) return false;
    return StayEnquiriesController.ensure().acceptChange(e.id, offerId);
  }

  static Future<void> reportTraveller(BuildContext context, TripEnquiryModel e) =>
      TripReportTravellerSheet.show(context, enquiry: e);

  static Future<bool> confirmShare(BuildContext context) async {
    if (_opening) return false;
    _opening = true;
    try {
      final stay = await StayEnquiriesController.ensure().ensureStay();
      if (!context.mounted) return false;
      if (stay == null) {
        AppToast.error(TripStrings.couldNotLoad);
        return false;
      }
      if (!stay.hasShareDetails) {
        await Get.toNamed(AppRoutes.stayShareDetails);
        return false;
      }
      final upi = stay.upiId ?? '';
      final wa = stay.whatsAppNumber ?? '';
      final ok = await Dialog3D.show<bool>(
        context,
        builder: (ctx) => Dialog3D(
          tone: ListingTone.forest,
          art: ListingArt.speechBalloon,
          title: StayShareStrings.confirmTitle,
          lines: [
            if (upi.isNotEmpty) DialogLine('${StayShareStrings.upiLabel} · $upi', art: ListingArt.moneyBag),
            if (wa.isNotEmpty) DialogLine('${StayShareStrings.whatsAppLabel} · +91 $wa', art: ListingArt.speechBalloon),
          ],
          secondaryLabel: StayShareStrings.cancel,
          onSecondary: () => Navigator.pop(ctx, false),
          primaryLabel: StayShareStrings.share,
          onPrimary: () => Navigator.pop(ctx, true),
        ),
      );
      return ok == true;
    } finally {
      _opening = false;
    }
  }

  static Future<bool> notAvailable(BuildContext context, TripEnquiryModel e) async {
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.forest,
        art: ListingArt.clipboard,
        title: StayEnquiryStrings.notAvailableTitle,
        body: StayEnquiryStrings.notAvailableBody,
        content: _summary(e, [_dates(e), e.context.peopleLabel].whereType<String>().where((t) => t.isNotEmpty).join(' · '), TripStrings.nights(e.nights)),
        secondaryLabel: StayEnquiryStrings.cancelAction,
        onSecondary: () => Navigator.pop(ctx, false),
        primaryLabel: TripStrings.notAvailableAction,
        primaryDanger: true,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    if (ok != true) return false;
    return StayEnquiriesController.ensure().notAvailable(e.id);
  }

  static Future<bool> cancel(BuildContext context, TripEnquiryModel e) async {
    final cancelled = await TripCancelSheet.show(context, enquiry: e, ownerSide: true);
    if (cancelled) await StayEnquiriesController.ensure().afterExternalChange(e.id);
    return cancelled;
  }
}
