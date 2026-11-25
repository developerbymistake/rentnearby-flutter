import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/plan_bindings.dart';
import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/plan/plan_keys.dart';
import 'package:bakhli/features/owner_core/session/owner_plan_sync.dart';
import 'package:bakhli/features/stay_owner/hub/stay_hub_controller.dart';
import 'package:bakhli/features/stay_owner/stay_owner_session.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../core/stay_fixtures.dart';

// Plan lifecycle L3 to L14 for the stay owner: every /plans/me change reaches the hub (the stay read behind
// Rooms, Photos, Special prices, Calendar rows) through the real PlanController, OwnerPlanSync and
// StayOwnerSession.onPlanChanged. The server body is whatever the fake says; the app must follow it.

class _LiveRepo extends FakePlanRepository {
  _LiveRepo(this.current) : super([current]);

  Map<String, dynamic> current;

  @override
  Future<MyPlanModel> getMe({bool forceRefresh = false}) async {
    meCalls++;
    final f = failWith;
    if (f != null) throw f;
    return MyPlanModel.fromJson(current);
  }
}

const _freeLimits = {'photos': 2, 'roomTypes': 2, 'jobsPosts': 1, 'specialPrices': 1, 'calendarEntries': 4, 'blockedRanges': 1};
const _plusLimits = {
  'photos': 8,
  'roomTypes': 6,
  'jobsPosts': 4,
  'specialPrices': 5,
  'calendarEntries': 50,
  'blockedRanges': 10,
  'upcomingDays': 183,
  'monthsAhead': 6,
  'monthSummary': true,
  'reminders': true,
  'featured': true,
  'priority': 1,
};

Map<String, dynamic> _free() => {'paymentEnabled': true, 'trialAvailable': true, 'limits': _freeLimits};

Map<String, dynamic> _plus({String state = 'SUBSCRIPTION_STATE_ACTIVE', bool renew = true, String? endsAt, String source = 'Play'}) => {
      'paymentEnabled': true,
      'isPaid': true,
      'source': source,
      'plan': {'id': 'plus', 'name': 'Plus', 'isDefault': false},
      'endsAt': endsAt ?? '2026-12-25T00:00:00Z',
      'limits': _plusLimits,
      'play': {'state': state, 'autoRenewEnabled': renew, 'expiryAt': endsAt ?? '2026-12-25T00:00:00Z', 'ownsActivePlan': true},
    };

Map<String, dynamic> _ended({int photos = 2, int rooms = 1, String state = 'SUBSCRIPTION_STATE_EXPIRED'}) => {
      'paymentEnabled': true,
      'trialAvailable': false,
      'limits': _freeLimits,
      'hidden': {'photos': photos, 'roomTypes': rooms},
      'pausedByPlanCount': photos + rooms,
      'play': {
        'state': state,
        'autoRenewEnabled': false,
        'expiryAt': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
        'ownsActivePlan': false,
      },
    };

Map<String, dynamic> _onHold() => {
      'paymentEnabled': true,
      'limits': _freeLimits,
      'hidden': {'photos': 2, 'roomTypes': 1},
      'play': {'state': 'SUBSCRIPTION_STATE_ON_HOLD', 'autoRenewEnabled': true, 'ownsActivePlan': true},
    };

Map<String, dynamic> _stayFree() => stayJson();

Map<String, dynamic> _stayPlus() => stayJson(
      rooms: 4,
      photos: 6,
      meters: [
        {'key': 'Photos', 'used': 6, 'limit': 8},
        {'key': 'RoomTypes', 'used': 4, 'limit': 6},
      ],
    );

Map<String, dynamic> _stayExpired() => stayJson(hiddenRooms: 2, hiddenPhotos: 4);

late _LiveRepo _repo;
late Map<String, dynamic> _server;
late StayHubController _hub;
int _hubFetches = 0;

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 600));

Future<void> _boot({Map<String, dynamic>? plan, Map<String, dynamic>? stay}) async {
  Get.reset();
  Get.testMode = true;
  OwnerPlanSync.reset();
  PlanGate.debugPlan = null;
  Get.put<TabConfigController>(FakeTabs());
  final auth = StayFakeAuth();
  Get.put<AuthController>(auth);
  auth.signIn(role: 'STAY_OWNER', stayStatus: 'Approved');
  _repo = _LiveRepo(plan ?? _free());
  Get.put<PlanRepository>(_repo, permanent: true);
  _server = stay ?? _stayFree();
  _hubFetches = 0;
  OwnerPlanSync.register('stay', StayOwnerSession.onPlanChanged);
  PlanBindings.ensure();
  _hub = Get.put(
    StayHubController(
      userId: () => 'user-a',
      fetch: () async {
        _hubFetches++;
        return {'data': _server};
      },
    ),
    tag: StayHubController.tag,
  );
  await _flush();
}

