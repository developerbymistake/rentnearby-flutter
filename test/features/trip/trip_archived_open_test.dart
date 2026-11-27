import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/data/trip_today_cache.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/screens/trip_map_screen.dart';
import 'package:bakhli/features/trip/trip_routes.dart';
import 'package:bakhli/features/trip/trip_strings_archived.dart';
import 'package:bakhli/features/trip/trip_strings_overview.dart';
import 'package:bakhli/features/trip/widgets/trip_archived_view.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../journeys/fake_api.dart';
import 'support/archived_fixtures.dart';
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
  bool get canUseTravellerFeatures => true;

  @override
  void switchToTab(int index) => tabs.add(index);

  @override
  void openPlace(AppPlace place, {bool detail = false}) => tabs.add(place == AppPlace.trips ? AppTabs.trips : -1);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _id = 'arc-1';

late _Auth _auth;

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _app(WidgetTester t, {required Widget home}) async {
  Get.put<TabConfigController>(_Tabs());
  _auth = Get.put<AuthController>(_Auth()) as _Auth;
  await t.pumpWidget(GetMaterialApp(
    home: home,
    getPages: [
      ...tripPages.where((p) => p.name == AppRoutes.tripPlan || p.name == AppRoutes.tripReplies || p.name == AppRoutes.tripArchived),
      GetPage(name: AppRoutes.tripOverview, page: () => const Scaffold(body: Text('overview stub'))),
    ],
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
  ));
  await _settle(t);
}

Future<void> _drain(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(minutes: 2));
}

