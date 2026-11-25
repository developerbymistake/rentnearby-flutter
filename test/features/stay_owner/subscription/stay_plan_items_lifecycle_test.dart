import 'dart:convert';
import 'dart:typed_data';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/jobs/controllers/my_jobs_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/plan_bindings.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/plan/plan_keys.dart';
import 'package:bakhli/features/stay/setup/stay_rooms_screen.dart';
import 'package:bakhli/features/stay/setup/stay_setup_controller.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_calendar_screen.dart';
import 'package:bakhli/features/stay_owner/calendar/widgets/stay_calendar_widgets.dart';
import 'package:bakhli/features/stay_owner/hub/stay_hub_controller.dart';
import 'package:bakhli/features/stay_owner/hub/stay_hub_screen.dart';
import 'package:bakhli/features/stay_owner/jobs_tab/stay_jobs_tab.dart';
import 'package:bakhli/features/stay_owner/special_prices/stay_special_prices_controller.dart';
import 'package:bakhli/features/stay_owner/special_prices/stay_special_prices_screen.dart';
import 'package:bakhli/features/stay_owner/strings/stay_gate_strings.dart';
import 'package:bakhli/features/stay_owner/strings/stay_gate_strings_calendar.dart';
import 'package:bakhli/features/stay_owner/strings/stay_hub_strings.dart';
import 'package:bakhli/features/stay_owner/strings/stay_work_strings.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import '../calendar/calendar_fixtures.dart';
import '../core/stay_fixtures.dart';
import '../core/stay_setup_fixtures.dart';

// Every plan-limited stay item walked through the lifecycle on screen: Free below the limit, Free at the
// limit (Add stays enabled and opens the Plus sheet), Plus below / full (greyed only when full), after the
// plan ends (inactive rows grey, one reason line, Delete only) and after buying again (rows active again,
// counters from the server).

