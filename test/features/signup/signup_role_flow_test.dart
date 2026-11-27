import 'dart:convert';
import 'dart:typed_data';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/extra/ext_auth.dart';
import 'package:bakhli/design/extra/ext_buddy.dart';
import 'package:bakhli/features/social/a/onboarding/onboarding_steps.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/screens/onboarding_screen.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/onboarding_walk.dart';
import '../../support/owner_fakes.dart';
import '../social/shared/social_test_support.dart' show putSeeker, pumpSocial, installServer, drain;

const _phone = '9876543210';
const _username = 'Bakhli#48291736';

class _Server implements HttpClientAdapter {
  final routes = <String, Map<String, dynamic>>{};
  final paths = <String>[];
  final sent = <String, Object?>{};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final key = '${options.method} ${options.path}';
    paths.add(key);
    sent[key] = options.data;
    final body = routes[key];
    return ResponseBody.fromString(jsonEncode(body ?? {'error': {'type': 'NotFound', 'message': 'Not found'}}), body == null ? 404 : 200, headers: {
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

String _token(String role) {
  String part(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'role': role})}.sig';
}

// The backend answers a name-only account with profileCompleted=false (ProfileCompleted = Gender != null).
Map<String, dynamic> _session(String role, {required bool roleConfirmed}) => {
      'data': {
        'token': _token(role),
        'user': {
          'id': 'u1',
          'phoneNumber': _phone,
          'name': 'Rahul Mehra',
          'username': _username,
          'createdAt': '2026-11-27T10:00:00Z',
          'role': role,
          'roleConfirmed': roleConfirmed,
          'profileCompleted': false,
        },
      },
    };

const _stubRoutes = [
  AppRoutes.main,
  AppRoutes.login,
  AppRoutes.basicDetails,
  AppRoutes.roleSelect,
  AppRoutes.onboarding,
  AppRoutes.staySetup,
  AppRoutes.taxiSetup,
  AppRoutes.profilePhoto,
];

Widget _app() => GetMaterialApp(
      initialRoute: AppRoutes.basicDetails,
      getPages: [for (final r in _stubRoutes) GetPage(name: r, page: () => Scaffold(body: Text('page $r')))],
    );

void main() {
  setUpAll(() async {
    await initTestStorage('signup_role_flow');
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await StorageService.clearToken();
    StorageService.clearUser();
    Get.reset();
  });

  group('new user: basic details -> role select -> setup', () {
    const expected = {
      UserRoleKeys.seeker: AppRoutes.onboarding,
      UserRoleKeys.stayOwner: AppRoutes.staySetup,
      UserRoleKeys.taxiDriver: AppRoutes.taxiSetup,
    };

    for (final MapEntry(key: role, value: target) in expected.entries) {
      testWidgets('$role: name-only account goes to role select, then $target', (t) async {
        Get.testMode = true;
        ApiService.init();
        Get.put<TabConfigController>(FakeTabs());
        Get.put<NotificationService>(_Notif());
        await t.pumpWidget(_app());
        await t.pumpAndSettle();
        expect(Get.currentRoute, AppRoutes.basicDetails);

        final a = Get.put<AuthController>(AuthController());
        a.signupUsername.value = _username;
        final server = _Server()
          ..routes['POST /auth/phone/complete-onboarding'] = _session(UserRoleKeys.seeker, roleConfirmed: false)
          ..routes['PUT /users/me/role-choice'] = _session(role, roleConfirmed: true);
        ApiService.dio.httpClientAdapter = server;

        expect(await t.runAsync(() => a.createOnboardingAccount(phone: _phone, name: 'Rahul Mehra')), isTrue);
        expect(server.sent['POST /auth/phone/complete-onboarding'], {'phoneNumber': _phone, 'name': 'Rahul Mehra', 'username': _username},
            reason: 'Fill basic details sends the name only, no traveller fields');
        expect(StorageService.isLoggedIn, isTrue, reason: 'the account and the session exist before any traveller call');
        expect(a.user.value!.profileCompleted, isFalse);
        expect(a.postLoginRoute, AppRoutes.roleSelect);
        Get.offAllNamed(a.postLoginRoute);
        await t.pumpAndSettle();
        expect(Get.currentRoute, AppRoutes.roleSelect);

        expect(await t.runAsync(() => a.chooseRole(role)), RoleActionResult.success);
        await t.pumpAndSettle();
        expect(a.postLoginRoute, target);
        expect(Get.currentRoute, target);
        if (role != UserRoleKeys.seeker) {
          expect(Get.currentRoute, isNot(AppRoutes.onboarding), reason: 'owners never see the traveller form');
        }
        expect(server.paths.where((p) => p.contains('/trips/')), isEmpty, reason: 'no traveller call during sign up');
      });
    }
  });

  group('postLoginRoute after role select (profileCompleted=false)', () {
    setUp(() => Get.testMode = true);

    test('Seeker goes to the traveller form', () {
      final a = putSeeker(role: UserRoleKeys.seeker, profileCompleted: false, gender: null);
      expect(a.postLoginRoute, AppRoutes.onboarding);
    });

    test('Stay Owner and Taxi Driver never get the traveller form', () {
      for (final (role, target) in [(UserRoleKeys.stayOwner, AppRoutes.staySetup), (UserRoleKeys.taxiDriver, AppRoutes.taxiSetup)]) {
        Get.reset();
        final a = putSeeker(role: role, profileCompleted: false, gender: null);
        expect(a.postLoginRoute, isNot(AppRoutes.onboarding), reason: role);
        expect(a.postLoginRoute, target, reason: role);
      }
    });

    test('a role not yet confirmed always goes to role select first', () {
      final a = putSeeker(profileCompleted: false, gender: null);
      a.user.value = UserModel.fromJson(_session(UserRoleKeys.seeker, roleConfirmed: false)['data']['user'] as Map<String, dynamic>);
      expect(a.postLoginRoute, AppRoutes.roleSelect);
    });
  });

  group('traveller form step 1 (existing account)', () {
    testWidgets('has no phone or username row and shows the prefilled name', (t) async {
      putSeeker(profileCompleted: false, gender: null);
      TripCityCatalog.to.seedForTest(const [
        TripCityModel(cityKey: 1, name: 'Rishikesh', districtName: 'Dehradun', stateName: 'Uttarakhand', latitude: 30.1, longitude: 78.3),
      ]);
      installServer();
      await pumpSocial(t, const OnboardingScreen(), pages: [GetPage(name: AppRoutes.main, page: () => const Scaffold(body: Text('MAIN')))]);
      expect(find.text(SocialStringsA.obStep1), findsOneWidget);
      expect(find.byType(OnboardingStepYou), findsOneWidget);
      expect(find.byType(AuthVerifiedRow), findsNothing);
      expect(find.byType(UsernameLockedPill), findsNothing);
      expect(find.textContaining('+91 '), findsNothing);
      expect(find.text('Bakhli#48291736'), findsNothing);
      expect((find.byKey(OnboardingWalk.nameKey).evaluate().single.widget as TextField).controller!.text, 'Rahul Verma');
      expect(OnboardingWalk.controllerOf(t).name.value, 'Rahul Verma');
      await drain(t);
      expect(t.takeException(), isNull);
    });
  });
}
