import 'dart:io';

import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/screens/login_screen.dart';
import 'package:bakhli/screens/phone_verify_screen.dart';
import 'package:bakhli/widgets/home_hero_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:pinput/pinput.dart';

import '../../ui_golden/golden_support.dart';

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Future<void> _host(WidgetTester t, Widget home, {double scale = 1}) async {
  t.view.physicalSize = const Size(360, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(GetMaterialApp(
    theme: AppTheme.theme,
    builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: home,
  ));
  await t.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('a5_gs').path,
    );
    await GetStorage.init();
    await loadGoldenFonts();
  });
  setUp(() {
    Get.reset();
    Get.put<TabConfigController>(_Tabs());
    Get.put<AuthController>(_Auth());
  });
  tearDown(Get.reset);

  void expectVisibleDigits(WidgetTester t) {
    final editable = t.widget<EditableText>(find.byType(EditableText).first);
    expect(editable.controller.text, '9876543210');
    final style = editable.style;
    expect(style.color, isNotNull);
    expect(style.color!.a, 1.0);
    expect(style.fontSize, greaterThan(10));
    expect(_contrast(style.color!, FitnessAppTheme.white), greaterThan(4.5));
  }

  testWidgets('LoginScreen phone digits are visible', (t) async {
    await _host(t, const LoginScreen());
    await t.enterText(find.byType(TextFormField).first, '9876543210');
    await t.pump();
    expectVisibleDigits(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('PhoneVerifyScreen phone digits are visible', (t) async {
    await _host(t, const PhoneVerifyScreen());
    await t.enterText(find.byType(TextFormField).first, '9876543210');
    await t.pump();
    expectVisibleDigits(t);
    expect(t.takeException(), isNull);
  });

  test('OTP box digits contrast with the box in every pin state', () {
    for (final theme in [GatePinThemes.base(64), GatePinThemes.focused(64)]) {
      final bg = (theme.decoration as BoxDecoration).color!;
      expect(_contrast(theme.textStyle!.color!, bg), greaterThan(4.5));
    }
    final submitted = GatePinThemes.submitted(64);
    expect(_contrast(submitted.textStyle!.color!, FitnessAppTheme.nearlyDarkBlue), greaterThan(3));
    expect(Pinput, isNotNull);
  });

  testWidgets('HomeHeroCarousel at text scale 1.3 does not overflow', (t) async {
    await _host(t, const Scaffold(body: SafeArea(child: HomeHeroCarousel())), scale: 1.3);
    await t.pump(const Duration(seconds: 5));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