void _seedLeftovers() {
  final p = enginePlan([[2, 2]]);
  StorageService.saveTripCache(_id, engineTripJson(p, extra: {'id': _id}));
  StorageService.saveTripPending(_id, plan: p.toJson(), baseUpdatedAt: DateTime.utc(2026, 8, 20));
  StorageService.saveTripResultCache(_id, {'days': <Object>[]});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('archived_open_gs').path);
    await GetStorage.init();
  });
  setUp(() => StorageService.clearTripCache(_id));
  tearDown(Get.reset);

  testWidgets('the overview of an archived trip shows the summary, never the plan, and never recalculates or saves', (t) async {
    _seedLeftovers();
    final api = installFakeApi([FakeRoute.value('GET', '/trips/{id}', archivedTripJson())]);
    await _app(t, home: const TripOverviewRoute(tripId: _id));
    expect(find.byType(TripArchivedView), findsOneWidget);
    expect(find.text(TripStringsArchived.note), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_city_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_city_1')), findsOneWidget);
    expect(find.text(TripStringsOverview.title), findsNothing);
    expect(api.calls('POST', '/trips/plan'), isEmpty);
    expect(api.calls('PUT', '/trips/$_id'), isEmpty);
    final c = TripPlanController.to;
    expect(c.isArchived, isTrue);
    expect(c.isReadOnly, isTrue);
    expect(c.plan.value, isNull);
    expect(c.result.value, isNull);
    expect(await c.saveNow(), isFalse);
    expect(api.calls('PUT', '/trips/$_id'), isEmpty);
    await _drain(t);
  });

  testWidgets('opening an archived trip drops the old plan copy, the pending edit and the result, and keeps a small archived copy', (t) async {
    _seedLeftovers();
    installFakeApi([FakeRoute.value('GET', '/trips/{id}', archivedTripJson())]);
    await _app(t, home: const TripArchivedRoute(tripId: _id));
    expect(StorageService.getTripPending(_id), isNull);
    expect(StorageService.getTripResultCache(_id), isNull);
    final cached = TripTodayCache.trip(_id);
    expect(cached, isNotNull);
    expect(cached!.archived, isTrue);
    expect(cached.archive!.cities, hasLength(2));
    expect(cached.plan.days, isEmpty);
    await _drain(t);
  });

  testWidgets('savePlan never writes a plan into an archived copy', (t) async {
    final archived = TripModel.fromJson(archivedTripJson());
    StorageService.saveTripCache(_id, archivedTripJson());
    TripTodayCache.savePlan(archived, enginePlan([[2, 2]]));
    expect(TripTodayCache.trip(_id)!.plan.days, isEmpty);
  });

  testWidgets('the archived route shows the summary', (t) async {
    installFakeApi([FakeRoute.value('GET', '/trips/{id}', archivedTripJson())]);
    await _app(t, home: const TripArchivedRoute(tripId: _id));
    expect(find.byType(TripArchivedView), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_taxi')), findsOneWidget);
    await _drain(t);
  });

  testWidgets('a trip that is not archived (stale list) goes from the archived route to the overview', (t) async {
    final p = enginePlan([[2, 2]]);
    installFakeApi([FakeRoute.value('GET', '/trips/{id}', engineTripJson(p, extra: {'id': _id}))]);
    await _app(t, home: const Scaffold(body: Text('home')));
    Get.toNamed(AppRoutes.tripArchived, arguments: {'tripId': _id});
    await _settle(t);
    expect(find.byType(TripArchivedView), findsNothing);
    expect(find.text('overview stub'), findsOneWidget);
    await _drain(t);
  });

  testWidgets('offline with an archived copy on the phone still shows the summary', (t) async {
    StorageService.saveTripCache(_id, archivedTripJson());
    installFakeApi([
      FakeRoute('GET', '/trips/{id}', (o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError)),
    ]);
    await _app(t, home: const TripArchivedRoute(tripId: _id));
    expect(find.byType(TripArchivedView), findsOneWidget);
    expect(TripPlanController.to.offline.value, isTrue);
    await _drain(t);
  });

  testWidgets('the plan page of an archived trip shows the summary and no exit question', (t) async {
    installFakeApi([FakeRoute.value('GET', '/trips/{id}', archivedTripJson())]);
    await _app(t, home: const Scaffold(body: Text('home')));
    Get.toNamed(AppRoutes.tripPlan, arguments: {'tripId': _id});
    await _settle(t);
    expect(find.byType(TripArchivedView), findsOneWidget);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text(TripStringsOverview.exitTitle), findsNothing);
    expect(find.text('home'), findsOneWidget);
    await _drain(t);
  });

  testWidgets('the replies page of an archived trip shows the summary', (t) async {
    installFakeApi([FakeRoute.value('GET', '/trips/{id}', archivedTripJson())]);
    await _app(t, home: const Scaffold(body: Text('home')));
    Get.toNamed(AppRoutes.tripReplies, arguments: {'tripId': _id, 'day': 1});
    await _settle(t);
    expect(find.byType(TripArchivedView), findsOneWidget);
    await _drain(t);
  });

  testWidgets('the map page of an archived trip shows the summary, not an endless loader', (t) async {
    installFakeApi([FakeRoute.value('GET', '/trips/{id}', archivedTripJson())]);
    await _app(t, home: const Scaffold(body: Text('home')));
    Get.to(() => const TripMapScreen(), arguments: {'tripId': _id});
    await _settle(t);
    expect(find.byType(TripArchivedView), findsOneWidget);
    await _drain(t);
  });

  testWidgets('overview back on an archived trip goes to the Trips tab without the exit question', (t) async {
    installFakeApi([FakeRoute.value('GET', '/trips/{id}', archivedTripJson())]);
    await _app(t, home: const TripOverviewRoute(tripId: _id));
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text(TripStringsOverview.exitTitle), findsNothing);
    expect(_auth.tabs, contains(AppTabs.trips));
    await _drain(t);
  });

  testWidgets('a save refused with TripArchived reopens the trip as archived', (t) async {
    final p = enginePlan([[2, 2]]);
    var archived = false;
    installFakeApi([
      FakeRoute('GET', '/trips/{id}', (_) => archived ? archivedTripJson() : engineTripJson(p, extra: {'id': _id})),
      FakeRoute('PUT', '/trips/{id}', (_) {
        archived = true;
        return null;
      }, code: 409, errorType: 'TripArchived'),
    ]);
    await _app(t, home: const Scaffold(body: Text('home')));
    final c = TripPlanController.to;
    c.openPages++;
    await t.runAsync(() => c.open(_id));
    await _settle(t);
    expect(c.isArchived, isFalse);
    c.plan.value = c.plan.value!.copyWith(days: c.plan.value!.days.take(1).toList());
    expect(await t.runAsync(c.saveNow), isFalse);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await _settle(t);
    expect(c.isArchived, isTrue);
    expect(c.plan.value, isNull);
    expect(StorageService.getTripPending(_id), isNull);
    c.openPages--;
    await _drain(t);
  });
}
