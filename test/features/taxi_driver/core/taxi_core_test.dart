import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/home/numbers_row.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_screen.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_sheets.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_attention_copy.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_controller.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_screen.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_home_compose.dart';
import 'package:bakhli/features/taxi_driver/plan/taxi_home_plan_card.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_home_strings.dart';
import 'package:bakhli/features/taxi_driver/widgets/taxi_widgets.dart';
import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/screens/profile/profile_rows_taxi_driver.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import 'taxi_fixtures.dart';

OwnerHomeDto dto(Map<String, dynamic> j) => OwnerHomeDto.fromJson(j);

void main() {
  setUpAll(() => initTestStorage('taxi_core'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  group('compose', () {
    test('state of the listing', () {
      OwnerHomeListing l(Map<String, dynamic> j) => dto(j).listing;
      expect(TaxiHomeCompose.stateOf(l(homeJson())), TaxiHomeState.live);
      expect(TaxiHomeCompose.stateOf(l(homeJson(switchOn: false))), TaxiHomeState.offline);
      expect(TaxiHomeCompose.stateOf(l(homeJson(status: 'PendingReview', everApproved: false))), TaxiHomeState.review);
      expect(TaxiHomeCompose.stateOf(l(homeJson(status: 'PendingReview'))), TaxiHomeState.changesReview);
      expect(TaxiHomeCompose.stateOf(l(homeJson(status: 'Rejected', everApproved: false))), TaxiHomeState.rejected);
      expect(TaxiHomeCompose.stateOf(l(homeJson(status: 'Rejected', takenDown: true))), TaxiHomeState.takenDown);
    });

    test('ring strip follows the switch and the phone notification setting', () {
      expect(TaxiHomeCompose.shown(TaxiHomeState.live, switchOn: false), TaxiHomeState.offline);
      expect(TaxiHomeCompose.shown(TaxiHomeState.offline, switchOn: true), TaxiHomeState.live);
      expect(TaxiHomeCompose.shown(TaxiHomeState.changesReview, switchOn: true), TaxiHomeState.changesReview);
      expect(TaxiHomeCompose.ringStrip(TaxiHomeState.live, denied: false), TaxiRingStrip.ringing);
      expect(TaxiHomeCompose.ringStrip(TaxiHomeState.live, denied: true), TaxiRingStrip.muted);
      expect(TaxiHomeCompose.ringStrip(TaxiHomeState.offline, denied: true), TaxiRingStrip.offline);
      expect(TaxiHomeCompose.ringStrip(TaxiHomeState.offline, denied: false), TaxiRingStrip.offline);
      for (final s in [TaxiHomeState.review, TaxiHomeState.changesReview, TaxiHomeState.rejected, TaxiHomeState.takenDown]) {
        expect(TaxiHomeCompose.ringStrip(s, denied: false), isNull, reason: '$s');
      }
      expect(identical(TaxiHomeCompose.tone(TaxiHomeState.live), ListingTone.cE), isTrue);
      expect(identical(TaxiHomeCompose.tone(TaxiHomeState.offline), TaxiLook.grey), isTrue);
      expect(TaxiHomeCompose.line(TaxiHomeState.offline, dto(homeJson()).listing), 'Offline · not taking requests');
    });

    test('home listing parses the photo, car name and seats', () {
      final l = dto(homeJson(photo: 'https://res.cloudinary.com/x/taxi.jpg', seats: 12)).listing;
      expect(l.displayPhotoUrl, 'https://res.cloudinary.com/x/taxi.jpg');
      expect(l.vehicleName, 'Maruti Ertiga');
      expect(l.seats, 12);
      expect(TaxiHomeStrings.seats(12), '12+ seats');
      expect(TaxiHomeStrings.seats(6), '6 seats');
      final bare = dto(homeJson(vehicleName: null, seats: null)).listing;
      expect(bare.displayPhotoUrl, isNull);
      expect(bare.vehicleName, isNull);
      expect(bare.seats, isNull);
    });

    test('one banner at a time, planner switch wins', () {
      final both = dto(homeJson(areaPaused: true, plannerOff: true)).listing;
      expect(TaxiHomeCompose.banner(TaxiHomeState.live, both), TaxiHomeStrings.plannerPaused);
      final area = dto(homeJson(areaPaused: true)).listing;
      expect(TaxiHomeCompose.banner(TaxiHomeState.live, area), TaxiHomeStrings.areaPaused);
      expect(TaxiHomeCompose.banner(TaxiHomeState.live, dto(homeJson()).listing), isNull);
    });

    test('attention: order by priority, unknown code skipped, client row at position 3, count', () {
      final d = dto(homeJson(attention: [att('Reports', 7, {'count': 1}), att('TravellerChoseYou', 1, {'offerId': 'o', 'confirmBy': DateTime.now().add(const Duration(minutes: 5)).toUtc().toIso8601String()}), att('Mystery', 6), att('NoPushToken', 2)], attentionCount: 4));
      final rows = TaxiHomeCompose.attention(d, denied: true);
      expect([for (final r in rows) r.code], ['TravellerChoseYou', 'NoPushToken', 'NotificationsOff', 'Mystery', 'Reports']);
      final views = TaxiHomeCompose.rowViews(rows, TaxiHomeActions.attention('t'), DateTime.now());
      expect(views, hasLength(4));
      expect(TaxiHomeCompose.attentionCount(d, rows, denied: true), 5);
      expect(TaxiHomeCompose.attentionCount(d, TaxiHomeCompose.attention(d, denied: false), denied: false), 4);
    });

    test('attention copy never prints money', () {
      final rows = TaxiHomeCompose.rowViews(
        [
          for (final c in ['NoPushToken', 'PaymentIssue', 'GetReady', 'AddLocalRate']) OwnerAttention(code: c),
          const OwnerAttention(code: 'Reports', args: {'count': 2}),
          const OwnerAttention(code: 'MissedRings', args: {'count': 3}),
          const OwnerAttention(code: 'PlanHidden', args: {'routes': 3}),
          const OwnerAttention(code: 'AddRoutes', args: {'fromCityName': 'Haldwani', 'toCityName': 'Badrinath'}),
        ],
        TaxiHomeActions.attention('t'),
        DateTime.now(),
        compact: false,
      );
      for (final r in rows) {
        expect('${r.title} ${r.sub}', isNot(contains('₹')));
        expect('${r.title} ${r.sub}'.toLowerCase(), isNot(contains('owed')));
      }
      expect(rows.map((r) => r.title), contains('Plus ended. 3 routes are hidden.'));
      expect(rows.map((r) => r.sub), contains('Add popular routes like Haldwani to Badrinath'));
    });

    test('chose you row: title, countdown line, coral Confirm; other pills are outlined', () {
      final now = DateTime(2026, 11, 21, 10);
      final by = now.add(const Duration(minutes: 12, seconds: 36)).toUtc().toIso8601String();
      final rows = TaxiHomeCompose.rowViews(
        [OwnerAttention(code: 'TravellerChoseYou', args: {'offerId': 'o', 'confirmBy': by}), const OwnerAttention(code: 'NoPushToken')],
        TaxiHomeActions.attention('t'),
        now,
      );
      expect(rows.first.title, 'A traveller chose you');
      expect(rows.first.sub, '12:36 left to confirm');
      expect((rows.first.trailing as TaxiPill).kind, TaxiPillKind.coral);
      expect((rows.last.trailing as TaxiPill).kind, TaxiPillKind.outline);
    });

    test('home plan card: hidden for the Free upsell, kept for the AFTER notices', () {
      for (final s in [PlanCardState.free, PlanCardState.unknown, PlanCardState.paymentOff]) {
        expect(TaxiHomePlanCard.showsOnHome(OwnerPlanCard(state: s)), isFalse, reason: '$s');
      }
      expect(TaxiHomePlanCard.showsOnHome(null), isFalse);
      for (final s in [PlanCardState.grace, PlanCardState.onHold, PlanCardState.ended, PlanCardState.cancelled, PlanCardState.plus, PlanCardState.trial]) {
        expect(TaxiHomePlanCard.showsOnHome(OwnerPlanCard(state: s)), isTrue, reason: '$s');
      }
    });

    test('countdown text', () {
      expect(TaxiAttentionCopy.countdown(const Duration(minutes: 12, seconds: 40)), '12:40');
      expect(TaxiAttentionCopy.countdown(const Duration(seconds: -5)), '00:00');
      expect(TaxiAttentionCopy.countdown(const Duration(seconds: 59)), '00:59');
    });
  });

  group('home controller', () {
    test('switch: under review makes no call', () async {
      var calls = 0;
      final h = TaxiHarness.setUp(homeJson(status: 'PendingReview', everApproved: false, switchOn: false), registerHome: false, switchCall: (on) async {
        calls++;
        return OwnerOk<void>(null);
      });
      await h.home.reload();
      await h.home.setAvailable(true);
      expect(calls, 0);
      expect(h.home.switchOn, isFalse);
      h.home.onClose();
    });

    test('switch on and off: calls the server, reloads, single flight', () async {
      final seen = <bool>[];
      final h = TaxiHarness.setUp(homeJson(switchOn: false), registerHome: false, switchCall: (on) async {
        seen.add(on);
        return OwnerOk<void>(null);
      });
      await h.home.reload();
      expect(h.home.switchOn, isFalse);
      final first = h.home.setAvailable(true);
      final second = h.home.setAvailable(true);
      await Future.wait([first, second]);
      expect(seen, [true]);
      h.home.onClose();
    });

    test('switch: refusal and offline roll the switch back', () async {
      for (final result in <OwnerResult<void>>[OwnerRefused<void>(statusCode: 409, type: 'X', message: 'No'), OwnerOffline<void>(), OwnerFailed<void>(message: 'x')]) {
        final h = TaxiHarness.setUp(homeJson(switchOn: false), registerHome: false, switchCall: (on) async => result);
        await h.home.reload();
        await h.home.setAvailable(true);
        expect(h.home.switchOn, isFalse, reason: '$result');
        expect(h.home.switchBusy.value, isFalse);
        h.home.onClose();
      }
    });

    test('first load without data and offline: error, with saved copy: stale data', () async {
      final h = TaxiHarness.setUp(homeJson(), registerHome: false, offline: true);
      await h.home.reload();
      expect(h.home.data, isNull);
      h.home.onClose();
    });

    test('countdown row ticks from one timer and reloads once at zero', () async {
      var now = DateTime(2026, 11, 21, 10);
      final by = now.add(const Duration(seconds: 2)).toUtc().toIso8601String();
      final h = TaxiHarness.setUp(homeJson(attention: [att('TravellerChoseYou', 1, {'offerId': 'o', 'confirmBy': by})]), registerHome: false, clock: () => now);
      Get.put<TaxiDriverHomeController>(h.home);
      await h.home.reload();
      final before = h.api.calls;
      now = now.add(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(h.api.calls, before + 1);
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      expect(h.api.calls, before + 1, reason: 'an expired row the server still sends must not reload every second');
      Get.delete<TaxiDriverHomeController>(force: true);
    });

    test('countdown ticker stops while the app is in the background and restarts on resume', () async {
      var now = DateTime(2026, 11, 21, 10);
      final by = now.add(const Duration(seconds: 2)).toUtc().toIso8601String();
      final h = TaxiHarness.setUp(homeJson(attention: [att('TravellerChoseYou', 1, {'offerId': 'o', 'confirmBy': by})]), registerHome: false, clock: () => now);
      Get.put<TaxiDriverHomeController>(h.home);
      await h.home.reload();
      final before = h.api.calls;
      h.home.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(h.api.calls, before, reason: 'no tick in the background');
      h.home.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(h.api.calls, greaterThan(before));
      Get.delete<TaxiDriverHomeController>(force: true);
    });
  });

  group('home screen is reactive', () {
    Future<void> settle(WidgetTester t) async {
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
    }

    Future<void> finish(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      Get.delete<TaxiDriverHomeController>(force: true);
    }

    testWidgets('the Confirm countdown text changes every second', (tester) async {
      var now = DateTime(2026, 11, 21, 10);
      final by = now.add(const Duration(minutes: 12, seconds: 40)).toUtc().toIso8601String();
      final h = TaxiHarness.setUp(homeJson(attention: [att('TravellerChoseYou', 1, {'offerId': 'o', 'confirmBy': by})]), clock: () => now);
      await pumpPhone(tester, TaxiDriverHomeScreen(controller: h.home), size: const Size(360, 800));
      await settle(tester);
      expect(find.text('A traveller chose you'), findsOneWidget);
      expect(find.text('12:40 left to confirm'), findsOneWidget);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('12:39 left to confirm'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a countdown tick rebuilds only the attention card', (tester) async {
      var now = DateTime(2026, 11, 21, 10);
      final by = now.add(const Duration(minutes: 12, seconds: 40)).toUtc().toIso8601String();
      final h = TaxiHarness.setUp(homeJson(attention: [att('TravellerChoseYou', 1, {'offerId': 'o', 'confirmBy': by})]), clock: () => now);
      await pumpPhone(tester, TaxiDriverHomeScreen(controller: h.home), size: const Size(360, 800));
      await settle(tester);
      final numbers = tester.widget(find.byType(NumbersRow));
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('12:39 left to confirm'), findsOneWidget);
      expect(identical(tester.widget(find.byType(NumbersRow)), numbers), isTrue);
      await finish(tester);
    });

    testWidgets('the switch repaints at once and rolls back', (tester) async {
      final h = TaxiHarness.setUp(homeJson(switchOn: false, attention: const []));
      await pumpPhone(tester, TaxiDriverHomeScreen(controller: h.home), size: const Size(360, 800));
      await settle(tester);
      bool on() => tester.widget<Switch3D>(find.byType(Switch3D)).value;
      expect(on(), isFalse);
      h.home.switchOverride.value = true;
      await tester.pump();
      expect(on(), isTrue);
      h.home.switchOverride.value = null;
      await tester.pump();
      expect(on(), isFalse);
      await finish(tester);
    });

    testWidgets('hero: green band, car row, route and local day facts, ring strip, no Available now row', (tester) async {
      final h = TaxiHarness.setUp(homeJson(attention: const []));
      final hub = Get.put(TaxiHubController(userId: () => 'user-a', fetch: () async => {'data': taxiJson()}), tag: TaxiHubController.tag);
      await hub.reload();
      await pumpPhone(tester, TaxiDriverHomeScreen(controller: h.home), size: const Size(360, 1400));
      await settle(tester);
      final card = tester.widget<TaxiStatusCard>(find.byType(TaxiStatusCard));
      expect(identical(card.tone, ListingTone.cE), isTrue);
      expect(card.rows, isEmpty);
      expect(card.note, isNull);
      Finder inCard(Finder f) => find.descendant(of: find.byType(TaxiStatusCard), matching: f);
      expect(inCard(find.byType(OwnerFacts)), findsOneWidget);
      expect(inCard(find.byType(TaxiCarRow)), findsOneWidget);
      expect(inCard(find.text('Maruti Ertiga')), findsOneWidget);
      expect(inCard(find.text('6 seats')), findsOneWidget);
      expect(find.text('Route'), findsOneWidget);
      expect(find.text('₹2,500'), findsOneWidget);
      expect(find.text('Local day rate'), findsOneWidget);
      expect(inCard(find.text('Requests will ring')), findsOneWidget);
      expect(inCard(find.text('Notifications are on.')), findsOneWidget);
      expect(find.textContaining('Going offline'), findsNothing);
      expect(find.textContaining('Your bookings stay'), findsNothing);
      expect(inCard(find.textContaining('From')), findsNothing);
      expect(find.text('Available now'), findsNothing);
      expect(find.text('Next booking'), findsNothing);
      expect(find.text('Share my taxi'), findsNothing);
      await finish(tester);
    });

    testWidgets('ring strip: switch off turns the band grey and says You are offline', (tester) async {
      final h = TaxiHarness.setUp(homeJson(switchOn: false, attention: const []));
      await pumpPhone(tester, TaxiDriverHomeScreen(controller: h.home), size: const Size(360, 1400));
      await settle(tester);
      Finder inCard(Finder f) => find.descendant(of: find.byType(TaxiStatusCard), matching: f);
      final card = tester.widget<TaxiStatusCard>(find.byType(TaxiStatusCard));
      expect(identical(card.tone, TaxiLook.grey), isTrue);
      expect(card.line, 'Offline · not taking requests');
      expect(inCard(find.text('You are offline')), findsOneWidget);
      expect(inCard(find.text('New requests will not ring.')), findsOneWidget);
      expect(inCard(find.text('Requests will ring')), findsNothing);
      expect(inCard(find.text('Turn on')), findsNothing);
      h.home.switchOverride.value = true;
      await tester.pump();
      expect(identical(tester.widget<TaxiStatusCard>(find.byType(TaxiStatusCard)).tone, ListingTone.cE), isTrue);
      expect(inCard(find.text('Requests will ring')), findsOneWidget);
      await finish(tester);
    });

    testWidgets('ring strip: online with phone notifications off shows the amber strip and Turn on', (tester) async {
      final h = TaxiHarness.setUp(homeJson(attention: const []), denied: true);
      await pumpPhone(tester, TaxiDriverHomeScreen(controller: h.home), size: const Size(360, 1400));
      await tester.runAsync(h.home.checkNotifications);
      await settle(tester);
      Finder inCard(Finder f) => find.descendant(of: find.byType(TaxiStatusCard), matching: f);
      expect(identical(tester.widget<TaxiStatusCard>(find.byType(TaxiStatusCard)).tone, ListingTone.cE), isTrue);
      expect(inCard(find.text('Notifications are off')), findsOneWidget);
      expect(inCard(find.text('Requests will not ring.')), findsOneWidget);
      final strip = tester.widget<TaxiRingStripView>(inCard(find.byType(TaxiRingStripView)));
      expect(strip.fill, TaxiLook.amberSoft);
      expect(strip.action, 'Turn on');
      expect(strip.onAction, isNotNull);
      expect(find.textContaining('Your bookings stay'), findsNothing);
      await finish(tester);
    });

    testWidgets('top band shows the taxi photo, else the taxi icon', (tester) async {
      final h = TaxiHarness.setUp(homeJson(attention: const [], photo: 'https://res.cloudinary.com/x/taxi.jpg'));
      await pumpPhone(tester, TaxiDriverHomeScreen(controller: h.home), size: const Size(360, 1400));
      await settle(tester);
      expect(tester.widget<TaxiStatusCard>(find.byType(TaxiStatusCard)).photoUrl, 'https://res.cloudinary.com/x/taxi.jpg');
      expect(find.byKey(TaxiStatusCard.photoKey), findsOneWidget);
      expect(tester.widget<KitPhoto>(find.byKey(TaxiStatusCard.photoKey)).url, 'https://res.cloudinary.com/x/taxi.jpg');
      await finish(tester);

      final h2 = TaxiHarness.setUp(homeJson(attention: const []));
      await pumpPhone(tester, TaxiDriverHomeScreen(controller: h2.home), size: const Size(360, 1400));
      await settle(tester);
      expect(tester.widget<TaxiStatusCard>(find.byType(TaxiStatusCard)).photoUrl, isNull);
      expect(find.byKey(TaxiStatusCard.photoKey), findsNothing);
      await finish(tester);
    });

    testWidgets('quick actions: Edit fares, Ready check, My rating in one rail, three colours', (tester) async {
      final h = TaxiHarness.setUp(homeJson(attention: const []));
      await pumpPhone(tester, TaxiDriverHomeScreen(controller: h.home), size: const Size(360, 1600));
      await settle(tester);
      final rail = tester.widget<TaxiRail>(find.byType(TaxiRail));
      expect([for (final t in rail.tiles) t.title], ['Edit fares', 'Ready check', 'My rating']);
      expect(identical(rail.tiles[0].tone, ListingTone.coral), isTrue);
      expect(identical(rail.tiles[1].tone, ListingTone.sunrise), isTrue);
      expect(identical(rail.tiles[2].tone, ListingTone.indigo), isTrue);
      expect(find.byType(MealsRail), findsOneWidget);
      await finish(tester);
    });

    testWidgets('needs attention: white card, A traveller chose you, filled Confirm', (tester) async {
      final now = DateTime(2026, 11, 21, 10);
      final by = now.add(const Duration(minutes: 12, seconds: 36)).toUtc().toIso8601String();
      final h = TaxiHarness.setUp(homeJson(attention: [att('TravellerChoseYou', 1, {'offerId': 'o', 'confirmBy': by})]), clock: () => now);
      await pumpPhone(tester, TaxiDriverHomeScreen(controller: h.home), size: const Size(360, 1400));
      await settle(tester);
      final card = tester.widget<TaxiRowsCard>(find.ancestor(of: find.text('A traveller chose you'), matching: find.byType(TaxiRowsCard)).first);
      expect(card.fill, const Color(0xFFFFFFFF));
      final pill = tester.widget<TaxiPill>(find.ancestor(of: find.text('Confirm'), matching: find.byType(TaxiPill)).first);
      expect(pill.kind, TaxiPillKind.coral);
      await finish(tester);
    });
  });

  group('rules and parsing', () {
    test('fare boundaries', () {
      for (final e in {'99': false, '100': true, '9900000': true, '9900001': false, '': false, '9,900,000': true}.entries) {
        expect(TaxiRules.fareOk(TaxiRules.parse(e.key)), e.value, reason: e.key);
      }
      expect(TaxiRules.fareError(''), 'Enter the fare');
      expect(TaxiRules.fareError('99'), 'Fare must be between ₹100 and ₹99,00,000');
      expect(TaxiRules.fareError('100'), isNull);
    });

    test('km boundaries', () {
      for (final e in {'0': false, '1': true, '1000': true, '1001': false}.entries) {
        expect(TaxiRules.kmOk(TaxiRules.parse(e.key)), e.value, reason: e.key);
      }
    });

    test('TaxiOwnerModel: every variant parses without throwing', () {
      var n = 0;
      for (final v in jsonVariants(taxiJson(routes: 2, hidden: 1, routesMeter: {'key': 'Routes', 'used': 2, 'limit': 5}))) {
        expect(() => TaxiOwnerModel.fromJson(v), returnsNormally, reason: '$v');
        n++;
      }
      expect(n, greaterThan(20));
    });

    test('TaxiOwnerModel: new fields and a bad route element', () {
      final j = taxiJson(routes: 2, hidden: 2, featured: true, reports: 3, bookings: 2, routesMeter: {'key': 'Routes', 'used': 2, 'limit': 5});
      j['routes'] = [...(j['routes'] as List), 'garbage'];
      final m = TaxiOwnerModel.fromJson(j);
      expect(m.routes, hasLength(2));
      expect(m.hiddenRoutes, hasLength(2));
      expect(m.isFeatured, isTrue);
      expect(m.shownReportCount, 3);
      expect(m.activeBookingCount, 2);
      expect(m.routesMeter?.limit, 5);
      expect(m.routes.first.toPayload()['fare'], 1800);
    });

    test('profile rating line', () {
      expect(TaxiDriverProfileRows.ratingSub(4.8, 72), '4.8 from 72 ratings');
      expect(TaxiDriverProfileRows.ratingSub(null, null), 'No ratings yet');
      expect(TaxiDriverProfileRows.ratingSub(4.0, 0), 'No ratings yet');
    });
  });

  group('hub controller', () {
    test('empty and error', () async {
      final c = hubFor(null);
      await c.reload();
      expect(c.load.value.runtimeType.toString(), contains('Empty'));
    });

    test('delete taxi clears caches and goes empty', () async {
      final c = hubFor(taxiJson(bookings: 1), deleteTaxiCall: () async => OwnerOk<void>(null));
      await c.reload();
      expect(c.taxi?.id, 't1');
      OwnerCache.write('user-a', OwnerCacheKeys.home, {'x': 1});
      final ok = await c.deleteTaxi();
      expect(ok, isTrue);
      expect(OwnerCache.read('user-a', OwnerCacheKeys.home), isNull);
    });
  });

  group('sizes', () {
    for (final rows in [0, 1, 5]) {
      testOwnerSizes(
        'hub with $rows routes',
        () {
          final c = hubFor(taxiJson(routes: rows == 0 ? 1 : rows), plan: OwnerPlans.plus);
          return TaxiHubScreen(root: true, controller: c);
        },
        arrange: (t) async {
          await t.pump(const Duration(milliseconds: 100));
          await t.pump(const Duration(milliseconds: 100));
        },
      );
    }
    for (final n in [0, 1, 2, 11]) {
      testOwnerSizes(
        'home with $n attention rows',
        () {
          final rows = [
            for (var i = 0; i < n; i++) att('Reports', 7 + i, {'count': i + 1}),
          ];
          final h = TaxiHarness.setUp(homeJson(attention: rows, attentionCount: n, taxi: {'newRequests': 2, 'ratingAvg': 4.8, 'ratingCount': 3}));
          return TaxiDriverHomeScreen(controller: h.home);
        },
        arrange: (t) async {
          await t.pump(const Duration(milliseconds: 100));
          await t.pump(const Duration(milliseconds: 100));
        },
      );
    }
  });
}

