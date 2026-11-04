import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../journeys/my_journeys_screen.dart';
import '../journeys/saved_journey_screen.dart';
import 'journey_plan_screen.dart';
import 'journey_road_screen.dart';
import 'taxi_ways_feed_screen.dart';

GetPage _page(String name, Widget Function() page) => GetPage(
      name: name,
      page: page,
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    );

final List<GetPage> taxiWaysPages = [
  _page(AppRoutes.taxiWays, () => const TaxiWaysFeedScreen()),
  _page(AppRoutes.journeyPlan, () => const JourneyPlanScreen()),
  _page(AppRoutes.journeyRoad, () => const JourneyRoadScreen()),
  _page(AppRoutes.myJourneys, () => const MyJourneysScreen()),
  _page(AppRoutes.savedJourney, () => const SavedJourneyScreen()),
];
