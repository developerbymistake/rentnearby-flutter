import 'dart:async';

import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/sheets/owner_states.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_models.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import 'taxi_avail_fixtures.dart';

void main() {
  setUpAll(() => initTestStorage('taxi_avail_store'));
  setUp(availBase);
  tearDown(availTearDown);

  test('cache first, then one refresh', () async {
    OwnerCache.write('user-a', OwnerCacheKeys.daysOff, availJson(daysOff: [dayRow('2026-11-29', 'cached')]));
    final fake = AvailFake(read: availJson());
    final gate = Completer<Map<String, dynamic>>();
    fake.readGate = gate;
    final store = availStore(fake);
    final f = store.ensure();
    expect(store.value.value?.daysOff.keys, ['2026-11-29']);
    expect(store.load.value, isA<OwnerLoadData<TaxiAvailability>>());
    expect((store.load.value as OwnerLoadData<TaxiAvailability>).stale, isFalse, reason: 'no stale line while the first refresh runs');
    gate.complete({'data': availJson()});
    await f;
    expect(store.value.value?.daysOff.keys, ['2026-11-27', '2026-11-30']);
    expect((store.load.value as OwnerLoadData<TaxiAvailability>).stale, isFalse);
    expect(fake.count('GET'), 1);
  });

  test('single flight: two ensure calls make one GET', () async {
    final fake = AvailFake(read: availJson());
    final store = availStore(fake);
    await Future.wait([store.ensure(), store.ensure()]);
    expect(fake.count('GET'), 1);
    await store.ensure();
    expect(fake.count('GET'), 1, reason: 'fresh for 30 s');
  });

  test('a GET that lands after a save is ignored', () async {
    final fake = AvailFake(read: availJson());
    final gate = Completer<Map<String, dynamic>>();
    fake.readGate = gate;
    final store = availStore(fake);
    final f = store.refresh();
    store.apply(TaxiAvailability.fromJson(availJson(daysOff: [dayRow('2026-11-29', 'saved')])));
    gate.complete({'data': availJson(daysOff: const [])});
    await f;
    expect(store.value.value?.daysOff.keys, ['2026-11-29']);
  });

  test('failure keeps the last value and marks it stale', () async {
    final fake = AvailFake(read: availJson());
    final store = availStore(fake);
    await store.refresh();
    fake.readOffline = true;
    await store.refresh(force: true);
    expect(store.value.value?.daysOff.length, 2);
    final load = store.load.value;
    expect(load, isA<OwnerLoadData<TaxiAvailability>>());
    expect((load as OwnerLoadData<TaxiAvailability>).stale, isTrue);
  });

  test('no cache and failure = error state, no value', () async {
    final fake = AvailFake(read: null);
    final store = availStore(fake);
    await store.refresh();
    expect(store.value.value, isNull);
    expect(store.load.value, isNot(isA<OwnerLoadData<TaxiAvailability>>()));
  });

  test('a second user reads nothing of the first', () async {
    final fake = AvailFake(read: availJson());
    final a = availStore(fake);
    await a.refresh();
    expect(OwnerCache.read('user-a', OwnerCacheKeys.daysOff), isNotNull);
    Get.delete<TaxiAvailabilityStore>(force: true);
    final b = availStore(AvailFake(read: null), user: 'user-b');
    await b.ensure();
    expect(b.value.value, isNull);
    expect(OwnerCache.read('user-b', OwnerCacheKeys.daysOff), isNull);
  });

  test('logout wipe removes the cached days', () async {
    final fake = AvailFake(read: availJson());
    final store = availStore(fake);
    await store.refresh();
    OwnerCache.clearAll();
    expect(OwnerCache.read('user-a', OwnerCacheKeys.daysOff), isNull);
  });

  test('days off is listing scoped: a deleted taxi drops it', () async {
    final store = availStore(AvailFake(read: availJson()));
    await store.refresh();
    OwnerCache.removeListingScoped('user-a');
    expect(OwnerCache.read('user-a', OwnerCacheKeys.daysOff), isNull);
  });

  test('isOff ignores past days', () async {
    final store = availStore(AvailFake(read: availJson(daysOff: [dayRow('2026-11-25'), dayRow('2026-11-27')])));
    await store.refresh();
    expect(store.isOff(DateTime(2026, 11, 25)), isFalse);
    expect(store.isOff(DateTime(2026, 11, 27)), isTrue);
    expect(store.offKeys, containsAll(['2026-11-27']));
  });

  test('a cached server today from yesterday does not keep yesterday open', () async {
    final store = availStore(AvailFake(read: availJson()));
    store.apply(TaxiAvailability.fromJson(availJson(today: '2026-11-25', daysOff: [dayRow('2026-11-25'), dayRow('2026-11-27')])));
    expect(store.today, DateTime(2026, 11, 26));
    expect(store.isOff(DateTime(2026, 11, 25)), isFalse);
    expect(store.isOff(DateTime(2026, 11, 27)), isTrue);
  });

  test('a server today ahead of the phone clock wins', () async {
    final store = availStore(AvailFake(read: availJson()));
    store.apply(TaxiAvailability.fromJson(availJson(today: '2026-11-27', daysOff: [dayRow('2026-11-26'), dayRow('2026-11-27')])));
    expect(store.today, DateTime(2026, 11, 27));
    expect(store.isOff(DateTime(2026, 11, 26)), isFalse);
    expect(store.isOff(DateTime(2026, 11, 27)), isTrue);
  });

  group('saveDay', () {
    test('marking a day off sends one set row with the reason and publishes the answer', () async {
      final fake = AvailFake(read: availJson(daysOff: const []));
      fake.save = (body) async => {'data': availJson(daysOff: [dayRow('2026-11-29', 'Family function')])};
      final store = availStore(fake);
      await store.refresh();
      final r = await store.saveDay(DateTime(2026, 11, 29, 15), off: true, reason: '  Family function  ');
      expect(r, isA<OwnerOk<TaxiAvailability>>());
      expect(fake.saves.single, {
        'set': [
          {'date': '2026-11-29', 'reason': 'Family function'},
        ],
        'clear': const <String>[],
      });
      expect(store.isOff(DateTime(2026, 11, 29)), isTrue);
    });

    test('removing a day off sends one clear key', () async {
      final fake = AvailFake(read: availJson());
      fake.save = (body) async => {'data': availJson(daysOff: [dayRow('2026-11-30')])};
      final store = availStore(fake);
      await store.refresh();
      await store.saveDay(DateTime(2026, 11, 27), off: false);
      expect(fake.saves.single, {'set': const <Map<String, dynamic>>[], 'clear': ['2026-11-27']});
      expect(store.isOff(DateTime(2026, 11, 27)), isFalse);
    });

    test('a bucket 429 holds the next save without a call', () async {
      final fake = AvailFake(read: availJson());
      fake.save = (body) async => throw refusal(daysOffPath, 429, bucket429(seconds: 130));
      final store = availStore(fake);
      await store.refresh();
      final first = await store.saveDay(DateTime(2026, 11, 29), off: true);
      expect((first as OwnerRefused<TaxiAvailability>).message, 'You can change this 3 times an hour. Try again in 3 min.');
      final second = await store.saveDay(DateTime(2026, 11, 29), off: true);
      expect(second, isA<OwnerRefused<TaxiAvailability>>());
      expect(fake.saves.length, 1);
      expect(store.isOff(DateTime(2026, 11, 29)), isFalse);
    });

    test('a booked-day refusal keeps the value', () async {
      final fake = AvailFake(read: availJson());
      fake.save = (body) async => throw refusal(daysOffPath, 409, {
            'data': {'dates': ['2026-11-28']},
            'error': {'type': 'DayOffBooked', 'message': 'This day has a booking.'},
          });
      final store = availStore(fake);
      await store.refresh();
      final r = await store.saveDay(DateTime(2026, 11, 28), off: true);
      expect((r as OwnerRefused<TaxiAvailability>).type, 'DayOffBooked');
      expect(store.isOff(DateTime(2026, 11, 28)), isFalse);
    });
  });

  test('inWindow follows the plan window (Free: this month, Plus: 6 months)', () async {
    final free = availStore(AvailFake(read: availJson()));
    await free.refresh();
    expect(free.inWindow(DateTime(2026, 11, 30)), isTrue);
    expect(free.inWindow(DateTime(2026, 12, 1)), isFalse);
    Get.delete<TaxiAvailabilityStore>(force: true);
    final plus = availStore(AvailFake(read: availJson(plus: true)));
    await plus.refresh();
    expect(plus.inWindow(DateTime(2027, 5, 31)), isTrue);
    expect(plus.inWindow(DateTime(2027, 6, 1)), isFalse);
  });
}
