import 'dart:io';

import 'package:bakhli/config/app_theme.dart';
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
import 'package:bakhli/screens/home_screen.dart';
import 'package:bakhli/widgets/home_owner_carousel.dart';
import 'package:bakhli/widgets/home_stay_rail_card.dart';
import 'package:bakhli/widgets/home_taxi_rail_card.dart';
import 'package:bakhli/widgets/nearby_item_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../golden_support.dart';

TaxiBrowseItem _taxi({bool featured = true, int? fare = 1800}) => TaxiBrowseItem(
      id: 't1',
      driverName: 'Ramesh Kumar Negi',
      vehicleTypeName: 'Innova Crysta',
      seats: 7,
      plateDisplay: 'UK07 AB 1234',
      cityName: 'Dehradun',
      minFare: fare,
      routeCount: 2,
      matchReversed: false,
      createdAt: DateTime(2026, 1, 1),
      isFeatured: featured,
    );

HomeStayModel _stay(String id, String name, {bool featured = false}) => HomeStayModel(
      item: StayBrowseItem.fromJson({
        'id': id,
        'name': name,
        'cityName': 'Mussoorie',
        'districtName': 'Dehradun',
        'stayTypeName': 'Homestay',
        'mealsChip': null,
        'minPricePerNight': 1800,
        'isFeatured': featured,
      }),
      districtName: 'Dehradun',
      createdAt: DateTime(2026, 5, 1),
    );

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Auth extends AuthController {
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

class _Loc extends LocationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

String _s(double s) => s == 1.0 ? '1.0' : '1.3';

void _golden(String name, Widget Function() build, {bool scroll = true}) {
  for (final scale in [1.0, 1.3]) {
    testWidgets('SH golden $name @${_s(scale)}', (t) async {
      setGoldenView(t);
      await t.pumpWidget(goldenHost(build(), scale: scale, scroll: scroll));
      await settleGolden(t);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('golden_root')),
        matchesGoldenFile('goldens/${name}_${_s(scale)}.png'),
      );
    });
  }
}

void _registerHome() {
  Get.reset();
  Get.put<TabConfigController>(_Tabs());
  Get.put<AuthController>(_Auth());
  Get.put<LocationController>(_Loc());
  Get.put<HomeController>(_Home());
  Get.put<NotificationController>(_Notif());
  Get.put<ChatController>(_Chat());
  Get.put<PlanController>(_Plan());
}

