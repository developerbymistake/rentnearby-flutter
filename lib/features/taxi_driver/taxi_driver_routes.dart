import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../../design/design.dart';
import '../owner_core/data/owner_args.dart';
import 'calendar/taxi_balance_due_screen.dart';
import 'calendar/taxi_calendar_entry_screen.dart';
import 'calendar/taxi_money_summary_screen.dart';
import 'calendar/taxi_past_screen.dart';
import 'calendar/taxi_upcoming_screen.dart';
import 'home/taxi_attention_screen.dart';
import 'plan_visible/taxi_plan_visible_screen.dart';

GetPage<dynamic> _page(String name, GetPageBuilder page) =>
    GetPage(name: name, page: page, customTransition: TemplateTransition(), transitionDuration: templateTransitionDuration);

final List<GetPage<dynamic>> taxiDriverPages = [
  // A5 pages
  _page(AppRoutes.taxiAttention, () => const TaxiAttentionScreen()),
  // end A5
  // A7 pages
  _page(AppRoutes.taxiCalendarEntry, () => TaxiCalendarEntryScreen(args: OwnerArgs.current)),
  _page(AppRoutes.taxiUpcoming, () => TaxiUpcomingScreen(args: OwnerArgs.current)),
  _page(AppRoutes.taxiPast, () => TaxiPastScreen(args: OwnerArgs.current)),
  _page(AppRoutes.taxiMoneySummary, () => TaxiMoneySummaryScreen(args: OwnerArgs.current)),
  _page(AppRoutes.taxiBalanceDue, () => TaxiBalanceDueScreen(args: OwnerArgs.current)),
  // end A7
  // A8 pages
  _page(AppRoutes.taxiPlanVisible, () => const TaxiPlanVisibleScreen()),
  // end A8
];
