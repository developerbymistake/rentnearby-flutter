import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/triplimit/trip_limit_actions.dart';
import 'package:bakhli/features/buddy/triplimit/trip_limit_api.dart';
import 'package:bakhli/features/buddy/triplimit/trip_limit_gate.dart';
import 'package:bakhli/features/buddy/triplimit/trip_limit_models.dart';
import 'package:bakhli/features/buddy/triplimit/trip_limit_sheet.dart';
import 'package:bakhli/features/buddy/triplimit/trip_limit_strings.dart';
import 'package:bakhli/features/buddy/viewer/controllers/trip_invite_controller.dart';
import 'package:bakhli/features/buddy/viewer/models/viewer_models.dart';
import 'package:bakhli/features/buddy/viewer/screens/trip_invite_screen.dart';
import 'package:bakhli/features/buddy/viewer/viewer_deps.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/screens/my_trips_screen.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../../../support/real_phone.dart';
import '../viewer/viewer_fixtures.dart';

Map<String, dynamic> _t(String id, String title, String role, String? s, String? e, {String? owner}) =>
    {'id': id, 'title': title, 'role': role, 'startDate': s, 'endDate': e, 'ownerName': owner};

Map<String, dynamic> _planData() => {
      'limit': 3,
      'count': 3,
      'trips': [
        _t('t1', 'Old Manali Trip', 'Owner', '2026-03-02', '2026-03-06'),
        _t('t2', 'Uttarakhand Hills Trip', 'Owner', '2026-05-16', '2026-05-22'),
        _t('t3', 'Goa Trip', 'Viewer', '2026-06-04', '2026-06-08', owner: 'Aman'),
      ],
    };

Map<String, dynamic> _inviteData() => {
      'limit': 3,
      'count': 3,
      'trips': [
        _t('t1', 'Old Manali Trip', 'Owner', '2026-03-02', '2026-03-06'),
        _t('t2', 'Rajasthan Forts Trip', 'owner', null, null),
        _t('t3', 'Goa Trip', 'Viewer', '2026-06-04', '2026-06-08', owner: 'Priya'),
      ],
    };

class _Actions extends TripLimitActions {
  _Actions({this.deleteOk = true});

  final bool deleteOk;
  final List<String> deleted = [];
  final List<String> left = [];

  @override
  Future<bool> deleteOwned(BuildContext context, TripSlotTrip trip) async {
    if (deleteOk) deleted.add(trip.id);
    return deleteOk;
  }

  @override
  Future<bool> leave(BuildContext context, TripSlotTrip trip) async {
    left.add(trip.id);
    return true;
  }
}

class _FakeLimitApi extends TripLimitApi {
  const _FakeLimitApi(this.result);

  final BuddyResult<TripSlots> result;

  @override
  Future<BuddyResult<TripSlots>> slots() async => result;
}

bool? _closed;

Future<void> _pumpApp(WidgetTester t, Widget child) => pumpPhone(t, child, toastHost: true);

Widget _opener(TripSlots slots, TripLimitReason reason, TripLimitActions actions) => Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: TextButton(
            key: const ValueKey('open_limit'),
            onPressed: () async => _closed = await TripLimitSheet.show(ctx, slots, reason: reason, actions: actions),
            child: const Text('open'),
          ),
        ),
      ),
    );

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _open(WidgetTester t) async {
  _closed = null;
  await t.tap(find.byKey(const ValueKey('open_limit')));
  await _settle(t);
}

