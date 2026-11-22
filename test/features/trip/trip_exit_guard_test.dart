import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/trip_navigation.dart';
import 'package:bakhli/features/trip/trip_routes.dart';
import 'package:bakhli/features/trip/trip_strings_overview.dart';
import 'package:bakhli/features/trip/widgets/trip_exit_confirm.dart';
import 'package:bakhli/features/trip/widgets/trip_plan_header.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../journeys/fake_api.dart';
import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';
import 'support/engine_rig.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Auth extends GetxController implements AuthController {
  final tabs = <int>[];

  @override
  final user = Rxn<UserModel>();

  @override
  void switchToTab(int index) => tabs.add(index);

  @override
  void openPlace(AppPlace place, {bool detail = false}) => tabs.add(switch (place) {
        AppPlace.home => AppTabs.home,
        AppPlace.stays => AppTabs.stays,
        AppPlace.trips => AppTabs.trips,
        AppPlace.taxi => AppTabs.taxi,
        AppPlace.profile => AppTabs.profile,
      });

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _nainital = TripCityModel(cityKey: 1, name: 'Nainital', stateName: 'Uttarakhand', latitude: 29.4, longitude: 79.4);

TripSpotModel _spot(String id) => TripSpotModel.fromJson({
      'id': id,
      'name': id,
      'latitude': 29.4,
      'longitude': 79.4,
      'category': 'attraction',
      'visitMinutes': 60,
    });

TripPlan _plan() {
  final p = enginePlan([[2, 2]]);
  return TripPlan(
    legs: p.legs,
    days: p.days,
    settings: p.settings,
    steps: const TripSteps(startFrom: TripStartFrom(name: 'Kathgodam', lat: 29.26, lon: 79.52)),
  );
}

late _Auth _auth;

class _Stack extends NavigatorObserver {
  final names = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => names.add(route.settings.name);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => names.remove(route.settings.name);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => names.remove(route.settings.name);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = names.indexOf(oldRoute?.settings.name);
    if (i >= 0) names[i] = newRoute?.settings.name;
  }
}

final _stack = _Stack();

Future<TripPlanController> _app(WidgetTester t, {Size size = phoneSize, bool saved = true}) async {
  Get.put<TabConfigController>(_Tabs());
  _auth = Get.put<AuthController>(_Auth()) as _Auth;
  TripCityCatalog.to.seedForTest(const [_nainital]);
  final c = TripPlanController();
  if (saved) {
    final p = _plan();
    c.plan.value = p;
    c.trip.value = engineTrip(p);
  }
  Get.put<TripPlanController>(c, permanent: true);
  await loadRealFonts();
  final view = t.view;
  view.devicePixelRatio = 3;
  view.physicalSize = Size(size.width * 3, size.height * 3);
  view.padding = FakeViewPadding(top: phoneTopInset * 3, bottom: phoneBottomInset * 3);
  view.viewPadding = view.padding;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    view.resetPadding();
    view.resetViewPadding();
  });
  await t.pumpWidget(GetMaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.theme,
    initialRoute: AppRoutes.main,
    navigatorObservers: [_stack],
    getPages: [
      GetPage(name: AppRoutes.main, page: () => const Scaffold(body: Text('main'))),
      ...tripPages.where((p) => p.name == AppRoutes.tripOverview || p.name == AppRoutes.tripPlan),
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  ));
  await t.pump();
  return c;
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _toOverview(WidgetTester t) async {
  Get.toNamed(AppRoutes.tripOverview, arguments: {'tripId': 't1'});
  await _settle(t);
  expect(find.text(TripStringsOverview.title), findsOneWidget);
}

Future<void> _toPlan(WidgetTester t, Map<String, Object?> args) async {
  Get.toNamed(AppRoutes.tripPlan, arguments: args);
  await _settle(t);
  expect(find.byType(TripPlanScreen), findsOneWidget);
}

Future<void> _systemBack(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await _settle(t);
}

Finder get _exitTitle => find.text(TripStringsOverview.exitTitle);

Finder get _planBack => find.descendant(of: find.byType(TripPlanHeader), matching: find.text('‹'));

