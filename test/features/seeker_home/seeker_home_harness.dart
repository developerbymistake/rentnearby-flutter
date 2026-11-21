import 'dart:async';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/controllers/home_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/extra/template_nav.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_controller.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_model.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'seeker_fakes.dart';

class HTabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class HAuth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class HHome extends HomeController {
  int retries = 0;
  Future<void> Function()? onRetry;

  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> reloadDistrict() async {}
  @override
  Future<void> reloadSections(Set<String> keys) async {
    retries++;
    await onRetry?.call();
  }
}

class HNotif extends NotificationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class HChat extends ChatController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class HPlan extends PlanController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class HLoc extends LocationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

HomeStayModel fixtureStay(String id, String name, String type, String city, String district, {String? km, int price = 3000}) {
  final m = HomeStayModel.fromJson({
    'id': id,
    'name': name,
    'cityName': city,
    'districtName': district,
    'stayTypeName': type,
    'minPricePerNight': price,
    'createdAt': '2026-11-01T10:00:00Z',
  });
  return HomeStayModel(
    item: km == null ? m.item : m.item.withPlace(placeName: city, distanceLabel: km),
    districtName: m.districtName,
    createdAt: m.createdAt,
    stayTypeName: m.stayTypeName,
  );
}

TaxiBrowseItem fixtureTaxi(String id, String name, String type, String city, int dayRate) => TaxiBrowseItem(
      id: id,
      driverName: name,
      vehicleTypeName: type,
      seats: 4,
      plateDisplay: 'UK 04 TA 2231',
      cityName: city,
      minFare: dayRate,
      localDayRate: dayRate,
      routeCount: 1,
      matchReversed: false,
      createdAt: DateTime(2026, 11, 1),
      isFeatured: false,
    );

List<HomeStayModel> fixtureStays(int n) => [
      fixtureStay('s1', 'Deodar Heights', 'Homestay', 'Mukteshwar', 'Nainital', km: '2.1 km', price: 3000),
      fixtureStay('s2', 'Lake View Inn', 'Guest House', 'Bhimtal', 'Nainital', km: '5.8 km', price: 1400),
      fixtureStay('s3', 'Pine Crest', 'Cottage', 'Satkhol', 'Nainital', price: 2400),
      for (var i = 3; i < n; i++) fixtureStay('sx$i', 'Stay number $i', 'Homestay', 'Nainital', 'Nainital', km: '$i.0 km'),
    ].take(n).toList();

List<TaxiBrowseItem> fixtureTaxis(int n) => [
      fixtureTaxi('t1', 'Ramesh Negi', 'Sedan', 'Nainital', 900),
      fixtureTaxi('t2', 'Mahesh Adhikari', 'Tempo Traveller', 'Haldwani', 2500),
      fixtureTaxi('t3', 'Kiran Bisht', 'SUV', 'Bhimtal', 1800),
      for (var i = 3; i < n; i++) fixtureTaxi('tx$i', 'Driver $i', 'Sedan', 'Nainital', 1000),
    ].take(n).toList();

List<HomeStayModel> fixtureRecent() => [
      HomeStayModel.fromJson({'id': 'r1', 'name': 'Snow Peak Cottage', 'cityName': 'Manali', 'districtName': 'Himachal', 'createdAt': '2026-11-20T10:00:00Z'}),
      HomeStayModel.fromJson({'id': 'r2', 'name': 'River Bend Stay', 'cityName': 'Rishikesh', 'districtName': 'Uttarakhand', 'createdAt': '2026-11-19T10:00:00Z'}),
    ];

const List<TripCityModel> fixtureCities = [
  TripCityModel(cityKey: 0, name: 'Nainital', stateName: 'Uttarakhand', latitude: 29.39, longitude: 79.45, isPopularDestination: true),
  TripCityModel(cityKey: 1, name: 'Kedarnath', stateName: 'Uttarakhand', latitude: 30.73, longitude: 79.06, isPopularDestination: true),
  TripCityModel(cityKey: 2, name: 'Rishikesh', stateName: 'Uttarakhand', latitude: 30.08, longitude: 78.26, isPopularDestination: true),
];

SeekerFeed fixtureNoTrip() => const SeekerFeed(slots: SeekerSlots(count: 0, limit: 3, full: false));

