import 'package:get/get.dart';
import '../../config/app_routes.dart';
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
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.tripPlan,
    page: () => const TripPlanScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.tripTaxi,
    page: () => const TripTaxiScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.tripStay,
    page: () => const TripStayScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.tripMap,
    page: () => const TripMapScreen(),
    transition: Transition.downToUp,
    transitionDuration: const Duration(milliseconds: 350),
  ),
  GetPage(
    name: AppRoutes.myTrips,
    page: () => const MyTripsScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.tripReplies,
    page: () => const TripRepliesScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.tripTaxiReplies,
    page: () => const TripTaxiRepliesScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.tripSummary,
    page: () => const TripSummaryScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
];
