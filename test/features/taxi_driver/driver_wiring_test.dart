import 'dart:convert';
import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/config/notification_types.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/taxi/leads/trip_leads_controller.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi/taxi_option_sets.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_bookings_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_rating_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_ready_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_requests_controller.dart';
import 'package:bakhli/features/taxi/requests/driver_bookings_screen.dart';
import 'package:bakhli/features/taxi/requests/driver_rating_screen.dart';
import 'package:bakhli/features/taxi/requests/driver_ready_screen.dart';
import 'package:bakhli/features/taxi/requests/driver_request_detail_screen.dart';
import 'package:bakhli/features/taxi/requests/driver_requests_screen.dart';
import 'package:bakhli/features/taxi/requests/driver_ring_screen.dart';
import 'package:bakhli/features/taxi/requests/strings/driver_ready_strings.dart';
import 'package:bakhli/features/taxi/requests/widgets/driver_ready_strip.dart';
import 'package:bakhli/features/taxi/setup/my_taxi_screen.dart';
import 'package:bakhli/features/taxi/setup/taxi_owner_card.dart';
import 'package:bakhli/features/taxi/setup/taxi_setup_controller.dart';
import 'package:bakhli/features/taxi/taxi_routes.dart';
import 'package:bakhli/models/notification_model.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:bakhli/services/trip_push_sync.dart';
import 'package:bakhli/widgets/notification_off_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/five_sizes.dart';
import 'driver_wiring_fakes.dart';

const _driverRoutes = [
  AppRoutes.taxiRequestRing,
  AppRoutes.taxiRequests,
  AppRoutes.taxiRequestDetail,
  AppRoutes.taxiBookings,
  AppRoutes.taxiRating,
  AppRoutes.taxiReady,
];

const _driverTypes = [
  'taxi_request_ring',
  'taxi_request_ring_ended',
  'TaxiSelected',
  'taxi_selected',
  'TaxiNotSelected',
  'taxi_not_selected',
  'TaxiRequestClosed',
  'taxi_request_closed',
  'TaxiBookingCancelled',
  'taxi_booking_cancelled',
  'TaxiRingsMissed',
  'taxi_rings_missed',
  'TaxiTripEnded',
  'taxi_trip_ended',
];

Map<String, dynamic> _sample(String name) =>
    jsonDecode(File('test/features/taxi_request/samples/$name').readAsStringSync()) as Map<String, dynamic>;

Widget _built(String route, {Object? args}) {
  Get.routing.args = args;
  final page = driverRequestPages.singleWhere((p) => p.name == route);
  return page.page();
}

