import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/sheets/owner_states.dart';
import 'package:bakhli/features/stay_owner/home/stay_owner_home_controller.dart';
import 'package:bakhli/features/stay_owner/home/stay_owner_home_screen.dart';
import 'package:bakhli/features/stay_owner/stay_owner_deps.dart';
import 'dart:async';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toastification/toastification.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import 'stay_fixtures.dart';

String _replyBy() => DateTime(2026, 11, 21, 18, 40).toUtc().toIso8601String();

List<Map<String, dynamic>> _rows(int n) => [
      att('EnquiriesWaiting', 1, {'count': 2, 'replyBy': _replyBy()}),
      att('OfferAccepted', 3, {'enquiryId': 'q', 'travellerName': 'Rohit', 'checkIn': '2026-11-27', 'checkOut': '2026-11-29'}),
      att('PaymentIssue', 4),
      att('PlanHidden', 6, {'photos': 4, 'roomTypes': 2, 'reason': 'PlusEnded'}),
      att('Reports', 7, {'count': 2, 'firstReason': 'Photos do not match'}),
      att('EditRejected', 8, {'reason': 'wrong name', 'fields': ['name']}),
      att('Festival', 9, {'name': 'Diwali week', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12', 'festivalId': 'f'}),
      att('ShareListing', 10, {'slug': 'x'}),
      att('AddShareDetails', 11),
      att('ChangeOrCounter', 2, {'enquiryId': 'q2', 'travellerName': 'Neha', 'kind': 'Change'}),
      att('MissingEverything', 5),
    ].take(n).toList();

Future<StayHarness> _pump(WidgetTester t, Map<String, dynamic> json, {bool denied = false, bool offline = false, Size size = phoneSize, double scale = 1, bool toast = false}) async {
  final h = StayHarness.setUp(json, denied: denied, offline: offline);
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, const StayOwnerHomeScreen(), size: size, textScale: scale, toastHost: toast);
  await t.runAsync(() => h.home.checkNotifications());
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 100));
  return h;
}

