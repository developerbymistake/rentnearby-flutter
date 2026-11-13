import 'dart:async';
import 'dart:io';

import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/models/role_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/screens/login_screen.dart';
import 'package:bakhli/screens/onboarding_screen.dart';
import 'package:bakhli/screens/phone_verify_screen.dart';
import 'package:bakhli/screens/role_change_screen.dart';
import 'package:bakhli/screens/role_select_screen.dart';
import 'package:bakhli/screens/intro/intro_scaffold.dart';
import 'package:bakhli/screens/splash/splash_hero.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:pinput/pinput.dart';
import 'package:toastification/toastification.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../support/real_phone.dart';

class _Auth extends AuthController {
  bool sendOk = true;
  String? verifyResult = 'Incorrect OTP. Please check and try again.';
  String? phoneSendResult;
  bool phoneVerifyOk = false;
  List<RoleModel> roles = const [
    RoleModel(key: 'SEEKER', name: 'Seeker', description: 'Plan trips, find stays and taxis', sortOrder: 1),
    RoleModel(key: 'STAY_OWNER', name: 'Stay Owner', description: 'List your stay', sortOrder: 2),
    RoleModel(key: 'TAXI_DRIVER', name: 'Taxi Driver', description: 'List your taxi', sortOrder: 3),
  ];
  bool hangRoles = false;
  int sendCalls = 0;
  int verifyCalls = 0;
  String? chosen;
  String? requested;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<bool> sendLoginOtp(String phone) async {
    sendCalls++;
    isLoading.value = false;
    return sendOk;
  }

  @override
  Future<String?> verifyLoginOtp(String phone, String otp) async {
    verifyCalls++;
    return verifyResult;
  }

  @override
  Future<void> completePhoneOnboarding({required String phone, required String name}) async {}

  @override
  Future<String?> sendPhoneOtp(String phone) async {
    sendCalls++;
    return phoneSendResult;
  }

  @override
  Future<bool> verifyPhoneOtp(String phone, String otp) async {
    verifyCalls++;
    return phoneVerifyOk;
  }

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<List<RoleModel>> fetchRoles() async {
    if (hangRoles) return Completer<List<RoleModel>>().future;
    return roles;
  }

  @override
  Future<RoleActionResult> chooseRole(String roleKey) async {
    chosen = roleKey;
    return RoleActionResult.success;
  }

  @override
  Future<RoleActionResult> requestRoleChange(String roleKey) async {
    requested = roleKey;
    return RoleActionResult.failed;
  }
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

const _dir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\auth';
final _configs = <(double, double)>[(360, 1.0), (360, 1.3), (300, 1.0)];
String _tag(double w, double s) => '${w.toInt()}_${s == 1.0 ? '10' : '13'}';

late _Auth _auth;

void _base({UserModel? user, String role = UserRoleKeys.seeker}) {
  Get.reset();
  Get.put<TabConfigController>(_Tabs());
  Get.put<LocationController>(JLoc(), permanent: true);
  _auth = Get.put<AuthController>(_Auth()) as _Auth;
  _auth.user.value = user;
  _auth.roleKey.value = role;
}

UserModel _user({String role = UserRoleKeys.seeker, String? status, String? reason, DateTime? next, String? stay, String? taxi}) => UserModel(
      id: 'u',
      phoneNumber: '9876543210',
      isPhoneVerified: true,
      createdAt: DateTime(2026),
      role: role,
      roleConfirmed: true,
      roleRequestStatus: status,
      roleRequestReason: reason,
      nextRoleRequestAt: next,
      stayStatus: stay,
      taxiStatus: taxi,
    );

Future<void> _open(WidgetTester t, Widget page, {double w = 360, double s = 1.0, Object? args}) async {
  debugDisableShadows = false;
  await pumpPhone(t, const SizedBox(), size: Size(w, 800), textScale: s, devicePixelRatio: 2);
  Get.to<void>(() => page, arguments: args, transition: Transition.noTransition, duration: Duration.zero);
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
  await settlePhone(t);
}

Future<void> _snap(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 400));
  await settlePhone(t);
  await shot(t, name);
}

