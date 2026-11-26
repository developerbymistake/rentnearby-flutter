import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../design/design.dart';
import 'guest/taxi_detail_screen.dart';
import 'guest/taxi_list_screen.dart';
import 'guest/v2/taxi_results_routes.dart';
import 'leads/trip_leads_screen.dart';
import 'requests/driver_bookings_screen.dart';
import 'requests/driver_rating_screen.dart';
import 'requests/driver_ready_screen.dart';
import 'requests/driver_request_detail_screen.dart';
import 'requests/driver_requests_screen.dart';
import 'requests/driver_ring_screen.dart';
import '../taxi_driver/hub/taxi_hub_screen.dart';
import 'setup/taxi_routes_screen.dart';
import 'setup/taxi_onboarding_screen.dart';
import 'setup/taxi_vehicle_screen.dart';

String _offerIdOf(Object? args) => args is Map ? (args['offerId']?.toString() ?? '') : '';

void _openOffer(String offerId) => Get.toNamed(AppRoutes.taxiRequestDetail, arguments: {'offerId': offerId});

Widget _requestsPage() => DriverRequestsScreen(onOpenOffer: _openOffer);

final List<GetPage> driverRequestPages = [
  GetPage(
    name: AppRoutes.taxiRequestRing,
    page: () => _offerIdOf(Get.arguments).isEmpty ? _requestsPage() : DriverRingScreen.fromArguments(Get.arguments),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.taxiRequests,
    page: _requestsPage,
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.taxiRequestDetail,
    page: () {
      final id = _offerIdOf(Get.arguments);
      if (id.isEmpty) return _requestsPage();
      return DriverRequestDetailScreen(offerId: id, onOpenBookings: () => Get.toNamed(AppRoutes.taxiBookings));
    },
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.taxiBookings,
    page: () => const DriverBookingsScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.taxiRating,
    page: () => const DriverRatingScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.taxiReady,
    page: () => const DriverReadyScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
];

final List<GetPage> taxiPages = [
  GetPage(
    name: AppRoutes.taxiSetup,
    page: () => const TaxiOnboardingScreen(),
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
    name: AppRoutes.myTaxi,
    page: () => const TaxiHubScreen(),
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
  ...driverRequestPages,
  ...taxiSeekerPages,
];
