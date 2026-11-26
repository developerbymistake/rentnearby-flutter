import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../social/shared/social_nav.dart';
import '../trip/trip_navigation.dart';

abstract final class BuddyNavigation {
  static Future<dynamic>? _go(String route, Map<String, dynamic> args, {bool replace = false}) =>
      replace ? Get.offNamed(route, arguments: args) : Get.toNamed(route, arguments: args);

  static Future<dynamic>? openBuddies({String tab = 'find', String? query, String? source}) =>
      SocialNav.openPeople(tab: tab == 'requests' ? 'requests' : 'buddies');

  static Future<dynamic>? openBlocked() => Get.toNamed(AppRoutes.buddiesBlocked);

  static Future<String?> openScan() async {
    final r = await Get.toNamed(AppRoutes.buddyScan);
    return r is String ? r : null;
  }

  static Future<dynamic>? openTripInvite(String memberId) => _go(AppRoutes.tripInvite, {'memberId': memberId});

  static Future<dynamic>? openTravellers(String tripId) => _go(AppRoutes.tripTravellers, {'tripId': tripId});

  static Future<dynamic>? openTripView(String tripId, {bool replace = false, bool deleted = false}) =>
      _go(AppRoutes.tripView, {'tripId': tripId, if (deleted) 'deleted': true}, replace: replace);

  static Future<dynamic>? openOwnerOverview(String tripId, {bool replace = false}) =>
      _go(AppRoutes.tripOverview, {'tripId': tripId}, replace: replace);

  static Future<dynamic>? openDayPlan(String tripId, {int? day}) => _go(AppRoutes.tripDayPlan, {'tripId': tripId, 'day': ?day});

  static Future<dynamic>? openDayMap(String tripId, {int? day}) => _go(AppRoutes.tripDayMap, {'tripId': tripId, 'day': ?day});

  static Future<dynamic>? openMyShare(String tripId, {bool replace = false}) => _go(AppRoutes.tripMyShare, {'tripId': tripId}, replace: replace);

  static Future<dynamic>? openExpenses(String tripId, {String? tab, int? day, bool replace = false}) =>
      _go(AppRoutes.tripExpenses, {'tripId': tripId, 'tab': ?tab, 'day': ?day}, replace: replace);

  static Future<dynamic>? openExpense(String tripId, String expenseId) => _go(AppRoutes.tripExpense, {'tripId': tripId, 'expenseId': expenseId});

  static Future<dynamic>? openSettleUp(String tripId) => _go(AppRoutes.tripSettle, {'tripId': tripId});

  static Future<dynamic>? openMoneySummary(String tripId) => _go(AppRoutes.tripMoneySummary, {'tripId': tripId});

  static Future<dynamic>? openMoneyHome(String tripId, {required bool tripEnded, required bool settled}) {
    if (!tripEnded) return openExpenses(tripId);
    return settled ? openMoneySummary(tripId) : openSettleUp(tripId);
  }

  static void openPlanATrip() => TripNavigation.openTripsTab();

  static void backToMyTrips() => TripNavigation.openTripsTab();
}
