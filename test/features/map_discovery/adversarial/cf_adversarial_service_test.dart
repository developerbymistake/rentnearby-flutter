import 'dart:async';

import 'package:bakhli/features/map_discovery/data/map_pack_api.dart';
import 'package:bakhli/features/map_discovery/data/map_pack_service.dart';
import 'package:bakhli/features/map_discovery/data/map_pack_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/fake_map_pack_api.dart';

void main() {
  late FakeMapPackApi api;
  late FakeVersion version;
  late FakeClock clock;

  MapPackService make() => MapPackService(
        api: api,
        versionCall: version.call,
        citiesOf: (keys) => [for (final k in keys) city(k, state: 'State One')],
        now: clock.call,
      );

  setUpAll(() => initMapPackTestStorage('map_pack_cf_adversarial'));
  setUp(() async {
    Get.reset();
    await resetMapPackStore();
    api = FakeMapPackApi();
    version = FakeVersion();
    clock = FakeClock();
  });
  tearDownAll(() => MapPackStore.debugUseBox(null));

  test('CF-ADV-1: catalog version answer (packs not known) arrives before the first map open; stored refs and pack still serve', () async {
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    api.body('s1', packBody());
    await make().ensureForCities([1]);
    expect(MapPackStore.readBody('s1'), isNotNull);
    expect(api.count, 1);

    Get.reset();
    final s = make();
    s.onVersion(ver(packs: const [], packsKnown: false));
    await s.settle();
    await s.ensureForCities([1]);
    expect(s.refs, isNotEmpty, reason: 'refs stored on disk must survive an unknown pack list');
    expect(s.index?.length, 20, reason: 'stored pack must serve with no network call');
    expect(api.count, 1);
  });

  test('CF-ADV-2: version moves while the first download runs and the old version 404s; the new version loads on the next ensure', () async {
    final gate = Completer<void>();
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    api.enqueue('s1', (_, _) async {
      await gate.future;
      return MapPackApi.failed;
    });
    api.body('s1', packBody(version: 'v2'));
    final s = make();
    final first = s.ensureForCities([1]);
    await pumpEventQueue();
    s.onVersion(ver(packs: [ref('s1', name: 'State One', version: 'v2')]));
    gate.complete();
    await first;
    await s.settle();
    await s.ensureForCities([1]);
    expect(s.index?.length, 20, reason: 'a failure of the old version must not block the new version for 60 s');
  });

  test('CF-journey D-2: a known but empty pack list drops the stored packs', () async {
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    api.body('s1', packBody());
    final s = make();
    await s.ensureForCities([1]);
    expect(s.index?.length, 20);

    s.onVersion(ver(packs: const [], packsKnown: true));
    await s.settle();
    expect(MapPackStore.readBody('s1'), isNull);
    expect(s.index, isNull);
  });
}
