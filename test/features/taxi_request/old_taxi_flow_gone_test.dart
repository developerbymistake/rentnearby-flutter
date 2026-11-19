import 'dart:convert';
import 'dart:io';

import 'package:bakhli/config/app_map_state.dart';
import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_journey_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_navigation.dart';
import 'package:bakhli/features/trip/trip_routes.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:bakhli/features/trip/widgets/trip_problem_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_taxi_booking_sheet.dart';
import 'package:bakhli/services/map_pause_observer.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:bakhli/widgets/global_location_gates.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../journeys/fake_api.dart';
import '../../support/real_phone.dart';
import '../trip/support/engine_rig.dart';

const _removedFiles = [
  'lib/features/trip/screens/trip_taxi_screen.dart',
  'lib/features/trip/screens/trip_taxi_replies_screen.dart',
  'lib/features/trip/widgets/trip_driver_row.dart',
  'lib/features/trip/widgets/trip_driver_reply_sheet.dart',
];

const _oldRoutes = ['/trip-taxi', '/trip-taxi-replies'];

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

// A running trip (day 1 is today) with dates and people, saved as t1, and no taxi request.
TripPlanController _todayTrip() {
  final base = enginePlan(const [[2, 2]], start: TripClock.today());
  final plan = TripPlan(legs: base.legs, days: base.days, settings: TripSettings(startDate: TripClock.today(), adults: 2));
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  c.plan.value = plan;
  c.trip.value = engineTrip(plan);
  return Get.put<TripPlanController>(c, permanent: true);
}

Future<List<Object?>> _pumpWithRequestPage(WidgetTester t, Widget home) async {
  final opened = <Object?>[];
  await loadRealFonts();
  await t.pumpWidget(GetMaterialApp(
    initialRoute: '/',
    getPages: [
      GetPage(name: '/', page: () => home),
      GetPage(
        name: AppRoutes.tripTaxiRequest,
        page: () {
          opened.add(Get.arguments);
          return const Scaffold(body: Text('request'));
        },
      ),
    ],
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
  ));
  await t.pump();
  return opened;
}

