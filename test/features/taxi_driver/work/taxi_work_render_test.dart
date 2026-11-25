import 'dart:async';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/notices/models/notice_models.dart';
import 'package:bakhli/features/buddy/notices/widgets/notice_row.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/session/owner_notice_registry.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_app_bookings_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_ready_controller.dart';
import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/driver_request_detail_screen.dart';
import 'package:bakhli/features/taxi/requests/driver_ring_screen.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/taxi/requests/widgets/driver_bookings_section.dart';
import 'package:bakhli/features/taxi_driver/notices/taxi_notice_copy.dart';
import 'package:bakhli/features/taxi_driver/requests_tab/taxi_requests_tab.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/services/taxi_ring_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_render.dart';
import 'work_fixtures.dart';

class _QuietReady extends DriverReadyController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Bookings extends DriverRequestRepository {
  _Bookings(this.items);
  final List<Map<String, dynamic>> items;

  @override
  Future<TaxiResult<DriverBookings>> bookings(DateTime from, DateTime to) async => TaxiOk(DriverBookings.fromJson({
        'from': '',
        'to': '',
        'occupied': const <Object>[],
        'items': [
          for (final b in items)
            if (!DateTime.parse(b['dateFrom'] as String).isBefore(from) && !DateTime.parse(b['dateFrom'] as String).isAfter(to)) b,
        ],
      }));
}

Map<String, dynamic> _b(String id, String state, String from, String to, String place, String name, {int? stars, String? by}) => {
      'bookingId': id,
      'offerId': 'o-$id',
      'requestId': 'r-$id',
      'state': state,
      'dateFrom': from,
      'dateTo': to,
      'pickupName': place,
      'travellerName': name,
      'travellerPhone': '+919876543210',
      'canWithdraw': true,
      'canEnd': true,
      'ratingStars': stars,
      'cancelledBy': by,
    };

