import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/plan/plan_bindings.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/sheets/owner_states.dart';
import 'package:bakhli/features/taxi/requests/widgets/driver_withdraw_sheet.dart';
import 'package:bakhli/features/taxi/setup/taxi_routes_screen.dart';
import 'package:bakhli/features/taxi/setup/taxi_vehicle_screen.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_calendar_entry_screen.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_trip_sheet.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_screen.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_controller.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_screen.dart';
import 'package:bakhli/features/taxi_driver/plan/taxi_plan_copy.dart';
import 'package:bakhli/features/taxi_driver/widgets/taxi_widgets.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/plan_model.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import '../../support/owner_fakes.dart';
import '../../support/real_phone.dart';
import 'calendar/taxi_cal_fixtures.dart';
import 'core/taxi_fixtures.dart';

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 120));
  }
}

TaxiRowData? _row(WidgetTester t, String title) {
  for (final card in t.widgetList<TaxiRowsCard>(find.byType(TaxiRowsCard))) {
    for (final r in card.rows) {
      if (r.title == title) return r;
    }
  }
  return null;
}

PlanModel _plan({required bool paid, required int routes}) => PlanModel(
      id: paid ? 'taxi_plus' : 'taxi_free',
      featureKey: 'Taxi',
      code: paid ? 'PLUS' : 'FREE',
      name: paid ? 'Plus' : 'Free',
      tagline: null,
      isDefault: !paid,
      trialDays: paid ? 7 : 0,
      features: {'Routes': routes},
      prices: const [],
    );

