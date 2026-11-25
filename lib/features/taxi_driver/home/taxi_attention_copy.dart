import '../../../design/design.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/json/owner_json.dart';
import '../strings/taxi_home_strings.dart';
import '../widgets/taxi_widgets.dart';

class TaxiAttentionActions {
  const TaxiAttentionActions({
    required this.confirm,
    required this.checkReady,
    required this.openNotificationSettings,
    required this.runTest,
    required this.fixPayment,
    required this.choose,
    required this.viewReports,
    required this.addLocalRate,
    required this.checkFares,
    required this.addRoute,
  });

  final void Function(String? offerId) confirm;
  final void Function() checkReady;
  final void Function() openNotificationSettings;
  final void Function() runTest;
  final void Function() fixPayment;
  final void Function() choose;
  final void Function() viewReports;
  final void Function() addLocalRate;
  final void Function() checkFares;
  final void Function() addRoute;
}

abstract final class TaxiAttentionCodes {
  static const travellerChoseYou = 'TravellerChoseYou';
  static const noPushToken = 'NoPushToken';
  static const notificationsOff = 'NotificationsOff';
  static const missedRings = 'MissedRings';
  static const paymentIssue = 'PaymentIssue';
  static const planHidden = 'PlanHidden';
  static const reports = 'Reports';
  static const getReady = 'GetReady';
  static const addLocalRate = 'AddLocalRate';
  static const festival = 'Festival';
  static const addRoutes = 'AddRoutes';

  static const int notificationsPriority = 3;
}

abstract final class TaxiAttentionCopy {
  static String countdown(Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  static Duration? remaining(OwnerAttention a, DateTime now) {
    final by = OwnerJson.time(a.args['confirmBy']);
    return by?.difference(now);
  }

  // compact = the two-line Home row, otherwise the list row of the See all screen.
  static TaxiRowData? of(OwnerAttention a, TaxiAttentionActions h, {required DateTime now, bool compact = true}) {
    final args = a.args;
    switch (a.code) {
      case TaxiAttentionCodes.travellerChoseYou:
        final left = remaining(a, now);
        if (left == null || left.isNegative) return null;
        final t = countdown(left);
        return TaxiRowData(
          art: ListingArt.bell,
          title: TaxiHomeStrings.choseYou,
          sub: TaxiHomeStrings.leftToConfirm(t),
          trailing: TaxiPill(label: TaxiHomeStrings.confirm, kind: TaxiPillKind.coral, onTap: () => h.confirm(OwnerJson.strOrNull(args['offerId']))),
        );
      case TaxiAttentionCodes.noPushToken:
        return TaxiRowData(
          art: ListingArt.calendar,
          title: compact ? TaxiHomeStrings.phoneCannot : TaxiHomeStrings.phoneCannotList,
          sub: compact ? null : TaxiHomeStrings.phoneCannotSub,
          trailing: TaxiPill(label: TaxiHomeStrings.checkNow, kind: TaxiPillKind.outline, onTap: h.checkReady),
        );
      case TaxiAttentionCodes.notificationsOff:
        return TaxiRowData(
          art: ListingArt.bell,
          title: TaxiHomeStrings.notifTitle,
          sub: TaxiHomeStrings.notifSub,
          trailing: TaxiPill(label: TaxiHomeStrings.turnOn, kind: TaxiPillKind.outline, onTap: h.openNotificationSettings),
        );
      case TaxiAttentionCodes.missedRings:
        final n = OwnerJson.integer(args['count']);
        if (n <= 0) return null;
        return TaxiRowData(
          art: ListingArt.alarmClock,
          title: compact ? TaxiHomeStrings.missed(n) : TaxiHomeStrings.missedList(n),
          sub: compact ? null : TaxiHomeStrings.missedSub,
          trailing: TaxiPill(label: compact ? TaxiHomeStrings.runTestRing : TaxiHomeStrings.runTest, kind: TaxiPillKind.outline, onTap: h.runTest),
        );
      case TaxiAttentionCodes.paymentIssue:
        return TaxiRowData(
          art: ListingArt.crown,
          tint: TaxiLook.artTintAmber,
          title: TaxiHomeStrings.paymentIssue,
          sub: TaxiHomeStrings.paymentIssueSub,
          trailing: TaxiPill(label: TaxiHomeStrings.fix, kind: TaxiPillKind.outline, onTap: h.fixPayment),
        );
      case TaxiAttentionCodes.planHidden:
        final n = OwnerJson.integer(args['routes']);
        if (n <= 0) return null;
        final started = args['reason'] == 'PlansStarted';
        return TaxiRowData(
          art: ListingArt.locked,
          tint: TaxiLook.artTintAmber,
          title: started ? TaxiHomeStrings.plansStarted(n) : TaxiHomeStrings.plusEnded(n),
          sub: TaxiHomeStrings.nothingDeleted,
          trailing: TaxiPill(label: TaxiHomeStrings.choose, kind: TaxiPillKind.outline, onTap: h.choose),
        );
      case TaxiAttentionCodes.reports:
        final n = OwnerJson.integer(args['count']);
        if (n <= 0) return null;
        return TaxiRowData(
          art: ListingArt.warning,
          tint: TaxiLook.artTintRed,
          title: TaxiHomeStrings.reports(n),
          sub: TaxiHomeStrings.reportsSub,
          trailing: TaxiPill(label: TaxiHomeStrings.view, kind: TaxiPillKind.outline, onTap: h.viewReports),
        );
      case TaxiAttentionCodes.getReady:
        return TaxiRowData(
          art: ListingArt.alarmClock,
          title: TaxiHomeStrings.getReady,
          trailing: TaxiPill(label: TaxiHomeStrings.checkNow, kind: TaxiPillKind.outline, onTap: h.checkReady),
        );
      case TaxiAttentionCodes.addLocalRate:
        return TaxiRowData(
          art: ListingArt.moneyBag,
          tint: TaxiLook.artTintAmber,
          title: TaxiHomeStrings.addLocalRate,
          sub: TaxiHomeStrings.addLocalRateSub,
          trailing: TaxiPill(label: TaxiHomeStrings.add, kind: TaxiPillKind.outline, onTap: h.addLocalRate),
        );
      case TaxiAttentionCodes.festival:
        final name = OwnerJson.strOrNull(args['name']);
        final from = OwnerDates.day(args['dateFrom']);
        if (name == null || from == null) return null;
        return TaxiRowData(
          art: ListingArt.diyaLamp,
          tint: TaxiLook.artTintAmber,
          title: TaxiHomeStrings.festivalStarts(name, TaxiHomeFormat.day(from)),
          sub: TaxiHomeStrings.festivalSub,
          trailing: TaxiPill(label: TaxiHomeStrings.checkFares, kind: TaxiPillKind.outline, onTap: h.checkFares),
        );
      case TaxiAttentionCodes.addRoutes:
        return TaxiRowData(
          art: ListingArt.compass,
          title: TaxiHomeStrings.getMoreCalls,
          sub: TaxiHomeStrings.addRoutes(OwnerJson.strOrNull(args['fromCityName']), OwnerJson.strOrNull(args['toCityName'])),
          trailing: TaxiPill(label: TaxiHomeStrings.add, kind: TaxiPillKind.outline, onTap: h.addRoute),
        );
    }
    return null;
  }
}

abstract final class TaxiHomeFormat {
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String day(DateTime d) => '${d.day} ${_months[d.month - 1]}';
}
