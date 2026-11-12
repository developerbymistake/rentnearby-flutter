import 'dart:io';
import 'dart:ui' as ui;

import 'package:bakhli/config/app_routes.dart';
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
import 'package:bakhli/models/home_feed_model.dart';
import 'package:bakhli/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../golden_support.dart';

const String _shots = r'F:\Dhasu\UI_Template_resume\Repair\shots';

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
        'mealsChip': 'breakfast',
        'roomNameChip': 'Deluxe room',
        'minPricePerNight': 1800,
        'isFeatured': featured,
      }),
      districtName: 'Dehradun',
      createdAt: DateTime(2026, 5, 1),
    );

void _register() {
  Get.reset();
  Get.put<TabConfigController>(_Tabs());
  Get.put<AuthController>(_Auth());
  Get.put<LocationController>(_Loc());
  Get.put<HomeController>(_Home());
  Get.put<NotificationController>(_Notif());
  Get.put<ChatController>(_Chat());
  Get.put<PlanController>(_Plan());
  final home = Get.find<HomeController>();
  home.stays.assignAll([_stay('s1', 'Deodar Valley Homestay', featured: true), _stay('s2', 'Lake View')]);
  home.taxis.assignAll([_taxi(), _taxi(featured: false, fare: null)]);
  home.recentlyAddedStays.assignAll([_stay('s3', 'Pine Cottage'), _stay('s4', 'River Camp', featured: true)]);
  home.staysLoading.value = false;
  home.taxisLoading.value = false;
  home.recentlyAddedStaysLoading.value = false;
}

final List<String> _visited = <String>[];

Widget _host(double scale, {Widget? bottomBar}) => GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      getPages: [
        for (final r in [AppRoutes.notifications, AppRoutes.chatsList, AppRoutes.stayDetail])
          GetPage(
            name: r,
            page: () {
              _visited.add(r);
              return const Scaffold(body: SizedBox());
            },
          ),
      ],
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: const ValueKey('golden_root'), child: child!),
      ),
      home: Scaffold(extendBody: true, body: const HomeScreen(), bottomNavigationBar: bottomBar),
    );

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _shot(WidgetTester t, String name) async {
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('golden_root')));
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shots).createSync(recursive: true);
    File('$_shots\\$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return Directory.systemTemp.createTempSync('hm_gs').path;
    });
    await GetStorage.init();
    await loadGoldenFonts();
  });

  setUp(() {
    _visited.clear();
    _register();
  });
  tearDown(Get.reset);

  testWidgets('HM shot top at 360 x 1.3', (t) async {
    setGoldenView(t, const Size(360, 780));
    await t.pumpWidget(_host(1.3));
    await _settle(t);
    expect(t.takeException(), isNull);
    await _shot(t, 'home_top_1.3');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('HM shot scrolled and bottom at 360 x 1.3', (t) async {
    setGoldenView(t, const Size(360, 780));
    await t.pumpWidget(_host(1.3, bottomBar: SizedBox(height: BarMetrics.boxHeight + 20)));
    await _settle(t);
    final scroll = find.byType(SingleChildScrollView);
    final pos = t.state<ScrollableState>(find.descendant(of: scroll, matching: find.byType(Scrollable)).first).position;
    pos.jumpTo(430);
    await _settle(t);
    await _shot(t, 'home_mid_1.3');
    pos.jumpTo(pos.maxScrollExtent);
    await _settle(t);
    await _shot(t, 'home_bottom_1.3');
    expect(pos.pixels, pos.maxScrollExtent);
    final lastRow = find.text('River Camp');
    expect(lastRow, findsOneWidget);
    final barTop = 780.0 - (BarMetrics.boxHeight + 20);
    expect(t.getBottomLeft(lastRow).dy, lessThanOrEqualTo(barTop));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('HM shot tall at 360 x 1.3', (t) async {
    setGoldenView(t, const Size(360, 1900));
    await t.pumpWidget(_host(1.3));
    await _settle(t);
    await _shot(t, 'home_tall_1.3');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('HM shows every old stay and taxi field on the rails', (t) async {
    setGoldenView(t, const Size(360, 1700));
    await t.pumpWidget(_host(1.0));
    await _settle(t);
    for (final s in [
      'Hi, there',
      'Where to next?',
      'View all',
      'Deodar Valley Homestay',
      'Homestay',
      'FOR STAY',
      'Ramesh Kumar Negi',
      'Innova Crysta',
      '7 seats',
      'Deluxe room',
      'TAXI',
      'FARE FROM',
      'LOCAL TAXI',
      'Recently added stays',
      'Follow us on Instagram',
    ]) {
      expect(find.textContaining(s), findsWidgets, reason: s);
    }
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('HM bell, chat and rail card taps navigate', (t) async {
    setGoldenView(t, const Size(360, 1700));
    await t.pumpWidget(_host(1.0));
    await _settle(t);
    for (final img in ['fitness_app/bell.png', 'travel3d/speech_balloon.png']) {
      await t.tap(find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.endsWith(img),
      ));
      await t.pump(const Duration(seconds: 1));
      Get.back();
      await t.pump(const Duration(seconds: 1));
    }
    expect(_visited, [AppRoutes.notifications, AppRoutes.chatsList]);
    await t.tap(find.text('Lake View'));
    await t.pump(const Duration(seconds: 1));
    expect(_visited.last, AppRoutes.stayDetail);
    await t.pumpWidget(const SizedBox());
  });
}
