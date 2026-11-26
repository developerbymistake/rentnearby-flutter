import 'dart:async';

import 'package:bakhli/features/owner_core/calendar/month_grid_data.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/home/owner_home_api.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_api.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_controller.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_models.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_controller.dart';
import 'package:bakhli/features/taxi_driver/taxi_driver_deps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import 'taxi_avail_fixtures.dart';

class _HomeApi implements OwnerHomeApi {
  _HomeApi(this.json);

  final Map<String, dynamic> json;

  @override
  Future<OwnerResult<OwnerHomeDto>> load() async => OwnerOk<OwnerHomeDto>(OwnerHomeDto.fromJson(json));
}

Map<String, dynamic> _home({bool switchOn = true}) => {
      'today': '2026-11-26',
      'listing': {'id': 't1', 'status': 'Approved', 'everApproved': true, 'switchOn': switchOn},
      'numbers': {
        'taxi': {
          'newRequests': 0,
          'availability': {'month': '2026-11', 'bookings': 3, 'daysOff': 0},
        },
      },
    };

DayCell _cell(TaxiAvailabilityController c, int day) => c.cells.firstWhere((x) => x.inMonth && x.date.day == day);

void main() {
  setUpAll(() => initTestStorage('taxi_avail_controller'));
  tearDown(availTearDown);

  group('state and pending', () {
    test('cells follow the rules: past, booked, off, free, today', () async {
      final h = await availSetUp(AvailFake(read: availJson()));
      final c = h.controller;
      expect(c.stateOf(_cell(c, 25)), TaxiAvailDay.past);
      expect(c.stateOf(_cell(c, 26)), TaxiAvailDay.free);
      expect(_cell(c, 26).isToday, isTrue);
      expect(c.stateOf(_cell(c, 27)), TaxiAvailDay.off);
      expect(c.stateOf(_cell(c, 28)), TaxiAvailDay.booked);
      expect(c.stateOf(_cell(c, 29)), TaxiAvailDay.free);
      expect(c.list.map((d) => d.key), ['2026-11-27', '2026-11-30']);
      expect(c.dirty.value, isFalse);
    });

    test('mark, then make available again = clean, Save off', () async {
      final h = await availSetUp(AvailFake(read: availJson()));
      final c = h.controller;
      c.apply(DateTime(2026, 11, 29), const TaxiReasonAction.mark('Wedding'));
      expect(c.dirty.value, isTrue);
      expect(c.stateOf(_cell(c, 29)), TaxiAvailDay.off);
      expect(c.list.map((d) => d.key), ['2026-11-27', '2026-11-29', '2026-11-30']);
      c.apply(DateTime(2026, 11, 29), const TaxiReasonAction.makeAvailable());
      expect(c.dirty.value, isFalse);
      expect(c.stateOf(_cell(c, 29)), TaxiAvailDay.free);
    });

    test('a booked or past day cannot be marked', () async {
      final h = await availSetUp(AvailFake(read: availJson()));
      final c = h.controller;
      c.apply(DateTime(2026, 11, 28), const TaxiReasonAction.mark(null));
      c.apply(DateTime(2026, 11, 20), const TaxiReasonAction.mark(null));
      expect(c.dirty.value, isFalse);
    });

    test('fresh data drops pending days that became booked', () async {
      final h = await availSetUp(AvailFake(read: availJson()));
      final c = h.controller;
      c.apply(DateTime(2026, 11, 29), const TaxiReasonAction.mark(null));
      h.store.apply(TaxiAvailability.fromJson(availJson(booked: ['2026-11-28', '2026-11-29'])));
      expect(c.pending, isEmpty);
      expect(c.stateOf(_cell(c, 29)), TaxiAvailDay.booked);
    });

    test('a cached server today from yesterday does not keep yesterday open', () async {
      final h = await availSetUp(AvailFake(read: availJson(today: '2026-11-25', daysOff: [dayRow('2026-11-25', 'old'), dayRow('2026-11-27')])));
      final c = h.controller;
      expect(c.today, availToday);
      expect(c.stateOf(_cell(c, 25)), TaxiAvailDay.past);
      expect(_cell(c, 26).isToday, isTrue);
      expect(c.list.map((d) => d.key), ['2026-11-27']);
      c.apply(DateTime(2026, 11, 25), const TaxiReasonAction.makeAvailable());
      expect(c.dirty.value, isFalse);
    });

    test('a page left open past midnight moves today on checkDay and drops the old day', () async {
      availBase();
      final store = availStore(AvailFake(read: availJson(daysOff: [dayRow('2026-11-26', 'old'), dayRow('2026-11-27')])));
      await store.refresh();
      var now = DateTime(2026, 11, 26, 23, 50);
      final c = Get.put(TaxiAvailabilityController(store: store, clock: () => now), tag: TaxiAvailabilityController.tag);
      c.apply(DateTime(2026, 11, 26), const TaxiReasonAction.saveReason('new'));
      expect(c.list.map((d) => d.key), ['2026-11-26', '2026-11-27']);
      expect(c.dirty.value, isTrue);
      now = DateTime(2026, 11, 27, 0, 10);
      c.checkDay();
      expect(c.today, DateTime(2026, 11, 27));
      expect(c.stateOf(_cell(c, 26)), TaxiAvailDay.past);
      expect(_cell(c, 27).isToday, isTrue);
      expect(c.list.map((d) => d.key), ['2026-11-27']);
      expect(c.pending, isEmpty);
      expect(c.dirty.value, isFalse);
      c.apply(DateTime(2026, 11, 26), const TaxiReasonAction.makeAvailable());
      expect(c.dirty.value, isFalse);
    });

    test('a server today ahead of the phone clock wins', () async {
      final h = await availSetUp(AvailFake(read: availJson(today: '2026-11-27')));
      final c = h.controller;
      expect(c.today, DateTime(2026, 11, 27));
      expect(c.stateOf(_cell(c, 26)), TaxiAvailDay.past);
    });

    test('a saved day beyond the window after a downgrade keeps its reason edit', () async {
      final h = await availSetUp(AvailFake(read: availJson(daysOff: [dayRow('2026-12-05', 'old')])));
      final c = h.controller;
      expect(c.list.map((d) => d.key), ['2026-12-05']);
      c.apply(DateTime(2026, 12, 5), const TaxiReasonAction.saveReason('new'));
      expect(c.diff().set.single.toJson(), {'date': '2026-12-05', 'reason': 'new'});
    });
  });

  group('save', () {
    test('one PUT with the whole diff; success applies the store, patches Home and returns true', () async {
      final fake = AvailFake(read: availJson());
      fake.save = (body) async => {
            'data': availJson(daysOff: [dayRow('2026-11-27', 'Family function in Almora'), dayRow('2026-11-29', 'Wedding')], daysOffCount: 2),
          };
      final h = await availSetUp(fake);
      final home = Get.put(TaxiDriverHomeController(api: _HomeApi(_home()), deniedProbe: () async => false, userId: () => 'user-a'));
      await home.reload();
      var refreshed = 0;
      TaxiDriverDeps.refreshHome = () async => refreshed++;
      final c = h.controller;
      c.apply(DateTime(2026, 11, 29), const TaxiReasonAction.mark('Wedding'));
      c.apply(DateTime(2026, 11, 30), const TaxiReasonAction.makeAvailable());
      final ok = await c.save();
      expect(ok, isTrue);
      expect(fake.count('PUT $daysOffPath'), 1);
      expect(fake.saves.single, {
        'set': [
          {'date': '2026-11-29', 'reason': 'Wedding'},
        ],
        'clear': ['2026-11-30'],
      });
      expect(fake.saves.single.containsKey('opId'), isFalse);
      expect(c.dirty.value, isFalse);
      expect(h.store.value.value?.hasOff(DateTime(2026, 11, 29)), isTrue);
      expect(home.data?.availability?.daysOff, 2);
      expect(refreshed, 1);
      expect(OwnerCache.read('user-a', OwnerCacheKeys.daysOff), isNotNull);
    });

    test('double tap = one call', () async {
      final fake = AvailFake(read: availJson());
      final h = await availSetUp(fake);
      final c = h.controller;
      c.apply(DateTime(2026, 11, 29), const TaxiReasonAction.mark(null));
      final a = c.save();
      final b = c.save();
      await Future.wait([a, b]);
      expect(fake.count('PUT'), 1);
    });

    test('offline keeps the choices and returns false', () async {
      final fake = AvailFake(read: availJson());
      fake.save = (body) async => throw offlineError(daysOffPath);
      final h = await availSetUp(fake);
      final c = h.controller;
      c.apply(DateTime(2026, 11, 29), const TaxiReasonAction.mark('x'));
      expect(await c.save(), isFalse);
      expect(c.dirty.value, isTrue);
      expect(c.stateOf(_cell(c, 29)), TaxiAvailDay.off);
      expect(c.saving.value, isFalse);
    });

    test('server failure and exception keep the choices', () async {
      final fake = AvailFake(read: availJson());
      fake.save = (body) async => throw refusal(daysOffPath, 500, {'error': {'message': 'boom'}});
      final h = await availSetUp(fake);
      final c = h.controller;
      c.apply(DateTime(2026, 11, 29), const TaxiReasonAction.mark(null));
      expect(await c.save(), isFalse);
      expect(c.dirty.value, isTrue);
      fake.save = (body) async => throw StateError('x');
      expect(await c.save(), isFalse);
      expect(c.dirty.value, isTrue);
    });

    test('429 with the bucket: minutes from the header, no retry, a second tap inside the window makes no call', () async {
      final fake = AvailFake(read: availJson());
      fake.save = (body) async => throw refusal(daysOffPath, 429, bucket429(seconds: 61), headers: {
            'retry-after': ['61'],
          });
      final h = await availSetUp(fake);
      final c = h.controller;
      c.apply(DateTime(2026, 11, 29), const TaxiReasonAction.mark(null));
      expect(await c.save(), isFalse);
      expect(fake.count('PUT'), 1);
      expect(TaxiHourlyLimit.heldSeconds(TaxiHourlyLimit.availability), inInclusiveRange(60, 61));
      expect(await c.save(), isFalse);
      expect(fake.count('PUT'), 1);
      expect(c.dirty.value, isTrue);
    });

    test('429 minutes: 61 s = 2 min, 1 s = 1 min, 1520 s = 26 min', () {
      expect(TaxiHourlyLimit.minutes(61), 2);
      expect(TaxiHourlyLimit.minutes(1), 1);
      expect(TaxiHourlyLimit.minutes(60), 1);
      expect(TaxiHourlyLimit.minutes(1520), 26);
    });

    test('a 429 without the bucket sets no hold', () async {
      final fake = AvailFake(read: availJson());
      fake.save = (body) async => throw refusal(daysOffPath, 429, {'error': {'type': 'TooManyRequests', 'message': 'Too many tries. Please wait.'}});
      final h = await availSetUp(fake);
      final c = h.controller;
      c.apply(DateTime(2026, 11, 29), const TaxiReasonAction.mark(null));
      expect(await c.save(), isFalse);
      expect(TaxiHourlyLimit.heldSeconds(TaxiHourlyLimit.availability), isNull);
      expect(await c.save(), isFalse);
      expect(fake.count('PUT'), 2);
    });

    test('hold expires with the clock', () async {
      var now = DateTime(2026, 11, 26, 10);
      TaxiHourlyLimit.clock = () => now;
      TaxiHourlyLimit.hold(TaxiHourlyLimit.availability, 120);
      expect(TaxiHourlyLimit.heldSeconds(TaxiHourlyLimit.availability), 120);
      now = now.add(const Duration(seconds: 121));
      expect(TaxiHourlyLimit.heldSeconds(TaxiHourlyLimit.availability), isNull);
    });

    test('DayOffBooked refreshes the store and drops the booked pending day', () async {
      final fake = AvailFake(read: availJson());
      fake.save = (body) async {
        fake.read = availJson(booked: ['2026-11-28', '2026-11-29']);
        throw refusal(daysOffPath, 409, {
          'data': {'dates': ['2026-11-29']},
          'error': {'type': 'DayOffBooked', 'message': 'This day has a booking'},
        });
      };
      final h = await availSetUp(fake);
      final c = h.controller;
      c.apply(DateTime(2026, 11, 29), const TaxiReasonAction.mark(null));
      expect(await c.save(), isFalse);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(fake.count('GET'), greaterThanOrEqualTo(2));
      expect(c.pending, isEmpty);
    });

    test('PlanFeatureLocked refreshes and keeps the choices inside the window', () async {
      final fake = AvailFake(read: availJson());
      fake.save = (body) async => throw refusal(daysOffPath, 403, {
            'data': {'key': 'monthsAhead'},
            'error': {'type': 'PlanFeatureLocked', 'message': 'Plus'},
          });
      final h = await availSetUp(fake);
      final c = h.controller;
      c.apply(DateTime(2026, 11, 29), const TaxiReasonAction.mark(null));
      expect(await c.save(), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(c.pending.keys, ['2026-11-29']);
    });

    test('nothing changed = no call', () async {
      final fake = AvailFake(read: availJson());
      final h = await availSetUp(fake);
      expect(await h.controller.save(), isFalse);
      expect(fake.count('PUT'), 0);
    });

    test('a change while the PUT is in flight is refused, so success cannot wipe it', () async {
      final fake = AvailFake(read: availJson());
      final gate = Completer<Map<String, dynamic>>();
      fake.save = (body) => gate.future;
      final h = await availSetUp(fake);
      final c = h.controller;
      c.apply(DateTime(2026, 11, 29), const TaxiReasonAction.mark(null));
      final f = c.save();
      expect(c.saving.value, isTrue);
      c.apply(DateTime(2026, 12, 1), const TaxiReasonAction.mark('late'));
      c.apply(DateTime(2026, 11, 27), const TaxiReasonAction.makeAvailable());
      expect(c.pending.keys, ['2026-11-29']);
      gate.complete({'data': availJson(daysOff: [dayRow('2026-11-27', 'Family function in Almora'), dayRow('2026-11-29'), dayRow('2026-11-30')])});
      expect(await f, isTrue);
      expect(fake.saves.single, {
        'set': [
          {'date': '2026-11-29', 'reason': null},
        ],
        'clear': <String>[],
      });
      expect(c.dirty.value, isFalse);
    });

    test('a success that lands after the page closed still updates the store and Home', () async {
      final fake = AvailFake(read: availJson());
      final gate = Completer<Map<String, dynamic>>();
      fake.save = (body) => gate.future;
      final h = await availSetUp(fake);
      final home = Get.put(TaxiDriverHomeController(api: _HomeApi(_home()), deniedProbe: () async => false, userId: () => 'user-a'));
      await home.reload();
      var refreshed = 0;
      TaxiDriverDeps.refreshHome = () async => refreshed++;
      final c = h.controller;
      c.apply(DateTime(2026, 11, 29), const TaxiReasonAction.mark('Wedding'));
      final f = c.save();
      Get.delete<TaxiAvailabilityController>(tag: TaxiAvailabilityController.tag, force: true);
      gate.complete({
        'data': availJson(daysOff: [dayRow('2026-11-27', 'Family function in Almora'), dayRow('2026-11-29', 'Wedding'), dayRow('2026-11-30')], daysOffCount: 3),
      });
      expect(await f, isTrue);
      expect(h.store.value.value?.daysOff['2026-11-29']?.reason, 'Wedding');
      expect(OwnerCache.read('user-a', OwnerCacheKeys.daysOff)?['daysOff'], hasLength(3));
      expect(home.data?.availability?.daysOff, 3);
      expect(refreshed, 1);
    });

    test('closing the page drops the pending map', () async {
      final fake = AvailFake(read: availJson());
      final h = await availSetUp(fake);
      h.controller.apply(DateTime(2026, 11, 29), const TaxiReasonAction.mark(null));
      Get.delete<TaxiAvailabilityController>(tag: TaxiAvailabilityController.tag, force: true);
      final again = Get.put(TaxiAvailabilityController(store: h.store, clock: () => availToday), tag: TaxiAvailabilityController.tag);
      expect(again.dirty.value, isFalse);
      expect(again.stateOf(_cell(again, 29)), TaxiAvailDay.free);
      expect(fake.count('PUT'), 0);
    });
  });

  group('offline note source', () {
    test('switch state follows the Home controller first, the days-off read second', () async {
      final h = await availSetUp(AvailFake(read: availJson(switchOn: false)));
      expect(h.controller.switchOn, isFalse);
      final home = Get.put(TaxiDriverHomeController(api: _HomeApi(_home(switchOn: true)), deniedProbe: () async => false, userId: () => 'user-a'));
      await home.reload();
      expect(h.controller.switchOn, isTrue);
      home.switchOverride.value = false;
      expect(h.controller.switchOn, isFalse);
    });

    test('the offline note shows only when Home has the switch', () async {
      final h = await availSetUp(AvailFake(read: availJson(switchOn: false)));
      expect(h.controller.showOfflineNote, isTrue, reason: 'no Home data: the days-off read decides');
      final down = _home(switchOn: false);
      down['listing'] = {'id': 't1', 'status': 'Approved', 'everApproved': true, 'switchOn': false, 'takenDown': true};
      final home = Get.put(TaxiDriverHomeController(api: _HomeApi(down), deniedProbe: () async => false, userId: () => 'user-a'));
      await home.reload();
      expect(h.controller.switchOn, isFalse);
      expect(h.controller.showOfflineNote, isFalse);
      Get.delete<TaxiDriverHomeController>(force: true);
      final live = Get.put(TaxiDriverHomeController(api: _HomeApi(_home(switchOn: false)), deniedProbe: () async => false, userId: () => 'user-a'));
      await live.reload();
      expect(h.controller.showOfflineNote, isTrue);
    });

    test('no offline note while changes are under review: the Home switch is locked', () async {
      final h = await availSetUp(AvailFake(read: availJson(switchOn: false)));
      final review = _home(switchOn: false);
      review['listing'] = {'id': 't1', 'status': 'PendingReview', 'everApproved': true, 'switchOn': false};
      final home = Get.put(TaxiDriverHomeController(api: _HomeApi(review), deniedProbe: () async => false, userId: () => 'user-a'));
      await home.reload();
      expect(h.controller.switchOn, isFalse);
      expect(h.controller.showOfflineNote, isFalse);
    });
  });
}
