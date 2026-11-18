import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/config/notification_types.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_taxi_request_controller.dart';
import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/trip_overview_screen.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/screens/trip_taxi_request_screen.dart';
import 'package:bakhli/features/trip/screens/trip_taxi_request_status_screen.dart';
import 'package:bakhli/features/trip/trip_navigation.dart';
import 'package:bakhli/features/trip/trip_routes.dart';
import 'package:bakhli/features/trip/trip_strings_dayplan.dart';
import 'package:bakhli/features/trip/trip_strings_v2_easy.dart';
import 'package:bakhli/features/trip/trip_strings_v2_find.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_view.dart';
import 'package:bakhli/features/trip/widgets/trip_easy_card.dart';
import 'package:bakhli/features/trip/widgets/trip_easy_row.dart';
import 'package:bakhli/features/trip/widgets/trip_plan_header.dart';
import 'package:bakhli/services/trip_push_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../journeys/fake_api.dart';
import '../../support/real_phone.dart';
import '../trip/support/engine_rig.dart';
import 'taxi_request_controller_fakes.dart';

const _requestId = '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

TripPlan _plan({bool dates = true}) {
  final p = enginePlan(const [[2, 2, 2]]);
  return TripPlan(
    legs: p.legs,
    days: p.days,
    settings: dates ? TripSettings(startDate: DateTime(2030, 11, 1), adults: 2) : const TripSettings(),
    steps: const TripSteps(startFrom: TripStartFrom(name: 'Kathgodam', lat: 29.26, lon: 79.52)),
  );
}

Map<String, dynamic> _lockJson(String state, String view) => {
      'planLock': {'locked': true, 'reason': 'TaxiRequestActive', 'requestId': _requestId},
      'taxiRequest': {'requestId': _requestId, 'state': state, 'view': view, 'version': 2},
    };

TripTaxiRequestRef _ref(String state, String view) =>
    TripTaxiRequestRef(requestId: _requestId, state: state, view: view, version: 2);

class _OfflineTripLookup extends FakeTaxiRepo {
  @override
  Future<TaxiResult<TaxiRequest?>> forTrip(String tripId) async => const TaxiOffline<TaxiRequest?>();
}

class _Rig {
  _Rig(this.plan, this.repo, this.api);

  final TripPlanController plan;
  final FakeTaxiRepo repo;
  final FakeTripAdapter api;
}

final _newPages = {AppRoutes.tripOverview, AppRoutes.tripTaxiRequest, AppRoutes.tripTaxiStatus};

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<_Rig> _pump(
  WidgetTester t, {
  bool dates = true,
  TripTaxiRequestRef? taxiRequest,
  TripPlanLock lock = TripPlanLock.none,
  List<GetPage> extra = const [],
}) async {
  final plan = _plan(dates: dates);
  final api = installFakeApi([
    FakeRoute.value('PUT', '/trips/{id}', engineTripJson(plan)),
    FakeRoute.value('GET', '/trips/{id}', engineTripJson(plan, extra: _lockJson('Open', 'Finding'))),
  ]);
  final finding = sampleRequest('taxi_request_finding.json', change: {'tripId': 't1'});
  final repo = FakeTaxiRepo()
    ..createAnswers.add(TaxiOk(finding))
    ..getAnswer = ((_) => TaxiOk(finding));
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  c.plan.value = plan;
  c.trip.value = engineTrip(plan, lock: lock).copyWith(taxiRequest: taxiRequest);
  Get.put<TripPlanController>(c, permanent: true);
  Get.put<TripTaxiRequestController>(TripTaxiRequestController(
    repo: repo,
    enquiries: FakeEnquiries(),
    realtime: null,
    newClientId: () => 'client-1',
  ));
  await loadRealFonts();
  final view = t.view;
  view.devicePixelRatio = 3;
  view.physicalSize = const Size(360 * 3, 800 * 3);
  view.padding = const FakeViewPadding(top: phoneTopInset * 3, bottom: phoneBottomInset * 3);
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
    scrollBehavior: const AppScrollBehavior(),
    initialRoute: AppRoutes.tripPlan,
    getPages: [
      GetPage(name: AppRoutes.tripPlan, page: () => const TripPlanScreen()),
      ...tripPages.where((p) => _newPages.contains(p.name)),
      ...extra,
    ],
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
  ));
  await _settle(t);
  c.planStep.value = 1;
  c.guideState.on.value = false;
  await _settle(t);
  return _Rig(c, repo, api);
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _settle(t);
}

