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
  Future<void> reload() async {}
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

void _register() {
  Get.reset();
  Get.put<TabConfigController>(_Tabs());
  Get.put<AuthController>(_Auth());
  Get.put<LocationController>(_Loc());
  Get.put<HomeController>(_Home());
  Get.put<NotificationController>(_Notif());
  Get.put<ChatController>(_Chat());
  Get.put<PlanController>(_Plan());
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
    final lastRow = find.text('Follow us');
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

  testWidgets('HM shows the trip blocks only, no stay or taxi rails (Change 7)', (t) async {
    setGoldenView(t, const Size(360, 1700));
    await t.pumpWidget(_host(1.0));
    await _settle(t);
    for (final s in [
      'Hi, there',
      'Where to next?',
      'Quick actions',
      'Follow us',
    ]) {
      expect(find.textContaining(s), findsWidgets, reason: s);
    }
    for (final s in ['Deodar Valley Homestay', 'Ramesh Kumar Negi', 'Recently added stays', 'Stays near you', 'Taxis near you']) {
      expect(find.textContaining(s), findsNothing, reason: s);
    }
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('HM bell and chat taps navigate', (t) async {
    setGoldenView(t, const Size(360, 1700));
    await t.pumpWidget(_host(1.0));
    await _settle(t);
    for (final img in ['travel3d/bell.png', 'travel3d/speech_balloon.png']) {
      await t.tap(find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.endsWith(img),
      ));
      await t.pump(const Duration(seconds: 1));
      Get.back();
      await t.pump(const Duration(seconds: 1));
    }
    expect(_visited, [AppRoutes.notifications, AppRoutes.chatsList]);
    await t.pumpWidget(const SizedBox());
  });
}
