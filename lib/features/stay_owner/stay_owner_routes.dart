import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../../design/design.dart';
import '../owner_core/data/owner_args.dart';
import 'calendar/stay_balance_due_screen.dart';
import 'calendar/stay_calendar_entry_screen.dart';
import 'calendar/stay_calendar_screen.dart';
import 'calendar/stay_money_summary_screen.dart';
import 'calendar/stay_past_screen.dart';
import 'calendar/stay_upcoming_screen.dart';
import 'home/stay_attention_screen.dart';
import 'live_edit/stay_live_edit_screen.dart';
import 'plan_visible/stay_plan_visible_screen.dart';
import 'quotation/screens/quote_business_screen.dart';
import 'quotation/screens/quote_form_screen.dart';
import 'quotation/screens/quote_list_screen.dart';
import 'quotation/screens/quote_preview_screen.dart';
import 'quotation/screens/quote_template_screen.dart';
import 'quotation/stay_owner_only_middleware.dart';
import 'special_prices/stay_special_prices_screen.dart';

GetPage<dynamic> _page(String name, GetPageBuilder page) =>
    GetPage(name: name, page: page, customTransition: TemplateTransition(), transitionDuration: templateTransitionDuration);

GetPage<dynamic> _quotePage(String name, GetPageBuilder page) => GetPage(
      name: name,
      page: page,
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
      middlewares: [StayOwnerOnlyMiddleware()],
    );

// Route and push ids are GUIDs; anything else is treated as missing and lands on the calendar.
Widget stayEntryPage(Map<String, dynamic> args) {
  final id = OwnerArgs.id(args, 'id');
  if (id == null) return const StayCalendarScreen();
  return StayCalendarEntryScreen(args: {...args, 'id': id});
}

final List<GetPage<dynamic>> stayOwnerPages = [
  // A2 pages
  _page(AppRoutes.stayAttention, () => const StayAttentionScreen()),
  _page(AppRoutes.stayLiveEdit, () => const StayLiveEditScreen()),
  // end A2
  // A4 pages
  _page(AppRoutes.stayCalendar, () => StayCalendarScreen(args: OwnerArgs.current)),
  _page(AppRoutes.stayCalendarEntry, () => stayEntryPage(OwnerArgs.current)),
  _page(AppRoutes.stayUpcoming, () => StayUpcomingScreen(args: OwnerArgs.current)),
  _page(AppRoutes.stayPast, () => StayPastScreen(args: OwnerArgs.current)),
  _page(AppRoutes.stayMoneySummary, () => StayMoneySummaryScreen(args: OwnerArgs.current)),
  _page(AppRoutes.stayBalanceDue, () => StayBalanceDueScreen(args: OwnerArgs.current)),
  _page(AppRoutes.staySpecialPrices, () => StaySpecialPricesScreen(args: OwnerArgs.current)),
  _page(AppRoutes.stayPlanVisible, () => const StayPlanVisibleScreen()),
  // end A4
  // quotation pages
  _quotePage(AppRoutes.stayQuotations, () => QuoteListScreen(args: OwnerArgs.current)),
  _quotePage(AppRoutes.stayQuotationBusiness, () => QuoteBusinessScreen(args: OwnerArgs.current)),
  _quotePage(AppRoutes.stayQuotationEdit, () => QuoteFormScreen(args: OwnerArgs.current)),
  _quotePage(AppRoutes.stayQuotationTemplate, () => QuoteTemplateScreen(args: OwnerArgs.current)),
  _quotePage(AppRoutes.stayQuotationPreview, () => QuotePreviewScreen(args: OwnerArgs.current)),
  // end quotation
];