void main() {
  setUpAll(() => initTestStorage('taxi_fixer_regression'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    calTearDown();
  });

  group('FT-05 past trips are read-only except amounts and delete', () {
    testWidgets('past own trip: Edit amounts + Delete, no Edit', (t) async {
      final past = tripJson('m03', from: '2026-11-03', time: '08:00', fromPlace: 'Haldwani', label: 'Bhowali drop');
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(), plus: true)}, entries: {'m03': past}), plan: OwnerPlans.plus);
      await c.open(DateTime(2026, 11));
      await pumpPhone(t, TaxiCalendarEntryScreen(args: const {'id': 'm03'}, controller: c));
      await _settle(t);
      expect(find.text('Add amounts'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('future own trip keeps the full Edit', (t) async {
      final next = tripJson('m25', from: '2026-11-25', time: '09:30', fromPlace: 'Haldwani', toPlace: 'Mukteshwar', label: 'Mehra family', finalAmount: 2200, received: 0);
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(), plus: true)}, entries: {'m25': next}), plan: OwnerPlans.plus);
      await c.open(DateTime(2026, 11));
      await pumpPhone(t, TaxiCalendarEntryScreen(args: const {'id': 'm25'}, controller: c));
      await _settle(t);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    test('ended rule uses the last day against today', () {
      final e = CalendarEntry.fromJson(tripJson('x', from: '2026-11-20'));
      expect(TaxiTripEnded.of(e, DateTime(2026, 11, 21)), isTrue);
      expect(TaxiTripEnded.of(e, DateTime(2026, 11, 20)), isFalse);
    });

    test('past trip money note saves through the money route', () async {
      final past = tripJson('m03', from: '2026-11-03', label: 'Bhowali drop', version: 2);
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries(), plus: true)}, entries: {'m03': past});
      final c = calSetUp(fake, plan: OwnerPlans.plus);
      await c.open(DateTime(2026, 11));
      final r = await c.saveMoney(CalendarEntry.fromJson(past), finalAmount: 900, receivedSoFar: 900, paidInFull: true);
      expect(r, isA<OwnerOk<EntryWriteResult>>());
      expect(fake.count('PUT /taxis/me/calendar/entries/m03/money'), 1);
      expect((r as OwnerOk<EntryWriteResult>).value.entry?.paidInFull, isTrue);
    });

    testWidgets('409 EntryEnded closes the edit sheet and reloads the month', (t) async {
      final next = tripJson('m25', from: '2026-11-25', time: '09:30', fromPlace: 'Haldwani', label: 'Mehra family');
      final fake = CalFake(
        months: {'2026-11': monthJson(entries: novEntries(), plus: true)},
        writeRefusal: {
          'status': 409,
          'body': {
            'error': {'type': 'EntryEnded', 'message': 'This trip has ended.'},
          },
        },
      );
      final c = calSetUp(fake, plan: OwnerPlans.plus);
      await c.open(DateTime(2026, 11));
      bool? saved;
      await pumpPhone(
        t,
        Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () async => saved = await TaxiTripSheet.show(ctx, controller: c, editing: CalendarEntry.fromJson(next)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        toastHost: true,
      );
      await t.tap(find.text('open'));
      await _settle(t);
      int months() => fake.calls.where((x) => x == 'GET /taxis/me/calendar').length;
      final m0 = months();
      await t.ensureVisible(find.text('Save trip').last);
      await t.tap(find.text('Save trip').last);
      await _settle(t);
      expect(saved, isFalse);
      expect(months(), m0 + 1);
      await t.pump(const Duration(seconds: 5));
    });
  });

  group('FT-07 taxi calendar money wire', () {
    test('summary parses the server shape and the cache keeps the server keys', () async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(), plus: true)}), plan: OwnerPlans.plus);
      await c.open(DateTime(2026, 11));
      await c.loadSummary();
      final s = c.summary.value.valueOrNull!;
      expect((s.booked, s.received, s.toCollect, s.top.length), (17100, 11100, 6000, 3));
      final cached = OwnerCache.read('user-a', OwnerCacheKeys.summary('2026-11'))!;
      final back = MoneySummary.fromJson(cached);
      expect((back.booked, back.received, back.toCollect, back.top.length), (17100, 11100, 6000, 3));
    });

    test('reminder stays on after the PUT and after the month is rebuilt from an older answer', () async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries(), plus: true, reminderOn: false)});
      final c = calSetUp(fake, plan: OwnerPlans.plus);
      await c.open(DateTime(2026, 11));
      expect(c.reminderOn.value, isFalse);
      final r = await c.setReminder(true);
      expect(r, isA<OwnerOk<CalendarReminder>>());
      expect(c.reminderOn.value, isTrue);
      await c.reload();
      expect(c.reminderOn.value, isTrue);
    });

    test('mark paid reads the bare entry answer: Paid in full', () async {
      final row = tripJson('m25', from: '2026-11-25', label: 'Mehra family', finalAmount: 2200, received: 0, version: 3);
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries(), plus: true)}, entries: {'m25': row}), plan: OwnerPlans.plus);
      await c.open(DateTime(2026, 11));
      final r = await c.markPaid(CalendarEntry.fromJson(row));
      final e = (r as OwnerOk<EntryWriteResult>).value.entry!;
      expect(e.paidInFull, isTrue);
      expect(e.id, 'm25');
    });
  });

  group('FT-06 Home after Delete taxi', () {
    testWidgets('Empty shows the setup entry, not Could not load', (t) async {
      final h = TaxiHarness.setUp(homeJson());
      h.api.result = () async => const OwnerRefused<OwnerHomeDto>(type: 'ListingNotFound', statusCode: 404);
      await t.runAsync(() => h.home.reload(force: true));
      await pumpPhone(t, TaxiDriverHomeScreen(controller: h.home));
      await _settle(t);
      expect(h.home.load.value, isA<OwnerLoadEmpty<OwnerHomeDto>>());
      expect(find.text('No taxi yet'), findsOneWidget);
      expect(find.text('Set up your taxi'), findsOneWidget);
      expect(find.text('Couldn’t load your taxi'), findsNothing);
    });

    test('hub delete success refreshes Home through the session hook and shows no raw error on failure', () async {
      final hub = hubFor(taxiJson(), deleteTaxiCall: () async => OwnerOk<void>(null));
      await hub.reload();
      expect(await hub.deleteTaxi(), isTrue);
      expect(hub.load.value, isA<OwnerLoadEmpty>());
      final failing = hubFor(taxiJson(), deleteTaxiCall: () async => const OwnerFailed<void>(message: 'DioException [bad response]: SocketException'));
      await failing.reload();
      expect(await failing.deleteTaxi(), isFalse);
    });
  });

  group('FT-08 / FT-11 My Taxi routes block', () {
    testWidgets('Free 1 of 1: My Taxi shows one Your routes row, no lock row; the Routes page has the plan strip', (t) async {
      final c = hubFor(taxiJson(routesMeter: {'key': 'Routes', 'used': 1, 'limit': 1}));
      await pumpPhone(t, TaxiHubScreen(root: true, controller: c));
      await _settle(t);
      expect(_row(t, 'Your routes'), isNotNull);
      expect(find.text('4 more routes'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      await pumpPhone(t, const TaxiRoutesScreen(manage: true), size: const Size(392, 1400));
      await _settle(t);
      expect(find.byKey(GateKeys.planStrip), findsOneWidget);
      expect(find.text('Free plan: 1 route. Plus allows up to 5 routes.'), findsOneWidget);
    });

    testWidgets('catalog Routes 7 prints up to 7 routes on the Routes page strip', (t) async {
      final c = hubFor(taxiJson(routesMeter: {'key': 'Routes', 'used': 1, 'limit': 1}));
      await c.reload();
      PlanGate.debugPlan = null;
      Get.put<PlanRepository>(FakePlanRepository([
        {'paymentEnabled': true, 'limits': {'routes': 1}},
      ]), permanent: true);
      PlanBindings.ensure();
      await t.runAsync(pumpEventQueue);
      final pc = Get.find<PlanController>();
      pc.myPlan.value = const MyPlanModel(paymentEnabled: true, featureKey: 'Taxi');
      pc.catalog.value = PlanCatalogModel({
        'Taxi': [_plan(paid: false, routes: 1), _plan(paid: true, routes: 7)],
      });
      await pumpPhone(t, const TaxiRoutesScreen(manage: true), size: const Size(392, 1400));
      await _settle(t);
      expect(find.text('Free plan: 1 route. Plus allows up to 7 routes.'), findsOneWidget);
      PlanBindings.dispose();
    });

    testWidgets('plan Plus after the hub reload: 3 of 5 used, no strip, Add route enabled', (t) async {
      var meter = {'key': 'Routes', 'used': 1, 'limit': 1};
      var routes = 1;
      Get.reset();
      final c = hubFor(null);
      Get.delete<TaxiHubController>(tag: TaxiHubController.tag, force: true);
      final hub = Get.put(TaxiHubController(userId: () => 'user-a', fetch: () async => {'data': taxiJson(routes: routes, routesMeter: meter)}), tag: TaxiHubController.tag);
      expect(c, isNotNull);
      await hub.reload();
      await pumpPhone(t, const TaxiRoutesScreen(manage: true), size: const Size(392, 1400));
      await _settle(t);
      expect(find.text('1 of 1 routes used'), findsOneWidget);
      PlanGate.debugPlan = OwnerPlans.plus;
      meter = {'key': 'Routes', 'used': 3, 'limit': 5};
      routes = 3;
      await hub.reload(force: true);
      await _settle(t);
      expect(find.text('3 of 5 routes used'), findsOneWidget);
      expect(find.byKey(GateKeys.planStrip), findsNothing);
      final add = t.widget<GradientPillButton>(find.descendant(of: find.byKey(const ValueKey('routes_manage_add')), matching: find.byType(GradientPillButton)));
      expect(add.enabled, isTrue);
    });
  });

  group('FT-09 Plus Home card copy', () {
    test('no weekly numbers: renew date, open routes and the 2x turn', () {
      final v = const TaxiPlanCopy().homeCard(OwnerPlanCard.maybe({
        'state': 'Plus',
        'renewsOn': '2026-12-21',
        'ringWeight': 2,
        'limits': {'routes': 5},
      }));
      expect(v.line, 'Renews on 21 Dec 2026. Up to 5 routes are open now. Your turn 2x as often.');
      expect(v.title, 'Your plan', reason: 'o_tx_12 heading');
      expect(v.pill, 'Plus');
    });

    test('admin grant without numbers: no date, open routes, turn', () {
      final v = const TaxiPlanCopy().homeCard(OwnerPlanCard.maybe({'state': 'AdminGrant', 'ringWeight': 2, 'limits': {'routes': 5}}));
      expect(v.line, 'Up to 5 routes are open now. Your turn 2x as often.');
    });

    test('weight 1 never claims a faster turn', () {
      final v = const TaxiPlanCopy().homeCard(OwnerPlanCard.maybe({'state': 'Plus', 'renewsOn': '2026-12-21', 'ringWeight': 1, 'limits': {'routes': 5}}));
      expect(v.line, 'Renews on 21 Dec 2026. Up to 5 routes are open now.');
    });

    test('weekly numbers keep the o_pl_16 line; week cells for the Plans page', () {
      final card = OwnerPlanCard.maybe({
        'state': 'Plus',
        'renewsOn': '2026-12-21',
        'ringWeight': 2,
        'weekly': {'requestsOnRoutes': 14, 'accepted': 6},
      });
      final v = const TaxiPlanCopy().homeCard(card);
      expect(v.title, '14 requests on your routes');
      expect(v.line, 'You accepted 6. Renews on 21 Dec 2026.');
      PlanGate.debugPlan = OwnerPlans.plus;
      expect(const TaxiPlanCopy().showsWeek, isTrue);
      expect(const TaxiPlanCopy().weekCells(card!.weekly!), [('14', 'Requests on your routes'), ('6', 'You accepted'), ('2x as often', 'Your turn')]);
      expect(const TaxiPlanCopy().weekCells(OwnerWeekly.fromJson(const {})), isEmpty);
    });
  });

  group('FT-19 plate photo decode size', () {
    test('decode width follows the tile, capped', () {
      expect(TaxiPlateDecode.width(110, 3), 330);
      expect(TaxiPlateDecode.width(400, 3), KitPhoto.maxDecodePx);
      expect(TaxiPlateDecode.width(0, 3), 1);
    });
  });

  group('FT-10 vehicle edit review rule', () {
    test('plate number only change needs review; spacing and case do not', () {
      bool need(String plate, {bool photo = false, bool dl = false, bool dob = false}) =>
          TaxiPlateDecode.needsReview(plate: plate, initialPlate: 'UK04TA2231', newPhoto: photo, licenceTyped: dl, dobPicked: dob);
      expect(need('UK 04 TA 2231'), isFalse);
      expect(need('uk04ta2231'), isFalse);
      expect(need('UK 04 TA 2232'), isTrue);
      expect(need('UK 04 TA 2231', photo: true), isTrue);
      expect(need('UK 04 TA 2231', dl: true), isTrue);
      expect(need('UK 04 TA 2231', dob: true), isTrue);
    });
  });

  group('FT-20 withdraw sheet at small heights and on tablets', () {
    for (final size in const [Size(800, 360), Size(320, 568), Size(1024, 768)]) {
      testWidgets('booking withdraw at ${size.width.toInt()}x${size.height.toInt()}', (t) async {
        await pumpPhone(
          t,
          Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () => DriverWithdrawSheet.show(ctx, travellerName: 'Priya', range: '18 to 21 Dec'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          size: size,
          devicePixelRatio: 2,
        );
        await t.tap(find.text('open'));
        await _settle(t);
        expect(t.takeException(), isNull);
        expect(find.byKey(const ValueKey('driver_withdraw_scroll')), findsOneWidget);
        final w = t.getSize(find.byKey(const ValueKey('driver_withdraw_scroll'))).width;
        expect(w, lessThanOrEqualTo(DriverWithdrawSheet.maxWidth));
        await t.ensureVisible(find.byKey(const ValueKey('driver_withdraw_keep')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('driver_withdraw_keep')));
        await _settle(t);
        expect(find.byKey(const ValueKey('driver_withdraw_scroll')), findsNothing);
      });
    }
  });
}
