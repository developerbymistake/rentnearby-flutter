import '../../../design/design.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/json/owner_json.dart';
import '../strings/stay_format.dart';
import '../strings/stay_home_strings.dart';
import '../widgets/stay_widgets.dart';

enum StayNotifVariant { review, rejected, live }

class StayAttentionActions {
  const StayAttentionActions({
    required this.reply,
    required this.openEnquiry,
    required this.fixPayment,
    required this.openNotificationSettings,
    required this.choose,
    required this.viewReports,
    required this.viewEditRejected,
    required this.setPrice,
    required this.addShare,
    required this.share,
  });

  final void Function() reply;
  final void Function(String id) openEnquiry;
  final void Function() fixPayment;
  final void Function() openNotificationSettings;
  final void Function() choose;
  final void Function() viewReports;
  final void Function() viewEditRejected;
  final void Function({String? dateFrom, String? dateTo, String? festivalId}) setPrice;
  final void Function() addShare;
  final void Function() share;
}

abstract final class StayAttentionCodes {
  static const enquiriesWaiting = 'EnquiriesWaiting';
  static const changeOrCounter = 'ChangeOrCounter';
  static const offerAccepted = 'OfferAccepted';
  static const paymentIssue = 'PaymentIssue';
  static const notificationsOff = 'NotificationsOff';
  static const planHidden = 'PlanHidden';
  static const reports = 'Reports';
  static const editRejected = 'EditRejected';
  static const festival = 'Festival';
  static const addShareDetails = 'AddShareDetails';
  static const shareListing = 'ShareListing';

  static const int notificationsPriority = 5;
}

