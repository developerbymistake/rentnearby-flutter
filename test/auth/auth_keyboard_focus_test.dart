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

const _sizes = <Size>[Size(360, 780), Size(411, 890)];

Future<void> _open(WidgetTester t, Widget page, Size size, {Object? args}) async {
  await pumpPhone(t, const SizedBox(), size: size, devicePixelRatio: 1);
  addTearDown(t.view.resetViewInsets);
  Get.to<void>(() => page, arguments: args, transition: Transition.noTransition, duration: Duration.zero);
  await t.pump();
  await t.pump(const Duration(milliseconds: 800));
}

Future<void> _openKeyboard(WidgetTester t, Finder field) async {
  await t.tap(field);
  await t.pump();
  for (var i = 1; i <= 6; i++) {
    t.view.viewInsets = FakeViewPadding(bottom: 300.0 * i / 6);
    t.view.padding = const FakeViewPadding(top: phoneTopInset);
    await t.pump(const Duration(milliseconds: 40));
  }
  await t.pump(const Duration(milliseconds: 600));
}

void _expectHeaderAndCard(WidgetTester t, Size size, String title) {
  final head = t.getRect(find.text(title).first);
  final card = t.getRect(find.byType(AuthCard));
  expect(head.top, greaterThanOrEqualTo(phoneTopInset), reason: 'header $head under status bar');
  expect(head.bottom, lessThanOrEqualTo(card.top + 0.5), reason: 'header $head overlaps card $card');
  expect(card.top, greaterThanOrEqualTo(head.bottom - 0.5), reason: 'card $card above header $head');
  expect(card.bottom, lessThanOrEqualTo(size.height - 300 + 0.5), reason: 'card $card under keyboard');
  expect(t.takeException(), isNull);
}

Future<void> _toLoginOtp(WidgetTester t) async {
  await t.enterText(find.byType(TextFormField).first, '9876543210');
  FocusManager.instance.primaryFocus?.unfocus();
  await t.tap(find.bySemanticsLabel('I agree to the Terms of Service and Privacy Policy'));
  await t.pump();
  await t.tap(find.text('Send OTP').last);
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
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
    final tag = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('login phone, tapped field, keyboard 300 $tag', (t) async {
      await _open(t, const LoginScreen(), size);
      await _openKeyboard(t, find.byType(EditableText).first);
      _expectHeaderAndCard(t, size, 'Bakhli');
    });

    testWidgets('login otp, tapped field, keyboard 300 $tag', (t) async {
      await _open(t, const LoginScreen(), size);
      await _toLoginOtp(t);
      expect(find.text('Verify OTP'), findsOneWidget);
      await _openKeyboard(t, find.byType(EditableText).first);
      _expectHeaderAndCard(t, size, 'Bakhli');
    });

    for (final change in [true, false]) {
      final name = change ? 'Change Number' : 'Verify Mobile';
      testWidgets('phone verify $name, tapped field, keyboard 300 $tag', (t) async {
        await _open(t, const PhoneVerifyScreen(), size, args: {'isChange': change});
        await _openKeyboard(t, find.byType(EditableText).first);
        _expectHeaderAndCard(t, size, name);
      });
    }
  }
}
