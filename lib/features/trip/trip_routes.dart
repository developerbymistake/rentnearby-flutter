import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../design/design.dart';
import 'screens/my_trips_screen.dart';
import 'screens/trip_map_screen.dart';
import 'screens/trip_plan_screen.dart';
import 'screens/trip_replies_screen.dart';
import 'screens/trip_spots_screen.dart';
import 'screens/trip_stay_screen.dart';
import 'screens/trip_taxi_replies_screen.dart';
import 'screens/trip_summary_screen.dart';
import 'screens/trip_taxi_screen.dart';

final List<GetPage> tripPages = [
  GetPage(
    name: AppRoutes.tripSpots,
    page: () => const TripSpotsScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripPlan,
    page: () => const TripPlanScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripTaxi,
    page: () => const TripTaxiScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripStay,
    page: () => const TripStayScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripMap,
    page: () => const TripMapScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.myTrips,
    page: () => const MyTripsScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripReplies,
    page: () => const TripRepliesScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripTaxiReplies,
    page: () => const TripTaxiRepliesScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripSummary,
    page: () => const TripSummaryScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
];