Future<void> _pumpApp(WidgetTester t, {String initial = '/'}) async {
  await t.pumpWidget(GetMaterialApp(
    theme: AppTheme.theme,
    initialRoute: initial,
    getPages: [
      GetPage(name: '/', page: () => const Scaffold(body: Text('HOME'))),
      ...driverRequestPages,
    ],
  ));
  await t.pump();
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

class _Svc extends NotificationService {}

void main() {
  tearDown(Get.reset);

  group('routes', () {
    test('six_driver_pages_registered_and_driver_only', () {
      expect({for (final p in driverRequestPages) p.name}, _driverRoutes.toSet());
      for (final route in _driverRoutes) {
        expect(AppRoutes.isRegistered(route), isTrue, reason: route);
        expect(AppRoutes.routes.where((p) => p.name == route), hasLength(1), reason: route);
        expect(AppRoutes.taxiDriverOnly.contains(route), isTrue, reason: route);
        expect(AppRoutes.tabKeyForRoute(route), AppTabKeys.taxi, reason: route);
      }
    });

    test('seeker_cannot_open_any_of_the_six_driver_routes', () {
      wireBase(driver: false);
      final seeker = Get.find<AuthController>();
      for (final route in _driverRoutes) {
        expect(seeker.canOpenRoute(route), isFalse, reason: route);
      }
      wireBase();
      final driver = Get.find<AuthController>();
      for (final route in _driverRoutes) {
        expect(driver.canOpenRoute(route), isTrue, reason: route);
      }
    });

    test('pages build the driver screens from their arguments', () {
      wireBase();
      expect(_built(AppRoutes.taxiRequests), isA<DriverRequestsScreen>());
      expect(_built(AppRoutes.taxiBookings), isA<DriverBookingsScreen>());
      expect(_built(AppRoutes.taxiRating), isA<DriverRatingScreen>());
      expect(_built(AppRoutes.taxiReady), isA<DriverReadyScreen>());
      final ring = _built(AppRoutes.taxiRequestRing, args: {'offerId': 'o9', 'action': 'accept'});
      expect(ring, isA<DriverRingScreen>());
      expect((ring as DriverRingScreen).offerId, 'o9');
      expect(ring.action, DriverRingAction.accept);
      final detail = _built(AppRoutes.taxiRequestDetail, args: {'offerId': 'o9'});
      expect((detail as DriverRequestDetailScreen).offerId, 'o9');
      expect(detail.onOpenBookings, isNotNull);
      expect(_built(AppRoutes.taxiRequestDetail, args: const {}), isA<DriverRequestsScreen>());
      expect(_built(AppRoutes.taxiRequestRing, args: null), isA<DriverRequestsScreen>());
      expect((_built(AppRoutes.taxiRequests) as DriverRequestsScreen).onOpenOffer, isNotNull);
    });

    test('route screen does not use the new request code', () {
      final src = File('lib/features/taxi/setup/taxi_routes_screen.dart').readAsStringSync();
      expect(src.contains('requests/'), isFalse);
      expect(src.contains('Driver'), isFalse);
    });
  });

  group('push', () {
    test('driver type keys cover the contract', () {
      expect(NotificationTypeKeys.driverTaxi, _driverTypes.toSet());
      expect(NotificationTypeKeys.isRingsMissed('taxi_rings_missed'), isTrue);
      expect(NotificationTypeKeys.isRingsMissed('TaxiRingsMissed'), isTrue);
      expect(NotificationTypeKeys.isRingsMissed('taxi_selected'), isFalse);
    });

    for (final type in _driverTypes) {
      testWidgets('driver_push_${type}_refreshes', (t) async {
        wireBase();
        final requests = Get.put<DriverRequestsController>(WireRequests()) as WireRequests;
        final bookings = Get.put<DriverBookingsController>(WireBookings()) as WireBookings;
        final rating = Get.put<DriverRatingController>(WireRating()) as WireRating;
        final ready = Get.put<DriverReadyController>(WireReady()) as WireReady;
        await t.pump();
        final readyBefore = ready.readinessLoads;
        TripPushSync.onPush(type, null);
        await t.pump(const Duration(milliseconds: 700));
        expect(requests.pushes, 1, reason: type);
        expect(bookings.reloads, 1, reason: type);
        final ended = type == 'TaxiTripEnded' || type == 'taxi_trip_ended';
        expect(rating.loads, ended ? 1 : 0, reason: type);
        final missed = type == 'TaxiRingsMissed' || type == 'taxi_rings_missed';
        expect(ready.readinessLoads - readyBefore, missed ? 1 : 0, reason: type);
      });
    }

    testWidgets('a driver route tap refreshes the driver lists', (t) async {
      wireBase();
      final requests = Get.put<DriverRequestsController>(WireRequests()) as WireRequests;
      final bookings = Get.put<DriverBookingsController>(WireBookings()) as WireBookings;
      TripPushSync.refreshNow(AppRoutes.taxiBookings);
      await t.pump();
      expect(requests.pushes, 1);
      expect(bookings.reloads, 1);
    });

    testWidgets('other pushes do not touch the driver lists', (t) async {
      wireBase();
      final requests = Get.put<DriverRequestsController>(WireRequests()) as WireRequests;
      for (final type in ['chat_message', 'plan_renewed', 'StayApproved', null]) {
        TripPushSync.onPush(type, null);
      }
      await t.pump(const Duration(milliseconds: 700));
      expect(requests.pushes, 0);
    });

    testWidgets('rings_missed_push_opens_the_checklist', (t) async {
      wireBase();
      final repo = WireReadyRepo();
      final ready = Get.put<DriverReadyController>(WireReady(repo: repo)) as WireReady;
      Get.put<DriverRequestsController>(WireRequests());
      await _pumpApp(t);
      await _settle(t);

      final data = {
        'notification_type': NotificationTypeKeys.taxiRingsMissedWire,
        'action_route': AppRoutes.taxiReady,
        'action_args_json': '{}',
      };
      repo.missedRings = true;
      TripPushSync.onPush(data['notification_type'], data['action_route']);
      await t.pump(const Duration(milliseconds: 700));
      await _settle(t);
      expect(ready.missedRings, isTrue);

      final route = data['action_route']!;
      expect(Get.find<AuthController>().canOpenRoute(route), isTrue);
      _Svc().openActionRoute(route, NotificationModel.parseArguments(data['action_args_json']));
      await _settle(t);
      expect(Get.currentRoute, AppRoutes.taxiReady);
      expect(find.byType(DriverReadyScreen), findsOneWidget);
      expect(find.text(DriverReadyStrings.missedLine), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 1));
    });
  });

  group('ready strip on the requests list', () {
    Widget screen(DriverReadyController ready) => DriverRequestsScreen(
          controller: WireRequests(),
          ready: ready,
          onOpenReady: () {},
        );

    testWidgets('strip shows on top when a check needs a fix', (t) async {
      wireBase();
      final ready = WireReady(repo: WireReadyRepo(missedRings: true));
      Get.put<DriverReadyController>(ready);
      await pumpAtSize(t, screen(ready), const Size(360, 800));
      await _settle(t);
      expect(find.byType(DriverReadyStrip), findsOneWidget);
      expect(find.text(DriverReadyStrings.stripTitle), findsOneWidget);
      final strip = t.getRect(find.text(DriverReadyStrings.stripTitle));
      final list = t.getRect(find.byKey(const ValueKey('requests_list')));
      expect(strip.bottom <= list.top, isTrue);
    });

    testWidgets('strip hides when every check is done', (t) async {
      wireBase();
      final ready = WireReady();
      Get.put<DriverReadyController>(ready);
      ready.ringShownHere.value = true;
      await pumpAtSize(t, screen(ready), const Size(360, 800));
      await _settle(t);
      expect(find.text(DriverReadyStrings.stripTitle), findsNothing);
    });

    for (final size in fiveSizes) {
      testWidgets('requests list with strip at ${sizeLabel(size)}', (t) async {
        wireBase();
        final ready = WireReady(repo: WireReadyRepo(missedRings: true));
        Get.put<DriverReadyController>(ready);
        await pumpAtSize(t, screen(ready), size);
        await _settle(t);
        expect(find.text(DriverReadyStrings.stripTitle), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('online switch', () {
    Future<WireTaxi> open(WidgetTester t, {required bool denied}) async {
      wireBase();
      Get.put<NotificationService>(WireNotif(denied: denied));
      final taxi = Get.put<TaxiSetupController>(WireTaxi(wireTaxi(available: false))) as WireTaxi;
      Get.put<TripLeadsController>(WireLeads());
      Get.put<DriverRequestsController>(WireRequests());
      Get.put<DriverReadyController>(WireReady(notificationsOn: !denied));
      await t.pumpWidget(GetMaterialApp(
        theme: AppTheme.theme,
        initialRoute: AppRoutes.myTaxi,
        getPages: [
          GetPage(name: AppRoutes.myTaxi, page: () => const MyTaxiScreen()),
          GetPage(name: AppRoutes.taxiReady, page: () => const Scaffold(body: Text('CHECKLIST'))),
        ],
      ));
      await _settle(t);
      return taxi;
    }

    Future<void> switchOn(WidgetTester t) async {
      t.widget<TaxiOwnerCard>(find.byType(TaxiOwnerCard)).onAvailableChanged!(true);
      await _settle(t);
    }

    Future<void> drain(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 6));
    }

    testWidgets('online_with_notifications_off_opens_the_checklist', (t) async {
      final taxi = await open(t, denied: true);
      expect(find.text(NotificationOffBanner.requestsBody), findsOneWidget);
      await switchOn(t);
      expect(taxi.availableCalls, [true]);
      expect((Get.find<DriverReadyController>() as WireReady).onlineReports, 1);
      expect(Get.currentRoute, AppRoutes.taxiReady);
      expect(find.text('CHECKLIST'), findsOneWidget);
      await drain(t);
    });

    testWidgets('online with notifications on stays on My Taxi', (t) async {
      final taxi = await open(t, denied: false);
      await switchOn(t);
      expect(taxi.availableCalls, [true]);
      expect(Get.currentRoute, AppRoutes.myTaxi);
      expect(find.text('CHECKLIST'), findsNothing);
      await drain(t);
    });

    testWidgets('going offline never opens the checklist', (t) async {
      await open(t, denied: true);
      t.widget<TaxiOwnerCard>(find.byType(TaxiOwnerCard)).onAvailableChanged!(false);
      await _settle(t);
      expect(Get.currentRoute, AppRoutes.myTaxi);
      await drain(t);
    });
  });

  group('requests badge load on My Taxi', () {
    Future<int> openWith(WidgetTester t, TaxiOwnerModel? model) async {
      wireBase();
      Get.put<NotificationService>(WireNotif(denied: false));
      Get.put<TaxiSetupController>(WireTaxi(model));
      Get.put<TripLeadsController>(WireLeads());
      final requests = Get.put<DriverRequestsController>(WireRequests()) as WireRequests;
      Get.put<DriverReadyController>(WireReady());
      await t.pumpWidget(GetMaterialApp(
        theme: AppTheme.theme,
        initialRoute: AppRoutes.myTaxi,
        getPages: [GetPage(name: AppRoutes.myTaxi, page: () => const MyTaxiScreen())],
      ));
      await _settle(t);
      final n = requests.reloads;
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 6));
      return n;
    }

    testWidgets('live_taxi_loads_the_requests_once', (t) async {
      expect(await openWith(t, wireTaxi()), 1);
    });

    testWidgets('draft_taxi_skips_the_requests_call', (t) async {
      expect(await openWith(t, wireTaxi(status: TaxiStatus.draft)), 0);
    });

    testWidgets('no_taxi_skips_the_requests_call', (t) async {
      expect(await openWith(t, null), 0);
    });
  });

  test('banner copy says requests on My Taxi and enquiries elsewhere', () {
    expect(NotificationOffBanner.requestsBody, 'You will miss new requests until notifications are on.');
    expect(const NotificationOffBanner().body, NotificationOffBanner.enquiriesBody);
    final src = File('lib/features/taxi/setup/my_taxi_screen.dart').readAsStringSync();
    expect(src.contains('NotificationOffBanner(body: NotificationOffBanner.requestsBody)'), isTrue);
  });

  test('push sample routes match the driver pages', () {
    final ring = _sample('push_ring.json')['data'] as Map<String, dynamic>;
    final end = _sample('push_ring_end.json')['data'] as Map<String, dynamic>;
    expect(NotificationTypeKeys.isDriverTaxi(ring['notification_type'] as String), isTrue);
    expect(NotificationTypeKeys.isDriverTaxi(end['notification_type'] as String), isTrue);
    expect(driverRequestPages.map((p) => p.name), contains(ring['action_route']));
    expect(driverRequestPages.map((p) => p.name), contains(end['action_route']));
  });
}
