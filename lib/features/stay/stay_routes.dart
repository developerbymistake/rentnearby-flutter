import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../design/design.dart';
import 'enquiries/stay_enquiries_screen.dart';
import 'guest/stay_detail_screen.dart';
import 'setup/my_stays_screen.dart';
import 'setup/stay_advance_details_screen.dart';
import 'setup/stay_basic_details_screen.dart';
import 'setup/stay_rooms_screen.dart';
import 'setup/stay_rules_screen.dart';
import 'setup/stay_setup_hub_screen.dart';
import 'setup/stay_submit_screen.dart';

final List<GetPage> stayPages = [
  GetPage(
    name: AppRoutes.staySetup,
    page: () => const StaySetupHubScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.stayBasicDetails,
    page: () => const StayBasicDetailsScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.stayRooms,
    page: () => const StayRoomsScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.stayRules,
    page: () => const StayRulesScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.staySubmit,
    page: () => const StaySubmitScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.myStays,
    page: () => const MyStaysScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.stayDetail,
    page: () => const StayDetailScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.stayAdvanceDetails,
    page: () => const StayAdvanceDetailsScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.stayEnquiries,
    page: () => const StayEnquiriesScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
];