Future<void> _drainToasts(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 5));
}

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
  });

  test('removed_routes_are_not_registered', () {
    expect(AppRoutes.retiredTripTaxiRoutes, _oldRoutes.toSet());
    final tripNames = {for (final p in tripPages) p.name};
    for (final r in _oldRoutes) {
      expect(AppRoutes.isRegistered(r), isFalse, reason: r);
      expect(tripNames.contains(r), isFalse, reason: r);
      expect(GlobalLocationGates.locationExempt(r), isFalse, reason: r);
      mapShouldPause.value = false;
      final route = MaterialPageRoute<void>(settings: RouteSettings(name: r), builder: (_) => const SizedBox());
      MapPauseObserver().didPush(route, null);
      expect(mapShouldPause.value, isFalse, reason: r);
    }
    mapShouldPause.value = false;
  });

  test('no_lib_file_imports_a_removed_file', () {
    for (final f in _removedFiles) {
      expect(File(f).existsSync(), isFalse, reason: f);
    }
    final names = [for (final f in _removedFiles) f.split('/').last];
    final offenders = <String>[];
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final src = e.readAsStringSync();
      for (final n in names) {
        if (RegExp("import\\s+'[^']*${RegExp.escape(n)}'").hasMatch(src)) offenders.add('${e.path} -> $n');
      }
      for (final symbol in ['TripTaxiScreen', 'TripTaxiRepliesScreen', 'TripDriverRow', 'TripDriverReplySheet', 'openTaxiReplies']) {
        if (RegExp('\\b$symbol\\b').hasMatch(src)) offenders.add('${e.path} uses $symbol');
      }
    }
    expect(offenders, isEmpty);
    final enquirySheet = File('lib/features/trip/screens/trip_taxi_enquiry_sheet.dart').readAsStringSync();
    expect(enquirySheet.contains('Widget'), isFalse, reason: 'only the pickup defaults stay');
  });

  group('old_taxi_route_in_a_push_opens_the_plan', () {
    test('push data with an old route is rewritten to the plan of the same trip', () {
      for (final r in _oldRoutes) {
        final data = NotificationService.liveRouteData({
          'notification_type': 'TripTaxiFareSent',
          'action_route': r,
          'action_args_json': jsonEncode({'tripId': 't1', 'day': 2, 'enquiryId': 'e1'}),
        });
        expect(data['action_route'], AppRoutes.tripPlan, reason: r);
        expect(jsonDecode(data['action_args_json'] as String), {'tripId': 't1'}, reason: r);
        expect(data['notification_type'], 'TripTaxiFareSent');
      }
      final other = {'action_route': AppRoutes.tripReplies, 'action_args_json': '{"day":1}'};
      expect(identical(NotificationService.liveRouteData(other), other), isTrue);
      expect(AppRoutes.liveTarget('/trip-taxi')!.args, isEmpty);
    });

    testWidgets('a tap on an old taxi push lands on the trip plan', (t) async {
      Get.testMode = true;
      addTearDown(Get.reset);
      Object? opened;
      await t.pumpWidget(GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const Text('home')),
          GetPage(
            name: AppRoutes.tripPlan,
            page: () {
              opened = Get.arguments;
              return const Text('plan');
            },
          ),
        ],
      ));
      NotificationService().openActionRoute('/trip-taxi-replies', {'tripId': 't9', 'day': 3, 'enquiryId': 'e9'});
      await t.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.tripPlan);
      expect(find.text('plan'), findsOneWidget);
      expect(opened, {'tripId': 't9', 'fresh': true});
    });
  });

  testWidgets('journey_car_booking_sheet_still_opens', (t) async {
    Get.testMode = true;
    installFakeApi([]);
    addTearDown(Get.reset);
    Get.put<TabConfigController>(_Tabs());
    Get.put(TripPlanController()).plan.value = journeyPlan([3]);
    await pumpPhone(
      t,
      Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => TripTaxiBookingSheet.showForJourneyCar(
                c,
                role: TripStepRole.gettingThere,
                journeyId: 'j1',
                carIndex: 1,
                car: const TripJourneyLeg(legIndex: 1, fromName: 'Haldwani', toName: 'Nainital', taxiId: 'x1', driverName: 'Ramesh Kumar', listedFare: 2500),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pump();
    await settlePhone(t);
    expect(find.text(TripStrings.iBookedTitle), findsOneWidget);
    expect(find.text(TripStrings.saveBooking), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  group('old_taxi_entry_points_open_the_request_page', () {
    setUp(() => Get.testMode = true);
    tearDown(Get.reset);

    testWidgets('taxi row with no request opens the request page', (t) async {
      installFakeApi([]);
      _todayTrip();
      final opened = await _pumpWithRequestPage(t, const Scaffold(body: Text('plan')));
      TripNavigation.openRepliesForRow(const TripEasyRowKey(TripEasyRowKind.taxi));
      await t.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.tripTaxiRequest);
      expect(opened, [
        {'tripId': 't1', 'keepChoices': true}
      ]);
      await _drainToasts(t);
    });

    testWidgets('driver did not come today opens the request page', (t) async {
      final api = installFakeApi([
        FakeRoute.value('POST', '/trips/{id}/problems', {'problemId': 'p1'}),
      ]);
      final c = _todayTrip();
      expect(c.todayDay, 1);
      final opened = await _pumpWithRequestPage(
        t,
        Scaffold(
          body: Builder(
            builder: (ctx) => Center(child: TextButton(onPressed: () => TripProblemSheet.show(ctx, day: 1), child: const Text('go'))),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      await t.tap(find.text(TripStrings.driverDidNotCome));
      await t.pumpAndSettle();
      final sent = api.calls('POST', '/trips/t1/problems');
      expect(sent, hasLength(1));
      expect((sent.single.data as Map)['kind'], TripProblemKinds.driverNoShow);
      expect(Get.currentRoute, AppRoutes.tripTaxiRequest);
      expect(opened, [
        {'tripId': 't1', 'keepChoices': true}
      ]);
      await _drainToasts(t);
    });
  });
}
