import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/jobs/controllers/my_jobs_controller.dart';
import 'package:bakhli/features/jobs/data/jobs_repository.dart';
import 'package:bakhli/features/jobs/models/my_job_model.dart';
import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/session/owner_plan_sync.dart';
import 'package:bakhli/features/owner_core/sheets/owner_states.dart';
import 'package:bakhli/features/stay/models/stay_owner_model.dart';
import 'package:bakhli/features/stay_owner/calendar/models/stay_calendar_models.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_balance_due_screen.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_calendar_entry_screen.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_entry_sheet.dart';
import 'package:bakhli/features/stay_owner/home/stay_owner_home_screen.dart';
import 'package:bakhli/features/stay_owner/hub/stay_hub_controller.dart';
import 'package:bakhli/features/stay_owner/jobs_tab/stay_jobs_tab.dart';
import 'package:bakhli/features/stay_owner/stay_owner_deps.dart';
import 'package:bakhli/features/stay_owner/stay_owner_session.dart';
import 'package:bakhli/features/stay_owner/strings/stay_home_strings.dart';
import 'package:bakhli/features/stay_owner/strings/stay_work_strings.dart';
import 'package:bakhli/features/stay_owner/strings/stay_hub_strings.dart';
import 'package:bakhli/utils/photo_upload/app_photo_pick.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../support/owner_fakes.dart';
import '../../support/real_phone.dart';
import 'calendar/calendar_fixtures.dart';
import 'core/stay_fixtures.dart';

class _FakeJobsRepo extends JobsRepository {
  _FakeJobsRepo(this.page);

  MyJobsPage page;
  int calls = 0;

  @override
  Future<MyJobsPage> getMine() async {
    calls++;
    return page;
  }
}

class _FakePicker extends ImagePickerPlatform {
  int single = 0;
  int multi = 0;
  int? lastLimit;

  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async {
    single++;
    return XFile('a.jpg');
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({MultiImagePickerOptions options = const MultiImagePickerOptions()}) async {
    multi++;
    lastLimit = options.limit;
    return [for (var i = 0; i < (options.limit ?? 2); i++) XFile('m$i.jpg')];
  }
}

const _jobsLocked = MyJobsPage(items: [], activeCount: 1, maxActive: 1, stayStatus: 'Approved', canPost: false, paymentEnabled: true, canUpgrade: true);
const _jobsOpen = MyJobsPage(items: [], activeCount: 1, maxActive: 4, stayStatus: 'Approved', canPost: true, paymentEnabled: true);

Future<void> _drain() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUpAll(() => initTestStorage('fs_stay_fixes'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    OwnerPlanSync.reset();
    StayOwnerDeps.debugReset();
    resetOwnerTestState();
  });

  group('FS-04 / FS-05 one plan signal reloads every Stay screen once', () {
    test('plan change: one Home, one hub, one jobs reload; jobs can post after the change', () async {
      final h = StayHarness.setUp(homeJson());
      PlanGate.debugPlan = OwnerPlans.free;
      var hubFetches = 0;
      Get.put(StayHubController(userId: () => 'user-a', fetch: () async {
        hubFetches++;
        return {'data': stayJson()};
      }), tag: StayHubController.tag);
      final repo = _FakeJobsRepo(_jobsLocked);
      final jobs = Get.put(MyJobsController(repo: repo, refreshOnTab: AppTabs.fourth), tag: StayJobsTab.tag);
      StayOwnerSession.register();
      await _drain();
      final home0 = h.api.calls;
      final hub0 = hubFetches;
      final jobs0 = repo.calls;
      expect(jobs.page.value?.canPost, isFalse);

      PlanGate.debugPlan = OwnerPlans.trial;
      repo.page = _jobsOpen;
      OwnerPlanSync.fire();
      await _drain();

      expect(h.api.calls, home0 + 1);
      expect(hubFetches, hub0 + 1);
      expect(repo.calls, jobs0 + 1);
      expect(jobs.page.value?.canPost, isTrue);
    });

    test('jobs tab refreshes when its tab is shown again after 30 s', () async {
      StayHarness.setUp(homeJson());
      var now = DateTime(2026, 11, 21, 10);
      final repo = _FakeJobsRepo(_jobsLocked);
      Get.put(MyJobsController(repo: repo, refreshOnTab: AppTabs.fourth, clock: () => now), tag: StayJobsTab.tag);
      await _drain();
      final auth = Get.find<AuthController>();
      expect(repo.calls, 1);
      auth.tabIndex.value = AppTabs.fourth;
      await _drain();
      expect(repo.calls, 1, reason: 'fresh within 30 s');
      auth.tabIndex.value = AppTabs.home;
      now = now.add(const Duration(seconds: 31));
      auth.tabIndex.value = AppTabs.fourth;
      await _drain();
      expect(repo.calls, 2);
    });
  });

