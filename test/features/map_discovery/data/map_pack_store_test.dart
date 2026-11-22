import 'package:bakhli/features/map_discovery/data/map_pack_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import '../support/fake_map_pack_api.dart';

void main() {
  setUpAll(() => initMapPackTestStorage('map_pack_store'));
  setUp(resetMapPackStore);
  tearDownAll(() => MapPackStore.debugUseBox(null));

  test('save, read body and version, stored states, drop', () {
    MapPackStore.save('s1', 'v1', '{"a":1}');
    MapPackStore.save('s2', 'v9', '{"b":2}');
    expect(MapPackStore.readBody('s1'), '{"a":1}');
    expect(MapPackStore.readVersion('s1'), 'v1');
    expect(MapPackStore.storedStates()..sort(), ['s1', 's2']);
    MapPackStore.drop('s1');
    expect(MapPackStore.readBody('s1'), isNull);
    expect(MapPackStore.readVersion('s1'), isNull);
    expect(MapPackStore.storedStates(), ['s2']);
  });

  test('meta round trip; corrupt meta erases the whole box (D8)', () {
    MapPackStore.writeMeta({'flag': true, 'refs': []});
    expect(MapPackStore.readMeta()?['flag'], true);
    MapPackStore.save('s1', 'v1', '{}');
    mapPackTestBox.write(MapPackStore.metaKey, 'not json');
    expect(MapPackStore.readMeta(), isNull);
    expect(mapPackTestBox.getKeys<Iterable<dynamic>>(), isEmpty);
    mapPackTestBox.write(MapPackStore.metaKey, 42);
    expect(MapPackStore.readMeta(), isNull);
    expect(mapPackTestBox.getKeys<Iterable<dynamic>>(), isEmpty);
  });

  test('a body of the wrong type is dropped and read as missing', () {
    mapPackTestBox.write('${MapPackStore.bodyPrefix}s1', 12);
    mapPackTestBox.write('${MapPackStore.versionPrefix}s1', 'v1');
    expect(MapPackStore.readBody('s1'), isNull);
    expect(MapPackStore.readVersion('s1'), isNull);
  });

  test('erase empties the box; calls never throw when no box is open', () {
    MapPackStore.save('s1', 'v1', '{}');
    MapPackStore.erase();
    expect(MapPackStore.storedStates(), isEmpty);
    MapPackStore.debugUseBox(null);
    expect(MapPackStore.readBody('s1'), isNull);
    expect(MapPackStore.readMeta(), isNull);
    MapPackStore.save('s1', 'v1', '{}');
    MapPackStore.erase();
    expect(MapPackStore.storedStates(), isEmpty);
  });

  test('T16: the default box gets no key from this lane', () {
    final def = GetStorage();
    final before = def.getKeys<Iterable<dynamic>>().toSet();
    MapPackStore.writeMeta({'flag': true});
    MapPackStore.save('s1', 'v1', '{"x":1}');
    MapPackStore.stampVersion('s1', 'v2');
    expect(def.getKeys<Iterable<dynamic>>().toSet(), before);
    expect(mapPackTestBox.getKeys<Iterable<dynamic>>(), isNotEmpty);
  });
}