Future<void> _done(WidgetTester t) async {
  await t.pump(const Duration(seconds: 6));
  toastification.dismissAll(delayForAnimation: false);
  await t.pump(const Duration(seconds: 2));
  final e = t.takeException();
  debugDisableShadows = true;
  expect(e, isNull);
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _phoneToOtp(WidgetTester t, {bool agree = false}) async {
  await t.enterText(find.byType(TextFormField).first, '9876543210');
  await t.pump();
  if (agree) {
    await t.tap(find.bySemanticsLabel('I agree to the Terms of Service and Privacy Policy'));
    await t.pump();
  }
  await _tapText(t, 'Send OTP');
  await _tapText(t, 'Confirm');
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('auth_gs').path,
    );
    await GetStorage.init();
    await loadRealFonts();
  });
  setUp(() => shotsDir = _dir);
  tearDown(Get.reset);

  group('login', () {
    for (final (w, s) in _configs) {
      testWidgets('main ${_tag(w, s)}', (t) async {
        _base();
        await _open(t, const LoginScreen(), w: w, s: s);
        await t.enterText(find.byType(TextFormField).first, '9876543210');
        FocusManager.instance.primaryFocus?.unfocus();
        await t.tap(find.bySemanticsLabel('I agree to the Terms of Service and Privacy Policy'));
        await _snap(t, 'login_${_tag(w, s)}');
        await _phoneToOtp(t);
        expect(_auth.sendCalls, 1);
        await t.enterText(find.byType(Pinput), '47');
        await _snap(t, 'login_otp_${_tag(w, s)}');
        await _done(t);
      });
    }

    testWidgets('states', (t) async {
      _base();
      await _open(t, const LoginScreen());
      await _snap(t, 'login_empty');
      await t.enterText(find.byType(TextFormField).first, '9876543');
      await t.tap(find.bySemanticsLabel('I agree to the Terms of Service and Privacy Policy'));
      await t.pump();
      await _tapText(t, 'Send OTP');
      await _snap(t, 'login_err');
      await t.pump(const Duration(seconds: 5));
      await t.enterText(find.byType(TextFormField).first, '9876543210');
      await t.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await _tapText(t, 'Send OTP');
      await _snap(t, 'login_confirm');
      await _tapText(t, 'Edit');
      _auth.isLoading.value = true;
      await _snap(t, 'login_load');
      _auth.isLoading.value = false;
      await t.pump();
      await _phoneToOtp(t);
      _auth.isLoading.value = true;
      await t.enterText(find.byType(Pinput), '4719');
      await _snap(t, 'login_verify');
      _auth.isLoading.value = false;
      await t.pump(const Duration(milliseconds: 300));
      await _snap(t, 'login_otp_err');
      await t.pump(const Duration(seconds: 5));
      await t.enterText(find.byType(Pinput), '1111');
      await t.pump(const Duration(seconds: 6));
      await t.enterText(find.byType(Pinput), '2222');
      await t.pump(const Duration(seconds: 6));
      await _snap(t, 'login_max');
      expect(find.text('Too Many Attempts'), findsOneWidget);
      await _tapText(t, 'Go Back');
      expect(find.text('Welcome to Bakhli'), findsOneWidget);
      await _done(t);
    });
  });

  group('onboarding', () {
    for (final (w, s) in _configs) {
      testWidgets('main ${_tag(w, s)}', (t) async {
        _base();
        await _open(t, const OnboardingScreen(), w: w, s: s, args: {'phone': '9876543210'});
        await t.enterText(find.byType(TextFormField).first, 'Rahul Sharma');
        await _snap(t, 'onb_${_tag(w, s)}');
        await _done(t);
      });
    }

    testWidgets('states', (t) async {
      _base();
      await _open(t, const OnboardingScreen(), args: {'phone': '9876543210'});
      await _tapText(t, 'Get Started');
      await _snap(t, 'onb_err');
      await t.pump(const Duration(seconds: 5));
      await t.enterText(find.byType(TextFormField).first, 'Rahul Sharma');
      FocusManager.instance.primaryFocus?.unfocus();
      _auth.isLoading.value = true;
      await _snap(t, 'onb_load');
      _auth.isLoading.value = false;
      await _done(t);
    });
  });

  group('phone verify', () {
    for (final (w, s) in _configs) {
      testWidgets('main ${_tag(w, s)}', (t) async {
        _base(user: _user());
        await _open(t, const PhoneVerifyScreen(), w: w, s: s);
        await _snap(t, 'pv_${_tag(w, s)}');
        await _tapText(t, 'Send OTP');
        await _snap(t, 'pv_confirm_${_tag(w, s)}');
        await _tapText(t, 'Confirm');
        await t.enterText(find.byType(Pinput), '471');
        await _snap(t, 'pv_otp_${_tag(w, s)}');
        await _done(t);
      });
    }

    testWidgets('states', (t) async {
      _base(user: _user());
      await _open(t, const PhoneVerifyScreen());
      await t.enterText(find.byType(TextFormField).first, '9876543');
      await _tapText(t, 'Send OTP');
      await _snap(t, 'pv_invalid');
      await t.pump(const Duration(seconds: 5));
      await t.enterText(find.byType(TextFormField).first, '9876543210');
      FocusManager.instance.primaryFocus?.unfocus();
      _auth.isLoading.value = true;
      await _snap(t, 'pv_send');
      _auth.isLoading.value = false;
      await t.pump();
      _auth.phoneSendResult = 'phone_claimed';
      await _tapText(t, 'Send OTP');
      await _tapText(t, 'Confirm');
      await _snap(t, 'pv_claimed');
      await _tapText(t, 'Use Different Number');
      _auth.phoneSendResult = null;
      await t.enterText(find.byType(TextFormField).first, '9876543210');
      FocusManager.instance.primaryFocus?.unfocus();
      await _tapText(t, 'Send OTP');
      await _tapText(t, 'Confirm');
      await t.enterText(find.byType(Pinput), '47');
      await _tapText(t, 'Verify Number');
      await _snap(t, 'pv_otp_short');
      await t.pump(const Duration(seconds: 5));
      _auth.isLoading.value = true;
      await t.enterText(find.byType(Pinput), '4719');
      await _snap(t, 'pv_verify');
      _auth.isLoading.value = false;
      await t.pump(const Duration(milliseconds: 300));
      await _snap(t, 'pv_otp_err');
      await _tapText(t, 'Resend OTP (1 left)');
      await _snap(t, 'pv_resent');
      await t.pump(const Duration(seconds: 5));
      await t.enterText(find.byType(Pinput), '1111');
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(find.byType(Pinput), '2222');
      await t.pump(const Duration(milliseconds: 500));
      await _snap(t, 'pv_max');
      expect(find.text('Too many attempts'), findsOneWidget);
      await _done(t);
    });

    testWidgets('success and change', (t) async {
      _base(user: _user());
      _auth.phoneVerifyOk = true;
      await _open(t, const PhoneVerifyScreen());
      await _tapText(t, 'Send OTP');
      await _tapText(t, 'Confirm');
      await t.enterText(find.byType(Pinput), '4719');
      await t.pump(const Duration(milliseconds: 500));
      await _snap(t, 'pv_success');
      expect(find.text('Phone Verified!'), findsOneWidget);
      await _done(t);
    });

    testWidgets('change mode', (t) async {
      _base(user: _user());
      await _open(t, const PhoneVerifyScreen(), args: {'isChange': true});
      await t.enterText(find.byType(TextFormField).first, '9876543210');
      await _tapText(t, 'Send OTP');
      await _snap(t, 'pv_change');
      await t.pump(const Duration(seconds: 5));
      _auth.phoneVerifyOk = true;
      await t.enterText(find.byType(TextFormField).first, '9876500000');
      FocusManager.instance.primaryFocus?.unfocus();
      await _tapText(t, 'Send OTP');
      await _tapText(t, 'Confirm');
      await t.enterText(find.byType(Pinput), '4719');
      await t.pump(const Duration(milliseconds: 500));
      await _snap(t, 'pv_success_change');
      await _done(t);
    });
  });

  group('role select', () {
    for (final (w, s) in _configs) {
      testWidgets('main ${_tag(w, s)}', (t) async {
        _base(user: _user());
        await _open(t, const RoleSelectScreen(), w: w, s: s);
        await _snap(t, 'rs_${_tag(w, s)}');
        await _done(t);
      });
    }

    testWidgets('states', (t) async {
      _base(user: _user());
      await _open(t, const RoleSelectScreen());
      await t.tap(find.text('Stay Owner'));
      await _snap(t, 'rs_stay');
      _auth.isLoading.value = true;
      await _snap(t, 'rs_busy');
      _auth.isLoading.value = false;
      await t.pump();
      await _tapText(t, 'Continue');
      expect(_auth.chosen, 'STAY_OWNER');
      await _done(t);
    });

    testWidgets('loading', (t) async {
      _base(user: _user());
      _auth.hangRoles = true;
      await _open(t, const RoleSelectScreen());
      await _snap(t, 'rs_load');
      await _done(t);
    });

    testWidgets('error', (t) async {
      _base(user: _user());
      _auth.roles = const [];
      await _open(t, const RoleSelectScreen());
      await _snap(t, 'rs_err');
      await _done(t);
    });

    testWidgets('correction', (t) async {
      _base(user: _user(role: UserRoleKeys.stayOwner), role: UserRoleKeys.stayOwner);
      await _open(t, const RoleSelectScreen(), args: {'correction': true, 'percent': 40});
      await _snap(t, 'rs_corr');
      await _done(t);
    });
  });

  group('role change', () {
    for (final (w, s) in _configs) {
      testWidgets('main ${_tag(w, s)}', (t) async {
        _base(user: _user());
        await _open(t, const RoleChangeScreen(), w: w, s: s);
        await t.tap(find.text('Stay Owner'));
        await _snap(t, 'rc_${_tag(w, s)}');
        await _done(t);
      });
    }

    final cases = <String, (UserModel, String, List<RoleModel>?)>{
      'rc_owner': (_user(role: UserRoleKeys.stayOwner), UserRoleKeys.stayOwner, null),
      'rc_taxi': (_user(role: UserRoleKeys.taxiDriver), UserRoleKeys.taxiDriver, null),
      'rc_paused': (
        _user(role: UserRoleKeys.stayOwner),
        UserRoleKeys.stayOwner,
        const [
          RoleModel(key: 'SEEKER', name: 'Seeker', description: 'Plan trips, find stays and taxis', sortOrder: 1),
          RoleModel(key: 'TAXI_DRIVER', name: 'Taxi Driver', description: 'List your taxi', sortOrder: 3),
        ]
      ),
      'rc_pending': (_user(status: RoleRequestStatus.pending), UserRoleKeys.seeker, null),
      'rc_rejected': (
        _user(status: RoleRequestStatus.rejected, reason: 'Stay photos are missing.', next: DateTime.now().add(const Duration(days: 3))),
        UserRoleKeys.seeker,
        null
      ),
      'rc_block': (_user(next: DateTime.now().add(const Duration(days: 3))), UserRoleKeys.seeker, null),
      'rc_err': (_user(), UserRoleKeys.seeker, const []),
      'rc_none': (_user(), UserRoleKeys.seeker, const [RoleModel(key: 'SEEKER', name: 'Seeker', description: 'Plan trips, find stays and taxis', sortOrder: 1)]),
    };
    for (final e in cases.entries) {
      testWidgets(e.key, (t) async {
        _base(user: e.value.$1, role: e.value.$2);
        if (e.value.$3 != null) _auth.roles = e.value.$3!;
        await _open(t, const RoleChangeScreen());
        await _snap(t, e.key);
        await _done(t);
      });
    }

    testWidgets('sending and fail', (t) async {
      _base(user: _user());
      await _open(t, const RoleChangeScreen());
      _auth.isLoading.value = true;
      await _snap(t, 'rc_sending');
      _auth.isLoading.value = false;
      await t.pump();
      await _tapText(t, 'Send request');
      expect(_auth.requested, 'STAY_OWNER');
      await _done(t);
    });

    testWidgets('loading', (t) async {
      _base(user: _user());
      _auth.hangRoles = true;
      await _open(t, const RoleChangeScreen());
      await _snap(t, 'rc_load');
      await _done(t);
    });
  });
  group('intro', () {
    for (final (w, s) in _configs) {
      testWidgets('pages ${_tag(w, s)}', (t) async {
        _base();
        await _open(t, IntroScaffold(onFinish: () {}, autoplay: false), w: w, s: s);
        for (var k = 0; k < IntroScaffold.pageCount; k++) {
          if (k > 0) {
            await t.tap(find.byKey(Key('intro_stop_$k')));
            await t.pump(const Duration(seconds: 1));
          }
          if (w == 360 && s == 1.0 || k == 0 || k == 3) await _snap(t, 'intro_${k + 1}_${_tag(w, s)}');
          if (k == 1) {
            await t.tap(find.text('Day 2 · 2 stops'));
            await t.pump(const Duration(milliseconds: 400));
            expect(find.text('Day 2 · 2 stops'), findsNWidgets(2));
            expect(find.text('Day 1 · 3 stops'), findsOneWidget);
            await _snap(t, 'intro_2_day2_${_tag(w, s)}');
            await t.tap(find.text('Day 2 · 2 stops').last);
            await t.pump(const Duration(milliseconds: 400));
            expect(find.text('Day 1 · 3 stops'), findsOneWidget);
            expect(find.text('Day 2 · 2 stops'), findsOneWidget);
            await t.tap(find.text('Day 2 · 2 stops'));
            await t.pump(const Duration(milliseconds: 400));
            await t.tap(find.text('Day 1 · 3 stops').last);
            await t.pump(const Duration(milliseconds: 400));
            expect(find.text('Day 1 · 3 stops'), findsNWidgets(2));
            await _snap(t, 'intro_2_day1_${_tag(w, s)}');
            await t.tap(find.text('Day 1 · 3 stops').last);
            await t.pump(const Duration(milliseconds: 400));
            expect(find.text('Day 1 · 3 stops'), findsOneWidget);
            expect(find.text('Day 2 · 2 stops'), findsOneWidget);
          }
          if (k == 2 && w == 360 && s == 1.0) {
            await t.tap(find.byKey(const ValueKey('reserve')));
            await t.pump(const Duration(milliseconds: 400));
            await _snap(t, 'intro_3b_${_tag(w, s)}');
            expect(find.text('Host replies soon'), findsOneWidget);
          }
          if (k == 4 && w == 360 && s == 1.0) {
            await t.tap(find.text('Check in'));
            await t.pump(const Duration(milliseconds: 400));
            await _snap(t, 'intro_5b_${_tag(w, s)}');
            expect(find.text('All done today'), findsOneWidget);
          }
        }
        await _done(t);
      });
    }
  });

  group('splash', () {
    testWidgets('scene and location dialog', (t) async {
      _base();
      await _open(t, const Scaffold(backgroundColor: DesignColors.dinnerEnd, body: SplashHero()));
      await t.pump(const Duration(seconds: 4));
      await _snap(t, 'splash');
      final ctx = t.element(find.byType(SplashHero));
      Dialog3D.show<void>(
        ctx,
        barrierDismissible: false,
        builder: (_) => Dialog3D(
          tone: ListingTone.indigo,
          art: ListingArt.roundPushpin,
          title: 'Location Access Required',
          body: 'This app helps you discover stays, taxis and trips near you. '
              'Location access is essential for the app to function. '
              'Please enable it to continue.',
          primaryLabel: 'Allow Location',
          onPrimary: () {},
        ),
      );
      await _snap(t, 'splash_loc');
      await _done(t);
    });
  });
  group('toasts', () {
    final cases = <String, (Widget Function(), Object?, void Function())>{
      'login_limit': (() => const LoginScreen(), null, () => AppToast.warning('OTP limit reached. Try again in 1 hour.')),
      'login_fail': (() => const LoginScreen(), null, () => AppToast.error('Failed to send OTP. Please try again.')),
      'login_offline': (() => const LoginScreen(), null, () => AppToast.error('No internet connection. Please check your network.')),
      'login_session': (() => const LoginScreen(), null, () => AppToast.info('Session expired. Please log in again.')),
      'login_role': (() => const LoginScreen(), null, () => AppToast.info('Role updated. Please log in again.')),
      'onb_long': (() => const OnboardingScreen(), {'phone': '9876543210'}, () => AppToast.error('Name cannot exceed 100 characters')),
      'pv_resend_max': (() => const PhoneVerifyScreen(), null, () => AppToast.warning('Maximum resends reached. Please try a different number.')),
      'rs_corr_err': (() => const RoleSelectScreen(), {'correction': true, 'percent': 40}, () => AppToast.error('Could not change role.')),
      'onb_fail': (() => const OnboardingScreen(), {'phone': '9876543210'}, () => AppToast.error('Could not complete sign up. Please try again.')),
      'pv_taken': (() => const PhoneVerifyScreen(), null, () => AppToast.warning('This number is already verified by another account.')),
      'rs_unavail': (() => const RoleSelectScreen(), null, () => AppToast.warning('This role is not available right now.')),
      'rs_save_err': (() => const RoleSelectScreen(), null, () => AppToast.error('Could not save your role.')),
      'rc_cool': (() => const RoleChangeScreen(), null, () => AppToast.warning('You can send a new request after 14 Nov 2026, 10:30 AM.')),
      'rc_live': (() => const RoleChangeScreen(), null, () => AppToast.warning('A stay that was approved or is under review blocks this role change.')),
      'rc_fail': (() => const RoleChangeScreen(), null, () => AppToast.error('Could not send request.')),
    };
    for (final e in cases.entries) {
      testWidgets(e.key, (t) async {
        _base(user: _user());
        await _open(t, e.value.$1(), args: e.value.$2);
        e.value.$3();
        await _snap(t, e.key);
        await _done(t);
      });
    }

    final otpToasts = <String, void Function()>{
      'login_otp_exp': () => AppToast.error('Invalid or expired OTP. Please try again.'),
      'login_otp_429': () => AppToast.error('Too many attempts. Try again in 15 minutes.'),
      'login_resend_max': () => AppToast.warning('Maximum resends reached. Please use a different number.'),
    };
    for (final e in otpToasts.entries) {
      testWidgets(e.key, (t) async {
        _base();
        await _open(t, const LoginScreen());
        await _phoneToOtp(t, agree: true);
        FocusManager.instance.primaryFocus?.unfocus();
        e.value();
        await _snap(t, e.key);
        await _done(t);
      });
    }

    testWidgets('rs_corr_dlg0', (t) async {
      _base(user: _user(role: UserRoleKeys.stayOwner), role: UserRoleKeys.stayOwner);
      await _open(t, const RoleSelectScreen(), args: {'correction': true, 'percent': 0});
      await _tapText(t, 'Continue');
      await _snap(t, 'rs_corr_dlg0');
      await _done(t);
    });

    testWidgets('rs_corr_dlg', (t) async {
      _base(user: _user(role: UserRoleKeys.stayOwner), role: UserRoleKeys.stayOwner);
      await _open(t, const RoleSelectScreen(), args: {'correction': true, 'percent': 40});
      await _tapText(t, 'Continue');
      await _snap(t, 'rs_corr_dlg');
      await _done(t);
    });
  });
}
