import 'package:get/get.dart';
import '../../config/app_routes.dart';
import 'guest/taxi_detail_screen.dart';
import 'guest/taxi_list_screen.dart';
import 'setup/my_taxi_screen.dart';
import 'setup/taxi_routes_screen.dart';
import 'setup/taxi_setup_hub_screen.dart';
import 'setup/taxi_submit_screen.dart';
import 'setup/taxi_vehicle_screen.dart';

final List<GetPage> taxiPages = [
  GetPage(
    name: AppRoutes.taxiSetup,
    page: () => const TaxiSetupHubScreen(),
    transition: Transition.fadeIn,
    transitionDuration: const Duration(milliseconds: 400),
  ),
  GetPage(
    name: AppRoutes.taxiVehicle,
    page: () => const TaxiVehicleScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.taxiRoutes,
    page: () => const TaxiRoutesScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.taxiSubmit,
    page: () => const TaxiSubmitScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.myTaxi,
    page: () => const MyTaxiScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.taxiDetail,
    page: () => const TaxiDetailScreen(),
    transition: Transition.downToUp,
    transitionDuration: const Duration(milliseconds: 350),
  ),
  GetPage(
    name: AppRoutes.taxiList,
    page: () => const TaxiListScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
];
