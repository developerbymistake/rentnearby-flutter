import 'dart:ui' as ui;

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/profile_photo_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/extra/ext_buddy.dart';
import 'package:bakhli/features/buddy/buddy_strings.dart';
import 'package:bakhli/features/buddy/widgets/username_qr_sheet.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/screens/onboarding_screen.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:toastification/toastification.dart';

import '../../support/real_phone.dart';

const _username = 'Bakhli#48291736';
const _shots = r'F:\Dhasu\TaxiRequest_resume\evidence\username_shots';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Auth extends AuthController {
  final submitted = <String>[];

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  bool get jobsBrowseEnabled {
    user.value;
    return true;
  }

  @override
  Future<bool> createOnboardingAccount({required String phone, required String name}) async {
    submitted.add(name);
    return false;
  }

  int refreshes = 0;
  String? serverUsername;

  @override
  Future<void> refreshProfile() async {
    refreshes++;
    final u = user.value;
    if (serverUsername == null || u == null) return;
    user.value = UserModel.fromJson({...u.toJson(), 'username': serverUsername});
  }
}

final _sizes = <(String, Size, double)>[
  ('360', const Size(360, 800), 1.0),
  ('360_s13', const Size(360, 800), 1.3),
  ('300', const Size(300, 700), 1.0),
  ('412_s15', const Size(412, 915), 1.5),
  ('320_s20', const Size(320, 760), 2.0),
];

_Auth _setup({String? username = _username, String name = 'Rahul Mehra'}) {
  Get.reset();
  final a = _Auth();
  Get.put<AuthController>(a);
  Get.put<TabConfigController>(_Tabs());
  final p = Get.put(PlanController());
  p.myPlan.value = MyPlanModel(paymentEnabled: false);
  a.profileName.value = name;
  a.profilePhone.value = '9876543210';
  a.profilePhoneVerified.value = true;
  a.user.value = UserModel(id: 'u', phoneNumber: '9876543210', isPhoneVerified: true, name: name, username: username, createdAt: DateTime(2026), roleConfirmed: true);
  a.signupUsername.value = username;
  return a;
}

List<String> _clipboard(WidgetTester t) {
  final copied = <String>[];
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
    return null;
  });
  addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return copied;
}

Future<void> _openOnboarding(WidgetTester t, {Size size = phoneSize, double scale = 1.0}) async {
  await pumpPhone(t, const SizedBox(), size: size, textScale: scale, toastHost: true);
  Get.to<void>(() => const OnboardingScreen(), arguments: {'phone': '9876543210'}, transition: Transition.noTransition, duration: Duration.zero);
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
  await settlePhone(t);
}

Future<void> _openProfile(WidgetTester t, {Size size = phoneSize, double scale = 1.0}) async {
  await pumpPhone(t, const ProfileScreen(), size: size, textScale: scale, toastHost: true);
  await settlePhone(t);
}

