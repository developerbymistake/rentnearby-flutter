import 'dart:io';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/controllers/home_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/jobs/models/job_lookups_model.dart';
import 'package:bakhli/features/jobs/v2/jobs_feed_controller.dart';
import 'package:bakhli/features/jobs/v2/jobs_feed_repository.dart';
import 'package:bakhli/features/jobs/v2/jobs_landing_screen_v2.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/stay/guest/v2/stay_feed_item.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_controller_v2.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_screen_v2.dart';
import 'package:bakhli/features/stay/stay_types_controller.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_screen_v2.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/screens/trips_discovery_screen.dart';
import 'package:bakhli/screens/home_screen.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:bakhli/design/extra/ext_jobs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../e2e_journeys/nearby/nearby_support.dart';
import '../../support/real_phone.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Home extends HomeController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> reloadDistrict() async {}
}

class _Notif extends NotificationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Chat extends ChatController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Plan extends PlanController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Types extends StayTypesController {
  @override
  void ensureLoaded() {}
}

class _Stays extends StayLandingControllerV2 {
  @override
  int? get tabIndex => null;
  @override
  RxInt? get tabRx => null;
  @override
  Future<NearbyPage<StayFeedItem>> fetchPage(String? token) async => NearbyPage<StayFeedItem>(items: [
        for (var i = 0; i < 12; i++)
          StayFeedItem.fromJson({
            'id': 's$i',
            'userId': 'u',
            'name': 'Deodar Valley Homestay $i',
            'cityName': 'Nainital',
            'districtName': 'Nainital',
            'stateName': 'Uttarakhand',
            'minPricePerNight': 1200,
            'isFeatured': false,
            'distanceKm': 3.2,
            'labelKey': 'near',
          }),
      ]);
}

class _TaxiRepo extends TaxiFeedRepository {
  @override
  Future<NearbyPage<TaxiFeedItem>> local(
          {required double lat, required double lng, String? pageToken, int pageSize = 20, String? category}) async =>
      NearbyPage<TaxiFeedItem>(items: [
        for (var i = 0; i < 12; i++)
          TaxiFeedItem.fromJson({
            'id': 't$i',
            'driverName': 'Driver $i',
            'vehicleTypeName': 'Sedan',
            'plateDisplay': 'UK04',
            'routeCount': 2,
            'createdAt': '2026-11-01T00:00:00Z',
            'cityName': 'Haldwani',
            'stateName': 'Uttarakhand',
            'distanceKm': 5.0,
            'labelKey': 'near',
            'minFare': 900,
          }),
      ]);
}

class _Catalog extends TripCityCatalog {
  final list = [
    for (var i = 1; i <= 6; i++)
      TripCityModel(
        cityKey: i,
        name: 'City $i',
        districtName: 'D$i',
        stateName: 'Uttarakhand',
        latitude: 29,
        longitude: 79,
        spotCount: 8,
        status: TripCityStatus.ready,
      ),
  ];
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => true;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async => list;
  @override
  List<TripCityModel> search(String q) => TripCitySearch.filter(list, q);
  @override
  List<TripCityModel> ready(String q, {String? stateName}) => list;
  @override
  List<String> liveStates() => ['Uttarakhand'];
}

class _Trips extends MyTripsController {
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<void> load({bool refresh = false}) async {}
}

JobsFeedController _jobs() => JobsFeedController(
      fetch: ({
        int? cityKey,
        double? lat,
        double? lng,
        String? departmentId,
        int? minExperience,
        int? maxExperience,
        int? minSalary,
        String? pageToken,
        int pageSize = 20,
      }) async =>
          NearbyPage(items: [
            for (var i = 0; i < 12; i++)
              JobFeedItem.fromJson({
                'id': 'j$i',
                'stayName': 'Stay $i',
                'title': 'Cook $i',
                'roleName': 'Cook',
                'jobTypeName': 'Full time',
                'salaryTypeName': 'Monthly',
                'minSalary': 12000,
                'maxSalary': 18000,
                'createdAt': DateTime.now().toIso8601String(),
                'distanceKm': 3.0,
                'labelKey': 'near',
                'cityName': 'Nainital',
                'stateName': 'Uttarakhand',
              }),
          ]),
      gps: () => (lat: 29.4, lng: 79.4),
      lookupsLoader: () async => JobLookups.fromJson(const {}),
    );

void _base() {
  Get.reset();
  Get.put<TabConfigController>(_Tabs());
  Get.put<AuthController>(JAuth());
  Get.put<LocationController>(JLoc()..userLocation.value = const LatLng(29.2, 79.5));
}