Future<void> _drain(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(minutes: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  testWidgets('save_trip_saves_then_opens_overview', (t) async {
    final rig = await _pump(t);
    await _tap(t, find.byKey(TripPlanScreen.saveTripKey));
    expect(rig.api.calls('PUT', '/trips/t1'), hasLength(1));
    expect(find.byType(TripOverviewScreen), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.tripOverview);
    expect((Get.arguments as Map)['tripId'], 't1');
    await _drain(t);
  });

  testWidgets('taxi_card_opens_request_page_without_a_request', (t) async {
    await _pump(t);
    await _tap(t, find.byKey(TripPlanScreen.saveTripKey));
    await _tap(t, find.byKey(const ValueKey('overview_taxi_button')));
    expect(find.byType(TripTaxiRequestScreen), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.tripTaxiRequest);
    await _drain(t);
  });

  testWidgets('taxi_card_opens_status_when_a_request_exists', (t) async {
    await _pump(t, taxiRequest: _ref('Collecting', 'Collecting'), lock: lockedByRequest);
    TripNavigation.openOverview(tripId: 't1');
    await _settle(t);
    expect(find.text(TripOverviewTaxi.of(_ref('Collecting', 'Collecting')).button), findsOneWidget);
    await _tap(t, find.byKey(const ValueKey('overview_taxi_button')));
    expect(find.byType(TripTaxiRequestStatusScreen), findsOneWidget);
    expect((Get.arguments as Map)['requestId'], _requestId);
    await _drain(t);
  });

  testWidgets('no_dates_opens_the_dates_sheet_first', (t) async {
    await _pump(t, dates: false);
    await _tap(t, find.byKey(TripPlanScreen.saveTripKey));
    await _tap(t, find.byKey(const ValueKey('overview_taxi_button')));
    expect(find.text(TripStringsV2Find.datesTitle), findsOneWidget);
    expect(find.byType(TripTaxiRequestScreen), findsNothing);
    await _drain(t);
  });

  testWidgets('help_me_find_on_the_taxi_row_goes_to_the_new_flow', (t) async {
    await _pump(t);
    final ctx = t.element(find.byType(TripPlanScreen));
    TripNavigation.helpMeFind(ctx, const TripEasyRowKey(TripEasyRowKind.taxi));
    await _settle(t);
    expect(find.byType(TripTaxiRequestScreen), findsOneWidget);
    await _drain(t);
  });

  testWidgets('replies_of_the_taxi_row_open_status_when_a_request_exists', (t) async {
    await _pump(t, taxiRequest: _ref('Booked', 'Booked'), lock: lockedByRequest);
    TripNavigation.openRepliesForRow(const TripEasyRowKey(TripEasyRowKind.taxi));
    await _settle(t);
    expect(find.byType(TripTaxiRequestStatusScreen), findsOneWidget);
    await _drain(t);
  });

  testWidgets('send_opens_status_and_plan_shows_locked_banner', (t) async {
    final rig = await _pump(t);
    await _tap(t, find.byKey(TripPlanScreen.saveTripKey));
    await _tap(t, find.byKey(const ValueKey('overview_taxi_button')));
    await _tap(t, find.byKey(const ValueKey('taxi_pickup_6377270')));
    await _tap(t, find.byKey(const ValueKey('taxi_request_send')));
    expect(rig.repo.createBodies, hasLength(1));
    expect(rig.repo.createBodies.single['clientRequestId'], 'client-1');
    expect(find.byType(TripTaxiRequestStatusScreen), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.tripTaxiStatus);
    expect(rig.api.calls('GET', '/trips/t1'), isNotEmpty);
    expect(rig.plan.isPlanLocked, isTrue);
    expect(rig.plan.trip.value?.taxiRequest?.requestId, _requestId);

    await _tap(t, find.byKey(const ValueKey('status_done')));
    expect(Get.currentRoute, AppRoutes.tripPlan);
    expect(find.byKey(TripPlanScreen.lockedBannerKey), findsOneWidget);
    expect(find.text(TripStringsDayplan.lockedByRequest), findsOneWidget);
    expect(find.byKey(TripPlanScreen.viewButtonKey), findsOneWidget);
    expect(find.byKey(TripPlanScreen.saveTripKey), findsNothing);
    await _drain(t);
  });

  for (final type in NotificationTypeKeys.travellerTaxi) {
    testWidgets('traveller_push_${type}_triggers_a_get', (t) async {
      final rig = await _pump(t, taxiRequest: _ref('Open', 'Finding'), lock: lockedByRequest);
      TripTaxiRequestController.to.apply(sampleRequest('taxi_request_finding.json', change: {'tripId': 't1'}));
      await _settle(t);
      final gets = rig.repo.getIds.length;
      final tripGets = rig.api.calls('GET', '/trips/t1').length;
      TripPushSync.onPush(type, null);
      await t.pump(const Duration(milliseconds: 700));
      await _settle(t);
      expect(rig.repo.getIds.length, gets + 1);
      expect(rig.repo.getIds.last, _requestId);
      expect(rig.api.calls('GET', '/trips/t1').length, tripGets + 1);
      await _drain(t);
    });
  }

  testWidgets('driver_push_types_do_not_get_the_traveller_request', (t) async {
    final rig = await _pump(t, taxiRequest: _ref('Open', 'Finding'), lock: lockedByRequest);
    TripTaxiRequestController.to.apply(sampleRequest('taxi_request_finding.json', change: {'tripId': 't1'}));
    await _settle(t);
    final gets = rig.repo.getIds.length;
    for (final type in ['TaxiSelected', 'taxi_not_selected', 'taxi_request_closed', 'taxi_rings_missed']) {
      TripPushSync.onPush(type, null);
    }
    await t.pump(const Duration(milliseconds: 700));
    await _settle(t);
    expect(rig.repo.getIds.length, gets);
    await _drain(t);
  });

  testWidgets('tapping_the_status_push_refreshes_the_request', (t) async {
    final rig = await _pump(t, taxiRequest: _ref('Open', 'Finding'), lock: lockedByRequest);
    TripTaxiRequestController.to.apply(sampleRequest('taxi_request_finding.json', change: {'tripId': 't1'}));
    final gets = rig.repo.getIds.length;
    TripPushSync.refreshNow(AppRoutes.tripTaxiStatus);
    await _settle(t);
    expect(rig.repo.getIds.length, gets + 1);
    await _drain(t);
  });

  testWidgets('make_it_easy_is_reachable_from_the_top_card', (t) async {
    var stayOpened = 0;
    final rig = await _pump(t, extra: [
      GetPage(name: AppRoutes.tripStay, page: () {
        stayOpened++;
        return const Scaffold(body: Text('stay'));
      }),
    ]);
    await _tap(t, find.byType(TripPlanStepCard));
    expect(rig.plan.planStep.value, 2);
    final shown = find.byType(TripGuideView).evaluate().isNotEmpty || find.byType(TripEasyCard).evaluate().isNotEmpty;
    expect(shown, isTrue);
    expect([for (final r in rig.plan.easyRows) r.key.id], ['gettingThere', 'stay:1', 'taxi', 'comingBack']);
    final ctx = t.element(find.byType(TripPlanScreen));
    TripNavigation.helpMeFind(ctx, const TripEasyRowKey(TripEasyRowKind.stay, 1));
    await _settle(t);
    expect(stayOpened, 1);
    await _drain(t);
  });

  testWidgets('status_without_request_id_finds_the_trip_request', (t) async {
    await _pump(t);
    Get.toNamed(AppRoutes.tripTaxiStatus, arguments: {'tripId': 't1'});
    await _settle(t);
    expect(find.byType(TripTaxiRequestStatusScreen), findsOneWidget);
    await _drain(t);
  });

  testWidgets('status_without_any_request_opens_the_request_page', (t) async {
    final rig = await _pump(t);
    rig.repo.getAnswer = (_) => const TaxiNotFound();
    Get.toNamed(AppRoutes.tripTaxiStatus, arguments: {'tripId': 't1'});
    await _settle(t);
    expect(find.byType(TripTaxiRequestStatusScreen), findsNothing);
    expect(find.byType(TripTaxiRequestScreen), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.tripTaxiRequest);
    await _drain(t);
  });

  testWidgets('status_lookup_failure_goes_back_to_the_plan', (t) async {
    await _pump(t);
    Get.delete<TripTaxiRequestController>(force: true);
    Get.put<TripTaxiRequestController>(TripTaxiRequestController(
      repo: _OfflineTripLookup(),
      enquiries: FakeEnquiries(),
      realtime: null,
      newClientId: () => 'client-1',
    ));
    Get.toNamed(AppRoutes.tripTaxiStatus, arguments: {'tripId': 't1'});
    await _settle(t);
    expect(find.byType(TripTaxiRequestStatusScreen), findsNothing);
    expect(Get.currentRoute, AppRoutes.tripPlan);
    await _drain(t);
  });

  testWidgets('selected_request_pill_reads_waiting_not_booked', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: TripEasyStatePill(TripRowState.asked, text: TripStringsDayplan.pillWaiting))));
    expect(find.text(TripStringsDayplan.pillWaiting), findsOneWidget);
    expect(find.text(TripStringsV2Easy.pillBooked), findsNothing);
  });

  testWidgets('traveller_pages_are_registered_and_can_open', (t) async {
    final auth = AuthController();
    for (final route in _newPages) {
      expect(AppRoutes.isRegistered(route), isTrue, reason: route);
      expect(auth.canOpenRoute(route), isTrue, reason: route);
      expect(tripPages.where((p) => p.name == route), hasLength(1), reason: route);
    }
  });
}
