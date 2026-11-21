import 'dart:async';

import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_app_bookings_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_ready_controller.dart';
import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/driver_request_detail_screen.dart';
import 'package:bakhli/features/taxi/requests/driver_ring_screen.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/taxi/requests/widgets/driver_bookings_section.dart';
import 'package:bakhli/features/taxi/requests/widgets/driver_offer_card.dart';
import 'package:bakhli/features/taxi/requests/widgets/driver_requests_body.dart';
import 'package:bakhli/features/taxi/requests/widgets/driver_withdraw_sheet.dart';
import 'package:bakhli/features/taxi_driver/requests_tab/taxi_requests_segments.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/services/taxi_ring_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import 'work_fixtures.dart';

class _QuietReady extends DriverReadyController {
  _QuietReady() : super();

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  bool get missedRings => false;
}

class _BookingsRepo extends DriverRequestRepository {
  _BookingsRepo(this.items, {this.fail = false});
  final List<Map<String, dynamic>> items;
  final bool fail;
  final calls = <String>[];

  @override
  Future<TaxiResult<DriverBookings>> bookings(DateTime from, DateTime to) async {
    calls.add('bookings');
    if (fail) return const TaxiOffline<DriverBookings>();
    final inRange = [
      for (final b in items)
        if (!DateTime.parse(b['dateFrom'] as String).isBefore(from) && !DateTime.parse(b['dateFrom'] as String).isAfter(to)) b,
    ];
    return TaxiOk(DriverBookings.fromJson({'from': '', 'to': '', 'occupied': const <Object>[], 'items': inRange}));
  }

  @override
  Future<TaxiResult<DriverBooking>> endBooking(String bookingId) async {
    calls.add('end:$bookingId');
    return TaxiOk(DriverBooking.fromJson({...items.first, 'state': 'Completed'}));
  }
}

Map<String, dynamic> _b(String id, String state, String from, String to, {String name = 'Aarav Sharma', Object? stars, String? by}) => {
      'bookingId': id,
      'offerId': 'o-$id',
      'requestId': 'r-$id',
      'state': state,
      'dateFrom': from,
      'dateTo': to,
      'pickupName': 'Kathgodam',
      'travellerName': name,
      'travellerPhone': '+919876543210',
      'canWithdraw': true,
      'canEnd': true,
      'ratingStars': stars,
      'cancelledBy': by,
    };

final _textNoPlan = RegExp(r'Plus|Free|Upgrade|plan', caseSensitive: false);

