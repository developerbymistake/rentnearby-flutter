import 'dart:io';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/design/extra/ext_auth.dart';
import 'package:bakhli/screens/login_screen.dart';
import 'package:bakhli/screens/onboarding_screen.dart';
import 'package:bakhli/screens/phone_verify_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../support/real_phone.dart';

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<bool> sendLoginOtp(String phone) async => true;

  @override
  Future<String?> sendPhoneOtp(String phone) async => null;
}

const _sizes = <Size>[Size(360, 640), Size(320, 568), Size(412, 915), Size(360, 780)];
final _worst = <String, double>{};
const _scales = <double>[1.0, 1.3];
const _keyboards = <double>[260, 340];

Future<void> _open(WidgetTester t, Widget page, Size size, double scale, {Object? args}) async {
  await pumpPhone(t, const SizedBox(), size: size, devicePixelRatio: 1, textScale: scale);
  addTearDown(t.view.resetViewInsets);
  Get.to<void>(() => page, arguments: args, transition: Transition.noTransition, duration: Duration.zero);
  await t.pump();
  await t.pump(const Duration(milliseconds: 800));
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _toOtp(WidgetTester t, {required bool login}) async {
  await t.enterText(find.byType(TextFormField).first, '9876543210');
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle(t);
  if (login) {
    await t.ensureVisible(find.bySemanticsLabel('I agree to the Terms of Service and Privacy Policy'));
    await t.pump();
    await t.tap(find.bySemanticsLabel('I agree to the Terms of Service and Privacy Policy'));
  }
  await t.pump();
  await t.ensureVisible(find.text('Send OTP').last);
  await _settle(t);
  await t.tap(find.text('Send OTP').last);
  await _settle(t);
  await t.tap(find.text('Confirm').last);
  await t.pump(const Duration(milliseconds: 900));
  await t.pump(const Duration(milliseconds: 900));
}

Future<void> _toVerifyOtp(WidgetTester t) async {
  await t.enterText(find.byType(TextFormField).first, '9876543210');
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump();
  await t.ensureVisible(find.text('Send OTP').last);
  await _settle(t);
  await t.tap(find.text('Send OTP').last);
  await _settle(t);
  await t.tap(find.text('Confirm').last);
  await t.pump(const Duration(milliseconds: 900));
  await t.pump(const Duration(milliseconds: 900));
}

Future<void> _expectBelowBand(WidgetTester t, Size size, double kb, String screen, String title, String subtitle) async {
  final scroll = t.state<ScrollableState>(find.descendant(of: find.byType(SingleChildScrollView).first, matching: find.byType(Scrollable)).first);
  scroll.position.jumpTo(0);
  await t.pump();
  final card = t.getRect(find.byType(AuthCard));
  final sub = t.getRect(find.text(subtitle).first);
  final head = t.getRect(find.text(title).first);
  final bottom = sub.bottom > head.bottom ? sub.bottom : head.bottom;
  final gap = card.top - bottom;
  if (gap > (_worst[screen] ?? -1e9)) _worst[screen] = gap;
  expect(card.top, greaterThanOrEqualTo(bottom - 0.5), reason: 'card $card covers band text title $head subtitle $sub');
  expect(gap, lessThanOrEqualTo(10), reason: 'gap $gap too big: card $card title $head subtitle $sub');
  final visible = size.height - kb;
  if (card.bottom > visible + 0.5) {
    await t.drag(find.byType(SingleChildScrollView).first, Offset(0, -(card.bottom - visible) - 40));
    await t.pump(const Duration(milliseconds: 500));
    expect(t.getRect(find.byType(AuthCard)).bottom, lessThanOrEqualTo(visible + 0.5), reason: 'card must scroll above the keyboard');
  }
  expect(t.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('auth_band').path,
    );
    await GetStorage.init();
    await loadRealFonts();
  });
  setUp(() {
    Get.reset();
    Get.put<AuthController>(_Auth());
  });
  tearDown(Get.reset);
  tearDownAll(() {
    _worst.forEach((k, v) => debugPrint('WORST GAP $k: ${v.toStringAsFixed(2)}'));
  });

  for (final size in _sizes) {
    for (final scale in _scales) {
      for (final kb in _keyboards) {
        final tag = '${size.width.toInt()}x${size.height.toInt()} scale $scale kb ${kb.toInt()}';

        testWidgets('login phone card below band $tag', (t) async {
          await _open(t, const LoginScreen(), size, scale);
          t.view.viewInsets = FakeViewPadding(bottom: kb);
          await _settle(t);
          await _expectBelowBand(t, size, kb, 'login', 'Bakhli', 'Plan your next trip');
        });

        testWidgets('login otp card below band $tag', (t) async {
          await _open(t, const LoginScreen(), size, scale);
          await _toOtp(t, login: true);
          t.view.viewInsets = FakeViewPadding(bottom: kb);
          await _settle(t);
          await _expectBelowBand(t, size, kb, 'login', 'Bakhli', 'Plan your next trip');
        });

        for (final change in [false, true]) {
          final name = change ? 'Change Number' : 'Verify Mobile';
          final sub = change ? 'Enter your new mobile number' : 'Required to post listings';

          testWidgets('$name phone card below band $tag', (t) async {
            await _open(t, const PhoneVerifyScreen(), size, scale, args: {'isChange': change});
            t.view.viewInsets = FakeViewPadding(bottom: kb);
            await _settle(t);
            await _expectBelowBand(t, size, kb, '$name phone', name, sub);
          });

          testWidgets('$name otp card below band $tag', (t) async {
            await _open(t, const PhoneVerifyScreen(), size, scale, args: {'isChange': change});
            await _toVerifyOtp(t);
            expect(find.text('Enter OTP'), findsOneWidget);
            t.view.viewInsets = FakeViewPadding(bottom: kb);
            await _settle(t);
            await _expectBelowBand(t, size, kb, '$name otp', name, sub);
          });
        }

        testWidgets('onboarding card below band $tag', (t) async {
          await _open(t, const OnboardingScreen(), size, scale, args: {'phone': '9876543210'});
          t.view.viewInsets = FakeViewPadding(bottom: kb);
          await _settle(t);
          await _expectBelowBand(t, size, kb, 'onboarding', 'Complete your profile', 'Just one more step');
        });
      }
    }
  }
}