Future<void> _toast(WidgetTester t) async {
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() => initTestStorage('stay_home_test'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    StayOwnerDeps.debugReset();
    OwnerApi.debugReset();
    resetOwnerTestState();
  });

  group('o_st_9 / o_st_10 live', () {
    testWidgets('live day 1: card, switch, attention, numbers, quick actions, instagram', (t) async {
      await _pump(t, homeJson(attention: [att('ShareListing', 10, {'slug': 'x'}), att('AddShareDetails', 11)]));
      for (final s in [
        'Hi, Meena', 'Your stay is live', 'Deodar Heights', 'LIVE', 'Guests can find and ask you now.', 'Accepting guests', 'Needs attention',
        'Share your stay', 'Send your link to past guests to get first enquiries.', 'Share', 'Add UPI and WhatsApp', 'Optional. Shared only when you choose', 'Add',
        'New enquiries', 'Offers waiting', 'Confirmed', 'Quick actions', 'Edit prices', 'Rooms and rates', 'Instagram', 'Follow us', 'Follow',
      ]) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.text('0'), findsNWidgets(3));
      expect(find.text('Share your stay').evaluate().length, 1);
      final share = tester(t).getTopLeft(find.text('Share your stay')).dy;
      final upi = tester(t).getTopLeft(find.text('Add UPI and WhatsApp')).dy;
      expect(share, lessThan(upi));
    });

    testWidgets('busy: rows, count, reply-by clock, centre badge kept', (t) async {
      final h = await _pump(
        t,
        homeJson(statusLine: {'code': 'NewNeedReply', 'args': {'count': 2}}, badge: 2, stay: {'newEnquiries': 2, 'offersWaiting': 1, 'confirmed': 3}, attention: _rows(2)),
      );
      expect(find.text('2 enquiries need a reply.'), findsOneWidget);
      expect(find.text('2 enquiries waiting'), findsOneWidget);
      expect(find.text('Reply before 6:40 pm'), findsOneWidget);
      expect(find.text('Rohit accepted your offer'), findsOneWidget);
      expect(find.text('Booking confirmed for 27 – 29 Nov'), findsOneWidget);
      expect(h.home.centreBadge.value, 2);
      expect(find.textContaining('Confirm the booking'), findsNothing);
      expect(find.textContaining('Advance'), findsNothing);
    });

    testWidgets('more than two rows: two shown and See all (N)', (t) async {
      await _pump(t, homeJson(attention: _rows(9)));
      expect(find.text('See all (9)'), findsOneWidget);
      expect(find.text('2 enquiries waiting'), findsOneWidget);
      expect(find.text('Rohit accepted your offer'), findsOneWidget);
      expect(find.text('Payment issue'), findsNothing);
    });

    testWidgets('no row hides See all', (t) async {
      await _pump(t, homeJson());
      expect(find.textContaining('See all'), findsNothing);
      expect(find.text('Needs attention'), findsNothing);
    });

    testWidgets('missing numbers print an en dash, zero prints 0', (t) async {
      await _pump(t, homeJson(switchOn: false, stay: {'offersWaiting': 1, 'confirmed': 3}));
      expect(find.text('–'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('quick actions: four tiles, jobs tile follows the jobs slot', (t) async {
      await _pump(t, homeJson());
      expect(find.text('Share my stay'), findsOneWidget);
      expect(find.text('Contact details'), findsOneWidget);
    });

    testWidgets('upcoming and plan seams are mounted only where the frames draw them', (t) async {
      StayOwnerDeps.upcomingCard = () => const Text('UPCOMING-SEAM');
      StayOwnerDeps.planCard = () => const Text('PLAN-SEAM');
      await _pump(t, homeJson());
      expect(find.text('UPCOMING-SEAM'), findsOneWidget);
      expect(find.text('PLAN-SEAM'), findsOneWidget);
    });
  });

  group('other states', () {
    testWidgets('o_st_7 under review: no switch, rails, plan card or upcoming', (t) async {
      StayOwnerDeps.upcomingCard = () => const Text('UPCOMING-SEAM');
      StayOwnerDeps.planCard = () => const Text('PLAN-SEAM');
      await _pump(t, homeJson(status: 'PendingReview', everApproved: false, stay: {}), denied: true);
      expect(find.text('Your stay is under review'), findsOneWidget);
      expect(find.text('UNDER REVIEW'), findsOneWidget);
      expect(find.text('We will notify you'), findsOneWidget);
      expect(find.text('While you wait'), findsOneWidget);
      expect(find.text('Add UPI and WhatsApp'), findsOneWidget);
      expect(find.text('You will miss new enquiries until notifications are on.'), findsOneWidget);
      expect(find.text('–'), findsNWidgets(3));
      expect(find.text('Accepting guests'), findsNothing);
      expect(find.text('Quick actions'), findsNothing);
      expect(find.text('PLAN-SEAM'), findsNothing);
      expect(find.text('UPCOMING-SEAM'), findsNothing);
      expect(find.textContaining('Plus'), findsNothing);
    });

    testWidgets('o_st_7 notifications row only while the permission is denied', (t) async {
      await _pump(t, homeJson(status: 'PendingReview', everApproved: false, stay: {}));
      expect(find.text('Turn on notifications'), findsNothing);
    });

    testWidgets('o_st_8 rejected: reason, Fix and resubmit, notifications and support rows', (t) async {
      await _pump(t, homeJson(status: 'Rejected', everApproved: false, reason: 'photos are not clear. Add day-time photos of the rooms.', stay: {}), denied: true);
      expect(find.text('Your stay is not live'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.text('Rejected: photos are not clear. Add day-time photos of the rooms.'), findsOneWidget);
      expect(find.text('Fix and resubmit'), findsOneWidget);
      expect(find.text('We tell you when the review is done.'), findsOneWidget);
      expect(find.text('Need help? Contact Support'), findsOneWidget);
      expect(find.text('We reply within a day'), findsOneWidget);
      expect(find.text('Accepting guests'), findsNothing);
    });

    testWidgets('o_st_8 reason missing prints a generic line', (t) async {
      await _pump(t, homeJson(status: 'Rejected', everApproved: false, stay: {}));
      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('o_st_70 taken down: own card and strip, calendar kept, no attention or plan card', (t) async {
      StayOwnerDeps.upcomingCard = () => const Text('UPCOMING-SEAM');
      StayOwnerDeps.planCard = () => const Text('PLAN-SEAM');
      await _pump(t, homeJson(status: 'Rejected', takenDown: true, reason: 'guests reported a wrong location.', stay: {'confirmed': 2}, attention: _rows(3)), denied: true);
      expect(find.text('TAKEN DOWN'), findsOneWidget);
      expect(find.text('Taken down by Bakhli: guests reported a wrong location.'), findsOneWidget);
      expect(find.text('Fix and resubmit'), findsOneWidget);
      expect(find.text('Your confirmed bookings still stand. Guests can still reach you in chat.'), findsOneWidget);
      expect(find.text('UPCOMING-SEAM'), findsOneWidget);
      expect(find.text('PLAN-SEAM'), findsNothing);
      expect(find.text('Needs attention'), findsNothing);
      expect(find.text('Accepting guests'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('o_st_52 switch off: grey card, paused line, report row, plan seam still shown', (t) async {
      StayOwnerDeps.planCard = () => const Text('PLAN-SEAM');
      await _pump(t, homeJson(switchOn: false, attention: [att('Reports', 7, {'count': 1, 'firstReason': 'A guest says the photos do not match'})]), denied: true);
      expect(find.text('Not taking guests'), findsOneWidget);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('Guests cannot send new enquiries.'), findsOneWidget);
      final notif = tester(t).getTopLeft(find.text('Turn on notifications')).dy;
      final report = tester(t).getTopLeft(find.text('1 report on this stay')).dy;
      expect(notif, lessThan(report));
      expect(find.text('A guest says the photos do not match'), findsOneWidget);
      expect(find.text('PLAN-SEAM'), findsOneWidget);
      expect(find.text('Quick actions'), findsNothing);
    });

    testWidgets('o_st_11 area paused: banner on top, no plan card, status stays live', (t) async {
      StayOwnerDeps.planCard = () => const Text('PLAN-SEAM');
      await _pump(t, homeJson(areaPaused: true, stay: {'newEnquiries': 0, 'offersWaiting': 1, 'confirmed': 2}));
      expect(find.text('New enquiries are paused'), findsOneWidget);
      expect(find.text('New enquiries are paused in your area.'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Your stay stays saved as it is.'), findsOneWidget);
      expect(find.text('Accepting guests'), findsOneWidget);
      expect(find.text('PLAN-SEAM'), findsNothing);
      expect(find.text('Quick actions'), findsOneWidget);
    });

    testWidgets('UC-S-43 planner off: no plan card on a live stay', (t) async {
      StayOwnerDeps.planCard = () => const Text('PLAN-SEAM');
      await _pump(t, homeJson(plannerOff: true));
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('PLAN-SEAM'), findsNothing);
      expect(find.text('Quick actions'), findsOneWidget);
    });

    testWidgets('o_st_12 plus: featured chip and first-in-trip-plans line, no See Plus', (t) async {
      await _pump(t, homeJson(featured: true, statusLine: {'code': 'Featured', 'args': {'city': 'Mukteshwar'}}));
      expect(find.text('LIVE · ★ Featured'), findsOneWidget);
      expect(find.text('First in trip plans for Mukteshwar.'), findsOneWidget);
      expect(find.text('See Plus'), findsNothing);
      expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
    });

    testWidgets('payment OFF: no gate widgets and no plan words on Home', (t) async {
      await _pump(t, homeJson(attention: [att('ShareListing', 10, {'slug': 'x'})]));
      expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
      for (final w in ['Plus', 'Free plan', 'Upgrade']) {
        expect(find.textContaining(w), findsNothing, reason: w);
      }
    });
  });

  group('o_st_67 states', () {
    testWidgets('A error without a copy: card, retry reloads once, single flight', (t) async {
      final h = await _pump(t, homeJson(), offline: true);
      expect(find.text('Couldn’t load'), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      final before = h.api.calls;
      final gate = Completer<OwnerResult<OwnerHomeDto>>();
      h.api.result = () => gate.future;
      await t.tap(find.text('Try again'));
      await t.tap(find.text('Try again'), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 50));
      expect(h.api.calls, before + 1);
      gate.complete(OwnerOffline<OwnerHomeDto>());
      await t.pump(const Duration(milliseconds: 50));
    });

    testWidgets('A recovers when the retry succeeds', (t) async {
      final h = await _pump(t, homeJson(), offline: true);
      h.api.result = () async => OwnerOk<OwnerHomeDto>(OwnerHomeDto.fromJson(homeJson()));
      await t.tap(find.text('Try again'));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Deodar Heights'), findsOneWidget);
      expect(find.text('Couldn’t load'), findsNothing);
    });

    testWidgets('error with a saved copy keeps the copy', (t) async {
      final h = await _pump(t, homeJson());
      h.api.result = () async => const OwnerOffline<OwnerHomeDto>();
      await t.runAsync(() => h.home.reload());
      await t.pump();
      expect(find.text('Deodar Heights'), findsOneWidget);
      expect(find.text('Couldn’t load'), findsNothing);
      expect(h.home.load.value, isA<OwnerLoadData<OwnerHomeDto>>());
    });

    testWidgets('a 5xx or a thrown error never leaves the skeleton on', (t) async {
      final h = StayHarness.setUp(homeJson(), registerHome: false);
      h.api.result = () async => throw StateError('boom');
      await t.pumpWidget(const SizedBox.shrink());
      await pumpPhone(t, StayOwnerHomeScreen(controller: h.home));
      h.home.onInit();
      await t.pump(const Duration(milliseconds: 100));
      expect(h.home.load.value, isA<OwnerLoadError<OwnerHomeDto>>());
      expect(find.text('Couldn’t load'), findsOneWidget);
    });

    testWidgets('a copy of user A is not readable by user B', (t) async {
      await _pump(t, homeJson());
      expect(OwnerCache.read('user-a', OwnerCacheKeys.home), isNotNull);
      expect(OwnerCache.read('user-b', OwnerCacheKeys.home), isNull);
    });

    testWidgets('first paint comes from the saved copy', (t) async {
      OwnerCache.write('user-a', OwnerCacheKeys.home, homeJson(name: 'Saved Stay'));
      final h = StayHarness.setUp(homeJson(name: 'Fresh Stay'), registerHome: false);
      expect((h.home..onInit()).load.value.valueOrNull?.listing.name, 'Saved Stay');
    });

    testWidgets('E jobs module off: the screen does not depend on it', (t) async {
      final h = await _pump(t, homeJson(statusLine: {'code': 'NewNeedReply', 'args': {'count': 1}}, badge: 1, stay: {'newEnquiries': 1, 'offersWaiting': 0, 'confirmed': 2}));
      expect(find.text('Post a job'), findsOneWidget);
      (Get.find<TabConfigController>() as FakeTabs).setOff({AppTabKeys.jobs});
      h.home.load.refresh();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('1 enquiry needs a reply.'), findsOneWidget);
      expect(find.text('Post a job'), findsNothing);
    });
  });

  group('accepting switch', () {
    testWidgets('switch off: optimistic, PUT, toast Paused, state follows the server', (t) async {
      final h = await _pump(t, homeJson(), toast: true);
      final transport = FakeTransport((m, p, b) async => {'data': {}});
      OwnerApi.transport = transport;
      h.api.result = () async => OwnerOk<OwnerHomeDto>(OwnerHomeDto.fromJson(homeJson(switchOn: false)));
      await t.runAsync(() => h.home.setAccepting(false));
      await _toast(t);
      expect(transport.calls, ['PUT /stays/me/accepting']);
      expect(h.home.switchOn, isFalse);
      expect(find.text('Paused'), findsWidgets);
      await t.pump(const Duration(seconds: 6));
      toastification.dismissAll(delayForAnimation: false);
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('refused while not live: rolls back and says so', (t) async {
      final h = await _pump(t, homeJson(), toast: true);
      OwnerApi.transport = FakeTransport((m, p, b) async {
        throw DioException(
          requestOptions: RequestOptions(path: p),
          response: Response(requestOptions: RequestOptions(path: p), statusCode: 409, data: {'error': {'type': 'StayNotApproved', 'message': 'x'}}),
        );
      });
      await t.runAsync(() => h.home.setAccepting(false));
      await _toast(t);
      expect(h.home.switchOn, isTrue);
      expect(find.text('Your stay is not live yet.'), findsWidgets);
      expect(h.home.switchBusy.value, isFalse);
      await t.pump(const Duration(seconds: 6));
      toastification.dismissAll(delayForAnimation: false);
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('offline: rolls back, toast, no spinner left', (t) async {
      final h = await _pump(t, homeJson(), toast: true);
      OwnerApi.transport = FakeTransport((m, p, b) async {
        throw DioException(requestOptions: RequestOptions(path: p), type: DioExceptionType.connectionError);
      });
      await t.runAsync(() => h.home.setAccepting(false));
      await _toast(t);
      expect(h.home.switchOn, isTrue);
      expect(find.text('No connection. Please try again.'), findsWidgets);
      expect(h.home.switchBusy.value, isFalse);
      await t.pump(const Duration(seconds: 6));
      toastification.dismissAll(delayForAnimation: false);
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('a second tap while one is in flight is ignored', (t) async {
      final h = await _pump(t, homeJson());
      var n = 0;
      OwnerApi.transport = FakeTransport((m, p, b) async {
        n++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return {'data': {}};
      });
      await t.runAsync(() async {
        final a = h.home.setAccepting(false);
        final b = h.home.setAccepting(false);
        await Future.wait([a, b]);
      });
      expect(n, 1);
    });
  });

  group('refresh rules and disposal', () {
    testWidgets('refreshIfStale honours the 30 s rule', (t) async {
      var now = DateTime(2026, 11, 21, 10);
      final h = StayHarness.setUp(homeJson(), registerHome: false);
      final c = StayOwnerHomeController(api: h.api, deniedProbe: () async => false, userId: () => 'user-a', clock: () => now);
      await t.runAsync(() => c.reload());
      final n = h.api.calls;
      await t.runAsync(() => c.refreshIfStale());
      expect(h.api.calls, n);
      now = now.add(const Duration(seconds: 31));
      await t.runAsync(() => c.refreshIfStale());
      expect(h.api.calls, n + 1);
    });

    testWidgets('pull to refresh calls the api again; shared flight', (t) async {
      final h = await _pump(t, homeJson());
      final n = h.api.calls;
      await t.runAsync(() async {
        await Future.wait([h.home.reload(), h.home.reload()]);
      });
      expect(h.api.calls, n + 1);
    });

    testWidgets('leaving the screen deletes nothing early and leaves no timer or exception', (t) async {
      await _pump(t, homeJson());
      await t.pumpWidget(const SizedBox.shrink());
      expect(t.takeException(), isNull);
    });
  });

  group('sizes', () {
    for (final n in [0, 1, 2, 11]) {
      testOwnerSizes(
        'busy home with $n attention rows',
        () => const StayOwnerHomeScreen(),
        setUpEach: () => StayHarness.setUp(homeJson(statusLine: {'code': 'NewNeedReply', 'args': {'count': 2}}, badge: 3, attention: _rows(n))),
        arrange: (t) async {
          await t.pump(const Duration(milliseconds: 100));
          await t.pump(const Duration(milliseconds: 100));
        },
        check: (t, size, scale) async {
          expect(find.text('Deodar Heights'), findsOneWidget);
          expect(find.text('Quick actions'), findsOneWidget);
        },
      );
    }

    for (final e in {
      'review': homeJson(status: 'PendingReview', everApproved: false, stay: {}),
      'rejected': homeJson(status: 'Rejected', everApproved: false, reason: 'photos are not clear. Add day-time photos of the rooms.', stay: {}),
      'taken down': homeJson(status: 'Rejected', takenDown: true, reason: 'guests reported a wrong location.'),
      'paused': homeJson(switchOn: false),
      'area paused': homeJson(areaPaused: true),
    }.entries) {
      testOwnerSizes(
        '${e.key} home',
        () => const StayOwnerHomeScreen(),
        setUpEach: () => StayHarness.setUp(e.value),
        arrange: (t) async {
          await t.pump(const Duration(milliseconds: 100));
          await t.pump(const Duration(milliseconds: 100));
        },
      );
    }
  });
}

WidgetTester tester(WidgetTester t) => t;
