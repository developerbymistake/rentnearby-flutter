import 'dart:io';

import 'package:bakhli/config/basic_details_strings.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/design/extra/ext_auth.dart';
import 'package:bakhli/features/social/a/onboarding/onboarding_steps.dart';
import 'package:bakhli/screens/basic_details_screen.dart';
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

Rect _snap(WidgetTester t, {Type card = AuthCard}) {
  final scroll = t.state<ScrollableState>(find.descendant(of: find.byType(SingleChildScrollView).first, matching: find.byType(Scrollable)).first);
  scroll.position.jumpTo(0);
  return t.getRect(find.byType(card));
}

Future<void> _expectStays(WidgetTester t, Size size, double kb, Rect base, String screen, String title, String subtitle, {Type cardType = AuthCard}) async {
  final scroll = t.state<ScrollableState>(find.descendant(of: find.byType(SingleChildScrollView).first, matching: find.byType(Scrollable)).first);
  scroll.position.jumpTo(0);
  await t.pump();
  final card = t.getRect(find.byType(cardType));
  final moved = (card.top - base.top).abs();
  if (moved > (_worst[screen] ?? -1)) _worst[screen] = moved;
  expect(card.top, closeTo(base.top, 0.5), reason: 'card moved when the keyboard opened: before ${base.top}, after ${card.top}');
  expect(card.height, closeTo(base.height, 0.5), reason: 'card size changed when the keyboard opened');
  final head = t.getRect(find.text(title).first);
  final sub = t.getRect(find.text(subtitle).first);
  expect(head.top, greaterThanOrEqualTo(0));
  expect(sub.bottom, lessThanOrEqualTo(card.top + 40), reason: 'hero text must stay above the card');
  final visible = size.height - kb;
  if (card.bottom > visible + 0.5 && card.top + 60 <= visible) {
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await t.pump();
    expect(t.getRect(find.byType(cardType)).bottom, lessThanOrEqualTo(visible + 0.5), reason: 'card must scroll above the keyboard');
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
    _worst.forEach((k, v) => debugPrint('MAX CARD MOVE $k: ${v.toStringAsFixed(2)}'));
  });

  for (final size in _sizes) {
    for (final scale in _scales) {
      for (final kb in _keyboards) {
        final tag = '${size.width.toInt()}x${size.height.toInt()} scale $scale kb ${kb.toInt()}';

        testWidgets('login phone card below band $tag', (t) async {
          await _open(t, const LoginScreen(), size, scale);
          final base = _snap(t);
          t.view.viewInsets = FakeViewPadding(bottom: kb);
          await _settle(t);
          await _expectStays(t, size, kb, base, 'login', 'Bakhli', 'Plan your next trip');
        });

        testWidgets('login otp card below band $tag', (t) async {
          await _open(t, const LoginScreen(), size, scale);
          await _toOtp(t, login: true);
          final base = _snap(t);
          t.view.viewInsets = FakeViewPadding(bottom: kb);
          await _settle(t);
          await _expectStays(t, size, kb, base, 'login', 'Bakhli', 'Plan your next trip');
        });

        for (final change in [false, true]) {
          final name = change ? 'Change Number' : 'Verify Mobile';
          final sub = change ? 'Enter your new mobile number' : 'Required to post listings';

          testWidgets('$name phone card below band $tag', (t) async {
            await _open(t, const PhoneVerifyScreen(), size, scale, args: {'isChange': change});
            final base = _snap(t);
          t.view.viewInsets = FakeViewPadding(bottom: kb);
            await _settle(t);
            await _expectStays(t, size, kb, base, '$name phone', name, sub);
          });

          testWidgets('$name otp card below band $tag', (t) async {
            await _open(t, const PhoneVerifyScreen(), size, scale, args: {'isChange': change});
            await _toVerifyOtp(t);
            expect(find.text('Enter OTP'), findsOneWidget);
            final base = _snap(t);
          t.view.viewInsets = FakeViewPadding(bottom: kb);
            await _settle(t);
            await _expectStays(t, size, kb, base, '$name otp', name, sub);
          });
        }

        testWidgets('basic details card below band $tag', (t) async {
          await _open(t, const BasicDetailsScreen(), size, scale, args: {'phone': '9876543210'});
          final base = _snap(t, card: OnboardingCard);
          t.view.viewInsets = FakeViewPadding(bottom: kb);
          await _settle(t);
          await _expectStays(t, size, kb, base, 'basic details', BasicDetailsStrings.title, BasicDetailsStrings.subtitle, cardType: OnboardingCard);
        });
      }
    }
  }
}
