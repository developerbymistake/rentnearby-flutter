import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'trip_discovery_layer_test.dart' show FakePort, FakeSource, features, layer, settle, spot;

void main() {
  tearDown(Get.reset);

  test('CF-ADV-3: a moved or renamed spot (same id, same thumb) reaches disc-all and the open card', () async {
    final src = FakeSource([spot('a', lat: 30.5)]);
    final l = layer(source: src);
    await l.refreshData();
    final port = FakePort();
    expect(await l.attach(port), isTrue);
    await l.select('a');
    src.spots = [
      const DiscoverySpot(id: 'a', lat: 31.0, lon: 78.2, category: 'waterfall', rank: 1, name: 'Renamed', cityKey: 7),
    ];
    await l.refreshData();
    final f = features(port.geo['disc-all']).single;
    expect((f['geometry'] as Map)['coordinates'], [78.2, 31.0]);
    expect(l.selected.value?.name, 'Renamed');
  });

  test('CF-journey D-1: a new cover (same id) is composed again while the map stays open', () async {
    final src = FakeSource([spot('a', thumb: true)]);
    final l = layer(source: src);
    await l.refreshData();
    final port = FakePort();
    expect(await l.attach(port), isTrue);
    await settle();
    final first = port.calls.where((c) => c.startsWith('image:disc-p')).length;
    expect(first, 1);

    src.spots = [
      const DiscoverySpot(id: 'a', lat: 30.5, lon: 78.2, category: 'lake', rank: 1, name: 'a', cityKey: 7,
          thumbUrl: 'https://res.cloudinary.com/x/image/upload/a2.jpg'),
    ];
    await l.refreshData();
    await settle();
    expect(port.calls.where((c) => c.startsWith('image:disc-p')).length, 2);
  });
}