void main() {
  useOwnerRenderScale();
  setUp(() {
    Get.reset();
    TaxiRingSession.reset();
    PlanGate.debugPlan = WorkPlans.free;
  });
  tearDown(() => PlanGate.debugPlan = null);

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  Widget ring(Map<String, dynamic> json, {bool fail = false}) {
    final repo = WorkRepo(detail: json, list: listJson([json]));
    if (fail) {
      repo.detailResult = const TaxiOffline<DriverOffer>();
      repo.listResult = const TaxiOffline<DriverOfferList>();
    }
    return DriverRingScreen(
      offerId: 'offer-1',
      controller: workController(repo),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 4, seconds: 10)),
      onAccepted: (_) {},
      onClose: () {},
      onChooseRoute: () {},
      closeDelay: const Duration(minutes: 10),
    );
  }

  testWidgets('render o_tx_13', (t) async {
    final repo = WorkRepo(detail: offerJson(), list: listJson([offerJson()]));
    await renderOwnerFrame(t, 'o_tx_13', DriverRingScreen(offerId: 'offer-1', controller: workController(repo), onClose: () {}, closeDelay: const Duration(minutes: 10)), arrange: settle);
  });

  testWidgets('render o_tx_36 A', (t) async {
    final repo = WorkRepo(detail: offerJson())..hold = Completer<void>();
    await renderOwnerFrame(t, 'o_tx_36', DriverRingScreen(offerId: 'offer-1', controller: workController(repo), onClose: () {}), part: 'A', arrange: (tt) async {});
  });

  testWidgets('render o_tx_36 B', (t) async {
    await renderOwnerFrame(t, 'o_tx_36', ring(offerJson(), fail: true), part: 'B', arrange: settle);
  });

  testWidgets('render o_tx_36 C', (t) async {
    await renderOwnerFrame(t, 'o_tx_36', ring(offerJson(state: 'Missed', bucket: 'Earlier')), part: 'C', arrange: settle);
  });

  testWidgets('render o_tx_36 D', (t) async {
    await renderOwnerFrame(t, 'o_tx_36', ring(offerJson(state: 'Closed', bucket: 'Earlier', endReason: 'Filled')), part: 'D', arrange: settle);
  });

  testWidgets('render o_tx_36 E', (t) async {
    await renderOwnerFrame(t, 'o_tx_36', ring(offerJson(state: 'Closed', bucket: 'Earlier', endReason: 'RoutePausedByPlan')), part: 'E', arrange: settle);
  });

  testWidgets('render o_tx_36 F', (t) async {
    final repo = WorkRepo(detail: offerJson())
      ..detailResult = const TaxiPaused<DriverOffer>()
      ..listResult = const TaxiPaused<DriverOfferList>();
    await renderOwnerFrame(t, 'o_tx_36', DriverRingScreen(offerId: 'offer-1', controller: workController(repo), onClose: () {}), part: 'F', arrange: settle);
  });

  testWidgets('render o_tx_14', (t) async {
    Get.put<DriverReadyController>(_QuietReady());
    final repo = WorkRepo(
      list: listJson([
        offerJson(id: 'n1', routeLine: 'Kathgodam to Nainital, Ranikhet +2', ringLeft: const Duration(minutes: 3, seconds: 12)),
        offerJson(id: 'm1', state: 'Missed', bucket: 'Earlier', routeLine: 'Kathgodam to Nainital +3'),
      ]),
    );
    final c = workController(repo, now: workNow);
    await renderOwnerFrame(t, 'o_tx_14', TaxiRequestsTab(requests: c), arrange: settle);
  });

  Widget detail(String state, {List<String> manual = const []}) {
    final json = offerJson(state: state, manualTripOn: manual);
    final repo = WorkRepo(detail: json, list: listJson([json]));
    return DriverRequestDetailScreen(offerId: 'offer-1', controller: workController(repo), onBack: () {}, onCall: (_) async {}, onOpenBookings: () {});
  }

  testWidgets('render o_tx_15', (t) async {
    await renderOwnerFrame(t, 'o_tx_15', detail('Selected'), arrange: settle);
  });

  testWidgets('render o_tx_37 A', (t) async {
    await renderOwnerFrame(t, 'o_tx_37', detail('Accepted'), part: 'A', arrange: settle);
  });

  testWidgets('render o_tx_37 B', (t) async {
    await renderOwnerFrame(t, 'o_tx_37', detail('Accepted'), part: 'B', arrange: (tt) async {
      await settle(tt);
      await tt.tap(find.text('Withdraw'));
      await tt.pump(const Duration(seconds: 1));
      await tt.tap(find.text('Vehicle issue'));
      await tt.pump(const Duration(milliseconds: 300));
    });
  });

  testWidgets('render o_tx_38 A', (t) async {
    await renderOwnerFrame(t, 'o_tx_38', detail('Confirmed'), part: 'A', arrange: settle);
  });

  testWidgets('render o_tx_38 B', (t) async {
    await renderOwnerFrame(t, 'o_tx_38', detail('Confirmed'), part: 'B', arrange: (tt) async {
      await settle(tt);
      await tt.tap(find.text('Withdraw'));
      await tt.pump(const Duration(seconds: 1));
      await tt.tap(find.text('Not reachable'));
      await tt.pump(const Duration(milliseconds: 300));
    });
  });

  Widget section(List<Map<String, dynamic>> items, DateTime today) {
    final c = DriverAppBookingsController(repo: _Bookings(items), now: () => today, onChanged: () {});
    return Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: DS.insets(l: 18, t: 24, r: 18),
          child: DriverBookingsSection(controller: c, onCall: (_) {}),
        ),
      ),
    );
  }

  testWidgets('render o_tx_39 B', (t) async {
    await renderOwnerFrame(
      t,
      'o_tx_39',
      section([_b('t1', 'InProgress', '2026-12-18', '2026-12-26', 'Kathgodam', 'Aarav Sharma')], DateTime(2026, 12, 20)),
      part: 'B',
      arrange: (tt) async {
        await settle(tt);
        await tt.tap(find.text('End trip'));
        await tt.pump(const Duration(seconds: 1));
      },
    );
  });

  testWidgets('render o_tx_39 C', (t) async {
    await renderOwnerFrame(
      t,
      'o_tx_39',
      section([
        _b('c1', 'Completed', '2026-12-18', '2026-12-26', 'Kathgodam', 'Aarav Sharma', stars: 5),
        _b('x1', 'Cancelled', '2027-01-02', '2027-01-02', 'Pantnagar airport', 'Seema Joshi', by: 'Traveller'),
        _b('x2', 'Cancelled', '2027-01-09', '2027-01-11', 'Haldwani', 'Ritu Pant', by: 'Admin'),
      ], DateTime(2026, 12, 28)),
      part: 'C',
      arrange: settle,
    );
  });

  testWidgets('render o_tx_49 stored rows subset', (t) async {
    OwnerNoticeRegistry.reset();
    TaxiNoticeCopy.register();
    TaxiNoticeCopy.debugPlan = const MyPlanModel(paymentEnabled: true, hidden: PlanHiddenModel(routes: 3));
    Notice n(String kind, {String? title, Map<String, dynamic> args = const {}}) =>
        Notice.fromJson({'id': kind, 'kind': kind, 'refTitle': title, 'args': args, 'createdAt': DateTime.now().toUtc().subtract(const Duration(days: 22)).toIso8601String()});
    await renderOwnerFrame(
      t,
      'o_tx_49',
      Scaffold(
        backgroundColor: ListingPalette.indigo.page,
        body: SafeArea(
          child: ListView(
            padding: DS.insets(l: 0, t: 20, r: 0),
            children: [
              const DayLabel3D('FARES AND CALENDAR'),
              NoticeRow(notice: n('FestivalReminder', title: 'Diwali week', args: {'dateFrom': '2026-11-06'}), onTap: () {}),
              const DayLabel3D('PLAN'),
              NoticeRow(notice: n('PlanLimitsChanged'), onTap: () {}),
            ],
          ),
        ),
      ),
      arrange: settle,
    );
    TaxiNoticeCopy.debugPlan = null;
  });
}