Widget _homeHost(double scale) => GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: const ValueKey('golden_root'), child: child!),
      ),
      home: const HomeScreen(),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      final dir = Directory.systemTemp.createTempSync('golden_gs');
      return dir.path;
    });
    await GetStorage.init();
    await loadGoldenFonts();
  });

  _golden(
    'rail_cards',
    () => SizedBox(
      height: HomeStayRailCard.railHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          HomeStayRailCard(stay: _stay('s1', 'Deodar Valley Homestay', featured: true), onOpen: () {}),
          const SizedBox(width: 12),
          HomeTaxiRailCard(taxi: _taxi(), onOpen: () {}),
        ],
      ),
    ),
  );

  _golden(
    'taxi_rail_no_fare',
    () => SizedBox(
      height: HomeStayRailCard.railHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [HomeTaxiRailCard(taxi: _taxi(featured: false, fare: null), onOpen: () {})],
      ),
    ),
  );

  _golden(
    'nearby_rows',
    () => Column(children: [
      NearbyItemRow(
        thumbnailUrl: null,
        tag: 'FOR STAY',
        title: 'Deodar Valley Homestay With A Long Name',
        subtitle: 'Homestay · 2 km',
        caption: 'FROM',
        value: '₹1,800',
        unit: '/night',
        placeholderIcon: Icons.hotel,
        isFeatured: true,
        onTap: () {},
      ),
      NearbyItemRow(
        thumbnailUrl: null,
        tag: 'FOR STAY',
        title: 'Lake View Guest House',
        subtitle: 'Nainital',
        caption: 'FROM',
        value: 'On request',
        placeholderIcon: Icons.hotel,
        onTap: () {},
        actions: [
          NearbyRowAction(
            icon: const Icon(Icons.call_rounded, size: 18, color: DesignColors.primary),
            label: 'Call',
            color: DesignColors.primary,
            onTap: () {},
          ),
          NearbyRowAction(
            icon: const Icon(Icons.chat_bubble_rounded, size: 18, color: DesignColors.primary),
            label: 'Chat',
            color: DesignColors.primary,
            onTap: () {},
          ),
        ],
      ),
      const SizedBox(height: 12),
      NearbyItemRow(
        thumbnailUrl: null,
        tag: 'FOR STAY',
        title: 'Map preview row',
        subtitle: 'Homestay · 1.2 km',
        caption: 'FROM',
        value: '₹2,400',
        unit: '/night',
        placeholderIcon: Icons.hotel,
        elevated: true,
        onTap: () {},
      ),
    ]),
  );

  group('home', () {
    setUp(_registerHome);
    tearDown(Get.reset);

    for (final scale in [1.0, 1.3]) {
      testWidgets('SH golden owner_banners seeker @${_s(scale)}', (t) async {
        setGoldenView(t);
        await t.pumpWidget(GetMaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
              key: const ValueKey('golden_root'),
              child: Container(color: goldenBg, alignment: Alignment.topCenter, child: child),
            ),
          ),
          home: const Scaffold(backgroundColor: goldenBg, body: SafeArea(child: HomeOwnerCarousel())),
        ));
        await t.pump();
        await t.pump(const Duration(seconds: 2));
        expect(t.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('golden_root')),
          matchesGoldenFile('goldens/owner_banners_seeker_${_s(scale)}.png'),
        );
        await t.pumpWidget(const SizedBox());
      });

      testWidgets('SH golden home_loading @${_s(scale)}', (t) async {
        setGoldenView(t, const Size(360, 1500));
        await t.pumpWidget(_homeHost(scale));
        await t.pump();
        await t.pump(const Duration(seconds: 3));
        expect(t.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('golden_root')),
          matchesGoldenFile('goldens/home_loading_${_s(scale)}.png'),
        );
        await t.pumpWidget(const SizedBox());
      });

      testWidgets('SH golden home_loaded @${_s(scale)}', (t) async {
        setGoldenView(t, const Size(360, 1500));
        final home = Get.find<HomeController>();
        home.stays.assignAll([_stay('s1', 'Deodar Valley Homestay', featured: true), _stay('s2', 'Lake View')]);
        home.taxis.assignAll([_taxi(), _taxi(featured: false, fare: null)]);
        home.recentlyAddedStays.assignAll([_stay('s3', 'Pine Cottage'), _stay('s4', 'River Camp', featured: true)]);
        home.staysLoading.value = false;
        home.taxisLoading.value = false;
        home.recentlyAddedStaysLoading.value = false;
        await t.pumpWidget(_homeHost(scale));
        await t.pump();
        await t.pump(const Duration(seconds: 3));
        expect(t.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('golden_root')),
          matchesGoldenFile('goldens/home_loaded_${_s(scale)}.png'),
        );
        await t.pumpWidget(const SizedBox());
      });
    }

    testWidgets('home shows greeting order and keeps a bottom clearance above the bar', (t) async {
      setGoldenView(t);
      await t.pumpWidget(_homeHost(1.0));
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      final hi = t.getTopLeft(find.textContaining('Hi,')).dy;
      final next = t.getTopLeft(find.text('Where to next?')).dy;
      expect(hi, lessThan(next));
      final scroll = t.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect((scroll.padding as EdgeInsets).bottom, greaterThanOrEqualTo(BarMetrics.bodyBottom(0)));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('home clears a visible trip bar above the nav bar', (t) async {
      setGoldenView(t);
      await t.pumpWidget(GetMaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          extendBody: true,
          body: const HomeScreen(),
          bottomNavigationBar: SizedBox(height: BarMetrics.boxHeight + 40),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      final scroll = t.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      final bottom = (scroll.padding as EdgeInsets).bottom;
      expect(bottom, BarMetrics.boxHeight + 40 + BarMetrics.bodyGap);
      await t.pumpWidget(const SizedBox());
    });
  });
}