  group('FS-06 deleted stay', () {
    test('a 404 ListingNotFound after data leaves Home Empty and drops the cached Home', () async {
      final h = StayHarness.setUp(homeJson());
      await _drain();
      expect(h.home.load.value, isA<OwnerLoadData<OwnerHomeDto>>());
      expect(OwnerCache.read('user-a', OwnerCacheKeys.home), isNotNull);
      h.api.result = () async => const OwnerRefused<OwnerHomeDto>(type: 'ListingNotFound', statusCode: 404);
      await h.home.reload();
      expect(h.home.load.value, isA<OwnerLoadEmpty<OwnerHomeDto>>());
      expect(OwnerCache.read('user-a', OwnerCacheKeys.home), isNull);
    });

    testWidgets('Empty Home shows the setup entry card', (t) async {
      final h = StayHarness.setUp(homeJson());
      h.api.result = () async => const OwnerRefused<OwnerHomeDto>(type: 'ListingNotFound', statusCode: 404);
      await pumpPhone(t, const StayOwnerHomeScreen());
      await t.runAsync(h.home.reload);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(StayHubStrings.noStayYet), findsOneWidget);
      expect(find.text(StayHubStrings.setUpStay), findsOneWidget);
    });
  });

  group('FS-12 write answers keep the plan rows', () {
    test('mergeJson keeps hidden rows and meters missing from the answer', () {
      final current = stayJson(rooms: 2, hiddenRooms: 2, photos: 2, hiddenPhotos: 1);
      final body = {...current}..remove('hiddenRooms')..remove('hiddenPhotos')..remove('meters');
      final merged = StayOwnerModel.fromJson(StayOwnerModel.mergeJson(current, body));
      expect(merged.hiddenRooms, hasLength(2));
      expect(merged.hiddenPhotos, hasLength(1));
      expect(merged.meter('Photos')?.limit, 2);
      final fresh = StayOwnerModel.fromJson(StayOwnerModel.mergeJson(current, {...body, 'hiddenRooms': <dynamic>[]}));
      expect(fresh.hiddenRooms, isEmpty, reason: 'a key the server sends wins');
    });

    test('hub price update keeps meters and hidden rows', () async {
      final hub = hubHarness(stayJson(rooms: 2, hiddenRooms: 1));
      await _drain();
      final answer = stayJson(rooms: 2)..remove('hiddenRooms')..remove('meters');
      OwnerApi.transport = FakeTransport((m, p, b) async => {'data': answer});
      expect(await hub.updatePrice(hub.stay!.rooms.first.id, 3100), isTrue);
      expect(hub.stay!.hiddenRooms, hasLength(1));
      expect(hub.stay!.meter('RoomTypes')?.limit, 2);
    });
  });

  group('FS-14 choose what stays', () {
    test('stored hidden rows count as something hidden even within the limit', () {
      final s = StayPlanVisibleState.fromJson({
        'photos': [
          {'id': 'p1', 'url': '', 'photoOrder': 0},
        ],
        'hiddenPhotos': [
          {'id': 'p2', 'url': '', 'photoOrder': 1},
        ],
        'rooms': <dynamic>[],
        'hiddenRooms': <dynamic>[],
        'meters': [
          {'key': 'Photos', 'used': 1, 'limit': 2},
        ],
      }, photoLimit: 8, roomLimit: 6);
      expect(s.somethingHidden, isTrue);
      expect(s.hiddenPhotoIds, ['p2']);
    });

    test('payload limit 2 wins over a stale plan limit 8', () {
      final s = StayPlanVisibleState.fromJson({
        'photos': [for (var i = 0; i < 3; i++) {'id': 'p$i', 'url': '', 'photoOrder': i}],
        'hiddenPhotos': [for (var i = 3; i < 5; i++) {'id': 'p$i', 'url': '', 'photoOrder': i}],
        'rooms': <dynamic>[],
        'meters': [
          {'key': 'Photos', 'used': 3, 'limit': 2},
        ],
      }, photoLimit: 8, roomLimit: 6);
      expect(s.photoTarget, 2);
      expect(s.limitsFromServer, isTrue);
    });
  });

  group('FS-03 last photo slot', () {
    test('one slot left uses a single pick, two or more a multi pick', () async {
      final before = ImagePickerPlatform.instance;
      addTearDown(() => ImagePickerPlatform.instance = before);
      final p = _FakePicker();
      ImagePickerPlatform.instance = p;
      expect(await AppPhotoPick.pickGallery(1), hasLength(1));
      expect(p.single, 1);
      expect(p.multi, 0);
      expect(await AppPhotoPick.pickGallery(2), hasLength(2));
      expect(p.multi, 1);
      expect(p.lastLimit, 2);
      expect(await AppPhotoPick.pickGallery(0), isEmpty);
    });
  });

  group('FS-08 ended entries and blocks are read-only', () {
    testWidgets('a past manual booking offers Edit amounts and Delete only', (t) async {
      final h = CalendarHarness.setUp(plan: OwnerPlans.plus, month: monthJson(plus: true), extra: (p) {
        if (p == '/stays/me/calendar/entries/old') return entryJson('old', '2026-11-01', '2026-11-03', 'Walk-in', finalAmount: 4000, received: 1000);
        return null;
      });
      await pumpPhone(t, StayCalendarEntryScreen(args: const {'id': 'old'}, controller: h.calendar));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Edit amounts'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Edit booking'), findsNothing);
    });

    testWidgets('an ended block from the month payload opens read-only', (t) async {
      final h = CalendarHarness.setUp(
        plan: OwnerPlans.plus,
        month: monthJson(plus: true, blocks: [{'id': 'b9', 'dateFrom': '2026-11-03', 'dateTo': '2026-11-05', 'reason': 'Painting', 'version': 1}]),
        extra: (p) => p == '/stays/me/blocked-ranges' ? {'items': <dynamic>[], 'meters': <dynamic>[]} : null,
      );
      await h.calendar.start();
      await pumpPhone(t, StayCalendarEntryScreen(args: const {'id': 'b9', 'kind': 'block'}, controller: h.calendar));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Painting'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Remove block'), findsNothing);
    });

    testWidgets('editing a long booking keeps its own start date pickable', (t) async {
      final h = CalendarHarness.setUp(plan: OwnerPlans.plus, month: monthJson(plus: true));
      await h.calendar.start();
      final started = CalendarEntry.fromJson(entryJson('long', '2026-11-02', '2026-11-28', 'Long stay'));
      await pumpPhone(t, Material(child: StayEntryForm(controller: h.calendar, startBlock: false, from: started.dateFrom!, to: started.dateTo!, entry: started)));
      final state = t.state<StayEntryFormState>(find.byType(StayEntryForm));
      expect(state.firstPickable, DateTime(2026, 11, 2));
    });
  });

  group('FS-19 Home attention reacts', () {
    testWidgets('notifications-off row appears without a reload', (t) async {
      final h = StayHarness.setUp(homeJson());
      await pumpPhone(t, const StayOwnerHomeScreen());
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(StayHomeStrings.notificationsTitle), findsNothing);
      final calls = h.api.calls;
      h.home.notificationsDenied.value = true;
      await t.pump();
      expect(find.text(StayHomeStrings.notificationsTitle), findsOneWidget);
      expect(h.api.calls, calls);
    });
  });

  group('FS-07 Jobs tab button above the dock', () {
    for (final size in const [Size(320, 568), Size(360, 800)]) {
      testWidgets('Post a job is above the floating bar at ${size.width.toInt()}x${size.height.toInt()}', (t) async {
        Get.reset();
        PlanGate.debugPlan = OwnerPlans.plus;
        Get.put(MyJobsController(repo: _FakeJobsRepo(_jobsOpen)), tag: StayJobsTab.tag);
        late double dockTop;
        await pumpPhone(
          t,
          Builder(builder: (context) {
            dockTop = MediaQuery.sizeOf(context).height - BarMetrics.bodyBottomOf(context) + BarMetrics.bodyGap;
            return const Scaffold(extendBody: true, body: StayJobsTab());
          }),
          size: size,
        );
        await t.pump(const Duration(milliseconds: 300));
        final button = t.getRect(find.text(StayWorkStrings.postAJob));
        expect(button.bottom, lessThanOrEqualTo(dockTop));
      });
    }
  });

  group('FS-20 pushed calendar pages at small heights', () {
    for (final size in const [Size(800, 360), Size(360, 420)]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('entry and balance due: no overflow, bar reachable at ${size.width.toInt()}x${size.height.toInt()} x$scale', (t) async {
          final h = CalendarHarness.setUp(plan: OwnerPlans.plus, month: monthJson(plus: true), extra: (p) {
            if (p == '/stays/me/calendar/entries/gupta') return entryJson('gupta', '2026-11-25', '2026-11-27', 'Gupta ji, 2 rooms', finalAmount: 9000, received: 3000);
            if (p.endsWith('/balance-due')) return {'items': (summaryJson()['topBalances'] as List), 'nextCursor': null};
            return null;
          });
          await pumpPhone(t, StayCalendarEntryScreen(args: const {'id': 'gupta'}, controller: h.calendar), size: size, textScale: scale);
          await t.pump(const Duration(milliseconds: 300));
          expect(t.takeException(), isNull);
          await t.scrollUntilVisible(find.text('Edit booking'), 120, scrollable: find.byType(Scrollable).first);
          expect(find.text('Edit booking'), findsOneWidget);
          await pumpPhone(t, StayBalanceDueScreen(clock: calClock, args: const {'month': '2026-11'}), size: size, textScale: scale);
          await t.pump(const Duration(milliseconds: 300));
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
