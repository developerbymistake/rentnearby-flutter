import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/controllers/home_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/gradient_icon_card.dart';
import 'package:bakhli/design/extra/info_row_card.dart';
import 'package:bakhli/design/extra/stay_grid_card.dart';
import 'package:bakhli/design/extra/template_nav.dart';
import 'package:bakhli/features/jobs/jobs_colors.dart';
import 'package:bakhli/features/jobs/widgets/job_list_card.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/trip/widgets/trip_home_card.dart';
import 'package:bakhli/features/trip/widgets/trip_status.dart';
import 'package:bakhli/features/trip/widgets/trip_status_card.dart';
import 'package:bakhli/models/card_fact.dart';
import 'package:bakhli/models/role_model.dart';
import 'package:bakhli/screens/home_screen.dart';
import 'package:bakhli/widgets/home_taxi_rail_card.dart';
import 'package:bakhli/widgets/nearby_item_row.dart';
import 'package:bakhli/widgets/role_option_card.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'golden_support.dart';

const _t3d = 'assets/images/design/travel3d/';
const _fit = 'assets/images/design/fitness_app/';

TaxiBrowseItem _taxi() => TaxiBrowseItem(
      id: 't1',
      driverName: 'Ramesh Kumar Negi',
      vehicleTypeName: 'Innova Crysta',
      seats: 7,
      plateDisplay: 'UK07 AB 1234',
      cityName: 'Dehradun',
      minFare: 1800,
      routeCount: 2,
      matchReversed: false,
      createdAt: DateTime(2026, 1, 1),
      isFeatured: true,
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

void _golden(String name, Widget Function() build) {
  for (final scale in [1.0, 1.3]) {
    testWidgets('golden $name @${_s(scale)}', (t) async {
      setGoldenView(t);
      recordBaselineIssues('$name @${_s(scale)}');
      await t.pumpWidget(goldenHost(build(), scale: scale));
      await settleGolden(t);
      await expectLater(
        find.byKey(const ValueKey('golden_root')),
        matchesGoldenFile('goldens/${name}_${_s(scale)}.png'),
      );
    });
  }
}

RoleModel _role(String key) => RoleModel(
      key: key,
      name: RoleVisuals.displayName(key),
      description: 'Plan trips, find stays and taxis',
      sortOrder: 1,
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
  tearDownAll(() {
    // ignore: avoid_print
    print(['BASELINE ISSUES ${baselineIssues.length}', ...baselineIssues.toSet()].join(String.fromCharCode(10)));
  });

  for (final key in [UserRoleKeys.seeker, UserRoleKeys.stayOwner, UserRoleKeys.taxiDriver]) {
    _golden(
      'role_option_card_${key.toLowerCase()}',
      () => Column(children: [
        RoleOptionCard(role: _role(key), selected: true, onTap: () {}),
        const SizedBox(height: 16),
        RoleOptionCard(role: _role(key), isCurrent: true, onTap: () {}),
        const SizedBox(height: 16),
        RoleOptionCard(role: _role(key), onTap: () {}),
      ]),
    );
  }

  _golden(
    'stay_grid_card',
    () => SizedBox(
      width: 190,
      height: StayGridCard.height,
      child: StayGridCard(
        thumbnailUrl: null,
        tagLabel: 'Homestay',
        title: 'Deodar Valley Homestay',
        locationLabel: 'Mussoorie',
        facts: const [
          CardFact('2 rooms'),
          CardFact('Breakfast', tone: FactTone.cyan),
          CardFact('Hill view', tone: FactTone.slate),
        ],
        priceCaption: 'FROM',
        priceValue: '₹1,800',
        priceUnit: '/night',
        isFeatured: true,
        onViewDetails: () {},
      ),
    ),
  );

  _golden(
    'home_taxi_rail_card',
    () => MealsRail(children: [HomeTaxiRailCard(taxi: _taxi(), onOpen: () {})]),
  );

  _golden(
    'nearby_item_row',
    () => Column(children: [
      NearbyItemRow(
        thumbnailUrl: null,
        tag: 'Homestay',
        title: 'Deodar Valley Homestay',
        subtitle: 'Mussoorie',
        caption: 'FROM',
        value: '₹1,800',
        unit: '/night',
        placeholderIcon: Icons.hotel,
        placeholderAsset: '${_t3d}hotel.png',
        isFeatured: true,
        onTap: () {},
      ),
      NearbyItemRow(
        thumbnailUrl: null,
        tag: 'Stay',
        title: 'Lake View Guest House',
        subtitle: 'Nainital',
        caption: 'FROM',
        value: '₹2,400',
        unit: '/night',
        placeholderIcon: Icons.hotel,
        placeholderAsset: '${_t3d}hotel.png',
        elevated: true,
        onTap: () {},
      ),
    ]),
  );

  _golden(
    'info_row_card',
    () => InfoRowCard(
      title: 'Stay bookings',
      subtitle: '3 new enquiries',
      tag: 'New',
      value: '3',
      unit: 'open',
      iconAsset: '${_t3d}hotel.png',
      startColor: TravelPalette.sunriseStart,
      endColor: TravelPalette.sunriseEnd,
      onTap: () {},
    ),
  );

  _golden(
    'gradient_icon_card',
    () => Row(mainAxisSize: MainAxisSize.min, children: [
      GradientIconCard(
        title: 'Trips',
        iconAsset: '${_t3d}compass.png',
        startColor: TravelPalette.skyStart,
        endColor: TravelPalette.skyEnd,
        subtitleLines: const ['Plan a trip', 'Add spots'],
        value: '4',
        unit: 'saved',
        showPlus: true,
        width: 130,
        height: 168,
        onTap: () {},
      ),
      GradientIconCard(
        title: 'Taxi',
        iconAsset: '${_t3d}taxi.png',
        startColor: TravelPalette.roseStart,
        endColor: TravelPalette.roseEnd,
        width: 130,
        height: 168,
        onTap: () {},
      ),
    ]),
  );

  _golden('trip_home_card', () => const TripHomeCard());

  _golden(
    'taxi_card',
    () => Column(children: [
      TaxiCard(item: _taxi(), onOpen: () {}),
      const SizedBox(height: 16),
      TaxiCard(item: _taxi(), onOpen: () {}, onSelect: () {}, selected: true, onBook: () {}, onEnquire: () {}),
    ]),
  );

  _golden(
    'job_list_card',
    () => JobListCard(
      title: 'Front desk executive',
      roleLabel: 'Reception',
      experienceTag: '1-2 yrs',
      metaLine: 'Mussoorie, Uttarakhand',
      salaryLabel: '₹18,000',
      salaryUnit: '/month',
      topRightText: '2d ago',
      trailingChip: 'Food + stay',
      accent: JobColors.accent,
      accentDark: JobColors.accentDark,
      onTap: () {},
      actions: [
        JobListCardAction(icon: Icons.call_outlined, label: 'Call', color: JobColors.accentDark, onTap: () {}),
        JobListCardAction(icon: Icons.chat_bubble_outline, label: 'Chat', color: JobColors.accentDark, onTap: () {}),
      ],
    ),
  );

  _golden(
    'trip_status_card',
    () => Column(children: [
      for (final s in [
        TripDisplayStatus.asked,
        TripDisplayStatus.offered,
        TripDisplayStatus.confirmedByBoth,
        TripDisplayStatus.declined,
      ]) ...[
        TripStatusCard(
          status: s,
          onTap: () {},
          child: Text(
            'Dehradun to Mussoorie  ${s.name}',
            style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 14),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ]),
  );

  group('home top bar', () {
    setUp(() {
      Get.reset();
      Get.put<TabConfigController>(_Tabs());
      Get.put<AuthController>(_Auth());
      Get.put<LocationController>(_Loc());
      Get.put<HomeController>(_Home());
      Get.put<NotificationController>(_Notif());
      Get.put<ChatController>(_Chat());
      Get.put<PlanController>(_Plan());
    });
    tearDown(Get.reset);

    for (final scale in [1.0, 1.3]) {
      testWidgets('golden home_top_bar @${_s(scale)}', (t) async {
        setGoldenView(t, const Size(360, 96));
        recordBaselineIssues('home_top_bar @${_s(scale)}');
        await t.pumpWidget(GetMaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: const ValueKey('golden_root'), child: child!),
          ),
          home: const HomeScreen(),
        ));
        await t.pump(const Duration(seconds: 2));
        await expectLater(
          find.byKey(const ValueKey('golden_root')),
          matchesGoldenFile('goldens/home_top_bar_${_s(scale)}.png'),
        );
      });
    }
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('golden template_bottom_bar @${_s(scale)}', (t) async {
      setGoldenView(t, const Size(360, 120));
      recordBaselineIssues('template_bottom_bar @${_s(scale)}');
      await t.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'WorkSans'),
        home: MediaQuery(
          data: MediaQueryData(size: const Size(360, 120), textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            backgroundColor: goldenBg,
            body: RepaintBoundary(
              key: const ValueKey('golden_root'),
              child: Container(
                color: goldenBg,
                alignment: Alignment.bottomCenter,
                child: TemplateBottomBar(
                  items: const [
                    TemplateNavItem(index: 0, image: '${_fit}tab_1.png', selectedImage: '${_fit}tab_1s.png', label: 'Home'),
                    TemplateNavItem(index: 1, image: '${_t3d}hotel.png', label: 'Stays'),
                    TemplateNavItem(index: 2, image: '${_t3d}compass.png', label: 'Trips', center: true),
                    TemplateNavItem(index: 3, image: '${_t3d}taxi.png', label: 'Taxi'),
                    TemplateNavItem(index: 4, image: '${_fit}tab_4.png', selectedImage: '${_fit}tab_4s.png', label: 'Profile'),
                  ],
                  selectedIndex: 0,
                  onTap: (_) {},
                  bottomInset: 0,
                ),
              ),
            ),
          ),
        ),
      ));
      await settleGolden(t);
      await expectLater(
        find.byKey(const ValueKey('golden_root')),
        matchesGoldenFile('goldens/template_bottom_bar_${_s(scale)}.png'),
      );
    });
  }
}