void main() {
  useBuddyRenderScale();
  setUp(() {
    useMemoryCache();
    TripClock.clockUtc = () => DateTime.utc(2026, 5, 10, 6);
  });
  tearDown(() {
    ViewerDeps.debugReset();
    TripLimitGate.debugReset();
    TripClock.resetClock();
    BuddyLive.reset();
    Get.reset();
  });

  group('models', () {
    test('fromRefusal reads the contract body and lower-cases the role', () {
      final s = TripSlots.fromRefusal(_inviteData());
      expect((s.limit, s.count, s.trips.length), (3, 3, 3));
      expect(s.trips[1].isOwner, isTrue);
      expect(s.trips[1].startDate, isNull);
      expect(s.trips[2].isOwner, isFalse);
      expect(s.trips[2].ownerName, 'Priya');
      expect(s.isFull, isTrue);
    });

    test('fromRefusal is tolerant of missing fields', () {
      final s = TripSlots.fromRefusal(const {});
      expect((s.limit, s.count, s.trips.length), (3, 0, 0));
      final odd = TripSlots.fromRefusal({
        'limit': 0,
        'trips': [
          {'id': 'x'}
        ],
      });
      expect((odd.limit, odd.count), (3, 1));
      expect(odd.trips.single.title, '');
    });

    test('without drops one trip and one slot', () {
      final s = TripSlots.fromRefusal(_planData()).without('t1');
      expect((s.count, s.trips.length, s.isFull), (2, 2, false));
      expect(TripSlots.fromRefusal(_planData()).without('nope').count, 3);
    });

    test('ended only when the end date is before today', () {
      final s = TripSlots.fromRefusal(_planData());
      final today = DateTime(2026, 5, 10);
      expect(s.trips.map((t) => t.endedBy(today)), [true, false, false]);
    });

    test('strings follow the frames', () {
      expect(TripLimitStrings.body(TripLimitReason.plan, 3), 'You can keep 3 trips. Delete one to plan a new trip.');
      expect(TripLimitStrings.body(TripLimitReason.invite, 3), 'You can keep 3 trips. Delete or leave one to join this trip.');
      expect(TripLimitStrings.ownLine(DateTime(2026, 5, 16), DateTime(2026, 5, 22)), 'Your plan · 16 – 22 May');
      expect(TripLimitStrings.ownLine(null, null), 'Your plan · No dates yet');
      expect(TripLimitStrings.viewerLine('Aman', DateTime(2026, 6, 4), DateTime(2026, 6, 8)), 'Aman’s trip · 4 – 8 Jun');
    });
  });

  group('sheet', () {
    testWidgets('plan reason shows the rows and no invite note', (t) async {
      await _pumpApp(t, _opener(TripSlots.fromRefusal(_planData()), TripLimitReason.plan, _Actions()));
      await _open(t);
      expect(find.text('Trip limit reached'), findsOneWidget);
      expect(find.text('You can keep 3 trips. Delete one to plan a new trip.'), findsOneWidget);
      expect(find.text('Old Manali Trip'), findsOneWidget);
      expect(find.text('Your plan · 2 – 6 Mar'), findsOneWidget);
      expect(find.text('Ended'), findsOneWidget);
      expect(find.text('Aman’s trip · 4 – 8 Jun'), findsOneWidget);
      expect(find.text('Delete'), findsNWidgets(2));
      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.text(TripLimitStrings.inviteWaits), findsNothing);
    });

    testWidgets('invite reason shows the waiting note and the no-dates line', (t) async {
      await _pumpApp(t, _opener(TripSlots.fromRefusal(_inviteData()), TripLimitReason.invite, _Actions()));
      await _open(t);
      expect(find.text('You can keep 3 trips. Delete or leave one to join this trip.'), findsOneWidget);
      expect(find.text('Your plan · No dates yet'), findsOneWidget);
      expect(find.text('Priya’s trip · 4 – 8 Jun'), findsOneWidget);
      expect(find.text('Your invite stays waiting.'), findsOneWidget);
    });

    testWidgets('delete frees a slot and closes with true', (t) async {
      final a = _Actions();
      await _pumpApp(t, _opener(TripSlots.fromRefusal(_planData()), TripLimitReason.plan, a));
      await _open(t);
      await t.tap(find.byKey(const ValueKey('trip_limit_action_t1')));
      await _settle(t);
      expect(a.deleted, ['t1']);
      expect(_closed, isTrue);
    });

    testWidgets('leave on the viewer row frees a slot', (t) async {
      final a = _Actions();
      await _pumpApp(t, _opener(TripSlots.fromRefusal(_planData()), TripLimitReason.plan, a));
      await _open(t);
      await t.tap(find.byKey(const ValueKey('trip_limit_action_t3')));
      await _settle(t);
      expect(a.left, ['t3']);
      expect(_closed, isTrue);
    });

    testWidgets('a refused delete keeps the row and the sheet', (t) async {
      final a = _Actions(deleteOk: false);
      await _pumpApp(t, _opener(TripSlots.fromRefusal(_planData()), TripLimitReason.plan, a));
      await _open(t);
      await t.tap(find.byKey(const ValueKey('trip_limit_action_t1')));
      await _settle(t);
      expect(find.text('Old Manali Trip'), findsOneWidget);
      expect(_closed, isNull);
    });

    testWidgets('not now closes with false', (t) async {
      await _pumpApp(t, _opener(TripSlots.fromRefusal(_planData()), TripLimitReason.plan, _Actions()));
      await _open(t);
      await t.tap(find.byKey(const ValueKey('trip_limit_not_now')));
      await _settle(t);
      expect(_closed, isFalse);
    });

    testWidgets('over the limit: the row goes away and the sheet stays until a slot is free', (t) async {
      final data = _planData();
      (data['trips'] as List).add(_t('t4', 'Extra Trip', 'Owner', null, null));
      data['count'] = 4;
      final a = _Actions();
      await _pumpApp(t, _opener(TripSlots.fromRefusal(data), TripLimitReason.plan, a));
      await _open(t);
      await t.tap(find.byKey(const ValueKey('trip_limit_action_t4')));
      await _settle(t);
      expect(find.text('Extra Trip'), findsNothing);
      expect(_closed, isNull);
    });
  });

  group('invite controller', () {
    BuddyRefused<String> limit() => BuddyRefused<String>(type: 'TripLimitReached', statusCode: 409, data: _inviteData());

    test('limit refusal keeps ready, prompts, and joins again after a free slot', () async {
      registerViewerFakes();
      final api = FakeViewerApi(preview: BuddyOk(InvitePreview.fromJson(sample('s7_invite_preview'))))..accept = limit();
      final prompts = <TripSlots>[];
      final c = TripInviteController(memberId, api: api, limitPrompt: (s) async {
        prompts.add(s);
        api.accept = const BuddyOk(tripId);
        return true;
      });
      Get.put(c);
      await c.load();
      await c.join();
      expect(prompts.single.trips.length, 3);
      expect(api.acceptCalls, 2);
      expect(c.state.value, TripInviteState.ready);
      expect(BuddyLive.sharedTrips.value, 1);
    });

    test('closing the sheet leaves the invite ready and does not retry', () async {
      final api = FakeViewerApi(preview: BuddyOk(InvitePreview.fromJson(sample('s7_invite_preview'))))..accept = limit();
      final c = TripInviteController(memberId, api: api, limitPrompt: (_) async => false);
      Get.put(c);
      await c.load();
      await c.join();
      expect(api.acceptCalls, 1);
      expect(c.state.value, TripInviteState.ready);
      expect(c.joining.value, isFalse);
      expect(c.full.value, isFalse);
    });

    test('an old server answer without the type keeps the old behaviour', () async {
      final api = FakeViewerApi(preview: BuddyOk(InvitePreview.fromJson(sample('s7_invite_preview'))))
        ..accept = const BuddyRefused<String>(type: 'TripFull', statusCode: 409);
      var prompted = false;
      final c = TripInviteController(memberId, api: api, limitPrompt: (_) async => prompted = true);
      Get.put(c);
      await c.load();
      await c.join();
      expect(prompted, isFalse);
      expect(c.state.value, TripInviteState.ended);
    });
  });

  group('gate', () {
    testWidgets('passes on 404, offline and failure, and when a slot is free', (t) async {
      await _pumpApp(t, const SizedBox());
      for (final r in <BuddyResult<TripSlots>>[
        const BuddyRefused<TripSlots>(type: null, statusCode: 404),
        BuddyOffline<TripSlots>(),
        const BuddyFailed<TripSlots>(message: 'x'),
        const BuddyOk(TripSlots(limit: 3, count: 2, trips: [])),
      ]) {
        TripLimitGate.api = _FakeLimitApi(r);
        expect(await TripLimitGate.ensureSlot(), isTrue);
      }
    });

    testWidgets('full: shows the sheet and Not now blocks the caller', (t) async {
      TripLimitGate.api = _FakeLimitApi(BuddyOk(TripSlots.fromRefusal(_planData())));
      await _pumpApp(
        t,
        Builder(
          builder: (ctx) => Center(
            child: TextButton(
              key: const ValueKey('go'),
              onPressed: () async => _closed = await TripLimitGate.ensureSlot(ctx),
              child: const Text('go'),
            ),
          ),
        ),
      );
      _closed = null;
      await t.tap(find.byKey(const ValueKey('go')));
      await _settle(t);
      expect(find.text('Trip limit reached'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('trip_limit_not_now')));
      await _settle(t);
      expect(_closed, isFalse);
    });
  });

  group('frames', () {
    Widget myTrips() {
      Get.put<MyTripsController>(FakeMyTrips(), permanent: true);
      registerViewerFakes(api: FakeViewerApi(sharedResult: BuddyOk(sharedTrips())));
      return const MyTripsScreen();
    }

    testWidgets('3.16 trip limit reached while planning', (t) async {
      final slots = TripSlots.fromRefusal(_planData());
      await renderFrame(t, '3.16', myTrips(), arrange: (t) async {
        final ctx = t.element(find.byType(MyTripsScreen));
        TripLimitSheet.show(ctx, slots, reason: TripLimitReason.plan, actions: _Actions());
        await t.pump(const Duration(milliseconds: 600));
      });
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 6));
    });

    testWidgets('3.17 trip limit reached while accepting an invite', (t) async {
      final slots = TripSlots.fromRefusal(_inviteData());
      final api = FakeViewerApi(preview: BuddyOk(InvitePreview.fromJson(sample('s7_invite_preview'))));
      await renderFrame(t, '3.17', TripInviteScreen(memberId: memberId, api: api), arrange: (t) async {
        final ctx = t.element(find.byType(TripInviteScreen));
        TripLimitSheet.show(ctx, slots, reason: TripLimitReason.invite, actions: _Actions());
        await t.pump(const Duration(milliseconds: 600));
      });
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 6));
    });
  });
}
