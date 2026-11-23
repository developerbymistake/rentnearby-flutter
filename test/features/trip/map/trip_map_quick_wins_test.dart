import 'dart:io';

import 'package:bakhli/features/trip/map/discovery_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/features/trip/screens/trip_map_screen.dart').readAsStringSync();

  test('trip map: drag off, camera tracking off', () {
    expect(src.contains('dragEnabled: false'), isTrue);
    expect(src.contains('trackCameraPosition: false'), isTrue);
    expect(src.contains('trackCameraPosition: true'), isFalse);
  });

  test('every route line is added through _addLine with interaction off', () {
    final body = RegExp(r'Future<void> _addLine\([\s\S]*?\n  \}').firstMatch(src)!.group(0)!;
    expect(body.contains('enableInteraction: false'), isTrue);
    expect('addLineLayer('.allMatches(src).length, 1);
  });

  test('scale bar (D4): no web-only plugin option, no onCameraMove, one onCameraIdle that only measures', () {
    expect(RegExp(r'scaleControl').hasMatch(src), isFalse, reason: 'the plugin scale control is web only');
    expect(src.contains('onCameraMove'), isFalse);
    expect('onCameraIdle:'.allMatches(src).length, 1);
    expect(src.contains('onCameraIdle: _onCameraIdle,'), isTrue);
    final body = RegExp(r'Future<void> _onCameraIdle\(\) async \{[\s\S]*?\n  \}').firstMatch(src)!.group(0)!;
    final withoutGuard = body.replaceFirst('_disc == null', '');
    for (final banned in ['_disc', 'ensure', 'ApiService', '_plan.', 'setState(', '_sync', 'refreshData', 'setPhotoArea']) {
      expect(withoutGuard.contains(banned), isFalse, reason: '_onCameraIdle must not call $banned');
    }
    expect(body.contains('getVisibleRegion()'), isTrue);
    expect(body.contains('getMetersPerPixelAtLatitude('), isTrue);
    expect(body.contains('seq != _idleSeq'), isTrue, reason: 'a newer idle wins');
    expect(src.contains('metersPerDp: _metersPerDp'), isTrue);
  });

  test('discovery attach happens before the first draw; routes go above place markers and below the selection (D6)', () {
    final style = RegExp(r'Future<void> _onStyleLoaded\(\)[\s\S]*?\n  \}').firstMatch(src)!.group(0)!;
    expect(style.indexOf('_attachDisc()'), lessThan(style.indexOf('_sync()')));
    expect(src.contains('DiscIds.layerSelHalo : map.circleManager?.layerIds.first'), isTrue);
    expect(src.contains('DiscIds.layerPhoto : map.circleManager'), isFalse);
    // Bottom to top: dots, badge, photo, routes (inserted below sel-halo), sel-halo, sel-dot, sel-icon, numbered circles.
    final order = [...DiscIds.layers]..insert(DiscIds.layers.indexOf(DiscIds.layerSelHalo), 'routes');
    expect(order, ['disc-dots', 'disc-badge', 'disc-photo', 'routes', 'disc-sel-halo', 'disc-sel-dot', 'disc-sel-icon']);
    expect(src.contains('_disc?.dispose()'), isTrue);
  });
}