void main() {
  setUp(() {
    Get.reset();
    TaxiRingSession.reset();
    WorkPlans.use(WorkPlans.free);
  });
  tearDown(() => PlanGate.debugPlan = null);

  group('o_tx_13 / o_tx_36 ring screen', () {
    Future<WorkRepo> open(WidgetTester t, {Map<String, dynamic>? detail, bool fail = false, Size size = phoneSize, double scale = 1.0}) async {
      final repo = WorkRepo(detail: detail ?? offerJson(), list: listJson([detail ?? offerJson()]));
      if (fail) {
        repo.detailResult = const TaxiOffline<DriverOffer>();
        repo.listResult = const TaxiOffline<DriverOfferList>();
      }
      final c = workController(repo);
      await pumpPhone(
        t,
        DriverRingScreen(offerId: 'offer-1', controller: c, onAccepted: (_) {}, onClose: () {}, onChooseRoute: () {}, expiresAt: workNow.add(const Duration(minutes: 4, seconds: 10)), closeDelay: const Duration(minutes: 5)),
        size: size,
        textScale: scale,
      );
      await t.pump();
      await t.pump();
      return repo;
    }

    testWidgets('ring_fields_and_no_plan_words', (t) async {
      await open(t);
      for (final s in ['INCOMING REQUEST', 'New taxi request', 'Pickup', 'Sightseeing 6 days', 'Drop', '9 days · 8 nights · 18 to 26 Dec', 'Kathgodam to Nainital, Ranikhet, Kausani +2', '4 seater · 2 travellers', 'Decline', 'Accept', 'Swipe up to answer']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      final texts = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').join(' ');
      expect(_textNoPlan.hasMatch(texts), isFalse);
      expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true && RegExp(r'^\d+:\d0$').hasMatch(w.properties.label ?? '')), findsOneWidget);
    });

    testWidgets('accept_single_flight', (t) async {
      final repo = await open(t);
      final hold = Completer<void>();
      repo.actionHold = hold;
      await t.tap(find.text('Accept'));
      await t.tap(find.text('Accept'), warnIfMissed: false);
      await t.pump();
      hold.complete();
      await t.pump();
      expect(repo.calls.where((c) => c == 'accept').length, 1);
    });

    testWidgets('B_could_not_open_with_time_left', (t) async {
      await open(t, fail: true);
      expect(find.text('TAXI REQUEST'), findsOneWidget);
      expect(find.text('Could not open the request'), findsOneWidget);
      expect(find.textContaining('Check your internet. The request is still yours for '), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('C_missed', (t) async {
      await open(t, detail: offerJson(state: 'Missed', bucket: 'Earlier'));
      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('Went to the next drivers.'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('D_pushed_end_line', (t) async {
      await open(t);
      TaxiRingSession.ended.value = const TaxiRingEnd('offer-1', 'Filled');
      await t.pump();
      expect(find.text('Taken by another driver'), findsOneWidget);
      expect(find.text('This does not count as a miss.'), findsOneWidget);
    });

    testWidgets('D_other_offer_end_is_ignored', (t) async {
      await open(t);
      TaxiRingSession.ended.value = const TaxiRingEnd('other', 'Filled');
      await t.pump();
      expect(find.text('New taxi request'), findsOneWidget);
    });

    testWidgets('E_route_paused_payment_on', (t) async {
      await open(t, detail: offerJson(state: 'Closed', bucket: 'Earlier', endReason: 'RoutePausedByPlan'));
      expect(find.text('This route is paused on Free.'), findsOneWidget);
      expect(find.text('Choose your route'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('E_hidden_with_payment_off', (t) async {
      WorkPlans.use(WorkPlans.off);
      await open(t, detail: offerJson(state: 'Closed', bucket: 'Earlier', endReason: 'RoutePausedByPlan'));
      expect(find.text('This route is paused on Free.'), findsNothing);
      expect(find.text('This request is closed'), findsOneWidget);
      expect(find.text('Choose your route'), findsNothing);
    });

    testWidgets('F_requests_paused', (t) async {
      final repo = WorkRepo(detail: offerJson());
      repo.detailResult = const TaxiPaused<DriverOffer>();
      repo.listResult = const TaxiPaused<DriverOfferList>();
      await pumpPhone(t, DriverRingScreen(offerId: 'offer-1', controller: workController(repo), onClose: () {}));
      await t.pump();
      await t.pump();
      expect(find.text('Taxi requests are paused for now'), findsOneWidget);
      expect(find.text('New requests will come back soon.'), findsOneWidget);
    });

    testWidgets('A_opening_while_loading', (t) async {
      final repo = WorkRepo(detail: offerJson())..hold = Completer<void>();
      await pumpPhone(t, DriverRingScreen(offerId: 'offer-1', controller: workController(repo), onClose: () {}));
      await t.pump();
      expect(find.text('Getting the request'), findsOneWidget);
      expect(find.text('One moment.'), findsOneWidget);
      repo.hold!.complete();
      await t.pump();
    });

    for (final size in ownerSizes) {
      for (final scale in ownerTextScales) {
        testWidgets('ring_sizes ${ownerSizeLabel(size, scale)}', (t) async {
          await open(t, size: size, scale: scale);
          expect(t.takeException(), isNull);
          TaxiRingSession.ended.value = const TaxiRingEnd('offer-1', 'RoutePausedByPlan');
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  });

  group('o_tx_14 requests body', () {
    Future<WorkRepo> open(WidgetTester t, List<Map<String, dynamic>> items, {String? next, Size size = phoneSize, double scale = 1.0}) async {
      final repo = WorkRepo(list: listJson(items, next: next));
      final c = workController(repo);
      await pumpPhone(
        t,
        Scaffold(body: DriverRequestsBody(key: UniqueKey(), controller: c, ready: _QuietReady(), onOpenOffer: (_) {})),
        size: size,
        textScale: scale,
      );
      await t.pump();
      await t.pump();
      return repo;
    }

    final fresh = offerJson(id: 'n1', routeLine: 'Kathgodam to Nainital, Ranikhet +2', ringLeft: const Duration(minutes: 3, seconds: 12));
    final missed = offerJson(id: 'm1', state: 'Missed', bucket: 'Earlier', routeLine: 'Kathgodam to Nainital +3');

    testWidgets('groups_frame_strings', (t) async {
      await open(t, [fresh, missed]);
      for (final s in ['New', 'Earlier', 'Kathgodam pickup', '3:12 left', '9 days · 8 nights · 18 to 26 Dec', 'Kathgodam to Nainital, Ranikhet +2 · 4 seater', 'Missed', 'Went to the next drivers', '9 days · Kathgodam to Nainital +3']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.text('Traveller'), findsNWidgets(2));
      expect(find.text('Plus drivers get their turn 2x as often.'), findsOneWidget);
      expect(find.text('See Plus'), findsOneWidget);
    });

    testWidgets('g3_not_without_earlier', (t) async {
      await open(t, [fresh]);
      expect(find.byKey(GateKeys.of('G3')), findsNothing);
    });

    testWidgets('g3_hidden_for_plus', (t) async {
      WorkPlans.use(WorkPlans.plus);
      await open(t, [fresh, missed]);
      expect(find.byKey(GateKeys.of('G3')), findsNothing);
    });

    testWidgets('payment_off_no_gate_key_no_plan_word', (t) async {
      WorkPlans.use(WorkPlans.off);
      await open(t, [fresh, missed]);
      expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
      final texts = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').join(' ');
      expect(RegExp(r'\bFree\b|\bPlus\b').hasMatch(texts), isFalse);
    });

    testWidgets('empty_0_rows', (t) async {
      await open(t, const []);
      expect(find.text('No requests yet'), findsOneWidget);
    });

    testWidgets('error_then_offline_keeps_last_list', (t) async {
      final repo = WorkRepo()..listResult = const TaxiOffline<DriverOfferList>();
      final c = workController(repo);
      await pumpPhone(t, Scaffold(body: DriverRequestsBody(controller: c, ready: _QuietReady())));
      await t.pump();
      await t.pump();
      expect(find.text('Could not load requests'), findsOneWidget);
      repo.listResult = TaxiOk(DriverOfferList.fromJson(listJson([fresh])));
      await t.tap(find.text('Try again'));
      await t.pump();
      await t.pump();
      expect(find.text('Kathgodam pickup'), findsOneWidget);
      repo.listResult = const TaxiOffline<DriverOfferList>();
      await c.reloadList();
      await t.pump();
      expect(find.text('Could not refresh. Showing your last list.'), findsOneWidget);
      expect(find.text('Kathgodam pickup'), findsOneWidget);
    });

    testWidgets('paused_view', (t) async {
      final repo = WorkRepo()..listResult = const TaxiPaused<DriverOfferList>();
      await pumpPhone(t, Scaffold(body: DriverRequestsBody(controller: workController(repo), ready: _QuietReady())));
      await t.pump();
      await t.pump();
      expect(find.text('Requests are paused right now'), findsOneWidget);
      expect(find.text('New requests will come back soon. Pull down to check again.'), findsOneWidget);
    });

    testWidgets('rows_20_and_21_show_more', (t) async {
      final twenty = [for (var i = 0; i < 20; i++) offerJson(id: 'e$i', state: 'Missed', bucket: 'Earlier')];
      await open(t, twenty);
      expect(find.text('Show more'), findsNothing);
      final repo = await open(t, twenty, next: 'c2');
      final list = find.descendant(of: find.byKey(const ValueKey('requests_list')), matching: find.byType(Scrollable));
      await t.scrollUntilVisible(find.text('Show more'), 300, scrollable: list.first);
      await t.tap(find.text('Show more'));
      await t.pump();
      expect(repo.calls, contains('more:c2'));
    });

    testWidgets('one_timer_for_whole_list', (t) async {
      await open(t, [fresh, offerJson(id: 'n2'), offerJson(id: 'n3')]);
      expect(find.textContaining(' left'), findsNWidgets(3));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
    });

    testWidgets('tick_rebuilds_only_counting_cards', (t) async {
      await open(t, [fresh, missed]);
      DriverOfferCard card(String route) => t.widget<DriverOfferCard>(find.ancestor(of: find.textContaining(route), matching: find.byType(DriverOfferCard)).first);
      final missedBefore = card('Kathgodam to Nainital +3');
      final freshBefore = card('Ranikhet +2');
      await t.pump(const Duration(seconds: 1));
      expect(identical(card('Kathgodam to Nainital +3'), missedBefore), isTrue);
      expect(identical(card('Ranikhet +2'), freshBefore), isFalse);
    });

    for (final rows in [0, 1, 20]) {
      testOwnerSizes('requests_body_rows_$rows', () {
        final repo = WorkRepo(list: listJson([for (var i = 0; i < rows; i++) i == 0 ? fresh : offerJson(id: 'e$i', state: 'Missed', bucket: 'Earlier')]));
        return Scaffold(body: DriverRequestsBody(controller: workController(repo), ready: _QuietReady()));
      }, arrange: (t) async {
        await t.pump();
        await t.pump();
      });
    }
  });

  group('segments', () {
    testWidgets('leads_badge_and_select', (t) async {
      var picked = -1;
      await pumpPhone(t, Material(child: TaxiRequestsSegments(selected: 0, leadsBadge: 1, onSelect: (i) => picked = i)));
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Trip leads'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      await t.tap(find.text('Trip leads'));
      expect(picked, 1);
    });

    testOwnerSizes('segments_sizes', () => Material(child: TaxiRequestsSegments(selected: 1, leadsBadge: 12, onSelect: (_) {})));
  });

  group('o_tx_15 / o_tx_37 / o_tx_38 detail', () {
    Future<WorkRepo> open(WidgetTester t, Map<String, dynamic> json, {Size size = phoneSize, double scale = 1.0}) async {
      final repo = WorkRepo(detail: json, list: listJson([json]));
      final c = workController(repo);
      await pumpPhone(t, DriverRequestDetailScreen(key: UniqueKey(), offerId: 'offer-1', controller: c, onBack: () {}, onCall: (_) async {}, onOpenBookings: () {}), size: size, textScale: scale);
      await t.pump();
      await t.pump();
      return repo;
    }

    testWidgets('titles_by_state', (t) async {
      const titles = {'Ringing': 'Request details', 'Accepted': 'Request accepted', 'Selected': 'Booking request', 'Confirmed': 'Booking', 'NotSelected': 'Request'};
      for (final e in titles.entries) {
        await open(t, offerJson(state: e.key));
        expect(find.text(e.value), findsOneWidget, reason: e.key);
      }
    });

    testWidgets('selected_frame_strings', (t) async {
      await open(t, offerJson(state: 'Selected'));
      for (final s in ['Aarav Sharma', '+91 98765 43210', 'Selected you · confirm in 12:40', 'Decline', 'Confirm booking', 'Kathgodam pickup']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
    });

    testWidgets('selected_countdown_zero_flips_to_over', (t) async {
      await open(t, offerJson(state: 'Selected', confirmLeft: Duration.zero));
      expect(find.text('Time to confirm is over'), findsOneWidget);
    });

    testWidgets('amber_line_from_manualTripOn', (t) async {
      await open(t, offerJson(state: 'Accepted', manualTripOn: ['2026-12-20']));
      expect(find.text('You added a trip on 20 Dec.'), findsOneWidget);
      await open(t, offerJson(state: 'Accepted', manualTripOn: ['2026-12-20', '2026-12-22']));
      expect(find.text('You added trips on 20 Dec and 22 Dec.'), findsOneWidget);
      await open(t, offerJson(state: 'Accepted'));
      expect(find.byKey(const ValueKey('request_manual_trip')), findsNothing);
    });

    testWidgets('accepted_buttons_and_withdraw_request_sheet', (t) async {
      final repo = await open(t, offerJson(state: 'Accepted'));
      expect(find.text('Waiting for traveller to choose'), findsOneWidget);
      expect(find.text('Call traveller'), findsOneWidget);
      await t.tap(find.text('Withdraw'));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(seconds: 1));
      for (final s in ['Withdraw from request', 'The traveller can choose another driver.', 'Reason', 'Asked by the traveller', 'Changed plan', 'Vehicle issue', 'Price not agreed', 'Other', 'Confirm withdraw', 'Keep']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.text('Not reachable'), findsNothing);
      await t.tap(find.text('Vehicle issue'));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('driver_withdraw_confirm')));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump();
      expect(repo.calls, contains('withdraw:VehicleIssue'));
    });

    testWidgets('accepted_no_phone_hides_call', (t) async {
      await open(t, {...offerJson(state: 'Accepted'), 'traveller': {'name': 'Aarav Sharma', 'phone': null}});
      expect(find.text('Call traveller'), findsNothing);
      expect(find.text('Withdraw'), findsOneWidget);
    });

    testWidgets('booked_buttons_and_required_sheet', (t) async {
      final repo = await open(t, offerJson(state: 'Confirmed'));
      expect(find.text('Booked · 18 to 26 Dec'), findsOneWidget);
      expect(find.text('My bookings'), findsOneWidget);
      await t.tap(find.text('Withdraw'));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(seconds: 1));
      for (final s in ['Withdraw from booking', 'Aarav · 18 to 26 Dec', 'Why are you withdrawing?', 'Required', 'Not reachable', 'Keep booking', 'Aarav’s request opens again for other drivers. Your calendar entry stays, marked Cancelled.']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      await t.tap(find.byKey(const ValueKey('driver_withdraw_confirm')));
      await t.pump();
      expect(repo.calls.where((c) => c.startsWith('withdraw')), isEmpty);
      await t.tap(find.text('Not reachable'));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('driver_withdraw_confirm')));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump();
      expect(repo.calls, contains('withdraw:NotReachable'));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 6));
    });

    testWidgets('refusals_have_frame_lines', (t) async {
      final repo = await open(t, offerJson(state: 'Selected'));
      repo.actionResult = const TaxiConfirmWindowPassed<DriverOffer>();
      await t.tap(find.text('Confirm booking'));
      await t.pump();
      await t.pump();
      expect(find.text('Time to confirm is over'), findsWidgets);
    });

    for (final state in ['Selected', 'Accepted', 'Confirmed']) {
      for (final size in ownerSizes) {
        for (final scale in ownerTextScales) {
          testWidgets('detail_${state}_${ownerSizeLabel(size, scale)}', (t) async {
            await open(t, offerJson(state: state, manualTripOn: ['2026-12-20', '2026-12-22']), size: size, scale: scale);
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  });

  group('withdraw sheet', () {
    testOwnerSizes('withdraw_booking_sheet', () => Material(
          child: Align(alignment: Alignment.bottomCenter, child: SingleChildScrollView(child: Padding(padding: EdgeInsets.only(top: 60), child: DriverWithdrawSheet(travellerName: 'Aarav', range: '18 to 26 Dec')))),
        ));
  });

  group('o_tx_39 bookings section', () {
    final items = [
      _b('t1', 'InProgress', '2026-12-08', '2026-12-16'),
      _b('c1', 'Completed', '2026-11-18', '2026-11-26', stars: 5),
      _b('x1', 'Cancelled', '2026-11-02', '2026-11-02', name: 'Seema Joshi', by: 'Traveller'),
      _b('x2', 'Cancelled', '2026-11-09', '2026-11-11', name: 'Ritu Pant', by: 'Admin'),
    ];

    Future<_BookingsRepo> open(WidgetTester t, List<Map<String, dynamic>> list, {bool fail = false, Size size = phoneSize, double scale = 1.0}) async {
      final repo = _BookingsRepo(list, fail: fail);
      final c = DriverAppBookingsController(repo: repo, now: () => DateTime(2026, 12, 10), onChanged: () {});
      await pumpPhone(t, Scaffold(body: SingleChildScrollView(child: DriverBookingsSection(key: UniqueKey(), controller: c, onCall: (_) {}))), size: size, textScale: scale);
      await t.pump();
      await t.pump();
      return repo;
    }

    testWidgets('cards_and_lines', (t) async {
      await open(t, items);
      for (final s in ['From the app', 'last 90 days', 'On trip', 'Completed', 'Aarav rated you 5 stars', 'Seema cancelled. Your dates are free again.', 'Cancelled by Bakhli.', 'Call traveller', 'End trip']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
    });

    testWidgets('end_trip_asks_first', (t) async {
      final repo = await open(t, items);
      await t.tap(find.text('End trip'));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('End this trip?'), findsOneWidget);
      expect(find.text('Aarav will be asked to rate you.'), findsOneWidget);
      expect(find.text('Not yet'), findsOneWidget);
      await t.tap(find.text('Not yet'));
      await t.pump(const Duration(milliseconds: 500));
      expect(repo.calls.where((c) => c.startsWith('end')), isEmpty);
    });

    testWidgets('empty_and_error', (t) async {
      await open(t, const []);
      expect(find.text('No bookings yet'), findsOneWidget);
      await open(t, items, fail: true);
      expect(find.text('Could not load bookings'), findsOneWidget);
    });

    for (final n in [0, 1, 4]) {
      for (final size in ownerSizes) {
        for (final scale in ownerTextScales) {
          testWidgets('section_rows_${n}_${ownerSizeLabel(size, scale)}', (t) async {
            await open(t, items.take(n).toList(), size: size, scale: scale);
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  });
}
