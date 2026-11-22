import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/controllers/auth_controller.dart' show LogoutReason;
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/jobs/controllers/my_jobs_controller.dart';
import 'package:bakhli/features/jobs/data/jobs_repository.dart';
import 'package:bakhli/features/jobs/models/my_job_model.dart';
import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/plan_bindings.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/plan/plan_keys.dart';
import 'package:bakhli/features/owner_core/session/owner_plan_sync.dart';
import 'package:bakhli/features/owner_core/session/owner_session_hooks.dart';
import 'package:bakhli/features/stay/models/stay_owner_model.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_calendar_entry_screen.dart';
import 'package:bakhli/features/stay_owner/hub/stay_hub_controller.dart';
import 'package:bakhli/features/stay_owner/jobs_tab/stay_jobs_tab.dart';
import 'package:bakhli/features/stay_owner/stay_owner_session.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../features/stay_owner/calendar/calendar_fixtures.dart';
import '../features/stay_owner/core/stay_fixtures.dart';
import '../support/owner_fakes.dart';
import '../support/real_phone.dart';

// JT-A-ST-1 (app half): Free -> Trial -> Plus -> Cancelled -> Ended -> Resubscribed, fed as /plans/me bodies to the
// real PlanController. Every step = one reload each of Home, My Stay, Calendar and Jobs (FX-03, FS-04, FS-05).
// The Free / Draft first-login step (setup without MainScreen) is in stay_setup_plan_wiring_test.dart (FS-10).

const _plusLimits = {
  'photos': 8,
  'roomTypes': 6,
  'calendarEntries': 50,
  'blockedRanges': 10,
  'upcomingDays': 183,
  'monthsAhead': 6,
  'monthSummary': true,
  'reminders': true,
  'specialPrices': 5,
  'jobsPosts': 4,
};
const _freeLimits = {'photos': 2, 'roomTypes': 2, 'calendarEntries': 4, 'blockedRanges': 1, 'specialPrices': 1, 'jobsPosts': 1};

final Map<String, Map<String, dynamic>> _steps = {
  'Free': {'state': 'Free', 'paymentEnabled': true, 'trialAvailable': true, 'limits': _freeLimits},
  'Trial': {'state': 'Trial', 'paymentEnabled': true, 'isPaid': true, 'source': 'Trial', 'endsAt': '2026-11-28T00:00:00Z', 'limits': _plusLimits},
  'Plus': {'state': 'Plus', 'paymentEnabled': true, 'isPaid': true, 'endsAt': '2026-12-21T00:00:00Z', 'limits': _plusLimits},
  'Cancelled': {'state': 'Cancelled', 'paymentEnabled': true, 'isPaid': true, 'endsAt': '2026-12-21T00:00:00Z', 'limits': _plusLimits, 'play': {'autoRenewEnabled': false}},
  'Ended': {'state': 'Ended', 'paymentEnabled': true, 'limits': _freeLimits, 'hidden': {'photos': 3, 'roomTypes': 1, 'specialPrices': 2}},
  'Resubscribed': {'state': 'Plus', 'paymentEnabled': true, 'isPaid': true, 'endsAt': '2027-01-21T00:00:00Z', 'limits': _plusLimits},
};

bool _plus(String step) => step != 'Free' && step != 'Ended';

class _Jobs extends JobsRepository {
  bool open = false;
  int calls = 0;

  @override
  Future<MyJobsPage> getMine() async {
    calls++;
    return MyJobsPage(items: const [], activeCount: 1, maxActive: open ? 4 : 1, stayStatus: 'Approved', canPost: open, paymentEnabled: true, canUpgrade: !open);
  }
}

Map<String, dynamic> _stayFor(String step) => _plus(step)
    ? stayJson(photos: 5, rooms: 3, meters: [{'key': 'Photos', 'used': 5, 'limit': 8}, {'key': 'RoomTypes', 'used': 3, 'limit': 6}])
    : step == 'Ended'
        ? stayJson(photos: 2, rooms: 2, hiddenPhotos: 3, hiddenRooms: 1)
        : stayJson();

