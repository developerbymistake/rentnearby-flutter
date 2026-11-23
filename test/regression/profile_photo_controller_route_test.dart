import 'dart:convert';
import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/config/profile_photo_strings.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/profile_photo_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/screens/profile_photo_screen.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/owner_fakes.dart';

// APP-1 (AU3-01, AU3-02): the photo controller is created by the screens through ensure() (no Get.put in the
// set-up) and must survive every offAllNamed that disposes the route it was first used on.

class _Notif extends NotificationService {
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}

  @override
  Future<void> registerTokenAfterLogin() async {}
}

class _Auth extends AuthController {
  @override
  Future<void> refreshProfile() async {}
}

class _Fake {
  final sent = <String>[];
  int picks = 0;
  late final Directory dir = Directory.systemTemp.createTempSync('dp_route');

  ProfilePhotoController build() => ProfilePhotoController(
        pick: (_) async {
          picks++;
          return File('${dir.path}/face$picks.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
        },
        send: (path, _) async {
          sent.add(path);
          return {'data': _user('https://x/new${sent.length}.jpg')};
        },
        offline: () async => false,
      );
}

Map<String, dynamic> _user(String? url) => {
      'id': 'u1',
      'phoneNumber': '9876543210',
      'createdAt': '2026-11-22T10:00:00Z',
      'roleConfirmed': true,
      'role': UserRoleKeys.seeker,
      'profilePhotoUrl': url,
      'profilePhotoRemoved': url == null,
    };

String _token() {
  String part(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'role': UserRoleKeys.seeker})}.sig';
}

final _tabs = <ProfilePhotoController>[];
BuildContext? _tabContext;

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _photo = ProfilePhotoController.ensure();

  @override
  void initState() {
    super.initState();
    _tabs.add(_photo);
  }

  @override
  Widget build(BuildContext context) {
    _tabContext = context;
    return const Scaffold(body: Text('profile tab'));
  }
}

// Same shape as MainScreen: the tab root lives in a nested Navigator built by a PageRouteBuilder (TabNavigator).
class _Main extends StatelessWidget {
  const _Main();
  @override
  Widget build(BuildContext context) =>
      Navigator(onGenerateRoute: (_) => PageRouteBuilder(pageBuilder: (_, _, _) => const _ProfileTab()));
}

Widget _app() => GetMaterialApp(
      theme: AppTheme.theme,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: Stack(fit: StackFit.expand, children: [Positioned.fill(child: c!), Overlay(key: AppToast.overlayKey)]),
      ),
      initialRoute: AppRoutes.main,
      getPages: [
        GetPage(name: AppRoutes.main, page: () => const _Main()),
        GetPage(name: AppRoutes.profilePhoto, page: () => const ProfilePhotoScreen()),
        GetPage(name: AppRoutes.login, page: () => const Scaffold(body: Text('login'))),
      ],
    );

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
  await t.pumpAndSettle();
}

void main() {
  late _Fake fake;

  setUpAll(() async {
    await initTestStorage('dp_route');
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    Get.testMode = true;
    _tabs.clear();
    fake = _Fake();
    ProfilePhotoController.create = fake.build;
    Get.put<TabConfigController>(FakeTabs());
    Get.put<NotificationService>(_Notif());
    await StorageService.saveToken(_token());
  });

  tearDown(() async {
    ProfilePhotoController.create = ProfilePhotoController.new;
    await StorageService.clearToken();
    StorageService.clearUser();
    Get.reset();
  });

  Future<_Auth> start(WidgetTester t) async {
    t.view.devicePixelRatio = 3;
    t.view.physicalSize = const Size(392 * 3, 2400 * 3);
    addTearDown(t.view.reset);
    final a = _Auth();
    Get.put<AuthController>(a, permanent: true);
    a.user.value = UserModel.fromJson(_user('https://x/old.jpg'));
    await t.pumpWidget(_app());
    await _settle(t);
    expect(find.text('profile tab'), findsOneWidget);
    return a;
  }

  testWidgets('(a) Profile tab first, then offAllNamed(/profile-photo): the gate page holds a live controller and can pick', (t) async {
    final a = await start(t);
    a.applyUser(UserModel.fromJson(_user(null)));
    await _settle(t);
    expect(Get.currentRoute, AppRoutes.profilePhoto);
    expect(find.byType(ProfilePhotoScreen), findsOneWidget);
    expect(Get.isRegistered<ProfilePhotoController>(), isTrue);
    final c = Get.find<ProfilePhotoController>();
    expect(identical(c, _tabs.single), isTrue);
    expect(c.isClosed, isFalse);
    await t.tap(find.bySemanticsLabel(ProfilePhotoStrings.semProfilePhoto), warnIfMissed: false);
    await _settle(t);
    expect(fake.picks, 1);
    expect(c.localPath.value, isNotNull);
  });

  testWidgets('(b) /main -> offAllNamed(/main): the new Profile tab controller is live and change() uploads', (t) async {
    await start(t);
    Get.offAllNamed(AppRoutes.main);
    await _settle(t);
    expect(_tabs, hasLength(2));
    expect(_tabs.last.isClosed, isFalse);
    expect(Get.isRegistered<ProfilePhotoController>(), isTrue);
    await _tabs.last.change(_tabContext!);
    await _settle(t);
    expect(fake.sent, hasLength(1));
    expect(Get.find<AuthController>().user.value!.profilePhotoUrl, 'https://x/new1.jpg');
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('(c) session clean-up (logout) removes the session controller', (t) async {
    final a = await start(t);
    expect(Get.isRegistered<ProfilePhotoController>(), isTrue);
    await t.runAsync(() => a.forceLogout(reason: LogoutReason.explicitLogout));
    await _settle(t);
    expect(Get.isRegistered<ProfilePhotoController>(), isFalse);
    expect(_tabs.single.isClosed, isTrue);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('journey: Profile visited -> picture removed -> gate page -> pick -> Continue -> main -> pencil changes it again', (t) async {
    final a = await start(t);
    a.applyUser(UserModel.fromJson(_user(null)));
    await _settle(t);
    expect(Get.currentRoute, AppRoutes.profilePhoto);
    await t.tap(find.bySemanticsLabel(ProfilePhotoStrings.semProfilePhoto), warnIfMissed: false);
    await _settle(t);
    await t.tap(find.text(ProfilePhotoStrings.continueLabel), warnIfMissed: false);
    await _settle(t);
    expect(fake.sent, hasLength(1));
    expect(Get.currentRoute, AppRoutes.main);
    expect(find.text('profile tab'), findsOneWidget);
    final live = Get.find<ProfilePhotoController>();
    expect(live.isClosed, isFalse);
    await live.change(_tabContext!);
    await _settle(t);
    expect(fake.picks, 2);
    expect(fake.sent, hasLength(2));
    expect(a.user.value!.profilePhotoUrl, 'https://x/new2.jpg');
    expect(find.text(ProfilePhotoStrings.updated), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
  });
}
