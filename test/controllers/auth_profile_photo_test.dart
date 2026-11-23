import 'dart:convert';
import 'dart:typed_data';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/profile_photo_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toastification/toastification.dart';
import 'package:get/get.dart';

import '../support/owner_fakes.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;
  final paths = <String>[];
  final sent = <Object?>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    paths.add('${options.method} ${options.path}');
    sent.add(options.data);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _Notif extends NotificationService {
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}

  @override
  Future<void> registerTokenAfterLogin() async {}
}

class _Quiet extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

// A token whose payload carries the role claim.
String _token(String role) {
  String part(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'role': role})}.sig';
}

Map<String, dynamic> _user({String id = 'u1', Object? url = 'absent', bool roleConfirmed = true, bool removed = false}) => {
      'id': id,
      'phoneNumber': '9876543210',
      'createdAt': '2026-11-22T10:00:00Z',
      'roleConfirmed': roleConfirmed,
      'role': UserRoleKeys.seeker,
      if (url != 'absent') 'profilePhotoUrl': url,
      'profilePhotoRemoved': removed,
    };

Widget _app({List<String> extra = const [], bool toasts = false}) => GetMaterialApp(
      builder: toasts
          ? (context, c) => Stack(fit: StackFit.expand, children: [Positioned.fill(child: c!), Overlay(key: AppToast.overlayKey)])
          : null,
      initialRoute: AppRoutes.main,
      getPages: [
        for (final r in [AppRoutes.main, AppRoutes.login, AppRoutes.onboarding, AppRoutes.profilePhoto, AppRoutes.roleSelect, ...extra])
          GetPage(name: r, page: () => Scaffold(body: Text('page $r'))),
      ],
    );

