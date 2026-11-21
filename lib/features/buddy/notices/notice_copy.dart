import '../../../config/app_routes.dart';
import '../shared/buddy_format.dart';
import '../shared/buddy_look.dart';
import 'models/notice_models.dart';
import 'notice_strings.dart';

enum NoticeTone { teal, indigo, rose }

class NoticeView {
  const NoticeView({required this.title, required this.body, required this.tag, required this.art, required this.tone, required this.route, required this.args});

  final String title;
  final String body;
  final String tag;
  final String art;
  final NoticeTone tone;
  final String? route;
  final Map<String, dynamic> args;
}

abstract final class NoticeCopy {
  static NoticeView? of(Notice n) {
    final actor = _text(n.actorName) ?? NoticeStrings.someone;
    final trip = _text(n.tripTitle) ?? NoticeStrings.yourTrip;
    final amount = n.amount;
    final many = n.count > 1;
    final travellers = n.travellers;
    final item = _text(n.refTitle);
    final tripArgs = <String, dynamic>{'tripId': ?n.tripId};
    switch (n.kind) {
      case NoticeKinds.buddyRequest:
        return NoticeView(
          title: NoticeStrings.buddyRequestTitle,
          body: many ? NoticeStrings.buddyRequestMany(n.count) : NoticeStrings.buddyRequestOne(actor),
          tag: NoticeStrings.tagBuddies,
          art: BuddyArt.panda,
          tone: NoticeTone.teal,
          route: AppRoutes.buddies,
          args: const {'tab': 'requests'},
        );
      case NoticeKinds.tripInvite:
        return NoticeView(
          title: NoticeStrings.tripInviteTitle,
          body: NoticeStrings.tripInviteBody(actor, trip),
          tag: NoticeStrings.tagTrip,
          art: BuddyArt.luggage,
          tone: NoticeTone.teal,
          route: AppRoutes.tripInvite,
          args: {'memberId': ?n.refId},
        );
      case NoticeKinds.paymentSaidPaid:
        return NoticeView(
          title: NoticeStrings.saidPaidTitle(actor),
          body: many
              ? NoticeStrings.saidPaidMany(n.count, trip)
              : amount == null
                  ? NoticeStrings.saidPaidNoAmount(trip)
                  : NoticeStrings.saidPaidOne(BuddyFormat.rupees(amount), trip),
          tag: NoticeStrings.tagExpenses,
          art: BuddyArt.moneyBag,
          tone: NoticeTone.rose,
          route: AppRoutes.tripExpenses,
          args: {...tripArgs, 'tab': 'balances'},
        );
      case NoticeKinds.settleReminder:
        return _money(NoticeStrings.settleTitle, amount == null ? NoticeStrings.moneyNoAmount(trip) : NoticeStrings.settleBody(actor, BuddyFormat.rupees(amount)), tripArgs);
      case NoticeKinds.paymentNotReceived:
        return _money(
            NoticeStrings.notReceivedTitle, amount == null ? NoticeStrings.moneyNoAmount(trip) : NoticeStrings.notReceivedBody(actor, BuddyFormat.rupees(amount)), tripArgs);
      case NoticeKinds.expensesChanged:
        return _money(NoticeStrings.expensesTitle, many ? NoticeStrings.expensesMany(n.count, trip) : NoticeStrings.expensesOne(actor, trip), tripArgs);
      case NoticeKinds.tripRemoved:
        return NoticeView(
          title: NoticeStrings.removedTitle,
          body: NoticeStrings.removedBody(actor, trip),
          tag: NoticeStrings.tagTrip,
          art: BuddyArt.luggage,
          tone: NoticeTone.indigo,
          route: AppRoutes.tripView,
          args: tripArgs,
        );
      case NoticeKinds.tripDeleted:
        final named = _text(n.actorName);
        return NoticeView(
          title: NoticeStrings.deletedTitle,
          body: named == null ? NoticeStrings.deletedNoActor : NoticeStrings.deletedBody(named),
          tag: NoticeStrings.tagTrip,
          art: BuddyArt.luggage,
          tone: NoticeTone.indigo,
          route: AppRoutes.tripView,
          args: {...tripArgs, 'deleted': true},
        );
      case NoticeKinds.buddyAccepted:
        return _buddies(NoticeStrings.acceptedTitle, many ? NoticeStrings.acceptedMany(actor, n.count - 1) : NoticeStrings.acceptedOne(actor));
      case NoticeKinds.newBuddy:
        return _buddies(NoticeStrings.newBuddyTitle, many ? NoticeStrings.newBuddyMany(n.count) : NoticeStrings.newBuddyOne(actor));
      case NoticeKinds.tripJoined:
        return NoticeView(
          title: NoticeStrings.joinedTitle(actor),
          body: travellers == null || travellers < 2 ? NoticeStrings.joinedNoCount(trip) : NoticeStrings.joinedBody(trip, travellers),
          tag: NoticeStrings.tagTrip,
          art: BuddyArt.luggage,
          tone: NoticeTone.indigo,
          route: AppRoutes.tripTravellers,
          args: tripArgs,
        );
      case NoticeKinds.planUpdated:
        return NoticeView(
          title: NoticeStrings.planTitle,
          body: many || amount == null || amount < 1 ? NoticeStrings.planNoDay(actor, trip) : NoticeStrings.planDay(actor, amount, trip),
          tag: NoticeStrings.tagTrip,
          art: BuddyArt.compass,
          tone: NoticeTone.indigo,
          route: AppRoutes.tripView,
          args: tripArgs,
        );
      case NoticeKinds.expenseAdded:
        return _money(
          NoticeStrings.expenseAddedTitle,
          amount == null ? NoticeStrings.expenseAddedNoAmount(trip) : NoticeStrings.expenseAddedShare(item, BuddyFormat.rupees(amount)),
          tripArgs,
          BuddyArt.taxi,
        );
      case NoticeKinds.shareChanged:
        return _money(
          NoticeStrings.shareChangedTitle,
          amount == null ? NoticeStrings.shareChangedNoAmount(trip) : NoticeStrings.shareChangedNow(item, BuddyFormat.rupees(amount)),
          tripArgs,
          BuddyArt.hotel,
        );
    }
    return null;
  }

  static NoticeView _buddies(String title, String body) => NoticeView(
        title: title,
        body: body,
        tag: NoticeStrings.tagBuddies,
        art: BuddyArt.panda,
        tone: NoticeTone.teal,
        route: AppRoutes.buddies,
        args: const {},
      );

  static NoticeView _money(String title, String body, Map<String, dynamic> args, [String art = BuddyArt.moneyBag]) => NoticeView(
        title: title,
        body: body,
        tag: NoticeStrings.tagExpenses,
        art: art,
        tone: NoticeTone.rose,
        route: AppRoutes.tripExpenses,
        args: args,
      );

  static String? _text(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}