Future<void> _serverChanges(String push, Map<String, dynamic> plan, Map<String, dynamic> stay) async {
  _repo.current = plan;
  _server = stay;
  Get.find<PlanController>().onPushNotification(push);
  await _flush();
}

PlanCardState _card() => PlanCardStates.ofPlan(Get.find<PlanController>().myPlan.value);

void main() {
  setUpAll(() => initTestStorage('stay_plan_sync_lifecycle'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanBindings.dispose();
    PlanGate.debugPlan = null;
    OwnerApi.debugReset();
    resetOwnerTestState();
  });

  group('L1 and L2 Free: limits come from /plans/me, not from a constant', () {
    test('Free owner: limits 2 / 2 / 1 / 1 / 4 / 1, Plus can be bought, card is Free', () async {
      await _boot();
      expect(PlanGate.loaded, isTrue);
      expect(PlanGate.paymentOn, isTrue);
      expect(PlanGate.limit(PlanKey.photos), 2);
      expect(PlanGate.limit(PlanKey.roomTypes), 2);
      expect(PlanGate.limit(PlanKey.jobsPosts), 1);
      expect(PlanGate.limit(PlanKey.specialPrices), 1);
      expect(PlanGate.limit(PlanKey.calendarEntries), 4);
      expect(PlanGate.limit(PlanKey.blockedRanges), 1);
      expect(PlanGate.canUpgrade, isTrue);
      expect(PlanGate.locks(PlanKey.photos, 2), isTrue);
      expect(PlanGate.locks(PlanKey.photos, 1), isFalse);
      expect(PlanGate.addEnabled(true), isTrue, reason: 'Add stays enabled at the Free limit, it opens the Plus sheet');
      expect(_card(), PlanCardState.free);
      expect(_hub.stay?.photos.length, 2);
    });
  });

  group('L3 buy Plus', () {
    test('a plan push after the purchase raises every limit and reloads the stay once', () async {
      await _boot();
      final plansBefore = _repo.meCalls;
      final hubBefore = _hubFetches;
      await _serverChanges('plan_activated', _plus(), _stayPlus());
      expect(_repo.meCalls, greaterThan(plansBefore));
      expect(_hubFetches, hubBefore + 1, reason: 'one planVersion bump, one debounced reload');
      expect(PlanGate.limit(PlanKey.photos), 8);
      expect(PlanGate.limit(PlanKey.roomTypes), 6);
      expect(PlanGate.limit(PlanKey.jobsPosts), 4);
      expect(PlanGate.limit(PlanKey.specialPrices), 5);
      expect(PlanGate.limit(PlanKey.calendarEntries), 50);
      expect(PlanGate.limit(PlanKey.blockedRanges), 10);
      expect(PlanGate.canUpgrade, isFalse);
      expect(PlanGate.locks(PlanKey.photos, 7), isFalse);
      expect(PlanGate.locks(PlanKey.photos, 8), isFalse, reason: 'Plus full is greyed, never the Plus sheet');
      expect(PlanGate.addEnabled(true), isFalse);
      expect(_card(), PlanCardState.plus);
      expect(_hub.stay?.photos.length, 6, reason: 'counters come from the server');
      expect(_hub.stay?.rooms.length, 4);
      expect(_hub.stay?.meter('Photos')?.limit, 8);
    });

    test('PlanLimitsChanged (PascalCase hub event) is read as a plan event too', () async {
      await _boot();
      final before = _repo.meCalls;
      await _serverChanges('PlanLimitsChanged', _plus(), _stayPlus());
      expect(_repo.meCalls, greaterThan(before));
      expect(PlanGate.limit(PlanKey.photos), 8);
    });
  });

  group('L5 cancel while Plus runs', () {
    test('auto-renew off: everything stays at Plus limits, card says Cancelled, rows stay active', () async {
      await _boot(plan: _plus(), stay: _stayPlus());
      expect(_card(), PlanCardState.plus);
      final hubBefore = _hubFetches;
      await _serverChanges('plan_cancelled', _plus(state: 'SUBSCRIPTION_STATE_CANCELED', renew: false), _stayPlus());
      expect(_card(), PlanCardState.cancelled);
      expect(PlanGate.limit(PlanKey.photos), 8, reason: 'Plus runs until endsAt');
      expect(PlanGate.canUpgrade, isFalse);
      expect(Get.find<PlanController>().myPlan.value.endsAt, isNotNull);
      expect(_hubFetches, hubBefore + 1);
      expect(_hub.stay?.hiddenPhotos, isEmpty);
      expect(_hub.stay?.hiddenRooms, isEmpty);
    });

    test('resubscribe while cancelled: back to Plus, no row changes', () async {
      await _boot(plan: _plus(state: 'SUBSCRIPTION_STATE_CANCELED', renew: false), stay: _stayPlus());
      expect(_card(), PlanCardState.cancelled);
      await _serverChanges('plan_activated', _plus(), _stayPlus());
      expect(_card(), PlanCardState.plus);
      expect(_hub.stay?.hiddenPhotos, isEmpty);
    });
  });

  group('L6 expire', () {
    test('Plus ends: Free limits, Subscribe again, older rows come back as hidden (kept, not deleted)', () async {
      await _boot(plan: _plus(state: 'SUBSCRIPTION_STATE_CANCELED', renew: false), stay: _stayPlus());
      await _serverChanges('plan_expired', _ended(), _stayExpired());
      expect(_card(), PlanCardState.ended);
      expect(PlanGate.limit(PlanKey.photos), 2);
      expect(PlanGate.limit(PlanKey.roomTypes), 2);
      expect(PlanGate.canUpgrade, isTrue, reason: 'Plus can be bought again');
      expect(Get.find<PlanController>().myPlan.value.hidden.photos, 2);
      expect(Get.find<PlanController>().myPlan.value.hidden.roomTypes, 1);
      expect(_hub.stay?.photos.length, 2);
      expect(_hub.stay?.hiddenPhotos.length, 4, reason: 'nothing deleted');
      expect(_hub.stay?.hiddenRooms.length, 2);
    });

    test('expire with no rows over the limit: plan is Free again, nothing hidden', () async {
      await _boot(plan: _plus(), stay: _stayFree());
      await _serverChanges('plan_expired', _ended(photos: 0, rooms: 0), _stayFree());
      expect(PlanGate.limit(PlanKey.photos), 2);
      expect(_hub.stay?.hiddenPhotos, isEmpty);
    });
  });

  group('L7 grace and L8 hold or pause', () {
    test('grace: Plus stays, card is Grace', () async {
      await _boot(plan: _plus(), stay: _stayPlus());
      await _serverChanges('plan_grace', _plus(state: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'), _stayPlus());
      expect(_card(), PlanCardState.grace);
      expect(PlanGate.limit(PlanKey.photos), 8);
      expect(_hub.stay?.hiddenPhotos, isEmpty);
    });

    test('hold: Free limits, card OnHold; resume restores Plus', () async {
      await _boot(plan: _plus(), stay: _stayPlus());
      await _serverChanges('plan_on_hold', _onHold(), _stayExpired());
      expect(_card(), PlanCardState.onHold);
      expect(PlanGate.limit(PlanKey.photos), 2);
      expect(_hub.stay?.hiddenPhotos.length, 4);
      await _serverChanges('plan_resumed', _plus(), _stayPlus());
      expect(_card(), PlanCardState.plus);
      expect(PlanGate.limit(PlanKey.photos), 8);
      expect(_hub.stay?.hiddenPhotos, isEmpty);
    });

    test('paused reads as not Plus, same as hold', () async {
      await _boot(plan: _plus(), stay: _stayPlus());
      final paused = {..._onHold(), 'play': {'state': 'SUBSCRIPTION_STATE_PAUSED', 'autoRenewEnabled': true, 'ownsActivePlan': true}};
      await _serverChanges('plan_paused', paused, _stayExpired());
      expect(_card(), PlanCardState.onHold);
      expect(PlanGate.limit(PlanKey.roomTypes), 2);
    });
  });

  group('L9 re-subscribe after expiry', () {
    test('Free ended with hidden rows, buy again: limits Plus, hidden rows active again, counters from server', () async {
      await _boot(plan: _ended(), stay: _stayExpired());
      expect(_card(), PlanCardState.ended);
      expect(_hub.stay?.hiddenPhotos.length, 4);
      await _serverChanges('plan_activated', _plus(), _stayPlus());
      expect(_card(), PlanCardState.plus);
      expect(PlanGate.limit(PlanKey.photos), 8);
      expect(_hub.stay?.hiddenPhotos, isEmpty);
      expect(_hub.stay?.hiddenRooms, isEmpty);
      expect(_hub.stay?.photos.length, 6);
      expect(_hub.stay?.rooms.length, 4);
    });
  });

  group('L10 refund or revoke', () {
    test('a revoked purchase is read like an expiry at once', () async {
      await _boot(plan: _plus(), stay: _stayPlus());
      await _serverChanges('plan_revoked', _ended(state: 'SUBSCRIPTION_STATE_EXPIRED'), _stayExpired());
      expect(_card(), PlanCardState.ended);
      expect(PlanGate.limit(PlanKey.photos), 2);
      expect(_hub.stay?.hiddenPhotos.length, 4);
    });
  });

  group('L11 trial start and end', () {
    test('trial: Plus limits and card Trial; trial end: as an expiry', () async {
      await _boot();
      await _serverChanges('plan_activated', _plus(source: 'Trial'), _stayPlus());
      expect(_card(), PlanCardState.trial);
      expect(PlanGate.limit(PlanKey.photos), 8);
      expect(PlanGate.canUpgrade, isFalse);
      await _serverChanges('plan_expired', _ended(), _stayExpired());
      expect(_card(), PlanCardState.ended);
      expect(PlanGate.limit(PlanKey.photos), 2);
      expect(_hub.stay?.hiddenPhotos.length, 4);
    });
  });

  group('L12 switch cycle and plan change', () {
    test('a longer cycle moves endsAt only: no limit drops, rows stay active', () async {
      await _boot(plan: _plus(), stay: _stayPlus());
      final hubBefore = _hubFetches;
      await _serverChanges('plan_changed', _plus(endsAt: '2027-02-25T00:00:00Z'), _stayPlus());
      expect(PlanGate.limit(PlanKey.photos), 8);
      expect(_card(), PlanCardState.plus);
      expect(_hub.stay?.hiddenPhotos, isEmpty);
      expect(_hubFetches, hubBefore + 1);
    });
  });

  group('L13 restore purchases', () {
    test('the same entitlement answered again changes no screen and reloads nothing', () async {
      await _boot(plan: _plus(), stay: _stayPlus());
      final hubBefore = _hubFetches;
      final plansBefore = _repo.meCalls;
      Get.find<PlanController>().onPushNotification('plan_restored');
      await _flush();
      expect(_repo.meCalls, greaterThan(plansBefore), reason: 'the plan is asked again');
      expect(_hubFetches, hubBefore, reason: 'same answer, no planVersion bump, no reload');
      expect(_card(), PlanCardState.plus);
      expect(_hub.stay?.hiddenPhotos, isEmpty);
    });
  });

  group('L14 payment off', () {
    test('payment OFF: nothing hidden, no upgrade path, limits are the full ones', () async {
      await _boot(plan: _ended(), stay: _stayExpired());
      final off = {'paymentEnabled': false, 'limits': _plusLimits};
      await _serverChanges('plan_changed', off, _stayPlus());
      expect(PlanGate.paymentOn, isFalse);
      expect(PlanGate.canUpgrade, isFalse);
      expect(PlanGate.limit(PlanKey.photos), 8);
      expect(PlanGate.locks(PlanKey.photos, 8), isFalse);
      expect(_card(), PlanCardState.paymentOff);
      expect(_hub.stay?.hiddenPhotos, isEmpty);
    });
  });

  group('refresh rules', () {
    test('a push that is not a plan event never asks /plans/me', () async {
      await _boot();
      final plansBefore = _repo.meCalls;
      final hubBefore = _hubFetches;
      Get.find<PlanController>().onPushNotification('stay_approved');
      Get.find<PlanController>().onPushNotification('enquiry_received');
      Get.find<PlanController>().onPushNotification(null);
      await _flush();
      expect(_repo.meCalls, plansBefore);
      expect(_hubFetches, hubBefore);
    });

    test('a burst of plan pushes ends on the newest answer and reloads the stay at most twice', () async {
      await _boot();
      final hubBefore = _hubFetches;
      _repo.current = _plus();
      _server = _stayPlus();
      final c = Get.find<PlanController>();
      for (final t in ['plan_activated', 'PlanActivated', 'plan_limits_changed']) {
        c.onPushNotification(t);
      }
      await _flush();
      expect(PlanGate.limit(PlanKey.photos), 8);
      expect(_hubFetches - hubBefore, lessThanOrEqualTo(2));
      expect(_hub.stay?.photos.length, 6);
    });

    test('a failed /plans/me keeps the last known plan and never fakes Plus', () async {
      await _boot();
      _repo.failWith = Exception('offline');
      Get.find<PlanController>().onPushNotification('plan_activated');
      await _flush();
      expect(PlanGate.limit(PlanKey.photos), 2);
      expect(PlanGate.canUpgrade, isTrue);
      expect(_card(), PlanCardState.free);
    });

    test('expire, then buy, then expire again: every step follows the server', () async {
      await _boot();
      await _serverChanges('plan_activated', _plus(), _stayPlus());
      expect(PlanGate.limit(PlanKey.roomTypes), 6);
      await _serverChanges('plan_expired', _ended(), _stayExpired());
      expect(PlanGate.limit(PlanKey.roomTypes), 2);
      await _serverChanges('plan_activated', _plus(), _stayPlus());
      expect(PlanGate.limit(PlanKey.roomTypes), 6);
      expect(_hub.stay?.hiddenRooms, isEmpty);
      await _serverChanges('plan_expired', _ended(), _stayExpired());
      expect(PlanGate.limit(PlanKey.roomTypes), 2);
      expect(_hub.stay?.hiddenRooms.length, 2);
    });
  });
}
