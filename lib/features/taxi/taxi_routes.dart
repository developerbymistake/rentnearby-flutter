import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../design/design.dart';
import 'guest/taxi_detail_screen.dart';
import 'guest/taxi_list_screen.dart';
import 'leads/trip_leads_screen.dart';
import 'setup/my_taxi_screen.dart';
import 'setup/taxi_routes_screen.dart';
import 'setup/taxi_setup_hub_screen.dart';
import 'setup/taxi_submit_screen.dart';
import 'setup/taxi_vehicle_screen.dart';

final List<GetPage> taxiPages = [
  GetPage(
    name: AppRoutes.taxiSetup,
    page: () => const TaxiSetupHubScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.taxiVehicle,
    page: () => const TaxiVehicleScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.taxiRoutes,
    page: () => const TaxiRoutesScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.taxiSubmit,
    page: () => const TaxiSubmitScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.myTaxi,
    page: () => const MyTaxiScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.taxiDetail,
    page: () => const TaxiDetailScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.taxiList,
    page: () => const TaxiListScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripLeads,
    page: () => const TripLeadsScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
];
