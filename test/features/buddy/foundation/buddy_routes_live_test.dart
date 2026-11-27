import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/buddy_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const trip = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  test('every buddy route is registered and named as the backend pushes it', () {
    const names = {
      AppRoutes.buddies: '/buddies',
      AppRoutes.buddiesBlocked: '/buddies-blocked',
      AppRoutes.buddyScan: '/buddy-scan',
      AppRoutes.tripInvite: '/trip-invite',
      AppRoutes.tripInvitePeople: '/trip-invite-people',
      AppRoutes.tripTravellers: '/trip-travellers',
      AppRoutes.tripView: '/trip-view',
      AppRoutes.tripDayPlan: '/trip-day-plan',
      AppRoutes.tripDayMap: '/trip-day-map',
      AppRoutes.tripMyShare: '/trip-my-share',
      AppRoutes.tripExpenses: '/trip-expenses',
      AppRoutes.tripExpense: '/trip-expense',
      AppRoutes.tripSettle: '/trip-settle',
      AppRoutes.tripMoneySummary: '/trip-money-summary',
    };
    names.forEach((constant, route) {
      expect(constant, route);
      expect(AppRoutes.isRegistered(route), isTrue, reason: route);
    });
    expect(buddyPages.length, names.length);
    expect(AppRoutes.tabKeyForRoute(AppRoutes.tripExpenses), isNull);
  });

  test('a deleted trip push opens the viewer page in its deleted state', () {
    final t = AppRoutes.liveTarget(AppRoutes.myTrips, {'deletedTripId': trip});
    expect(t!.route, AppRoutes.tripView);
    expect(t.args, {'tripId': trip, 'deleted': true});
    expect(AppRoutes.liveTarget(AppRoutes.myTrips)!.route, AppRoutes.myTrips);
    expect(AppRoutes.liveTarget(AppRoutes.tripExpenses, {'tripId': trip})!.args, {'tripId': trip});
  });

  group('BuddyPushSync', () {
    test('wire types bump the right ticks once after the debounce', () {
      final b = BuddyLive.buddies.value;
      final n = BuddyLive.notices.value;
      final s = BuddyLive.sharedTrips.value;
      final e = BuddyLive.expenses(trip).value;
      final v = BuddyLive.tripView(trip).value;
      BuddyPushSync.onPush('buddy_request_received', '/buddies', {'tab': 'requests'});
      BuddyPushSync.onPush('trip_payment_said_paid', '/trip-expenses', {'tripId': trip, 'tab': 'balances'});
      BuddyPushSync.onPush('trip_expenses_updated', '/trip-expenses', {'tripId': trip});
      BuddyPushSync.onPush('chat_message', null, null);
      expect(BuddyLive.notices.value, n);
      BuddyPushSync.flush();
      expect(BuddyLive.buddies.value, b + 1);
      expect(BuddyLive.notices.value, n + 1);
      expect(BuddyLive.sharedTrips.value, s + 1);
      expect(BuddyLive.expenses(trip).value, e + 1);
      expect(BuddyLive.tripView(trip).value, v);
    });

    test('removed and deleted name the gone trip', () {
      BuddyPushSync.onPush('trip_deleted_for_viewer', '/my-trips', {'deletedTripId': trip});
      BuddyPushSync.flush();
      expect(BuddyLive.goneTrip.value, trip);
      BuddyLive.reset();
    });

    test('a hub expense hint with an old version is ignored', () {
      BuddyLive.seenBalancesVersion(trip, 7);
      final e = BuddyLive.expenses(trip).value;
      BuddyPushSync.onHubEvent(BuddyHubEvents.tripExpensesChanged, {'tripId': trip, 'balancesVersion': 7});
      BuddyPushSync.flush();
      expect(BuddyLive.expenses(trip).value, e);
      BuddyPushSync.onHubEvent(BuddyHubEvents.tripExpensesChanged, {'tripId': trip, 'balancesVersion': 8});
      BuddyPushSync.flush();
      expect(BuddyLive.expenses(trip).value, e + 1);
      BuddyLive.reset();
    });

    test('type check and local notification id collapse', () {
      for (final t in BuddyWireTypes.all) {
        expect(BuddyPushSync.isBuddyType(t), isTrue);
      }
      expect(BuddyPushSync.isBuddyType('trip_offer'), isFalse);
      final a = {'feature': 'buddy', 'notification_type': 'trip_expenses_updated', 'action_args_json': '{"tripId":"$trip"}', 'body': 'one'};
      final b = {...a, 'body': 'two'};
      expect(BuddyPushSync.isBuddyPush(a), isTrue);
      expect(BuddyPushSync.localNotificationId(a), BuddyPushSync.localNotificationId(b));
    });
  });
}