void main() {
  setUpAll(() async {
    await initTestStorage('dp_auth');
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() {
    toastification.managers.clear();
    Get.testMode = true;
    ApiService.init();
    Get.put<TabConfigController>(FakeTabs());
    Get.put<NotificationService>(_Notif());
  });

  tearDown(() async {
    await StorageService.clearToken();
    StorageService.clearUser();
    Get.reset();
  });

  group('postLoginRoute', () {
    test('known and no picture goes to the photo page before every other rule', () {
      final a = _Quiet();
      for (final confirmed in [false, true]) {
        a.user.value = UserModel.fromJson(_user(url: null, roleConfirmed: confirmed));
        expect(a.postLoginRoute, AppRoutes.profilePhoto);
      }
    });

    test('unknown picture keeps the old order', () {
      final a = _Quiet();
      a.user.value = UserModel.fromJson(_user(roleConfirmed: false));
      expect(a.postLoginRoute, AppRoutes.roleSelect);
      a.user.value = UserModel.fromJson(_user());
      expect(a.postLoginRoute, AppRoutes.main);
    });

    test('with a picture the old order is unchanged', () {
      final a = _Quiet();
      a.user.value = UserModel.fromJson(_user(url: 'https://x/a.jpg', roleConfirmed: false));
      expect(a.postLoginRoute, AppRoutes.roleSelect);
      a.user.value = UserModel.fromJson(_user(url: 'https://x/a.jpg'));
      expect(a.postLoginRoute, AppRoutes.main);
      a.roleKey.value = UserRoleKeys.stayOwner;
      a.canListStays.value = true;
      expect(a.postLoginRoute, AppRoutes.staySetup);
    });
  });

  group('mid-session gate worker', () {
    testWidgets('a user who loses the picture on a main route lands on the photo page', (t) async {
      await StorageService.saveToken(_token(UserRoleKeys.seeker));
      final a = Get.put<AuthController>(AuthController());
      a.user.value = UserModel.fromJson(_user(url: 'https://x/a.jpg'));
      await t.pumpWidget(_app());
      await t.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.main);
      a.user.value = UserModel.fromJson(_user(url: null, removed: true));
      await t.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.profilePhoto);
    });

    for (final quiet in [AppRoutes.onboarding, AppRoutes.login, AppRoutes.profilePhoto]) {
      testWidgets('stays silent on $quiet', (t) async {
        await StorageService.saveToken(_token(UserRoleKeys.seeker));
        final a = Get.put<AuthController>(AuthController());
        await t.pumpWidget(_app());
        await t.pumpAndSettle();
        Get.offAllNamed(quiet);
        await t.pumpAndSettle();
        a.user.value = UserModel.fromJson(_user(url: null));
        await t.pumpAndSettle();
        expect(Get.currentRoute, quiet);
      });
    }

    for (final changeNumber in [AppRoutes.phoneVerify, AppRoutes.otp]) {
      testWidgets('interrupts the in-session change-number page $changeNumber', (t) async {
        await StorageService.saveToken(_token(UserRoleKeys.seeker));
        final a = Get.put<AuthController>(AuthController());
        a.user.value = UserModel.fromJson(_user(url: 'https://x/a.jpg'));
        await t.pumpWidget(_app(extra: [changeNumber]));
        await t.pumpAndSettle();
        Get.toNamed(changeNumber);
        await t.pumpAndSettle();
        a.user.value = UserModel.fromJson(_user(url: null, removed: true));
        await t.pumpAndSettle();
        expect(Get.currentRoute, AppRoutes.profilePhoto);
      });
    }

    testWidgets('logged out or unknown picture never navigates', (t) async {
      final a = Get.put<AuthController>(AuthController());
      await t.pumpWidget(_app());
      await t.pumpAndSettle();
      a.user.value = UserModel.fromJson(_user(url: null));
      await t.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.main);
      await StorageService.saveToken(_token(UserRoleKeys.seeker));
      a.user.value = UserModel.fromJson(_user());
      await t.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.main);
    });
  });

  group('createOnboardingAccount', () {
    testWidgets('ok: session saved, no navigation, true', (t) async {
      await t.pumpWidget(_app());
      await t.pumpAndSettle();
      Get.offAllNamed(AppRoutes.onboarding);
      await t.pumpAndSettle();
      final a = Get.put<AuthController>(AuthController());
      a.signupUsername.value = 'Bakhli#48291736';
      final adapter = _Adapter(200, {'data': {'token': _token(UserRoleKeys.seeker), 'user': _user(url: null, roleConfirmed: false)}});
      ApiService.dio.httpClientAdapter = adapter;
      expect(await t.runAsync(() => a.createOnboardingAccount(phone: '9876543210', name: 'Rahul')), isTrue);
      await t.pumpAndSettle();
      expect(adapter.paths, ['POST /auth/phone/complete-onboarding']);
      expect(adapter.sent.single, {'phoneNumber': '9876543210', 'name': 'Rahul', 'username': 'Bakhli#48291736'});
      expect(Get.currentRoute, AppRoutes.onboarding);
      expect(StorageService.isLoggedIn, isTrue);
      expect(a.user.value!.needsProfilePhoto, isTrue);
      expect(a.postLoginRoute, AppRoutes.profilePhoto);
      expect(a.isLoading.value, isFalse);
    });

    testWidgets('PhoneExists (account created, answer lost) sends the user to login with the server message', (t) async {
      await t.pumpWidget(_app(toasts: true));
      await t.pumpAndSettle();
      Get.offAllNamed(AppRoutes.onboarding);
      await t.pumpAndSettle();
      final a = Get.put<AuthController>(_Quiet());
      ApiService.dio.httpClientAdapter = _Adapter(409, {
        'error': {'type': 'PhoneExists', 'message': 'This phone number is already registered. Please sign in.'},
      });
      expect(await t.runAsync(() => a.createOnboardingAccount(phone: '9876543210', name: 'Rahul')), isFalse);
      await t.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.login);
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('This phone number is already registered. Please sign in.'), findsOneWidget);
      expect(a.isLoading.value, isFalse);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('OtpRequired sends the user back to login', (t) async {
      await t.pumpWidget(_app());
      await t.pumpAndSettle();
      Get.offAllNamed(AppRoutes.onboarding);
      await t.pumpAndSettle();
      final a = Get.put<AuthController>(_Quiet());
      ApiService.dio.httpClientAdapter = _Adapter(400, {
        'error': {'type': 'OtpRequired', 'message': 'Please verify your phone number again.'},
      });
      expect(await t.runAsync(() => a.createOnboardingAccount(phone: '9876543210', name: 'Rahul')), isFalse);
      await t.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.login);
      expect(StorageService.isLoggedIn, isFalse);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('other errors stay on the page', (t) async {
      await t.pumpWidget(_app());
      await t.pumpAndSettle();
      Get.offAllNamed(AppRoutes.onboarding);
      await t.pumpAndSettle();
      final a = Get.put<AuthController>(_Quiet());
      ApiService.dio.httpClientAdapter = _Adapter(400, {
        'error': {'type': 'Validation', 'message': 'Name is too short.'},
      });
      expect(await t.runAsync(() => a.createOnboardingAccount(phone: '9876543210', name: 'Rahul')), isFalse);
      await t.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.onboarding);
      await t.pump(const Duration(seconds: 5));
    });
  });

  group('saveName', () {
    test('ok applies the user and returns null; failure returns the message without changing the user', () async {
      final a = _Quiet();
      a.user.value = UserModel.fromJson(_user(url: 'https://x/a.jpg'));
      ApiService.dio.httpClientAdapter = _Adapter(200, {'data': {..._user(url: 'https://x/a.jpg'), 'name': 'Rahul Kumar'}});
      expect(await a.saveName('Rahul Kumar'), isNull);
      expect(a.profileName.value, 'Rahul Kumar');
      expect(StorageService.getUser()!.name, 'Rahul Kumar');
      ApiService.dio.httpClientAdapter = _Adapter(500, {'error': {'type': 'Server', 'message': 'x'}});
      expect(await a.saveName('Other'), 'Server error. Please try again.');
      expect(a.profileName.value, 'Rahul Kumar');
      expect(a.isLoading.value, isFalse);
    });
  });

  test('logout removes the photo controller and the next login sees only the new user', () async {
    final a = FakeAuth();
    Get.put<AuthController>(a, permanent: true);
    a.applyUser(UserModel.fromJson(_user(id: 'a', url: 'https://x/a.jpg')));
    ProfilePhotoController.ensure().localPath.value = '/tmp/a.jpg';
    await a.forceLogout(reason: LogoutReason.explicitLogout);
    expect(Get.isRegistered<ProfilePhotoController>(), isFalse);
    expect(a.user.value, isNull);
    expect(StorageService.getUser(), isNull);
    a.applyUser(UserModel.fromJson(_user(id: 'b', url: 'https://x/b.jpg')));
    expect(a.user.value!.profilePhotoUrl, 'https://x/b.jpg');
    expect(ProfilePhotoController.ensure().localPath.value, isNull);
    Get.delete<AuthController>(force: true);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
