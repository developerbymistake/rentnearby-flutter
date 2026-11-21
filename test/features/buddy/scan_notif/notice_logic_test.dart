import 'package:bakhli/features/buddy/notices/models/notice_models.dart';
import 'package:bakhli/features/buddy/notices/notice_copy.dart';
import 'package:bakhli/features/buddy/notices/widgets/inbox_feed.dart';
import 'package:bakhli/models/notification_model.dart';
import 'package:flutter_test/flutter_test.dart';

Notice notice(String kind, {String id = 'n1', String? actor = 'Rahul', String? trip = 'Uttarakhand Hills Trip', int? amount, int count = 1, DateTime? at, String? refId, String? refTitle, int? travellers, bool read = false}) => Notice(
      id: id,
      kind: kind,
      tripId: 'trip-1',
      tripTitle: trip,
      actorName: actor,
      refId: refId,
      amount: amount,
      refTitle: refTitle,
      travellers: travellers,
      count: count,
      createdAt: at,
      updatedAt: at,
      isRead: read,
    );

NotificationModel old(String id, DateTime at) =>
    NotificationModel(id: id, type: 't', title: 'T', body: 'B', actionRoute: null, actionArguments: null, isRead: false, createdAt: at);

void main() {
  group('NoticeCopy', () {
    test('buddy request one and many', () {
      final one = NoticeCopy.of(notice(NoticeKinds.buddyRequest, actor: 'Neha'))!;
      expect(one.title, 'New buddy request');
      expect(one.body, 'Neha wants to be your buddy.');
      expect(one.tag, 'BUDDIES');
      expect(one.route, '/buddies');
      expect(one.args, {'tab': 'requests'});
      expect(NoticeCopy.of(notice(NoticeKinds.buddyRequest, count: 3))!.body, '3 people want to be your buddy.');
    });

    test('trip invite', () {
      final v = NoticeCopy.of(notice(NoticeKinds.tripInvite, refId: 'm1'))!;
      expect(v.title, 'Trip invite');
      expect(v.body, 'Rahul invited you to Uttarakhand Hills Trip.');
      expect(v.tag, 'TRIP');
      expect(v.route, '/trip-invite');
      expect(v.args, {'memberId': 'm1'});
    });

    test('settle reminder with amount grouped the Indian way', () {
      final v = NoticeCopy.of(notice(NoticeKinds.settleReminder, amount: 11816))!;
      expect(v.title, 'Time to settle up');
      expect(v.body, 'You owe Rahul ₹11,816.');
      expect(v.tag, 'EXPENSES');
      expect(v.route, '/trip-expenses');
      expect(v.args, {'tripId': 'trip-1'});
    });

    test('missing amount drops the amount for every money kind', () {
      expect(NoticeCopy.of(notice(NoticeKinds.settleReminder))!.body, 'You have money to settle on Uttarakhand Hills Trip.');
      expect(NoticeCopy.of(notice(NoticeKinds.paymentNotReceived))!.body, 'You have money to settle on Uttarakhand Hills Trip.');
      expect(NoticeCopy.of(notice(NoticeKinds.paymentSaidPaid))!.body, isNot(contains('₹')));
    });

    test('payment not received and said paid', () {
      expect(NoticeCopy.of(notice(NoticeKinds.paymentNotReceived, amount: 500))!.body, 'Rahul has not got your ₹500 yet. Please check.');
      final s = NoticeCopy.of(notice(NoticeKinds.paymentSaidPaid, amount: 500))!;
      expect(s.title, 'Rahul says paid');
      expect(s.body, '₹500 for Uttarakhand Hills Trip. Mark it received when it is in your account.');
      expect(s.args, {'tripId': 'trip-1', 'tab': 'balances'});
      expect(NoticeCopy.of(notice(NoticeKinds.paymentSaidPaid, count: 2))!.body, '2 payments are waiting on Uttarakhand Hills Trip.');
    });

    test('expenses changed is one row with a count', () {
      expect(NoticeCopy.of(notice(NoticeKinds.expensesChanged))!.title, 'Expenses updated');
      expect(NoticeCopy.of(notice(NoticeKinds.expensesChanged))!.body, 'Rahul updated the expenses of Uttarakhand Hills Trip.');
      expect(NoticeCopy.of(notice(NoticeKinds.expensesChanged, count: 4))!.body, '4 updates on Uttarakhand Hills Trip.');
    });

    test('removed and deleted', () {
      final r = NoticeCopy.of(notice(NoticeKinds.tripRemoved))!;
      expect(r.title, 'Removed from a trip');
      expect(r.body, 'Rahul removed you from Uttarakhand Hills Trip.');
      expect(r.route, '/trip-view');
      final d = NoticeCopy.of(notice(NoticeKinds.tripDeleted))!;
      expect(d.body, 'Rahul deleted a trip you were on.');
      expect(d.args, {'tripId': 'trip-1', 'deleted': true});
      expect(NoticeCopy.of(notice(NoticeKinds.tripDeleted, actor: null))!.body, 'A trip you were on was deleted.');
    });

    test('buddy accepted and new buddy, one and many', () {
      final a = NoticeCopy.of(notice(NoticeKinds.buddyAccepted, actor: 'Aman'))!;
      expect((a.title, a.body, a.tag, a.route, a.tone), ('Request accepted', 'Aman is now your buddy.', 'BUDDIES', '/buddies', NoticeTone.teal));
      expect(NoticeCopy.of(notice(NoticeKinds.buddyAccepted, actor: 'Aman', count: 3))!.body, 'Aman and 2 others are now your buddies.');
      final b = NoticeCopy.of(notice(NoticeKinds.newBuddy, actor: 'Neha'))!;
      expect((b.title, b.body, b.tag, b.route), ('New buddy', 'You and Neha are buddies now.', 'BUDDIES', '/buddies'));
      expect(NoticeCopy.of(notice(NoticeKinds.newBuddy, count: 4))!.body, 'You and 4 new buddies.');
      expect(NoticeCopy.of(notice(NoticeKinds.newBuddy, actor: null))!.body, 'You and Someone are buddies now.');
    });

    test('trip joined uses the live traveller count, else a plain line', () {
      final v = NoticeCopy.of(notice(NoticeKinds.tripJoined, actor: 'Aman', travellers: 2))!;
      expect((v.title, v.body, v.tag, v.route, v.tone), ('Aman joined your trip', 'Uttarakhand Hills Trip now has 2 travellers.', 'TRIP', '/trip-travellers', NoticeTone.indigo));
      expect(v.args, {'tripId': 'trip-1'});
      expect(NoticeCopy.of(notice(NoticeKinds.tripJoined, actor: 'Aman', count: 3))!.body, 'Uttarakhand Hills Trip has new travellers.');
      expect(NoticeCopy.of(notice(NoticeKinds.tripJoined, trip: null))!.body, 'your trip has new travellers.');
    });

    test('plan updated with and without a day', () {
      final v = NoticeCopy.of(notice(NoticeKinds.planUpdated, actor: 'Neha', trip: 'Goa Beach Weekend', amount: 2))!;
      expect((v.title, v.body, v.tag, v.route), ('Plan updated', 'Neha changed Day 2 of Goa Beach Weekend.', 'TRIP', '/trip-view'));
      expect(v.args, {'tripId': 'trip-1'});
      expect(NoticeCopy.of(notice(NoticeKinds.planUpdated, actor: 'Neha'))!.body, 'Neha changed the plan of Uttarakhand Hills Trip.');
      expect(NoticeCopy.of(notice(NoticeKinds.planUpdated, amount: 3, count: 2))!.body, 'Rahul changed the plan of Uttarakhand Hills Trip.');
      expect(NoticeCopy.of(notice(NoticeKinds.planUpdated, amount: 0))!.body, 'Rahul changed the plan of Uttarakhand Hills Trip.');
    });

    test('expense added and share changed show the share with Indian grouping', () {
      final e = NoticeCopy.of(notice(NoticeKinds.expenseAdded, amount: 6400))!;
      expect((e.title, e.body, e.tag, e.route, e.tone), ('New expense', 'Your share ₹6,400.', 'EXPENSES', '/trip-expenses', NoticeTone.rose));
      expect(NoticeCopy.of(notice(NoticeKinds.expenseAdded, amount: 123456))!.body, 'Your share ₹1,23,456.');
      expect(NoticeCopy.of(notice(NoticeKinds.expenseAdded))!.body, 'A new expense was added to Uttarakhand Hills Trip.');
      expect(NoticeCopy.of(notice(NoticeKinds.expenseAdded, amount: 6400, refTitle: 'Taxi'))!.body, 'Taxi. Your share ₹6,400.');
      expect(NoticeCopy.of(notice(NoticeKinds.shareChanged, amount: 6166, refTitle: 'Taxi, Suresh (Dzire)'))!.body, 'Taxi, Suresh (Dzire). Now ₹6,166.');
      expect(NoticeCopy.of(notice(NoticeKinds.expenseAdded, amount: 6400, refTitle: ' '))!.body, 'Your share ₹6,400.');
      final s = NoticeCopy.of(notice(NoticeKinds.shareChanged, amount: 6166))!;
      expect((s.title, s.body), ('Your share changed', 'Now ₹6,166.'));
      expect(s.args, {'tripId': 'trip-1'});
      expect(NoticeCopy.of(notice(NoticeKinds.shareChanged))!.body, 'Your share changed on Uttarakhand Hills Trip.');
    });

    test('notice json carries refTitle and travellers', () {
      final n = Notice.fromJson({'id': 'n', 'kind': 'TripJoined', 'travellers': 3, 'refTitle': 'Taxi', 'count': 1, 'isRead': false});
      expect((n.travellers, n.refTitle, n.markedRead().travellers, n.markedRead().refTitle), (3, 'Taxi', 3, 'Taxi'));
    });

    test('every new kind is known', () {
      for (final k in [NoticeKinds.buddyAccepted, NoticeKinds.newBuddy, NoticeKinds.tripJoined, NoticeKinds.planUpdated, NoticeKinds.expenseAdded, NoticeKinds.shareChanged]) {
        expect(notice(k).isKnown, isTrue, reason: k);
        expect(NoticeCopy.of(notice(k)), isNotNull, reason: k);
      }
    });

    test('fallbacks for missing actor and trip', () {
      final v = NoticeCopy.of(notice(NoticeKinds.tripInvite, actor: null, trip: ' '))!;
      expect(v.body, 'Someone invited you to your trip.');
    });

    test('unknown kind has no view', () {
      expect(NoticeCopy.of(notice('FutureKind')), isNull);
      expect(notice('FutureKind').isKnown, isFalse);
    });

    test('no copy is ever taken from stored text fields', () {
      final v = NoticeCopy.of(notice(NoticeKinds.expensesChanged))!;
      expect(v.tone, NoticeTone.rose);
    });
  });

  group('InboxFeed.merge', () {
    final t0 = DateTime.utc(2026, 5, 20, 12);
    DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

    test('one list by time, newest first', () {
      final items = InboxFeed.merge([old('o1', at(5)), old('o2', at(-5))], [notice(NoticeKinds.buddyRequest, id: 'n1', at: at(0))]);
      expect(items.map((e) => e.key), ['o:o1', 'n:n1', 'o:o2']);
    });

    test('ties keep old rows first, then notices', () {
      final items = InboxFeed.merge([old('o1', at(0))], [notice(NoticeKinds.buddyRequest, id: 'n1', at: at(0))]);
      expect(items.map((e) => e.key), ['o:o1', 'n:n1']);
    });

    test('notice with no updatedAt falls back to createdAt then epoch', () {
      final n = Notice(id: 'x', kind: NoticeKinds.buddyRequest, count: 1, createdAt: at(3), isRead: false);
      expect(InboxFeed.noticeTime(n), at(3));
      final bare = Notice(id: 'y', kind: NoticeKinds.buddyRequest, count: 1, isRead: false);
      expect(InboxFeed.merge([old('o', at(0))], [bare]).last.key, 'n:y');
    });

    test('rows older than the oldest loaded row of a list with more pages are held back', () {
      final oldRows = [old('o1', at(10)), old('o2', at(8))];
      final notices = [notice(NoticeKinds.buddyRequest, id: 'n1', at: at(9)), notice(NoticeKinds.tripInvite, id: 'n2', at: at(1))];
      final held = InboxFeed.merge(oldRows, notices, oldHasMore: true);
      expect(held.map((e) => e.key), ['o:o1', 'n:n1', 'o:o2']);
      final all = InboxFeed.merge(oldRows, notices);
      expect(all.map((e) => e.key), ['o:o1', 'n:n1', 'o:o2', 'n:n2']);
    });

    test('notices having more pages hold back older old-rows', () {
      final oldRows = [old('o1', at(10)), old('o2', at(1))];
      final notices = [notice(NoticeKinds.buddyRequest, id: 'n1', at: at(5))];
      final held = InboxFeed.merge(oldRows, notices, noticesHasMore: true);
      expect(held.map((e) => e.key), ['o:o1', 'n:n1']);
    });
  });
}