SeekerFeed fixtureInProgress({bool full = false, SeekerStatus? status}) => SeekerFeed(
      tripCard: SeekerTripCard(
        state: SeekerTripState.inProgress,
        tripId: 'trip-1',
        title: 'Nainital trip',
        destinationName: 'Nainital',
        startDate: DateTime(2026, 11, 26),
        endDate: DateTime(2026, 11, 29),
        done: 3,
        total: 5,
        nextStep: const SeekerNextStep(key: 'taxi', kind: SeekerStepKind.taxi),
      ),
      status: status,
      slots: SeekerSlots(count: full ? 3 : 2, limit: 3, full: full),
    );

SeekerFeed fixtureOnTrip() => SeekerFeed(
      tripCard: SeekerTripCard(
        state: SeekerTripState.onTrip,
        tripId: 'trip-1',
        title: 'Nainital trip',
        destinationName: 'Nainital',
        startDate: DateTime(2026, 11, 26),
        endDate: DateTime(2026, 11, 29),
        done: 3,
        total: 5,
        today: const SeekerToday(dayNumber: 2, totalDays: 4, cityName: 'Mukteshwar', placeCount: 4),
      ),
      slots: const SeekerSlots(count: 1, limit: 3, full: false),
    );

final List<String> visitedRoutes = <String>[];

/// Registers the Home controllers with fixture rails. [feed] null = the feed call never completes (first open).
HHome registerHome({
  SeekerFeed? feed,
  bool railsLoading = false,
  bool railsFailed = false,
  int stays = 3,
  int taxis = 3,
  bool recent = true,
  bool cities = true,
}) {
  Get.reset();
  visitedRoutes.clear();
  Get.put<TabConfigController>(HTabs());
  final auth = Get.put<AuthController>(HAuth());
  auth.profileName.value = 'Rohit Sharma';
  Get.put<LocationController>(HLoc());
  final home = Get.put<HomeController>(HHome()) as HHome;
  Get.put<NotificationController>(HNotif());
  Get.put<ChatController>(HChat());
  Get.put<PlanController>(HPlan());
  TripCityCatalog.to.seedForTest(cities ? fixtureCities : const []);
  if (!railsFailed) {
    home.stays.assignAll(fixtureStays(stays));
    home.taxis.assignAll(fixtureTaxis(taxis));
    if (recent) home.recentlyAddedStays.assignAll(fixtureRecent());
  } else {
    home.failedSections.addAll({HomeSectionKeys.stays, HomeSectionKeys.taxis, HomeSectionKeys.recentStays});
  }
  home.staysLoading.value = railsLoading;
  home.taxisLoading.value = railsLoading;
  home.recentlyAddedStaysLoading.value = railsLoading;
  final api = ScriptedFeedApi(() => feed == null ? Completer<OwnerResult<SeekerFeed>>().future : Future.value(OwnerOk<SeekerFeed>(feed)));
  Get.put(SeekerFeedController(api: api, userIdOf: () => 'user-a'));
  return home;
}

Widget seekerBar() => TemplateBottomBar(
      bottomInset: 0,
      selectedIndex: 0,
      onTap: (_) {},
      items: const [
        TemplateNavItem(index: 0, image: 'assets/images/design/travel3d/compass.png', label: 'Home'),
        TemplateNavItem(index: 1, image: 'assets/images/design/travel3d/camping.png', label: 'Stays'),
        TemplateNavItem(index: 2, image: 'assets/images/design/travel3d/luggage.png', label: 'Trips', center: true),
        TemplateNavItem(index: 3, image: 'assets/images/design/travel3d/taxi.png', label: 'Taxi'),
        TemplateNavItem(index: 4, image: 'assets/images/design/travel3d/fox.png', label: 'Profile'),
      ],
    );

Widget homeHost({bool bar = false}) => Scaffold(
      extendBody: true,
      body: const HomeScreen(),
      bottomNavigationBar: bar ? seekerBar() : null,
    );

List<GetPage<dynamic>> routeStubs() => [
      for (final r in [
        AppRoutes.notifications,
        AppRoutes.chatsList,
        AppRoutes.stayDetail,
        AppRoutes.myTrips,
        AppRoutes.tripExpenses,
        AppRoutes.buddies,
        AppRoutes.tripOverview,
        AppRoutes.tripReplies,
        AppRoutes.tripDayPlan,
      ])
        GetPage(
          name: r,
          page: () {
            visitedRoutes.add(r);
            return const Scaffold(body: SizedBox());
          },
        ),
    ];