abstract final class StayAttentionCopy {
  static StayRowData? of(OwnerAttention a, StayAttentionActions h, {StayNotifVariant notif = StayNotifVariant.live}) {
    final args = a.args;
    switch (a.code) {
      case StayAttentionCodes.enquiriesWaiting:
        final n = OwnerJson.integer(args['count']);
        if (n <= 0) return null;
        final by = OwnerJson.time(args['replyBy']);
        return StayRowData(
          art: ListingArt.speechBalloon,
          title: StayHomeStrings.enquiriesWaiting(n),
          sub: by == null ? null : StayHomeStrings.replyBefore(StayFormat.clock(by)),
          trailing: StayPill(label: StayHomeStrings.reply, kind: StayPillKind.indigo, onTap: h.reply),
        );
      case StayAttentionCodes.changeOrCounter:
        final name = OwnerJson.strOrNull(args['travellerName']) ?? '';
        final id = OwnerJson.strOrNull(args['enquiryId']);
        final counter = args['kind'] == 'Counter';
        if (name.isEmpty) return null;
        return StayRowData(
          art: ListingArt.speechBalloon,
          title: counter ? StayHomeStrings.sentNewPrice(name) : StayHomeStrings.askedChange(name),
          trailing: StayPill(label: StayHomeStrings.open, kind: StayPillKind.indigo, onTap: id == null ? null : () => h.openEnquiry(id)),
        );
      case StayAttentionCodes.offerAccepted:
        final name = OwnerJson.strOrNull(args['travellerName']) ?? '';
        final id = OwnerJson.strOrNull(args['enquiryId']);
        final from = OwnerDates.day(args['checkIn']);
        final to = OwnerDates.day(args['checkOut']);
        if (name.isEmpty) return null;
        return StayRowData(
          art: ListingArt.key,
          title: StayHomeStrings.acceptedOffer(name),
          sub: from == null ? null : StayHomeStrings.bookingConfirmedFor(StayFormat.range(from, to)),
          trailing: StayPill(label: StayHomeStrings.open, kind: StayPillKind.white, onTap: id == null ? null : () => h.openEnquiry(id)),
        );
      case StayAttentionCodes.paymentIssue:
        return StayRowData(
          art: ListingArt.warning,
          tint: StayLook.artTintRed,
          title: StayHomeStrings.paymentIssue,
          trailing: StayPill(label: StayHomeStrings.fix, kind: StayPillKind.indigo, onTap: h.fixPayment),
        );
      case StayAttentionCodes.notificationsOff:
        return notificationRow(h, notif);
      case StayAttentionCodes.planHidden:
        final photos = OwnerJson.integer(args['photos']);
        final rooms = OwnerJson.integer(args['roomTypes']);
        final parts = [if (photos > 0) StayHomeStrings.photos(photos), if (rooms > 0) StayHomeStrings.roomTypes(rooms)];
        if (parts.isEmpty) return null;
        final what = parts.length == 2 ? StayHomeStrings.and(parts[0], parts[1]) : parts[0];
        final single = parts.length == 1 && (photos == 1 || rooms == 1);
        final started = args['reason'] == 'PlansStarted';
        return StayRowData(
          art: ListingArt.framedPicture,
          title: started ? StayHomeStrings.plansStarted(what, single: single) : StayHomeStrings.plusEnded(what, single: single),
          sub: StayHomeStrings.nothingDeleted,
          trailing: StayPill(label: StayHomeStrings.choose, kind: StayPillKind.indigo, onTap: h.choose),
        );
      case StayAttentionCodes.reports:
        final n = OwnerJson.integer(args['count']);
        if (n <= 0) return null;
        return StayRowData(
          art: ListingArt.warning,
          tint: StayLook.artTintRed,
          title: StayHomeStrings.reports(n),
          sub: OwnerJson.strOrNull(args['firstReason']),
          trailing: StayPill(label: StayHomeStrings.view, kind: StayPillKind.white, onTap: h.viewReports),
        );
      case StayAttentionCodes.editRejected:
        final reason = OwnerJson.strOrNull(args['reason']);
        if (reason == null) return null;
        final fields = OwnerJson.strings(args['fields']);
        final nameOnly = fields.length == 1 && fields.first == 'name';
        return StayRowData(
          art: ListingArt.warning,
          tint: StayLook.artTintRed,
          title: nameOnly ? StayHomeStrings.nameChangeNotApproved(reason) : StayHomeStrings.changeNotApproved(reason),
          trailing: StayPill(label: StayHomeStrings.view, kind: StayPillKind.white, onTap: h.viewEditRejected),
        );
      case StayAttentionCodes.festival:
        final name = OwnerJson.strOrNull(args['name']);
        final from = OwnerDates.day(args['dateFrom']);
        if (name == null || from == null) return null;
        final to = OwnerDates.day(args['dateTo']);
        return StayRowData(
          art: ListingArt.diyaLamp,
          tint: StayLook.artTintAmber,
          title: StayHomeStrings.festivalStarts(name, StayFormat.day(from)),
          sub: StayHomeStrings.festivalSub,
          trailing: StayPill(
            label: StayHomeStrings.setPrice,
            kind: StayPillKind.indigo,
            onTap: () => h.setPrice(dateFrom: OwnerDates.dayText(from), dateTo: OwnerDates.dayTextOrNull(to), festivalId: OwnerJson.strOrNull(args['festivalId'])),
          ),
        );
      case StayAttentionCodes.addShareDetails:
        return addShareRow(h);
      case StayAttentionCodes.shareListing:
        return StayRowData(
          art: ListingArt.mobilePhone,
          title: StayHomeStrings.shareStay,
          sub: StayHomeStrings.shareStaySub,
          trailing: StayPill(label: StayHomeStrings.share, kind: StayPillKind.teal, onTap: h.share),
        );
    }
    return null;
  }

  static StayRowData addShareRow(StayAttentionActions h) => StayRowData(
        art: ListingArt.key,
        title: StayHomeStrings.addShare,
        sub: StayHomeStrings.addShareSub,
        trailing: StayPill(label: StayHomeStrings.add, kind: StayPillKind.indigo, onTap: h.addShare),
      );

  static StayRowData notificationRow(StayAttentionActions h, StayNotifVariant v) => StayRowData(
        art: ListingArt.bell,
        title: StayHomeStrings.notificationsTitle,
        sub: switch (v) {
          StayNotifVariant.review => StayHomeStrings.notificationsMissUntil,
          StayNotifVariant.rejected => StayHomeStrings.notificationsReview,
          StayNotifVariant.live => StayHomeStrings.notificationsMiss,
        },
        trailing: StayPill(
          label: v == StayNotifVariant.live ? StayHomeStrings.turnOn : StayHomeStrings.open,
          kind: StayPillKind.indigo,
          onTap: h.openNotificationSettings,
        ),
      );
}
