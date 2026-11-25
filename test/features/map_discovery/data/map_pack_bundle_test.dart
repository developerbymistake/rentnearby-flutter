import 'package:bakhli/features/map_discovery/data/map_pack_bundle.dart';
import 'package:bakhli/features/map_discovery/data/map_pack_service.dart';
import 'package:bakhli/features/map_discovery/data/map_pack_store.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/fake_map_pack_api.dart';

const _uttarakhand = 'f24fcce0-f7b2-4f98-8ab2-4ce4f99e9f0d';
const _himachal = 'f9b210df-e2d0-4a1b-a7ce-4e3352009d4e';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeMapPackApi api;
  late FakeVersion version;
  late FakeClock clock;

  MapPackService make() => MapPackService(api: api, versionCall: version.call, citiesOf: (_) => const [], now: clock.call);

  setUpAll(() => initMapPackTestStorage('map_pack_bundle'));
  setUp(() async {
    Get.reset();
    await resetMapPackStore();
    api = FakeMapPackApi();
    version = FakeVersion();
    clock = FakeClock();
    MapPackBundle.disabled = false;
  });
  tearDown(() => MapPackBundle.disabled = true);
  tearDownAll(() => MapPackStore.debugUseBox(null));

  test('fresh install: the packs shipped in the app are ready at the first map open, with no network call', () async {
    final s = make();
    await s.ensureForPoint(30.3, 79.0);
    expect(s.enabled, isTrue);
    expect(api.count, 0);
    expect(s.source.state.value, DiscoveryDataState.ready);
    expect(MapPackStore.readBody(_uttarakhand), isNotNull);
    expect(MapPackStore.readBody(_himachal), isNotNull);
    expect(s.index!.length, greaterThan(0));
  });

  test('an install that already stores something is never overwritten by the shipped packs', () async {
    MapPackStore.writeMeta({'schema': 1, 'flag': false, 'refs': <Object>[], 'refsAtMs': clock.call().millisecondsSinceEpoch});
    final s = make();
    await s.ensureForPoint(30.3, 79.0);
    expect(s.enabled, isFalse);
    expect(MapPackStore.readBody(_uttarakhand), isNull);
  });

  test('the shipped manifest lists two packs and every file is non-empty', () async {
    final refs = await MapPackBundle.seed();
    expect(refs.length, 2);
    for (final r in refs) {
      expect(MapPackStore.readBody(r.stateId), isNotEmpty);
    }
  });
}