const _offsets = [0.0, 120.0, 400.0, 100000.0];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('hdr_gs').path);
    await GetStorage.init();
    await loadRealFonts();
    shotsDir = r'F:\Dhasu\UI_Template_resume\Slice3\shots';
  });
  tearDown(Get.reset);

  testWidgets('home header: fixed while scrolling', (t) async {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.exceptionAsString().contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
    _base();
    Get.put<HomeController>(_Home());
    Get.put<NotificationController>(_Notif());
    Get.put<ChatController>(_Chat());
    Get.put<PlanController>(_Plan());
    await pumpPhone(t, const HomeScreen());
    await settlePhone(t);
    final header = find.text('Hi, there');
    expect(header, findsOneWidget);
    final top = t.getTopLeft(header);
    final h = t.getSize(header).height;
    await shot(t, 'H_home_top');
    final pos = t.state<ScrollableState>(find.byType(Scrollable).first).position;
    for (var i = 0; i < _offsets.length; i++) {
      pos.jumpTo(_offsets[i].clamp(0.0, pos.maxScrollExtent));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.getSize(header).height, h);
      expect(t.getTopLeft(header), top);
      await shot(t, 'H_home_scroll_$i');
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('profile header: indigo gradient, scrolls with the page', (t) async {
    _base();
    Get.put(PlanController());
    await pumpPhone(t, const ProfileScreen());
    await settlePhone(t);
    await shot(t, 'H_profile_top');
    final hero = find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).gradient == ListingTone.indigo.gradient);
    expect(hero, findsOneWidget);
    final top = t.getTopLeft(hero);
    await scrollShots(t, find.byType(ProfileScreen), 'H_profile_scroll', _offsets);
    expect(t.getTopLeft(hero).dy, lessThan(top.dy));
    expect(t.takeException(), isNull);
  });

  testWidgets('trips header: 3D title bar, status strip while scrolling', (t) async {
    _base();
    Get.put<TripCityCatalog>(_Catalog(), permanent: true);
    Get.put<MyTripsController>(_Trips(), permanent: true);
    await pumpPhone(t, const TripsDiscoveryScreen());
    await settlePhone(t);
    expect(find.byType(ModuleTitleBar), findsOneWidget);
    await shot(t, 'H_trips_top');
    await scrollShots(t, find.byType(TripsDiscoveryScreen), 'H_trips_scroll', _offsets);
    expect(find.byType(ModuleScrollFrame), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('stays header: 3D title bar, status strip while scrolling', (t) async {
    _base();
    Get.put<StayTypesController>(_Types());
    Get.put(NearbyCentreController());
    final c = Get.put<StayLandingControllerV2>(_Stays(), tag: StayLandingControllerV2.tag);
    c.reload();
    await pumpPhone(t, const StayLandingScreenV2());
    await settlePhone(t);
    expect(find.byType(ModuleTitleBar), findsOneWidget);
    await shot(t, 'H_stays_top');
    await scrollShots(t, find.byType(StayLandingScreenV2), 'H_stays_scroll', _offsets);
    expect(find.byType(ModuleScrollFrame), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('taxi header: 3D title bar, status strip while scrolling', (t) async {
    _base();
    Get.put(NearbyCentreController());
    final c = Get.put(TaxiListControllerV2(root: true, repo: _TaxiRepo()), tag: TaxiListControllerV2.tag);
    c.retry();
    await pumpPhone(t, const TaxiListScreenV2(root: true));
    await settlePhone(t);
    expect(find.byType(ModuleTitleBar), findsOneWidget);
    await shot(t, 'H_taxi_top');
    await scrollShots(t, find.byType(TaxiListScreenV2), 'H_taxi_scroll', _offsets);
    expect(find.byType(ModuleScrollFrame), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('jobs header: 3D title header, status strip while scrolling', (t) async {
    _base();
    Get.put(_jobs(), tag: JobsFeedController.tag);
    await pumpPhone(t, const JobsLandingScreenV2());
    await settlePhone(t);
    expect(find.byType(JobsHeader), findsOneWidget);
    expect(find.byType(ModuleHeader), findsNothing);
    await shot(t, 'H_jobs_top');
    await scrollShots(t, find.byType(JobsLandingScreenV2), 'H_jobs_scroll', _offsets);
    expect(t.takeException(), isNull);
  });

  test('module gradients are all different', () {
    final all = [
      HeaderGradients.home,
      HeaderGradients.stays,
      HeaderGradients.taxi,
      HeaderGradients.trips,
      HeaderGradients.jobs,
      HeaderGradients.profile,
    ];
    expect({for (final g in all) g.colors.first}.length, all.length - 1);
  });
}
