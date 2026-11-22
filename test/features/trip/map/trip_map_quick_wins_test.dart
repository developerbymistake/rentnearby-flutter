import 'dart:io';

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

  test('scale bar only while the layer is attached, metric, bottom right; no camera callbacks', () {
    expect(src.contains('scaleControlEnabled: _disc != null'), isTrue);
    expect(src.contains('ScaleControlUnit.metric'), isTrue);
    expect(src.contains('ScaleControlPosition.bottomRight'), isTrue);
    expect(RegExp(r'onCameraMove|onCameraIdle').hasMatch(src), isFalse);
  });

  test('discovery attach happens before the first draw and routes go under photos when attached', () {
    final style = RegExp(r'Future<void> _onStyleLoaded\(\)[\s\S]*?\n  \}').firstMatch(src)!.group(0)!;
    expect(style.indexOf('_attachDisc()'), lessThan(style.indexOf('_sync()')));
    expect(src.contains('DiscIds.layerPhoto : map.circleManager?.layerIds.first'), isTrue);
    expect(src.contains('_disc?.dispose()'), isTrue);
  });
}
