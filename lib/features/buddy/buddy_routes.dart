import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../../design/design.dart';
import 'buddies/screens/blocked_people_screen.dart';
import 'buddies/screens/buddies_screen.dart';
import 'expenses/screens/expense_detail_screen.dart';
import 'expenses/screens/trip_expenses_screen.dart';
import 'ledger/screens/money_summary_screen.dart';
import 'ledger/screens/settle_up_screen.dart';
import 'scan/screens/scan_qr_screen.dart';
import 'travellers_route.dart';
import 'viewer/screens/former_share_screen.dart';
import 'viewer/screens/trip_invite_screen.dart';
import 'viewer/screens/viewer_day_plan_screen.dart';
import 'viewer/screens/viewer_map_screen.dart';
import 'viewer/screens/viewer_trip_screen.dart';

abstract final class BuddyArgs {
  static Map<dynamic, dynamic> get current {
    final a = Get.arguments;
    return a is Map ? a : const {};
  }

  static String text(Map<dynamic, dynamic> a, String key) {
    final v = a[key];
    return v is String ? v : '';
  }

  static String? textOrNull(Map<dynamic, dynamic> a, String key) {
    final v = a[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  static int? number(Map<dynamic, dynamic> a, String key) {
    final v = a[key];
    return v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
  }

  static bool flag(Map<dynamic, dynamic> a, String key) => a[key] == true || a[key] == 'true';
}

GetPage<dynamic> _page(String name, GetPageBuilder page) =>
    GetPage(name: name, page: page, customTransition: TemplateTransition(), transitionDuration: templateTransitionDuration);

final List<GetPage<dynamic>> buddyPages = [
  _page(AppRoutes.buddies, () {
    final a = BuddyArgs.current;
    return BuddiesScreen(tab: BuddyArgs.textOrNull(a, 'tab') ?? 'buddies', query: BuddyArgs.textOrNull(a, 'query'), source: BuddyArgs.textOrNull(a, 'source'));
  }),
  _page(AppRoutes.buddiesBlocked, () => const BlockedPeopleScreen()),
  _page(AppRoutes.buddyScan, () => const ScanQrScreen()),
  _page(AppRoutes.tripInvite, () => TripInviteScreen(memberId: BuddyArgs.text(BuddyArgs.current, 'memberId'))),
  _page(AppRoutes.tripTravellers, () => TravellersRoute(tripId: BuddyArgs.text(BuddyArgs.current, 'tripId'))),
  _page(AppRoutes.tripView, () {
    final a = BuddyArgs.current;
    return ViewerTripScreen(tripId: BuddyArgs.text(a, 'tripId'), deleted: BuddyArgs.flag(a, 'deleted'));
  }),
  _page(AppRoutes.tripDayPlan, () {
    final a = BuddyArgs.current;
    return ViewerDayPlanScreen(tripId: BuddyArgs.text(a, 'tripId'), day: BuddyArgs.number(a, 'day'));
  }),
  _page(AppRoutes.tripDayMap, () {
    final a = BuddyArgs.current;
    return ViewerMapScreen(tripId: BuddyArgs.text(a, 'tripId'), day: BuddyArgs.number(a, 'day'));
  }),
  _page(AppRoutes.tripMyShare, () => FormerShareScreen(tripId: BuddyArgs.text(BuddyArgs.current, 'tripId'))),
  _page(AppRoutes.tripExpenses, () {
    final a = BuddyArgs.current;
    return TripExpensesScreen(
      tripId: BuddyArgs.text(a, 'tripId'),
      tab: BuddyArgs.textOrNull(a, 'tab'),
      day: BuddyArgs.number(a, 'day'),
    );
  }),
  _page(AppRoutes.tripExpense, () {
    final a = BuddyArgs.current;
    return ExpenseDetailScreen(tripId: BuddyArgs.text(a, 'tripId'), expenseId: BuddyArgs.text(a, 'expenseId'));
  }),
  _page(AppRoutes.tripSettle, () => SettleUpScreen(tripId: BuddyArgs.text(BuddyArgs.current, 'tripId'))),
  _page(AppRoutes.tripMoneySummary, () => MoneySummaryScreen(tripId: BuddyArgs.text(BuddyArgs.current, 'tripId'))),
];
