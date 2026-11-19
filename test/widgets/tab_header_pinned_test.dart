import 'dart:io';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/controllers/home_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
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
import 'package:bakhli/features/trip/widgets/hub/hub_header.dart';
import 'package:bakhli/screens/home_screen.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:bakhli/widgets/tab_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../support/real_phone.dart';

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

void _base() {
  Get.reset();
  Get.put<TabConfigController>(_Tabs());
  Get.put<AuthController>(JAuth());
  Get.put<LocationController>(JLoc()..userLocation.value = const LatLng(29.2, 79.5));
  Get.put<NotificationController>(_Notif());
  Get.put<ChatController>(_Chat());
}

typedef _Tab = ({String name, String title, Widget Function() setup});

final List<_Tab> _tabs = [
  (
    name: 'home',
    title: 'Hi, there',
    setup: () {
      Get.put<HomeController>(_Home());
      Get.put<PlanController>(_Plan());
      return const HomeScreen();
    },
  ),
  (
    name: 'stays',
    title: 'Stays',
    setup: () {
      Get.put<StayTypesController>(_Types());
      Get.put(NearbyCentreController());
      Get.put<StayLandingControllerV2>(_Stays(), tag: StayLandingControllerV2.tag).reload();
      return const StayLandingScreenV2();
    },
  ),
  (
    name: 'trips',
    title: 'Trips',
    setup: () {
      Get.put<TripCityCatalog>(_Catalog(), permanent: true);
      Get.put<MyTripsController>(_Trips(), permanent: true);
      return const TripsDiscoveryScreen();
    },
  ),
  (
    name: 'taxi',
    title: 'Taxi',
    setup: () {
      Get.put(NearbyCentreController());
      Get.put(TaxiListControllerV2(root: true, repo: _TaxiRepo()), tag: TaxiListControllerV2.tag).retry();
      return const TaxiListScreenV2(root: true);
    },
  ),
  (
    name: 'profile',
    title: 'Profile',
    setup: () {
      Get.put<PlanController>(_Plan());
      return const ProfileScreen();
    },
  ),
];

const _sizes = [Size(320, 568), Size(360, 640), Size(360, 800), Size(411, 891), Size(600, 960)];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('tab_hdr_gs').path);
    await GetStorage.init();
    await loadRealFonts();
  });
  tearDown(Get.reset);

  for (final tab in _tabs) {
    for (final size in _sizes) {
      testWidgets('${tab.name} at ${size.width.toInt()}x${size.height.toInt()}: shared header, fixed, icons, no art', (t) async {
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          final fromHeader = d.informationCollector?.call().any((n) => n.toString().contains('TabHeader')) ?? false;
          if (!d.exceptionAsString().contains('overflowed') || fromHeader) prev?.call(d);
        };
        addTearDown(() => FlutterError.onError = prev);
        _base();
        await pumpPhone(t, tab.setup(), size: size);
        await settlePhone(t);

        expect(find.byType(TabHeader), findsOneWidget);
        expect(find.descendant(of: find.byType(TabHeader), matching: find.text(tab.title)), findsOneWidget);
        expect(find.descendant(of: find.byType(TabHeader), matching: find.bySemanticsLabel('Notifications')), findsOneWidget);
        expect(find.descendant(of: find.byType(TabHeader), matching: find.bySemanticsLabel('Chats')), findsOneWidget);
        expect(find.byType(ModuleTitleBar), findsNothing);
        expect(find.byType(HubHeader), findsNothing);
        expect(
          find.byWidgetPredicate((w) => w is Art3D && w.asset == ListingArt.profile),
          findsNothing,
        );

        final header = t.getRect(find.byType(TabHeader));
        expect(header.top, 0);
        expect(header.width, size.width);

        final scrollable = find
            .descendant(of: find.byType(TabHeaderFrame), matching: find.byType(Scrollable))
            .first;
        final pos = t.state<ScrollableState>(scrollable).position;
        for (final off in [120.0, 600.0, 100000.0]) {
          pos.jumpTo(off.clamp(pos.minScrollExtent, pos.maxScrollExtent));
          await t.pump(const Duration(milliseconds: 100));
          expect(t.getRect(find.byType(TabHeader)), header);
        }
        final chats = find.descendant(of: find.byType(TabHeader), matching: find.bySemanticsLabel('Chats'));
        final box = t.renderObject(chats);
        final hit = t.hitTestOnBinding(t.getCenter(chats));
        expect(hit.path.any((e) => identical(e.target, box)), isTrue);
        expect(t.takeException(), isNull);
      });
    }
  }
}