void main() {
  setUpAll(() => initTestStorage('stay_plan_journey'));
  setUp(OwnerCache.clearAll);
  tearDown(() async {
    await OwnerSessionHooks.onLogout(LogoutReason.explicitLogout, 'user-a');
    OwnerPlanSync.reset();
    PlanBindings.dispose();
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  testWidgets('JT-A-ST-1: each plan step reloads Home, My Stay, Calendar and Jobs once and follows the plan', (t) async {
    var step = 'Free';
    final cal = CalendarHarness.setUp(
      override: (method, path, body) async {
        if (method == 'GET' && path == '/stays/me/calendar') {
          return {'data': monthJson(plus: _plus(step), hiddenCount: step == 'Ended' ? 2 : 0)};
        }
        return const {};
      },
    );
    PlanGate.debugPlan = null;
    final plans = FakePlanRepository([_steps['Free']!]);
    Get.put<PlanRepository>(plans, permanent: true);
    PlanBindings.ensure();
    var hubCalls = 0;
    final hub = Get.put(
      StayHubController(
        userId: () => 'user-a',
        fetch: () async {
          hubCalls++;
          return {'data': _stayFor(step)};
        },
      ),
      tag: StayHubController.tag,
    );
    final jobsRepo = _Jobs();
    final jobs = Get.put(MyJobsController(repo: jobsRepo, refreshOnTab: AppTabs.fourth), tag: StayJobsTab.tag);
    StayOwnerSession.register();
    final calendar = cal.calendar;
    await t.runAsync(() async {
      await pumpEventQueue();
      await calendar.open(DateTime(2026, 11));
      await pumpEventQueue();
    });

    int months() => cal.transport.calls.where((c) => c == 'GET /stays/me/calendar').length;
    int summaries() => cal.transport.calls.where((c) => c == 'GET /stays/me/calendar/summary').length;

    for (final next in ['Trial', 'Plus', 'Cancelled', 'Ended', 'Resubscribed']) {
      final hub0 = hubCalls, m0 = months(), s0 = summaries(), j0 = jobsRepo.calls;
      step = next;
      jobsRepo.open = _plus(next);
      plans.bodies
        ..clear()
        ..add(_steps[next]!);
      await t.runAsync(() async {
        await Get.find<PlanController>().invalidate();
        await Future<void>.delayed(OwnerPlanSync.debounce + const Duration(milliseconds: 80));
        await pumpEventQueue();
      });
      await t.pump();
      expect(hubCalls - hub0, 1, reason: '$next: My Stay reloads once');
      expect(months() - m0, 1, reason: '$next: Calendar month reloads once');
      expect(jobsRepo.calls - j0, 1, reason: '$next: Jobs reloads once');
      expect(summaries() - s0, _plus(next) ? 1 : 0, reason: '$next: month summary follows the plan');
      expect(jobs.page.value?.canPost, _plus(next), reason: '$next: Post a job');

      final s = hub.stay!;
      final photoLimit = s.meter('Photos')?.limit ?? PlanGate.limit(PlanKey.photos);
      if (_plus(next)) {
        expect(s.hiddenPhotos, isEmpty, reason: '$next: nothing hidden');
        expect(s.photos.length < photoLimit, isTrue, reason: '$next: the add-photo tile is offered');
        expect(PlanGate.canUpgrade, isFalse);
      } else {
        expect(s.hiddenPhotos, hasLength(3), reason: 'Ended: hidden photos stay stored');
        expect(s.hiddenRooms, hasLength(1));
        expect(PlanGate.canUpgrade, isTrue);
        expect(calendar.data?.hiddenCount, 2, reason: 'Ended: calendar shows the hidden count');
      }
    }
  });

  testWidgets('JT-A-ST-1 Ended: a past booking offers Edit amounts and Delete only', (t) async {
    final h = CalendarHarness.setUp(plan: OwnerPlans.free, month: monthJson(), extra: (p) {
      if (p == '/stays/me/calendar/entries/old') return entryJson('old', '2026-11-01', '2026-11-03', 'Walk-in', finalAmount: 4000, received: 1000);
      return null;
    });
    await pumpPhone(t, StayCalendarEntryScreen(args: const {'id': 'old'}, controller: h.calendar));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Edit amounts'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Edit booking'), findsNothing);
  });

  test('JT-A-ST-1 Plus: the money summary reads the server body', () {
    final s = MoneySummary.fromJson(loadSample('calendar_summary'));
    expect(s.booked, greaterThan(0));
    expect(s.toCollect, s.booked - s.received);
    expect(s.top, isNotEmpty);
  });

  test('JT-A-ST-1 Ended: a write answer without plan rows keeps hidden rows and meters', () {
    final current = stayJson(hiddenPhotos: 3, hiddenRooms: 1);
    final body = Map<String, dynamic>.from(current)
      ..remove('hiddenPhotos')
      ..remove('hiddenRooms')
      ..remove('meters');
    final m = StayOwnerModel.fromJson(current).mergeFrom(StayOwnerModel.fromJson(body));
    expect(m.hiddenPhotos, hasLength(3));
    expect(m.hiddenRooms, hasLength(1));
    expect(m.meter('Photos')?.limit, 2);
  });
}