Future<void> _settle(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _openSheet(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

class _LiveRepo extends FakePlanRepository {
  _LiveRepo(this.current) : super([current]);

  Map<String, dynamic> current;

  @override
  Future<MyPlanModel> getMe({bool forceRefresh = false}) async {
    meCalls++;
    return MyPlanModel.fromJson(current);
  }
}

const _freeBody = {
  'paymentEnabled': true,
  'trialAvailable': true,
  'limits': {'photos': 2, 'roomTypes': 2, 'jobsPosts': 1, 'specialPrices': 1, 'calendarEntries': 4, 'blockedRanges': 1},
};
const _plusBody = {
  'paymentEnabled': true,
  'isPaid': true,
  'plan': {'id': 'plus', 'name': 'Plus', 'isDefault': false},
  'endsAt': '2026-12-25T00:00:00Z',
  'limits': {'photos': 8, 'roomTypes': 6, 'jobsPosts': 4, 'specialPrices': 5, 'calendarEntries': 50, 'blockedRanges': 10, 'upcomingDays': 183, 'monthsAhead': 6},
  'play': {'state': 'SUBSCRIPTION_STATE_ACTIVE', 'autoRenewEnabled': true, 'ownsActivePlan': true},
};

void main() {
  setUpAll(() => initTestStorage('stay_plan_items_lifecycle'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanBindings.dispose();
    PlanGate.debugPlan = null;
    StaySpecialPriceMemory.reset();
    OwnerApi.debugReset();
    resetOwnerTestState();
  });

  group('Photos on the hub', () {
    late Map<String, dynamic> server;

    StayHubController hub() {
      final c = hubHarness(null, fetch: () async => {'data': server});
      return c;
    }

    Future<void> pumpHub(WidgetTester t, StayHubController c) async {
      await t.pumpWidget(const SizedBox.shrink());
      await pumpPhone(
        t,
        StayHubScreen(root: true, controller: c),
        size: const Size(360, 2400),
        pages: [GetPage(name: AppRoutes.stayBasicDetails, page: () => const Scaffold(body: Text('photos page')))],
      );
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
    }

    InkWell addInk(WidgetTester t) => t.widget<InkWell>(find.ancestor(of: find.text('+ Add'), matching: find.byType(InkWell)).first);

    Finder lockedTiles() => find.byWidgetPredicate((w) => w is Art3D && w.asset == ListingArt.locked);

    testWidgets('L1 Free below the limit: Add is enabled, no reason line, no Plus sheet', (t) async {
      server = stayJson(photos: 1);
      await pumpHub(t, hub());
      expect(addInk(t).onTap, isNotNull);
      expect(find.text(StayHubStrings.photosOf(1, 2)), findsOneWidget);
      expect(find.text(StayGateStrings.photoInactive(2)), findsNothing);
      expect(find.byKey(GateKeys.sheet), findsNothing);
    });

    testWidgets('L2 Free at the limit: Add is enabled and opens the Plus sheet', (t) async {
      server = stayJson();
      await pumpHub(t, hub());
      expect(addInk(t).onTap, isNotNull);
      expect(find.text(StayHubStrings.photosOf(2, 2)), findsOneWidget);
      expect(find.text(StayHubStrings.photosLimitReached(2, 2)), findsNothing, reason: 'the calm line is for Plus full only');
      await t.tap(find.text('+ Add'));
      await _openSheet(t);
      expect(find.byKey(GateKeys.sheet), findsOneWidget);
      expect(find.text(StayGateStrings.photoGate().title), findsWidgets);
    });

    testWidgets('L3 and L4 Plus: below the limit enabled, full greyed with one calm line, no sheet', (t) async {
      server = stayJson(photos: 5, meters: [{'key': 'Photos', 'used': 5, 'limit': 8}, {'key': 'RoomTypes', 'used': 2, 'limit': 6}]);
      final c = hub();
      PlanGate.debugPlan = OwnerPlans.plus;
      await pumpHub(t, c);
      expect(addInk(t).onTap, isNotNull);
      expect(find.text(StayHubStrings.photosOf(5, 8)), findsOneWidget);
      server = stayJson(photos: 8, meters: [{'key': 'Photos', 'used': 8, 'limit': 8}, {'key': 'RoomTypes', 'used': 2, 'limit': 6}]);
      await t.runAsync(c.reload);
      await t.pump(const Duration(milliseconds: 200));
      expect(addInk(t).onTap, isNull);
      expect(find.text(StayHubStrings.photosLimitReached(8, 8)), findsOneWidget);
      expect(find.byKey(GateKeys.sheet), findsNothing);
    });

    testWidgets('L6 after expiry: first photos stay, extra photos are locked tiles with one reason and Delete only', (t) async {
      server = stayJson(hiddenPhotos: 2);
      await pumpHub(t, hub());
      expect(find.text(StayHubStrings.photosOf(2, 2)), findsOneWidget);
      expect(lockedTiles(), findsNWidgets(2));
      expect(find.text(StayGateStrings.photoInactive(2)), findsOneWidget, reason: 'one reason line, not one per tile');
      expect(find.text('Choose what stays'), findsOneWidget);
      await t.tap(lockedTiles().first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Delete this photo?'), findsOneWidget);
      expect(find.text('Keep'), findsOneWidget);
    });

    testWidgets('L9 buy again: locked tiles are active photos again, reason gone, counters from the server', (t) async {
      server = stayJson(hiddenPhotos: 2);
      final c = hub();
      await pumpHub(t, c);
      expect(lockedTiles(), findsNWidgets(2));
      PlanGate.debugPlan = OwnerPlans.plus;
      server = stayJson(photos: 4, meters: [{'key': 'Photos', 'used': 4, 'limit': 8}, {'key': 'RoomTypes', 'used': 2, 'limit': 6}]);
      await t.runAsync(c.reload);
      await t.pump(const Duration(milliseconds: 200));
      expect(lockedTiles(), findsNothing);
      expect(find.text(StayGateStrings.photoInactive(2)), findsNothing);
      expect(find.text('Choose what stays'), findsNothing);
      expect(find.text(StayHubStrings.photosOf(4, 8)), findsOneWidget);
      expect(addInk(t).onTap, isNotNull);
    });

    testWidgets('L14 payment off: eight slots, no lock, no upgrade words', (t) async {
      server = stayJson(photos: 2, meters: [{'key': 'Photos', 'used': 2, 'limit': 8}, {'key': 'RoomTypes', 'used': 2, 'limit': 6}]);
      final c = hub();
      PlanGate.debugPlan = OwnerPlans.paymentOff;
      await pumpHub(t, c);
      expect(addInk(t).onTap, isNotNull);
      expect(find.text(StayGateStrings.photoInactive(2)), findsNothing);
      expect(find.byKey(GateKeys.softRow), findsNothing);
      await t.tap(find.text('+ Add'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(GateKeys.sheet), findsNothing);
      expect(find.text('photos page'), findsOneWidget, reason: 'Add opens the photos page');
    });
  });

  group('Room types, real /plans/me', () {
    late _LiveRepo repo;
    late StaySetupController setup;

    Map<String, dynamic> rooms(int n, {int hidden = 0}) => {
          ...draftJson(step1: true, rooms: true, rules: true, status: 'Approved'),
          'rooms': [
            for (var i = 0; i < n; i++)
              {'id': 'r$i', 'roomIndex': i + 1, 'roomName': ['Deluxe', 'Family Room', 'Standard', 'Suite', 'Cottage', 'Dormitory'][i], 'pricePerNight': 3000 + i * 500, 'maxGuests': 3, 'meals': 'Breakfast'},
          ],
          'hiddenRooms': [
            for (var i = 0; i < hidden; i++)
              {'id': 'h$i', 'roomIndex': 1001 + i, 'roomName': ['Suite', 'Cottage'][i], 'pricePerNight': 6000, 'maxGuests': 4, 'meals': 'Breakfast'},
          ],
        };

    Future<void> boot(WidgetTester t, Map<String, dynamic> plan, Map<String, dynamic> stay) async {
      setup = setupFor(stayModel(stay), stayStatus: 'Approved');
      PlanGate.debugPlan = null;
      repo = _LiveRepo(plan);
      Get.put<PlanRepository>(repo, permanent: true);
      await t.pumpWidget(const SizedBox.shrink());
      await pumpPhone(t, const StayRoomsScreen(manage: true), size: const Size(360, 2600), toastHost: true);
      await _settle(t);
    }

    GradientPillButton addButton(WidgetTester t) => t.widget<GradientPillButton>(find.widgetWithText(GradientPillButton, 'Add room type'));

    Future<void> serverChanges(WidgetTester t, Map<String, dynamic> plan, Map<String, dynamic> stay) async {
      repo.current = plan;
      await t.runAsync(() => Get.find<PlanController>().invalidate());
      setup.stay.value = stayModel(stay);
      await _settle(t);
    }

    testWidgets('Free below, Free full, Plus, expiry, re-buy in one walk', (t) async {
      await boot(t, _freeBody, rooms(1));
      expect(addButton(t).enabled, isTrue);
      expect(find.byKey(GateKeys.softRow), findsNothing, reason: 'below the limit Add adds');

      await serverChanges(t, _freeBody, rooms(2));
      expect(find.text('2 of 2 room types used'), findsOneWidget);
      expect(addButton(t).enabled, isTrue, reason: 'Add stays enabled at the Free limit');
      expect(find.byKey(GateKeys.softRow), findsOneWidget);
      expect(find.text('2 of 2 · limit reached'), findsNothing);
      await t.tap(find.text('Add room type'));
      await _openSheet(t);
      expect(find.byKey(GateKeys.sheet), findsOneWidget);
      await t.tap(find.text('Not now'));
      await _settle(t);

      await serverChanges(t, _plusBody, rooms(3));
      expect(PlanGate.limit(PlanKey.roomTypes), 6);
      expect(find.text('3 of 6 room types used'), findsOneWidget);
      expect(addButton(t).enabled, isTrue);
      expect(find.byKey(GateKeys.softRow), findsNothing);
      expect(find.byKey(GateKeys.planStrip), findsNothing);

      await serverChanges(t, _plusBody, rooms(6));
      expect(find.text('6 of 6 room types used'), findsOneWidget);
      expect(addButton(t).enabled, isFalse, reason: 'Plus full is greyed');
      expect(find.text('6 of 6 · limit reached'), findsOneWidget);
      expect(find.byKey(GateKeys.sheet), findsNothing);

      final ended = {..._freeBody, 'hidden': {'roomTypes': 2}, 'trialAvailable': false};
      await serverChanges(t, ended, rooms(2, hidden: 2));
      expect(PlanGate.limit(PlanKey.roomTypes), 2);
      expect(find.byKey(GateKeys.inactiveRow), findsNWidgets(2));
      expect(find.text(StayGateStrings.roomInactive(2)), findsNWidgets(2));
      for (final label in ['Edit price', 'Edit room']) {
        final pills = find.descendant(of: find.byKey(GateKeys.inactiveRow), matching: find.widgetWithText(WhitePillButton, label));
        for (final p in t.widgetList<WhitePillButton>(pills)) {
          expect(p.enabled, isFalse, reason: label);
        }
      }
      expect(find.descendant(of: find.byKey(GateKeys.inactiveRow).first, matching: find.text('Delete')), findsOneWidget);
      expect(find.text('Choose what stays'), findsOneWidget);
      expect(addButton(t).enabled, isTrue, reason: 'Add opens the Plus sheet again');

      await serverChanges(t, _plusBody, rooms(4));
      expect(find.byKey(GateKeys.inactiveRow), findsNothing);
      expect(find.text('Choose what stays'), findsNothing);
      expect(find.text('4 of 6 room types used'), findsOneWidget);
      expect(find.text('ROOM 4'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('L14 payment off: six room types, no strip, no lock', (t) async {
      await boot(t, {'paymentEnabled': false, 'limits': _plusBody['limits']}, rooms(2));
      expect(find.byKey(GateKeys.planStrip), findsNothing);
      expect(find.byKey(GateKeys.softRow), findsNothing);
      expect(find.text('2 of 6 room types used'), findsOneWidget);
      expect(addButton(t).enabled, isTrue);
    });
  });

  group('Jobs tab', () {
    late _Adapter adapter;

    Map<String, dynamic> job(String id, String title, {int daysAgo = 2, String status = 'Active'}) => {
          'id': id,
          'title': title,
          'minimumExperienceYears': 1,
          'salaryTypeName': 'Monthly',
          'stayName': 'Deodar Heights Homestay',
          'minSalary': 12000,
          'maxSalary': 12000,
          'status': status,
          'createdAt': DateTime.now().subtract(Duration(days: daysAgo)).toUtc().toIso8601String(),
          'foodAndStay': true,
        };

    Map<String, dynamic> page(List<Map<String, dynamic>> items, {required int max, bool canUpgrade = true, bool payment = true}) {
      final active = items.where((j) => j['status'] == 'Active').length;
      return {
        'items': items,
        'activeCount': active,
        'maxActive': max,
        'stayStatus': 'Approved',
        'canPost': active < max,
        'paymentEnabled': payment,
        'canUpgrade': canUpgrade,
        'overCap': active > max,
      };
    }

    Future<void> boot(WidgetTester t, Map<String, dynamic> p, {MyPlanModel plan = const MyPlanModel(paymentEnabled: true, trialAvailable: true)}) async {
      Get.reset();
      PlanGate.debugPlan = plan;
      ApiService.init();
      adapter = _Adapter({'success': true, 'data': p});
      ApiService.dio.httpClientAdapter = adapter;
      await pumpPhone(t, const StayJobsTab(), size: const Size(392, 1800));
      await _settle(t);
    }

    Future<void> serverChanges(WidgetTester t, MyPlanModel plan, Map<String, dynamic> p) async {
      PlanGate.debugPlan = plan;
      adapter.body = {'success': true, 'data': p};
      await t.runAsync(() => Get.find<MyJobsController>(tag: StayJobsTab.tag).load());
      await _settle(t);
    }

    GradientPillButton post(WidgetTester t) => t.widget<GradientPillButton>(find.widgetWithText(GradientPillButton, StayWorkStrings.postAJob));

    testWidgets('Free below, Free at limit, Plus below, Plus full, expiry, re-buy in one walk', (t) async {
      await boot(t, page([], max: 1));
      expect(find.text('0 of 1 active'), findsOneWidget);
      expect(post(t).enabled, isTrue);

      await serverChanges(t, const MyPlanModel(paymentEnabled: true, trialAvailable: true), page([job('j1', 'Cook')], max: 1));
      expect(find.text('1 of 1 active'), findsOneWidget);
      expect(post(t).enabled, isTrue, reason: 'Post stays enabled at the Free limit');
      expect(find.text('See Plus'), findsNothing, reason: 'no banner, the sheet opens on tap');
      await t.tap(find.text(StayWorkStrings.postAJob));
      await _openSheet(t);
      expect(find.byKey(GateKeys.sheet), findsOneWidget);
      expect(find.text('1 active job on Free'), findsWidgets);
      await t.tap(find.text('Not now'));
      await _settle(t);

      await serverChanges(t, OwnerPlans.plus, page([job('j1', 'Cook'), job('j2', 'Driver', daysAgo: 4)], max: 4, canUpgrade: false));
      expect(find.text('2 of 4 active'), findsOneWidget);
      expect(post(t).enabled, isTrue);

      await serverChanges(t, OwnerPlans.plus, page([job('j1', 'Cook'), job('j2', 'Driver', daysAgo: 4), job('j3', 'Helper', daysAgo: 5), job('j4', 'Guard', daysAgo: 6)], max: 4, canUpgrade: false));
      expect(find.text('4 of 4 active'), findsOneWidget);
      expect(post(t).enabled, isFalse, reason: 'Plus full is greyed');
      expect(find.byKey(GateKeys.sheet), findsNothing);

      final expired = page([job('j1', 'Cook'), job('j2', 'Driver', daysAgo: 4, status: 'Inactive'), job('j3', 'Helper', daysAgo: 5, status: 'Inactive'), job('j4', 'Guard', daysAgo: 6, status: 'Inactive')], max: 1);
      await serverChanges(t, const MyPlanModel(paymentEnabled: true), expired);
      expect(find.text('1 of 1 active'), findsOneWidget);
      expect(find.text('INACTIVE'), findsNWidgets(3));
      expect(find.text('Inactive: the Free plan allows 1 active job.'), findsNWidgets(3));
      expect(find.text('Close'), findsNWidgets(4));
      final edits = t.widgetList<WhitePillButton>(find.widgetWithText(WhitePillButton, 'Edit')).toList();
      expect(edits.where((b) => b.onTap == null || !b.enabled).length, 3, reason: 'inactive jobs cannot be edited');
      expect(post(t).enabled, isTrue);

      await serverChanges(t, OwnerPlans.plus, page([job('j1', 'Cook'), job('j2', 'Driver', daysAgo: 4), job('j3', 'Helper', daysAgo: 5), job('j4', 'Guard', daysAgo: 6)], max: 4, canUpgrade: false));
      expect(find.text('INACTIVE'), findsNothing);
      expect(find.text('Inactive: the Free plan allows 1 active job.'), findsNothing);
      expect(find.text('4 of 4 active'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('L14 payment off: cap 4, no banner, no upgrade word', (t) async {
      await boot(t, page([job('j1', 'Cook')], max: 4, payment: false, canUpgrade: false), plan: OwnerPlans.paymentOff);
      expect(find.text('1 of 4 active'), findsOneWidget);
      expect(find.textContaining('pgrade'), findsNothing);
      expect(post(t).enabled, isTrue);
    });
  });

  group('Special prices', () {
    late Map<String, dynamic> special;

    Map<String, dynamic> rule(String id, {bool paused = false, bool live = true}) => {
          'id': id,
          'dateFrom': '2026-12-24',
          'dateTo': '2027-01-01',
          'nights': 9,
          'direction': 'Higher',
          'percent': 25,
          'label': 'Rule $id',
          'live': live && !paused,
          'pausedByPlan': paused,
          'version': 1,
        };

    Future<StaySpecialPricesController> boot(WidgetTester t, MyPlanModel plan, Map<String, dynamic> body) async {
      special = body;
      CalendarHarness.setUp(registerCalendar: false, plan: plan, extra: (p) => p == '/stays/me/special-prices' ? special : null);
      final sp = Get.put(
        StaySpecialPricesController(clock: calClock, userIdOf: () => 'user-a', listingNameOf: () => 'Deodar Heights'),
        tag: StaySpecialPricesController.tag,
      );
      await pumpPhone(t, StaySpecialPricesScreen(controller: sp), size: const Size(360, 2000));
      await _settle(t);
      return sp;
    }

    Future<void> serverChanges(WidgetTester t, StaySpecialPricesController sp, MyPlanModel plan, Map<String, dynamic> body) async {
      PlanGate.debugPlan = plan;
      special = body;
      await t.runAsync(sp.fetch);
      await _settle(t);
    }

    StayCalBar bar(WidgetTester t) => t.widget<StayCalBar>(find.byType(StayCalBar));

    testWidgets('Free below, Free at limit, expiry, re-buy, Plus full in one walk', (t) async {
      final sp = await boot(t, OwnerPlans.free, specialJson(items: []));
      expect(bar(t).onPrimary, isNotNull, reason: 'Free below the limit: Add works');
      expect(find.byKey(GateKeys.sheet), findsNothing);

      await serverChanges(t, sp, OwnerPlans.free, specialJson(items: [rule('a')]));
      expect(bar(t).onPrimary, isNotNull, reason: 'Add stays enabled at the Free limit');
      expect(find.byKey(GateKeys.planStrip), findsOneWidget);
      await t.tap(find.text('+ Add special price'));
      await _openSheet(t);
      expect(find.text('1 special price on Free'), findsOneWidget);
      await t.tap(find.text('Not now'));
      await _settle(t);

      await serverChanges(t, sp, OwnerPlans.plus, specialJson(plus: true, items: [rule('a'), rule('b'), rule('c'), rule('d'), rule('e')]));
      expect(bar(t).onPrimary, isNull, reason: 'Plus full is greyed');
      expect(find.byKey(GateKeys.planStrip), findsNothing);
      expect(find.text(StayGateStrings.specialInactive(1)), findsNothing);

      await serverChanges(t, sp, OwnerPlans.free, specialJson(items: [rule('a'), rule('b', paused: true), rule('c', paused: true), rule('d', paused: true), rule('e', paused: true)]));
      expect(find.text(StayGateStrings.specialInactive(1)), findsNWidgets(4));
      expect(find.text('Edit'), findsOneWidget, reason: 'only the active rule can be edited');
      expect(find.text('Delete'), findsNWidgets(5));
      expect(bar(t).onPrimary, isNotNull);

      await serverChanges(t, sp, OwnerPlans.plus, specialJson(plus: true, items: [rule('a'), rule('b'), rule('c')]));
      expect(find.text(StayGateStrings.specialInactive(1)), findsNothing);
      expect(find.text('Edit'), findsNWidgets(3));
      expect(bar(t).onPrimary, isNotNull, reason: '3 of 5');
      expect(t.takeException(), isNull);
    });

    testWidgets('L14 payment off: no strip, no gate key', (t) async {
      await boot(t, OwnerPlans.paymentOff, specialJson(items: [rule('a')]));
      expect(find.byKey(GateKeys.planStrip), findsNothing);
      expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
    });
  });

  group('Calendar entries and blocked ranges', () {
    late Map<String, dynamic> month;

    Future<CalendarHarness> boot(WidgetTester t, MyPlanModel plan, Map<String, dynamic> body) async {
      month = body;
      final h = CalendarHarness.setUp(
        plan: plan,
        month: body,
        override: (method, path, _) async => method == 'GET' && path == '/stays/me/calendar' ? {'data': month} : {},
      );
      await pumpPhone(t, StayCalendarScreen(controller: h.calendar), size: const Size(360, 4200));
      await _settle(t);
      return h;
    }

    Future<void> serverChanges(WidgetTester t, CalendarHarness h, MyPlanModel plan, Map<String, dynamic> body) async {
      PlanGate.debugPlan = plan;
      month = body;
      h.calendar.clearCache();
      await t.runAsync(h.calendar.reload);
      await _settle(t);
    }

    StayCalBar bar(WidgetTester t) => t.widget<StayCalBar>(find.byType(StayCalBar));

    Map<String, dynamic> old({bool inactive = false}) => {...entryJson('old1', '2026-11-25', '2026-11-26', 'Older booking'), if (inactive) 'inactiveByPlan': true};

    testWidgets('Free below, Free full, expiry, re-buy, Plus full in one walk', (t) async {
      final h = await boot(t, OwnerPlans.free, monthJson(entriesUsed: 3, blocksUsed: 0));
      expect(bar(t).onPrimary, isNotNull);
      expect(bar(t).onSecondary, isNotNull);

      await serverChanges(t, h, OwnerPlans.free, monthJson(entriesUsed: 4, blocksUsed: 1));
      expect(bar(t).onPrimary, isNotNull, reason: 'Add booking stays enabled at 4 of 4');
      expect(bar(t).onSecondary, isNotNull, reason: 'Block days stays enabled at 1 of 1');
      await t.tap(find.text('+ Add booking'));
      await _openSheet(t);
      expect(find.byKey(GateKeys.sheet), findsOneWidget);
      expect(find.text('You have 4 active entries'), findsOneWidget);
      await t.tap(find.text('Not now'));
      await _settle(t);
      await t.tap(find.text('Block days'));
      await _openSheet(t);
      expect(find.text('Free allows 1 blocked range'), findsOneWidget);
      await t.tap(find.text('Not now'));
      await _settle(t);

      await serverChanges(t, h, OwnerPlans.free, monthJson(entries: [...novEntries(), old(inactive: true)], entriesUsed: 4));
      expect(find.byKey(GateKeys.inactiveRow), findsOneWidget);
      expect(find.text(StayGateStringsCalendar.entryInactive(4)), findsOneWidget);
      expect(find.descendant(of: find.byKey(GateKeys.inactiveRow), matching: find.text('Delete')), findsOneWidget);
      expect(h.calendar.ownActive.where((e) => e.id == 'old1'), isEmpty);

      await serverChanges(t, h, OwnerPlans.plus, monthJson(plus: true, entries: [...novEntries(), old()]));
      expect(find.byKey(GateKeys.inactiveRow), findsNothing);
      expect(find.text(StayGateStringsCalendar.entryInactive(4)), findsNothing);
      expect(h.calendar.ownActive.where((e) => e.id == 'old1'), isNotEmpty, reason: 'the older booking is active again');
      expect(bar(t).onPrimary, isNotNull);
      expect(bar(t).onSecondary, isNotNull);

      final full = monthJson(plus: true)..['meters'] = [meter('CalendarEntries', 50, 50), meter('BlockedRanges', 10, 10)];
      await serverChanges(t, h, OwnerPlans.plus, full);
      expect(bar(t).onPrimary, isNull, reason: 'Plus full is greyed');
      expect(bar(t).onSecondary, isNull);
      expect(find.byKey(GateKeys.sheet), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('L14 payment off: nothing locked, nothing inactive, no gate key', (t) async {
      await boot(t, OwnerPlans.paymentOff, monthJson(paymentEnabled: false));
      expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
      expect(find.byKey(GateKeys.inactiveRow), findsNothing);
      expect(bar(t).onPrimary, isNotNull);
    });
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);

  Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}
