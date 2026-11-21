import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_screen.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_sheets.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_attention_copy.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_controller.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_screen.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_home_compose.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_home_strings.dart';
import 'package:bakhli/screens/profile/profile_rows_taxi_driver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';
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

    test('one banner at a time, planner switch wins', () {
      final both = dto(homeJson(areaPaused: true, plannerOff: true)).listing;
      expect(TaxiHomeCompose.banner(TaxiHomeState.live, both), TaxiHomeStrings.plannerPaused);
      final area = dto(homeJson(areaPaused: true)).listing;
      expect(TaxiHomeCompose.banner(TaxiHomeState.live, area), TaxiHomeStrings.areaPaused);
      expect(TaxiHomeCompose.banner(TaxiHomeState.live, dto(homeJson()).listing), isNull);
      expect(TaxiHomeCompose.showsPlanCard(TaxiHomeState.live, area), isFalse);
      expect(TaxiHomeCompose.showsPlanCard(TaxiHomeState.offline, dto(homeJson()).listing), isTrue);
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
      expect(h.api.calls, greaterThan(before));
      Get.delete<TaxiDriverHomeController>(force: true);
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

