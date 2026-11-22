import 'dart:async';
import 'dart:io';

import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/config/profile_photo_strings.dart';
import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/profile_photo_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_auth.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_controller.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/screens/onboarding_screen.dart';
import 'package:bakhli/screens/profile_photo_screen.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:bakhli/widgets/profile_photo_circle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/owner_fakes.dart';
import '../support/real_phone.dart';

const _done = '/done-route';

class _Auth extends AuthController {
  final created = <String>[];
  bool createOk = true;
  int logouts = 0;
  Completer<String?>? nameHold;
  String? nameError;
  final savedNames = <String>[];

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  String get postLoginRoute => _done;

  @override
  bool get jobsBrowseEnabled {
    user.value;
    return true;
  }

  @override
  Future<bool> createOnboardingAccount({required String phone, required String name}) async {
    created.add(name);
    return createOk;
  }

  @override
  Future<void> logout() async => logouts++;

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<String?> saveName(String name) async {
    savedNames.add(name);
    final h = nameHold;
    if (h != null) return h.future;
    if (nameError == null) profileName.value = name;
    return nameError;
  }
}

class _Home extends TaxiDriverHomeController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Photo {
  final sent = <String>[];
  bool fail = false;
  bool offline = false;
  String? url = 'https://x/new.jpg';
  int picks = 0;
  Completer<Map<String, dynamic>>? hold;
  late final File file = () {
    final dir = Directory.systemTemp.createTempSync('dp_screens');
    return File('${dir.path}/face.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
  }();

  ProfilePhotoController put() => Get.put(ProfilePhotoController(
        pick: (_) async {
          picks++;
          return file;
        },
        send: (path, progress) async {
          sent.add(path);
          final h = hold;
          if (h != null) return h.future;
          if (fail) throw Exception('upload failed');
          return {
            'data': {'id': 'u1', 'phoneNumber': '9876543210', 'createdAt': '2026-11-22T10:00:00Z', 'roleConfirmed': true, 'name': 'Applied Name', 'profilePhotoUrl': url},
          };
        },
        offline: () async => offline,
      ));
}

late _Auth _auth;

_Auth _setup({ShellKind kind = ShellKind.seeker, String? url, bool removed = false}) {
  Get.testMode = true;
  Get.put<TabConfigController>(FakeTabs());
  _auth = _Auth();
  Get.put<AuthController>(_auth);
  Get.put(PlanController()).myPlan.value = const MyPlanModel(paymentEnabled: false);
  _auth.shellKind.value = kind;
  _auth.profileName.value = 'Rahul Mehra';
  _auth.profilePhone.value = '9876543210';
  _auth.user.value = UserModel.fromJson({
    'id': 'u1',
    'phoneNumber': '9876543210',
    'createdAt': '2026-11-22T10:00:00Z',
    'roleConfirmed': true,
    'name': 'Rahul Mehra',
    'username': 'Bakhli#48291736',
    'profilePhotoUrl': url,
    'profilePhotoRemoved': removed,
  });
  _auth.signupUsername.value = 'Bakhli#48291736';
  return _auth;
}

Future<void> _pumpApp(WidgetTester t, {Widget home = const SizedBox()}) async {
  t.view.devicePixelRatio = 3;
  t.view.physicalSize = const Size(392 * 3, 2400 * 3);
  addTearDown(t.view.reset);
  await t.pumpWidget(GetMaterialApp(
    theme: AppTheme.theme,
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: Stack(fit: StackFit.expand, children: [Positioned.fill(child: c!), Overlay(key: AppToast.overlayKey)]),
    ),
    initialRoute: '/',
    getPages: [
      GetPage(name: '/', page: () => home),
      GetPage(name: _done, page: () => const Scaffold(body: Text('done page'))),
    ],
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> _openPage(WidgetTester t, Widget Function() page, {Object? args}) async {
  await _pumpApp(t);
  Get.to<void>(page, arguments: args, transition: Transition.noTransition, duration: Duration.zero);
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
  await settlePhone(t);
}

Future<void> _openProfile(WidgetTester t) async {
  await _pumpApp(t, home: const ProfileScreen());
  await settlePhone(t);
}

Future<void> _toast(WidgetTester t) async {
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f, warnIfMissed: false);
  await _toast(t);
}

Future<void> _drain(WidgetTester t) async {
  await t.pump(const Duration(seconds: 5));
  await t.pump(const Duration(seconds: 1));
}

Future<void> _openOnboarding(WidgetTester t) => _openPage(t, () => const OnboardingScreen(), args: {'phone': '9876543210'});

void main() {
  setUpAll(() async {
    await initTestStorage('dp_screens');
    await loadRealFonts();
  });
  tearDown(Get.reset);

  group('onboarding', () {
    testWidgets('the photo block is the first child of the card, above the phone row', (t) async {
      _setup();
      _Photo().put();
      await _openOnboarding(t);
      final card = t.widget<AuthCard>(find.byType(AuthCard));
      expect(card.children.first, isA<ProfilePhotoBlock>());
      expect(t.getTopLeft(find.byType(ProfilePhotoBlock)).dy, lessThan(t.getTopLeft(find.byType(AuthVerifiedRow)).dy));
      expect(find.text(ProfilePhotoStrings.label), findsOneWidget);
      expect(find.text(ProfilePhotoStrings.helper), findsOneWidget);
    });

    testWidgets('Get Started without a photo: red ring + toast, no API call', (t) async {
      _setup();
      final p = _Photo()..put();
      await _openOnboarding(t);
      await t.enterText(find.byType(TextFormField), 'Rahul Mehra');
      await _tap(t, find.text('Get Started'));
      expect(find.text(ProfilePhotoStrings.addTitle), findsOneWidget);
      expect(_auth.created, isEmpty);
      expect(p.sent, isEmpty);
      final circle = t.widget<ProfilePhotoCircle>(find.byType(ProfilePhotoCircle));
      expect(circle.failed, isFalse);
      expect(circle.ringColor, AuthInk.ringBad);
      await _drain(t);
    });

    testWidgets('photo picked, no name: the existing name toast', (t) async {
      _setup();
      final p = _Photo()..put();
      await _openOnboarding(t);
      await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semProfilePhoto));
      expect(p.picks, 1);
      expect(find.byKey(ProfilePhotoCircle.localKey), findsOneWidget);
      await _tap(t, find.text('Get Started'));
      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(_auth.created, isEmpty);
      await _drain(t);
    });

    testWidgets('create ok + upload fails: name locked, Try again repeats only the upload', (t) async {
      _setup();
      final p = _Photo()
        ..fail = true
        ..put();
      await _openOnboarding(t);
      await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semProfilePhoto));
      await t.enterText(find.byType(TextFormField), 'Rahul Mehra');
      await _tap(t, find.text('Get Started'));
      expect(_auth.created, ['Rahul Mehra']);
      expect(p.sent, hasLength(1));
      expect(find.text(ProfilePhotoStrings.uploadFailed), findsOneWidget);
      expect(find.text(ProfilePhotoStrings.tryAgain), findsOneWidget);
      expect(find.byKey(ProfilePhotoCircle.retryKey), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      final failedCircle = t.widget<ProfilePhotoCircle>(find.byType(ProfilePhotoCircle));
      expect((failedCircle.failed, failedCircle.ringWidth), (true, DS.s(3)));
      expect(t.widget<AuthPillInput>(find.byType(AuthPillInput).last).locked, isTrue);
      expect(t.widget<TextField>(find.byType(TextField)).style!.color, Ink3D.sub);

      p.fail = false;
      await _tap(t, find.text(ProfilePhotoStrings.tryAgain));
      await t.pumpAndSettle();
      expect(_auth.created, ['Rahul Mehra']);
      expect(p.sent, hasLength(2));
      expect(find.text('done page'), findsOneWidget);
    });

    testWidgets('create fails: no upload, still on the page', (t) async {
      _setup().createOk = false;
      final p = _Photo()..put();
      await _openOnboarding(t);
      await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semProfilePhoto));
      await t.enterText(find.byType(TextFormField), 'Rahul Mehra');
      await _tap(t, find.text('Get Started'));
      expect(_auth.created, ['Rahul Mehra']);
      expect(p.sent, isEmpty);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('both ok: leaves through postLoginRoute', (t) async {
      _setup();
      final p = _Photo()..put();
      await _openOnboarding(t);
      await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semProfilePhoto));
      await t.enterText(find.byType(TextFormField), 'Rahul Mehra');
      await _tap(t, find.text('Get Started'));
      await t.pumpAndSettle();
      expect(p.sent, hasLength(1));
      expect(find.text('done page'), findsOneWidget);
    });

    testWidgets('offline on Get Started: toast only, nothing sent', (t) async {
      _setup();
      final p = _Photo()..put();
      await _openOnboarding(t);
      await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semProfilePhoto));
      await t.enterText(find.byType(TextFormField), 'Rahul Mehra');
      p.offline = true;
      await _tap(t, find.text('Get Started'));
      expect(find.text(ProfilePhotoStrings.offline), findsOneWidget);
      expect(_auth.created, isEmpty);
      expect(p.sent, isEmpty);
      await _drain(t);
    });

    testWidgets('uploading shows the percent ring and a loading button', (t) async {
      _setup();
      final p = _Photo()
        ..hold = Completer()
        ..put();
      await _openOnboarding(t);
      await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semProfilePhoto));
      await t.enterText(find.byType(TextFormField), 'Rahul Mehra');
      await _tap(t, find.text('Get Started'));
      expect(find.text('0%'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      expect(find.text(ProfilePhotoStrings.tryAgain), findsNothing);
      p.hold!.complete({
        'data': {'id': 'u1', 'phoneNumber': '1', 'createdAt': '2026-11-22T10:00:00Z', 'profilePhotoUrl': 'https://x/a.jpg'},
      });
      await t.pumpAndSettle();
      expect(find.text('done page'), findsOneWidget);
    });
  });

  group('gate page', () {
    for (final removed in [true, false]) {
      testWidgets('subtitle follows profilePhotoRemoved=$removed', (t) async {
        _setup(url: null, removed: removed);
        _Photo().put();
        await _openPage(t, () => const ProfilePhotoScreen());
        expect(find.text(ProfilePhotoStrings.addTitle), findsOneWidget);
        expect(find.text(removed ? ProfilePhotoStrings.removedSubtitle : 'Just one more step'), findsOneWidget);
      });
    }

    testWidgets('Continue needs a photo, then uploads and leaves', (t) async {
      _setup(url: null);
      final p = _Photo()..put();
      await _openPage(t, () => const ProfilePhotoScreen());
      await _tap(t, find.text(ProfilePhotoStrings.continueLabel));
      expect(find.text(ProfilePhotoStrings.addTitle), findsNWidgets(2));
      expect(p.sent, isEmpty);
      await _drain(t);
      await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semProfilePhoto));
      await _tap(t, find.text(ProfilePhotoStrings.continueLabel));
      await t.pumpAndSettle();
      expect(p.sent, hasLength(1));
      expect(find.text('done page'), findsOneWidget);
    });

    testWidgets('Log out calls logout; back is blocked', (t) async {
      _setup(url: null);
      _Photo().put();
      await _openPage(t, () => const ProfilePhotoScreen());
      await t.binding.handlePopRoute();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(ProfilePhotoScreen), findsOneWidget);
      await _tap(t, find.text(ProfilePhotoStrings.logOut));
      expect(_auth.logouts, 1);
    });

    testWidgets('opened while a picture exists: leaves at once', (t) async {
      _setup(url: 'https://x/a.jpg');
      _Photo().put();
      await _openPage(t, () => const ProfilePhotoScreen());
      await t.pumpAndSettle();
      expect(find.text('done page'), findsOneWidget);
    });
  });

  group('profile', () {
    for (final kind in ShellKind.values) {
      testWidgets('$kind: picture button changes the photo, name button opens the sheet', (t) async {
        _setup(kind: kind);
        final p = _Photo()
          ..url = null
          ..put();
        if (kind == ShellKind.taxiDriver) Get.put<TaxiDriverHomeController>(_Home());
        await _openProfile(t);
        expect(find.bySemanticsLabel(ProfilePhotoStrings.semChangePhoto), findsOneWidget);
        expect(find.bySemanticsLabel(ProfilePhotoStrings.semEditName), findsOneWidget);

        await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semChangePhoto));
        await t.pump();
        expect(p.picks, 1);
        expect(p.sent, hasLength(1));
        expect(find.text('Enter your full name'), findsNothing);
        expect(find.text(ProfilePhotoStrings.updated), findsOneWidget);
        expect(_auth.profileName.value, 'Applied Name');
        await _drain(t);

        await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semEditName));
        await t.pump(const Duration(milliseconds: 600));
        expect(find.text('Enter your full name'), findsOneWidget);
        expect(p.picks, 1);
        await _tap(t, find.bySemanticsLabel('Cancel'));
        await t.pump(const Duration(seconds: 1));
      });
    }

    testWidgets('failed upload turns the badge into retry; busy disables the picture', (t) async {
      _setup();
      final p = _Photo()
        ..fail = true
        ..url = null
        ..put();
      await _openProfile(t);
      await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semChangePhoto));
      await t.pump();
      expect(find.text(ProfilePhotoStrings.updateFailed), findsOneWidget);
      expect(find.bySemanticsLabel(ProfilePhotoStrings.semRetryUpload), findsOneWidget);
      expect(t.widget<ProfilePhotoCircle>(find.byType(ProfilePhotoCircle)).failed, isTrue);
      expect(t.widget<ProfilePhotoCircle>(find.byType(ProfilePhotoCircle)).failColor, ListingTone.coral.g1);
      expect(_auth.profileName.value, 'Rahul Mehra');
      await _drain(t);

      p
        ..fail = false
        ..hold = Completer();
      await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semRetryUpload));
      expect(p.sent, hasLength(2));
      expect(p.picks, 1);
      expect(t.widget<ProfilePhotoCircle>(find.byType(ProfilePhotoCircle)).busy, isTrue);
      await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semChangePhoto));
      expect(p.picks, 1);
      p.hold!.complete({
        'data': {'id': 'u1', 'phoneNumber': '1', 'createdAt': '2026-11-22T10:00:00Z', 'profilePhotoUrl': null},
      });
      await _toast(t);
      expect(find.bySemanticsLabel(ProfilePhotoStrings.semRetryUpload), findsNothing);
      await _drain(t);
    });

    testWidgets('name sheet stays open while saving, closes on success', (t) async {
      _setup();
      _Photo().put();
      _auth.nameHold = Completer();
      await _openProfile(t);
      await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semEditName));
      await t.pump(const Duration(milliseconds: 600));
      await t.enterText(find.byType(TextFormField), 'Rahul Kumar Mehra');
      await t.pump();
      await _tap(t, find.bySemanticsLabel('Save'));
      expect(find.text('Enter your full name'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await t.binding.handlePopRoute();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Enter your full name'), findsOneWidget);
      _auth.nameHold!.complete(null);
      await _toast(t);
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Enter your full name'), findsNothing);
      expect(find.text('Profile updated'), findsOneWidget);
      expect(_auth.savedNames, ['Rahul Kumar Mehra']);
      await _drain(t);
    });

    testWidgets('name sheet shows the error inside on failure and stays open', (t) async {
      _setup();
      _Photo().put();
      _auth.nameError = 'Could not update name.';
      await _openProfile(t);
      await _tap(t, find.bySemanticsLabel(ProfilePhotoStrings.semEditName));
      await t.pump(const Duration(milliseconds: 600));
      await _tap(t, find.bySemanticsLabel('Save'));
      expect(find.text('Could not update name.'), findsOneWidget);
      expect(find.text('Enter your full name'), findsOneWidget);
      await _tap(t, find.bySemanticsLabel('Cancel'));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Enter your full name'), findsNothing);
    });
  });
}