Future<void> _openSheet(WidgetTester t, {Size size = phoneSize, double scale = 1.0, String name = 'Rahul Mehra'}) async {
  await pumpPhone(
    t,
    Scaffold(
      body: Builder(
        builder: (c) => Center(
          child: TextButton(
            onPressed: () => UsernameQrSheet.show(c, username: _username, name: name),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    size: size,
    textScale: scale,
    toastHost: true,
  );
  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await settlePhone(t);
}

bool _sameModules(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 3; i < a.length; i += 4) {
    if ((a[i] > 127) != (b[i] > 127)) return false;
  }
  return true;
}

Future<void> _toast(WidgetTester t) async {
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _finish(WidgetTester t) async {
  await t.pump(const Duration(seconds: 5));
  toastification.dismissAll(delayForAnimation: false);
  await t.pump(const Duration(seconds: 1));
  expect(t.takeException(), isNull);
}

void main() {
  setUpAll(() {
    loadRealFonts();
    shotsDir = _shots;
  });
  tearDown(Get.reset);

  group('onboarding username (frame 1.1)', () {
    testWidgets('shows the server username greyed with label and helper, above Full Name', (t) async {
      _setup();
      await _openOnboarding(t);
      expect(find.text(BuddyStrings.usernameLabel), findsOneWidget);
      expect(find.text(_username), findsOneWidget);
      expect(find.text(BuddyStrings.usernameHelper), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      final y = t.getTopLeft(find.text(_username)).dy;
      expect(y, lessThan(t.getTopLeft(find.text('Full Name')).dy));
      expect(y, greaterThan(t.getTopLeft(find.text('+91 9876543210')).dy));
      await _finish(t);
    });

    testWidgets('Copy puts the username on the clipboard and shows a toast', (t) async {
      _setup();
      final copied = _clipboard(t);
      await _openOnboarding(t);
      await t.tap(find.bySemanticsLabel(BuddyStrings.copyUsername));
      await _toast(t);
      expect(copied, [_username]);
      expect(find.text(BuddyStrings.copied), findsOneWidget);
      await _finish(t);
    });

    testWidgets('missing username shows a quiet loading look, Copy off, Get Started still works', (t) async {
      final a = _setup(username: null);
      Get.put(ProfilePhotoController(offline: () async => false));
      final copied = _clipboard(t);
      await _openOnboarding(t);
      expect(find.text(_username), findsNothing);
      expect(find.bySemanticsLabel(BuddyStrings.usernameLoading), findsOneWidget);
      await t.tap(find.bySemanticsLabel(BuddyStrings.copyUsername), warnIfMissed: false);
      await t.pump();
      expect(copied, isEmpty);
      await t.enterText(find.byType(TextFormField), 'Rahul Mehra');
      Get.find<ProfilePhotoController>().localPath.value = 'missing_photo.jpg';
      await t.pump();
      await t.ensureVisible(find.text('Get Started'));
      await t.pump();
      await t.tap(find.text('Get Started'));
      await t.pump();
      expect(a.submitted, ['Rahul Mehra']);
      a.signupUsername.value = _username;
      await t.pump();
      expect(find.text(_username), findsOneWidget);
      await _finish(t);
    });
  });

  group('profile username row (frame 1.2)', () {
    testWidgets('BUDDIES label above ACCOUNT with the username row and the Buddies row', (t) async {
      _setup();
      await _openProfile(t);
      expect(find.text(BuddyStrings.sectionBuddies), findsOneWidget);
      expect(find.text(_username), findsOneWidget);
      expect(find.text(BuddyStrings.myUsername), findsOneWidget);
      expect(find.text('Buddies'), findsOneWidget);
      expect(t.getTopLeft(find.text(BuddyStrings.sectionBuddies)).dy, lessThan(t.getTopLeft(find.text('ACCOUNT')).dy));
      await _finish(t);
    });

    testWidgets('Copy copies the username', (t) async {
      _setup();
      final copied = _clipboard(t);
      await _openProfile(t);
      await t.tap(find.bySemanticsLabel(BuddyStrings.copyUsername));
      await _toast(t);
      expect(copied, [_username]);
      expect(find.text(BuddyStrings.copied), findsOneWidget);
      await _finish(t);
    });

    testWidgets('QR opens My QR with the QR of the username', (t) async {
      _setup();
      await _openProfile(t);
      await t.tap(find.bySemanticsLabel(BuddyStrings.showQr));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await settlePhone(t);
      expect(find.text(BuddyStrings.qrTitle), findsOneWidget);
      expect(t.widget<UsernameQrCard>(find.byType(UsernameQrCard)).username, _username);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Rahul Mehra'), findsWidgets);
      await _finish(t);
    });

    testWidgets('no Share button on the row', (t) async {
      _setup();
      await _openProfile(t);
      expect(find.byIcon(Icons.share_rounded), findsNothing);
      expect(find.bySemanticsLabel(RegExp('share username', caseSensitive: false)), findsNothing);
      expect(find.bySemanticsLabel(BuddyStrings.showQr), findsOneWidget);
      expect(find.bySemanticsLabel(BuddyStrings.copyUsername), findsOneWidget);
      await _finish(t);
    });

    testWidgets('no username yet: buttons are off', (t) async {
      _setup(username: null);
      final copied = _clipboard(t);
      await _openProfile(t);
      expect(find.bySemanticsLabel(BuddyStrings.usernameLoading), findsOneWidget);
      await t.tap(find.bySemanticsLabel(BuddyStrings.copyUsername), warnIfMissed: false);
      await t.tap(find.bySemanticsLabel(BuddyStrings.showQr), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 600));
      expect(copied, isEmpty);
      expect(find.text(BuddyStrings.qrTitle), findsNothing);
      await _finish(t);
    });

    testWidgets('an account saved before usernames asks the server once and then shows it', (t) async {
      final a = _setup(username: null);
      a.serverUsername = _username;
      await _openProfile(t);
      expect(a.refreshes, 1);
      expect(find.text(_username), findsOneWidget);
      expect(find.bySemanticsLabel(BuddyStrings.usernameLoading), findsNothing);
      await _finish(t);
    });

    testWidgets('an account that already has its username is not fetched again', (t) async {
      final a = _setup();
      await _openProfile(t);
      expect(a.refreshes, 0);
      await _finish(t);
    });

    testWidgets('row is hidden for an owner', (t) async {
      final a = _setup();
      a.canListStays.value = true;
      a.roleKey.value = 'STAY_OWNER';
      await _openProfile(t);
      expect(find.text(_username), findsNothing);
      expect(find.text(BuddyStrings.sectionBuddies), findsNothing);
      await _finish(t);
    });
  });

  group('My QR sheet (frame 1.3)', () {
    testWidgets('QR payload is exactly the username, texts as drawn', (t) async {
      _setup();
      await _openSheet(t);
      expect(t.widget<UsernameQrCard>(find.byType(UsernameQrCard)).username, _username);
      final shown = t.widget<CustomPaint>(find.descendant(of: find.byType(QrImageView), matching: find.byType(CustomPaint)).first).painter! as QrPainter;
      final want = QrPainter(data: _username, version: QrVersions.auto, errorCorrectionLevel: QrErrorCorrectLevel.H, gapless: true);
      final other = QrPainter(data: 'Bakhli#00000000', version: QrVersions.auto, errorCorrectionLevel: QrErrorCorrectLevel.H, gapless: true);
      final bytes = await t.runAsync(() async => [
            (await shown.toImageData(100, format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List(),
            (await want.toImageData(100, format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List(),
            (await other.toImageData(100, format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List(),
          ]);
      expect(bytes![0].length, bytes[1].length);
      expect(_sameModules(bytes[0], bytes[1]), isTrue);
      expect(_sameModules(bytes[0], bytes[2]), isFalse);
      expect(find.text(BuddyStrings.qrTitle), findsOneWidget);
      expect(find.text(BuddyStrings.qrSubtitle), findsOneWidget);
      expect(find.text(_username), findsOneWidget);
      expect(find.text('Rahul Mehra'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      expect(find.text(BuddyStrings.close), findsOneWidget);
      await _finish(t);
    });

    testWidgets('no Share or Copy button and no link in the sheet', (t) async {
      _setup();
      await _openSheet(t);
      expect(find.byIcon(Icons.share_rounded), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Share', caseSensitive: false)), findsNothing);
      expect(find.textContaining('http'), findsNothing);
      expect(find.bySemanticsLabel(BuddyStrings.copyUsername), findsNothing);
      await _finish(t);
    });

    testWidgets('Close closes the sheet', (t) async {
      _setup();
      await _openSheet(t);
      await t.tap(find.text(BuddyStrings.close));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await settlePhone(t);
      expect(find.text(BuddyStrings.qrTitle), findsNothing);
      await _finish(t);
    });

    testWidgets('empty name falls back to an icon and no name line', (t) async {
      _setup(name: '');
      await _openSheet(t, name: '');
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.text(_username), findsOneWidget);
      await _finish(t);
    });
  });

  group('five sizes render without overflow', () {
    for (final (tag, size, scale) in _sizes) {
      testWidgets('onboarding $tag', (t) async {
        _setup();
        await _openOnboarding(t, size: size, scale: scale);
        await shot(t, 'onboarding_$tag');
        expect(find.text(_username), findsOneWidget);
        await _finish(t);
      });

      testWidgets('profile $tag', (t) async {
        _setup(name: tag == '300' ? 'Venkatanarasimha Raghavendra' : 'Rahul Mehra');
        await _openProfile(t, size: size, scale: scale);
        await shot(t, 'profile_$tag');
        expect(find.text(_username), findsOneWidget);
        await _finish(t);
      });

      testWidgets('qr sheet $tag', (t) async {
        _setup();
        await _openSheet(t, size: size, scale: scale, name: tag == '300' ? 'Venkatanarasimha Raghavendra Subramaniam' : 'Rahul Mehra');
        await shot(t, 'qr_$tag');
        expect(find.byType(QrImageView), findsOneWidget);
        await _finish(t);
      });
    }
  });
}