Future<void> _drain(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(minutes: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('exit_guard_gs').path);
    await GetStorage.init();
  });
  setUp(StorageService.clearTripNewDraft);
  tearDown(Get.reset);

  testWidgets('overview_header_back_asks_exit', (t) async {
    await _app(t);
    await _toOverview(t);
    await t.tap(find.byKey(const ValueKey('overview_back')));
    await _settle(t);
    expect(_exitTitle, findsOneWidget);
    expect(find.text(TripStringsOverview.exitBody), findsOneWidget);
    expect(find.text(TripStringsOverview.title), findsOneWidget);
    await _drain(t);
  });

  testWidgets('overview_system_back_asks_exit', (t) async {
    await _app(t);
    await _toOverview(t);
    await _systemBack(t);
    expect(_exitTitle, findsOneWidget);
    await _drain(t);
  });

  testWidgets('exit_confirm_lands_on_trips_tab', (t) async {
    await _app(t);
    await _toOverview(t);
    await t.tap(find.byKey(const ValueKey('overview_back')));
    await _settle(t);
    await t.tap(find.byKey(TripExitConfirm.exitKey));
    await _settle(t);
    expect(find.text('main'), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.main);
    expect(_auth.tabs, [AppTabs.trips]);
    await _drain(t);
  });

  testWidgets('keep_planning_stays', (t) async {
    await _app(t);
    await _toOverview(t);
    await _systemBack(t);
    await t.tap(find.byKey(TripExitConfirm.stayKey));
    await _settle(t);
    expect(_exitTitle, findsNothing);
    expect(find.text(TripStringsOverview.title), findsOneWidget);
    expect(_auth.tabs, isEmpty);
    await _drain(t);
  });

  testWidgets('double_back_shows_one_dialog', (t) async {
    await _app(t);
    await _toOverview(t);
    await t.tap(find.byKey(const ValueKey('overview_back')));
    await t.tap(find.byKey(const ValueKey('overview_back')), warnIfMissed: false);
    await _settle(t);
    expect(_exitTitle.evaluate().length, lessThanOrEqualTo(1));
    await _drain(t);
  });

  testWidgets('itinerary_header_back_asks_exit', (t) async {
    await _app(t);
    await _toPlan(t, {'tripId': 't1'});
    await t.tap(_planBack.first);
    await _settle(t);
    expect(_exitTitle, findsOneWidget);
    await t.tap(find.byKey(TripExitConfirm.exitKey));
    await _settle(t);
    expect(Get.currentRoute, AppRoutes.main);
    expect(_auth.tabs, [AppTabs.trips]);
    await _drain(t);
  });

  testWidgets('itinerary_system_back_asks_exit', (t) async {
    await _app(t);
    await _toPlan(t, {'tripId': 't1'});
    await _systemBack(t);
    expect(_exitTitle, findsOneWidget);
    expect(find.byType(TripPlanScreen), findsOneWidget);
    await _drain(t);
  });

  testWidgets('continue_open_never_shows_the_guide', (t) async {
    final c = await _app(t);
    await _toPlan(t, {'tripId': 't1'});
    expect(c.plan.value, isNotNull);
    expect(find.text("Let's get you there"), findsNothing);
    expect(find.text('Help me find'), findsNothing);
    await _drain(t);
  });

  testWidgets('unsaved_day_split_back_pops_without_question', (t) async {
    installFakeApi([
      FakeRoute('POST', '/trips/plan', (o) {
        final body = o.data as Map;
        final ids = [for (final s in body['spots'] as List) (s as Map)['id'] as String];
        return {
          'days': [
            {'day': 1, 'spotIds': ids, 'visitMinutes': 120, 'totalMinutes': 150},
          ],
          'osrmAvailable': true,
          'dayLimitMinutes': 300,
        };
      }),
    ]);
    final c = await _app(t, saved: false);
    await t.runAsync(() => c.startFromSelection(_nainital, [_spot('a'), _spot('b')]));
    await _toPlan(t, {'fresh': true});
    expect(c.isNewUnsaved, isTrue);
    await _systemBack(t);
    expect(_exitTitle, findsNothing);
    expect(find.text('main'), findsOneWidget);
    await _drain(t);
  });

  testWidgets('save_and_continue_leaves_only_main_and_overview', (t) async {
    _stack.names.clear();
    await _app(t);
    await _toPlan(t, {'fresh': true});
    TripNavigation.enterOverview('t1');
    await _settle(t);
    expect(_stack.names, [AppRoutes.main, AppRoutes.tripOverview]);
    expect(find.text(TripStringsOverview.title), findsOneWidget);
    expect(Get.isRegistered<TripPlanController>(), isTrue);

    Get.toNamed(AppRoutes.tripPlan, arguments: {'tripId': 't1'});
    await _settle(t);
    expect(_stack.names, [AppRoutes.main, AppRoutes.tripOverview, AppRoutes.tripPlan]);
    await _drain(t);
  });

  testWidgets('exit_dialog_five_sizes', (t) async {
    for (final size in fiveSizes) {
      await t.pumpWidget(const SizedBox.shrink());
      Get.reset();
      await _app(t, size: size);
      await _toOverview(t);
      await _systemBack(t);
      expect(t.takeException(), isNull, reason: sizeLabel(size));
      expect(_exitTitle, findsOneWidget, reason: sizeLabel(size));
      for (final k in [TripExitConfirm.exitKey, TripExitConfirm.stayKey]) {
        final r = t.getRect(find.byKey(k));
        expect(r.left, greaterThanOrEqualTo(0), reason: sizeLabel(size));
        expect(r.right, lessThanOrEqualTo(size.width), reason: sizeLabel(size));
        expect(r.bottom, lessThanOrEqualTo(size.height), reason: sizeLabel(size));
      }
      final title = t.getRect(_exitTitle);
      expect(title.top, greaterThanOrEqualTo(0), reason: sizeLabel(size));
      expect(title.bottom, lessThan(t.getRect(find.byKey(TripExitConfirm.exitKey)).top), reason: sizeLabel(size));
    }
    await _drain(t);
  });
}
