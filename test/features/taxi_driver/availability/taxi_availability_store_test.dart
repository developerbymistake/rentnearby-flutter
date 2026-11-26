import 'dart:async';

import 'package:bakhli/features/owner_core/data/owner_cache.dart';
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

  test('prefetch runs once per session', () async {
    final fake = AvailFake(read: availJson());
    final store = availStore(fake);
    store.prefetch();
    await Future<void>.delayed(Duration.zero);
    store.prefetch();
    await Future<void>.delayed(Duration.zero);
    expect(fake.count('GET'), 1);
  });
}
