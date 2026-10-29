import 'package:get/get.dart';
import '../../config/app_routes.dart';
import 'guest/stay_detail_screen.dart';
import 'setup/my_stays_screen.dart';
import 'setup/stay_basic_details_screen.dart';
import 'setup/stay_rooms_screen.dart';
import 'setup/stay_rules_screen.dart';
import 'setup/stay_setup_hub_screen.dart';
import 'setup/stay_submit_screen.dart';

final List<GetPage> stayPages = [
  GetPage(
    name: AppRoutes.staySetup,
    page: () => const StaySetupHubScreen(),
    transition: Transition.fadeIn,
    transitionDuration: const Duration(milliseconds: 400),
  ),
  GetPage(
    name: AppRoutes.stayBasicDetails,
    page: () => const StayBasicDetailsScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.stayRooms,
    page: () => const StayRoomsScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.stayRules,
    page: () => const StayRulesScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.staySubmit,
    page: () => const StaySubmitScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.myStays,
    page: () => const MyStaysScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.stayDetail,
    page: () => const StayDetailScreen(),
    transition: Transition.downToUp,
    transitionDuration: const Duration(milliseconds: 350),
  ),
];
