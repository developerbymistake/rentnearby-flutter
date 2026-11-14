import 'dart:io';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/design/extra/ext_auth.dart';
import 'package:bakhli/screens/login_screen.dart';
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

const _sizes = <Size>[Size(392, 800), Size(360, 640)];
const _scales = <double>[1.0, 1.3];

void _setKeyboard(WidgetTester t, double h) {
  t.view.viewInsets = FakeViewPadding(bottom: h);
}

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

Future<void> _expectFits(WidgetTester t, Size size, {required bool keyboard, required String title, bool strict = true}) async {
  var card = t.getRect(find.byType(AuthCard));
  final visible = size.height - (keyboard ? 300 : 0);
  final head = t.getRect(find.text(title).first);
  if (strict) {
    expect(head.bottom, lessThanOrEqualTo(card.top + 0.5), reason: 'title $head overlaps card $card');
    expect(card.top, greaterThanOrEqualTo(0), reason: 'card top');
    expect(card.bottom, lessThanOrEqualTo(visible + 0.5), reason: 'card bottom $card vs visible $visible');
  } else {
    expect(card.top, lessThan(visible), reason: 'card top must be above the keyboard');
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
    await t.pump(const Duration(milliseconds: 500));
    card = t.getRect(find.byType(AuthCard));
    expect(card.bottom, lessThanOrEqualTo(visible + 0.5), reason: 'card must scroll fully above the keyboard: $card vs $visible');
    return;
  }
  if (!keyboard) expect(card.top, lessThan(size.height * 0.6), reason: 'card should sit upper-middle');
  expect(t.takeException(), isNull);
}

Future<void> _toLoginOtp(WidgetTester t) async {
  await t.enterText(find.byType(TextFormField).first, '9876543210');
  FocusManager.instance.primaryFocus?.unfocus();
  await t.tap(find.bySemanticsLabel('I agree to the Terms of Service and Privacy Policy'));
  await t.pump();
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
  await t.tap(find.text('Send OTP').last);
  await _settle(t);
  await t.tap(find.text('Confirm').last);
  await t.pump(const Duration(milliseconds: 900));
  await t.pump(const Duration(milliseconds: 900));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('auth_kb').path,
    );
    await GetStorage.init();
    await loadRealFonts();
  });
  setUp(() {
    Get.reset();
    Get.put<AuthController>(_Auth());
  });
  tearDown(Get.reset);

  for (final size in _sizes) {
    for (final scale in _scales) {
      final tag = '${size.width.toInt()}x${size.height.toInt()} scale $scale';

      testWidgets('login phone card $tag', (t) async {
        await _open(t, const LoginScreen(), size, scale);
        await _expectFits(t, size, keyboard: false, title: 'Bakhli', strict: size.height >= 800 || scale == 1.0);
        _setKeyboard(t, 300);
        await _settle(t);
        await _expectFits(t, size, keyboard: true, title: 'Bakhli', strict: size.height >= 800 || scale == 1.0);
        _setKeyboard(t, 0);
        await _settle(t);
        await _expectFits(t, size, keyboard: false, title: 'Bakhli', strict: size.height >= 800 || scale == 1.0);
      });

      testWidgets('login otp card $tag', (t) async {
        await _open(t, const LoginScreen(), size, scale);
        await _toLoginOtp(t);
        expect(find.text('Verify OTP'), findsOneWidget);
        await _expectFits(t, size, keyboard: false, title: 'Bakhli', strict: size.height >= 800 || scale == 1.0);
        _setKeyboard(t, 300);
        await _settle(t);
        await _expectFits(t, size, keyboard: true, title: 'Bakhli', strict: size.height >= 800);
      });

      for (final change in [true, false]) {
        final name = change ? 'Change Number' : 'Verify Mobile';
        testWidgets('phone verify $name phone card $tag', (t) async {
          await _open(t, const PhoneVerifyScreen(), size, scale, args: {'isChange': change});
          await _expectFits(t, size, keyboard: false, title: name, strict: size.height >= 800 || scale == 1.0);
          _setKeyboard(t, 300);
          await _settle(t);
          await _expectFits(t, size, keyboard: true, title: name, strict: size.height >= 800);
          expect(find.byType(BackButtonListener), findsNothing);
        });

        testWidgets('phone verify $name otp card $tag', (t) async {
          await _open(t, const PhoneVerifyScreen(), size, scale, args: {'isChange': change});
          await _toVerifyOtp(t);
          expect(find.text('Enter OTP'), findsOneWidget);
          _setKeyboard(t, 300);
          await _settle(t);
          await _expectFits(t, size, keyboard: true, title: name, strict: size.height >= 800);
        });
      }
    }
  }
}
