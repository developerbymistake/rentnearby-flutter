import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../stay_owner/strings/stay_work_strings.dart';
import 'stay_cancel_booking_sheet.dart';
import '../../../models/browse_item.dart';
import '../../../widgets/trip_report_traveller_sheet.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_strings.dart';
import '../../trip/utils/trip_format.dart';
import 'stay_enquiry_format.dart';
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

  static Future<bool> sendOffer(BuildContext context, TripEnquiryModel e) async {
    if (_opening) return false;
    _opening = true;
    try {
      final stay = await StayEnquiriesController.ensure().ensureStay();
      if (!context.mounted) return false;
      if (stay == null) {
        AppToast.error(TripStrings.couldNotLoad);
        return false;
      }
      return await TripSendOfferSheet.show(context, enquiry: e, stay: stay);
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
    final ctrl = StayEnquiriesController.ensure();
    if (await ctrl.acceptChange(e.id, offerId)) return true;
    if (ctrl.lastErrorType != StayEnquiriesController.changeTouchesBlock || !context.mounted) return false;
    final again = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.forest,
        art: ListingArt.calendar,
        title: StayWorkStrings.blockedAcceptAnyway,
        secondaryLabel: StayEnquiryStrings.cancelAction,
        onSecondary: () => Navigator.pop(ctx, false),
        primaryLabel: StayWorkStrings.acceptAnyway,
        primaryDanger: false,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    if (again != true) return false;
    return ctrl.acceptChangeConfirmed(e.id, offerId);
  }

  static Future<bool> sendShareCard(TripEnquiryModel e) async {
    try {
      await ApiService.post('/trips/enquiries/${e.id}/share-details', const <String, dynamic>{});
      await StayEnquiriesController.ensure().afterExternalChange(e.id);
      return true;
    } catch (err) {
      if (DioErrorMapper.errorType(err) == shareDetailsNotSet) {
        await Get.toNamed(AppRoutes.stayShareDetails);
        return false;
      }
      AppToast.error(DioErrorMapper.toMessage(err, StayWorkStrings.shareFailed, showRawMessageForStatusCodes: const {400, 403}));
      return false;
    }
  }

  static const String shareDetailsNotSet = 'ShareDetailsNotSet';

  static bool canCall(TripEnquiryModel e) => ContactLauncher.tenDigits(e.traveller.phone ?? '').isNotEmpty;

  static Future<void> callGuest(TripEnquiryModel e) async {
    final phone = ContactLauncher.tenDigits(e.traveller.phone ?? '');
    if (phone.isEmpty) return;
    await ContactLauncher.call(phone);
  }

  static Future<bool> block(BuildContext context, TripEnquiryModel e) async {
    final id = e.traveller.id ?? '';
    if (id.isEmpty) return false;
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.forest,
        art: ListingArt.speechBalloon,
        title: StayWorkStrings.blockTitle,
        body: StayWorkStrings.blockBody(StayEnquiryFormat.guest(e)),
        secondaryLabel: StayEnquiryStrings.cancelAction,
        onSecondary: () => Navigator.pop(ctx, false),
        primaryLabel: StayWorkStrings.block,
        primaryDanger: true,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    if (ok != true) return false;
    try {
      await ApiService.post('/chat/users/$id/block', {});
      return true;
    } catch (err) {
      AppToast.error(DioErrorMapper.toMessage(err, StayWorkStrings.blockFailed, showRawMessageForStatusCodes: const {400, 403}));
      return false;
    }
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
    final cancelled = await StayCancelBookingSheet.show(context, e);
    if (cancelled) await StayEnquiriesController.ensure().afterExternalChange(e.id);
    return cancelled;
  }
}
