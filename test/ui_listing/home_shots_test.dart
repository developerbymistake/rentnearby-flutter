import 'dart:io';

import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/controllers/home_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay/models/stay_browse_item.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../support/real_phone.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Auth extends AuthController {
  _Auth({this.owner = false});
  final bool owner;
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  bool get staysEnabled {
    user.value;
    return owner;
  }

  @override
  bool get jobsEnabled {
    user.value;
    return owner;
  }

  @override
  bool get taxisEnabled {
    user.value;
    return false;
  }
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

class _Loc extends LocationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

TripCityModel _city(int k, String name, String state, int spots, {bool ready = true}) => TripCityModel(
      cityKey: k,
      name: name,
      stateName: state,
      latitude: 29,
      longitude: 79,
      spotCount: spots,
      isPopularDestination: true,
      status: ready ? TripCityStatus.ready : TripCityStatus.notReady,
    );

class _Catalog extends TripCityCatalog {
  final list = [
    _city(0, 'Nainital', 'Uttarakhand', 24),
    _city(1, 'Mussoorie', 'Uttarakhand', 18),
    _city(2, 'Manali', 'Himachal', 20),
    _city(3, 'Kasol', 'Himachal', 0, ready: false),
  ];
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => true;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async => list;
  @override
  List<TripCityModel> popular({String? stateName}) => list;
}

TaxiBrowseItem _taxi(String id, String name, String vehicle, int seats, {bool featured = false, int? fare = 2400}) => TaxiBrowseItem(
      id: id,
      driverName: name,
      vehicleTypeName: vehicle,
      seats: seats,
      plateDisplay: 'UK07 AB 1234',
      cityName: 'Nainital',
      minFare: fare,
      routeCount: 2,
      matchReversed: false,
      createdAt: DateTime(2026, 1, 1),
      isFeatured: featured,
    );

HomeStayModel _stay(String id, String name, String city, int price, {bool featured = false, String district = 'Nainital'}) => HomeStayModel(
      item: StayBrowseItem.fromJson({
        'id': id,
        'name': name,
        'cityName': city,
        'districtName': district,
        'stayTypeName': 'Homestay',
        'mealsChip': 'breakfast',
        'roomNameChip': 'Deluxe room',
        'minPricePerNight': price,
        'isFeatured': featured,
      }),
      districtName: district,
      createdAt: DateTime(2026, 5, 1),
    );

void _register({bool owner = false, bool long = false, bool empty = false}) {
  Get.reset();
  Get.put<TripCityCatalog>(_Catalog(), permanent: true);
  Get.put<TabConfigController>(_Tabs());
  final auth = Get.put<AuthController>(_Auth(owner: owner));
  auth.profileName.value = long ? 'Bhupendra Singh Rawat' : 'Rahul Sharma';
  auth.tabIndex.value = AppTabs.home;
  Get.put<LocationController>(_Loc());
  Get.put<HomeController>(_Home());
  Get.put<NotificationController>(_Notif()).unreadCount.value = 2;
  Get.put<ChatController>(_Chat()).unreadCount.value = 1;
  final plan = Get.put<PlanController>(_Plan());
  if (owner) {
    plan.myPlan.value = const MyPlanModel(paymentEnabled: true, isPaid: true, isDefault: false, daysLeft: 3, planName: 'Pro');
  }
  final home = Get.find<HomeController>();
  if (!empty) {
    home.stays.assignAll([
      _stay('s1', long ? 'Deodar Valley Riverside Heritage Homestay' : 'Deodar Cottage', 'Kausani', 1500, featured: true),
      _stay('s2', 'Pine Ridge', 'Mukteshwar', 2400),
      _stay('s3', 'Lakeside', 'Nainital', 3200),
    ]);
    home.taxis.assignAll([
      _taxi('t1', long ? 'Pradeep Kumar Singh Bisht' : 'Pradeep', 'Dzire', 4, featured: true),
      _taxi('t2', 'Rakesh', 'Innova', 7, fare: 1600),
      _taxi('t3', 'Sunil', 'Tempo Traveller', 12, fare: null),
    ]);
    home.recentlyAddedStays.assignAll([
      _stay('r1', long ? 'Lakeside Rooms and Family Suites by the Naini Lake' : 'Lakeside Rooms', 'Nainital', 3200),
      _stay('r2', 'Himalayan View', 'Bhimtal', 1800, featured: true, district: 'Bhimtal'),
    ]);
  }
  home.staysLoading.value = false;
  home.taxisLoading.value = false;
  home.recentlyAddedStaysLoading.value = false;
}

// SkeletonSwitcher (motion_kit) asserts under reduce motion; the shots run with motion on.
Widget _app() => Builder(
      builder: (c) => MediaQuery(
        data: MediaQuery.of(c).copyWith(disableAnimations: false),
        child: Scaffold(extendBody: true, body: const HomeScreen(), bottomNavigationBar: SizedBox(height: BarMetrics.boxHeight)),
      ),
    );

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump(const Duration(milliseconds: 400));
  }
  await settlePhone(t);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return Directory.systemTemp.createTempSync('home_shots').path;
    });
    await GetStorage.init();
  });
  setUp(() {
    shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\home';
  });
  tearDown(Get.reset);

  final cases = <(String, double, double, bool, bool, bool)>[
    ('seeker_360_1.0', 360, 1.0, false, false, false),
    ('seeker_360_1.3', 360, 1.3, false, false, false),
    ('seeker_300_1.0', 300, 1.0, false, false, false),
    ('long_360_1.3', 360, 1.3, false, true, false),
    ('long_300_1.3', 300, 1.3, false, true, false),
    ('owner_360_1.0', 360, 1.0, true, false, false),
    ('owner_300_1.3', 300, 1.3, true, true, false),
    ('empty_360_1.0', 360, 1.0, false, false, true),
  ];

  for (final c in cases) {
    testWidgets('home ${c.$1}', (t) async {
      debugDisableShadows = false;
      _register(owner: c.$4, long: c.$5, empty: c.$6);
      await pumpPhone(t, _app(), size: Size(c.$2, 3000), textScale: c.$3);
      await _settle(t);
      expect(t.takeException(), isNull);
      await shot(t, 'home_${c.$1}');
      await pumpPhone(t, _app(), size: Size(c.$2, 800), textScale: c.$3);
      await _settle(t);
      await shot(t, 'home_${c.$1}_top');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      debugDisableShadows = true;
    });
  }

  for (final c in <(String, double, double)>[('360_1.0', 360, 1.0), ('300_1.3', 300, 1.3)]) {
    testWidgets('photo cards ${c.$1}', (t) async {
      debugDisableShadows = false;
      Widget photo() => Image.asset('assets/images/design/travel3d/mountain.png', fit: BoxFit.cover);
      await pumpPhone(
        t,
        Scaffold(
          backgroundColor: ListingPalette.indigo.page,
          body: SingleChildScrollView(
            child: Column(
              children: [
                MealsRail(children: [
                  MealsCardV(tone: ListingTone.cE, tag: 'FOR STAY', title: 'Deodar Cottage', description: 'Kausani', chips: const ['Featured', 'Homestay', 'Breakfast'], photo: photo(), sticker: ListingArt.key, caption: 'FROM', number: '₹1,500', unit: '/night'),
                  MealsCardV(tone: ListingTone.cB, tag: 'FOR STAY', title: 'Pine Ridge Heritage Resort', description: 'Mukteshwar, Nainital', chips: const [], photo: photo(), sticker: ListingArt.bed, caption: 'FROM', number: '₹2,400', unit: '/night'),
                ]),
                WideCard(
                  kind: WideKind.photo,
                  tone: ListingTone.cE,
                  photo: SizedBox.expand(child: photo()),
                  sticker: ListingArt.hotel,
                  badge: 'Featured',
                  tag: 'FOR STAY',
                  title: 'Lakeside Rooms',
                  subtitle: 'Nainital',
                  reserveChips: false,
                  priceCaption: 'FROM',
                  number: '₹3,200',
                  unit: '/night',
                  onGo: () {},
                ),
              ],
            ),
          ),
        ),
        size: Size(c.$2, 1100),
        textScale: c.$3,
      );
      await settlePhone(t);
      await shot(t, 'home_photo_${c.$1}');
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });
  }

  testWidgets('home taps reach the same targets', (t) async {
    debugDisableShadows = false;
    _register();
    await pumpPhone(t, _app(), size: const Size(360, 3000));
    await _settle(t);
    expect(find.text('Hi, Rahul'), findsOneWidget);
    expect(find.text('Where to next?'), findsOneWidget);
    expect(find.text('See all'), findsNWidgets(3));
    expect(find.text('Popular destinations'), findsOneWidget);
    expect(find.text('Recently added stays'), findsOneWidget);
    expect(find.text('Featured'), findsWidgets);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    final auth = Get.find<AuthController>();
    await t.tap(find.text('See all').at(1));
    await t.pump();
    expect(auth.tabIndex.value, AppTabs.stays);
    await t.tap(find.text('See all').first);
    await t.pump();
    expect(auth.tabIndex.value, AppTabs.trips);
    debugDisableShadows = true;
    await t.pumpWidget(const SizedBox());
  });
}
