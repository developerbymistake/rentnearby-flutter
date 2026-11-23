import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _block(String src, String start) {
  final m = RegExp('${RegExp.escape(start)}[\\s\\S]*?\\n  \\}').firstMatch(src);
  return m?.group(0) ?? '';
}

void main() {
  final src = File('lib/features/stay/guest/stay_map_screen.dart').readAsStringSync().replaceAll('\r\n', '\n');

  test('50-pin cap still applies to stay pins and clusters only', () {
    expect(
      _block(src, '  List<_Cluster> _computeClusters('),
      '  List<_Cluster> _computeClusters(List<StayNearbyModel> stays) => MapClustering.cluster<StayNearbyModel>(\n'
      '        stays,\n'
      '        lat: (s) => s.latitude,\n'
      '        lon: (s) => s.longitude,\n'
      '        zoom: _currentZoom,\n'
      '        radiusPx: AppConstants.clusterCellPx,\n'
      '        maxClusters: AppConstants.maxMapMarkers,\n'
      '      ).map(_Cluster.new).toList();\n'
      '\n'
      '  static List<LatLng> _circlePolygonPoints(LatLng center, double radiusKm) {\n'
      '    const steps = 64;\n'
      '    const earthRadius = 6378137.0;\n'
      '    final latRad = center.latitude * pi / 180;\n'
      '    final points = <LatLng>[];\n'
      '    for (int i = 0; i <= steps; i++) {\n'
      '      final angle = 2 * pi * i / steps;\n'
      '      final dLat = (radiusKm * 1000 * cos(angle)) / earthRadius * (180 / pi);\n'
      '      final dLng = (radiusKm * 1000 * sin(angle)) / (earthRadius * cos(latRad)) * (180 / pi);\n'
      '      points.add(LatLng(center.latitude + dLat, center.longitude + dLng));\n'
      '    }\n'
      '    return points;\n'
      '  }',
    );
    expect('maxMapMarkers'.allMatches(src).length, 1);
  });

  test('pins still hide while the camera moves and come back 150 ms after idle', () {
    expect(
      src.contains('                    onCameraMove: (CameraPosition pos) {\n'
          '                      _currentZoom = pos.zoom;\n'
          '                      _cameraCenter = pos.target;\n'
          '                      _isCameraMoving = true;\n'
          '                      _cameraIdleDebounce?.cancel();\n'
          '                      if (mounted && _pinsVisible) setState(() => _pinsVisible = false);\n'
          '                    },\n'
          '                    onCameraIdle: _onCameraIdle,'),
      isTrue,
    );
    expect(
      _block(src, '  void _onCameraIdle() {'),
      '  void _onCameraIdle() {\n'
      '    _cameraIdleDebounce?.cancel();\n'
      '    _cameraIdleDebounce = Timer(const Duration(milliseconds: 150), () {\n'
      '      if (!mounted) return;\n'
      '      _isCameraMoving = false;\n'
      '      if (StayMapRules.shouldRebuildMarkers(markersDirty: _markersDirty, lastBuildZoom: _lastClusterZoom, idleZoom: _currentZoom)) {\n'
      '        _buildMarkers(animate: false);\n'
      '      }\n'
      '      if (!_pinsVisible) setState(() => _pinsVisible = true);\n'
      '    });\n'
      '  }',
    );
    expect(src.contains('                IgnorePointer(\n                  ignoring: !_pinsVisible,'), isTrue);
    expect(src.contains('trackCameraPosition: true'), isTrue);
  });

  test('_projectToScreen is unchanged', () {
    expect(
      _block(src, '  static Offset _projectToScreen('),
      '  static Offset _projectToScreen(LatLng ll, LatLng center, double zoom, Size screenSize) {\n'
      '    const tileSize = 512.0;\n'
      '    final scale = tileSize * pow(2.0, zoom);\n'
      '    double wx(double lng) => (lng + 180) / 360;\n'
      '    double wy(double lat) {\n'
      '      final s = sin(lat * pi / 180);\n'
      '      return (1 - log((1 + s) / (1 - s)) / (2 * pi)) / 2;\n'
      '    }\n'
      '\n'
      '    final dx = (wx(ll.longitude) - wx(center.longitude)) * scale;\n'
      '    final dy = (wy(ll.latitude) - wy(center.latitude)) * scale;\n'
      '    return Offset(screenSize.width / 2 + dx, screenSize.height / 2 + dy);\n'
      '  }',
    );
  });

  test('read-only discovery wiring: no camera-callback calls, drag off, details only, re-attach and dispose', () {
    final move = RegExp(r'onCameraMove: \(CameraPosition pos\) \{[\s\S]*?\n                    \},').firstMatch(src)!.group(0)!;
    expect(move.contains('_disc'), isFalse);
    expect(_block(src, '  void _onCameraIdle() {').contains('_disc'), isFalse);
    expect(src.contains('dragEnabled: false'), isTrue);
    expect(src.contains('onMapClick: (point, _) => _disc?.onMapTap(point.x, point.y)'), isTrue);
    expect(src.contains('mode: DiscoveryMode.readOnly'), isTrue);
    expect(src.contains('tuning: DiscTuning.stay'), isTrue);
    expect(src.contains('DiscoveryHost.readOnly('), isTrue);
    expect(RegExp(r'onAdd:|onRemove:|targetDayFor:').hasMatch(src), isFalse);
    expect(src.contains('showAction: false'), isTrue);
    expect(src.contains('partial: true'), isTrue);
    final style = _block(src, '  void _onStyleLoaded() async {');
    expect(style.indexOf('_initNativeCircle()'), lessThan(style.indexOf('_attachDisc()')));
    final pause = RegExp(r'_mapPauseWorker = ever\(mapShouldPause[\s\S]*?\n    \}\);').firstMatch(src)!.group(0)!;
    expect(pause.contains('_dropDisc()'), isTrue);
    expect(_block(src, '  void dispose() {').contains('_dropDisc()'), isTrue);
    expect(_block(src, '  Future<void> _showStaySheet(').contains('_disc?.clearSelection()'), isTrue);
    expect(src.contains('if (active) {\n        _disc?.clearSelection().ignore();'), isTrue);
    expect(src.contains('tapsBlocked: () => _sheetOpen || _guest.nearestActive.value'), isTrue);
    expect(src.contains('placement: DiscoveryPlacement.bottom'), isTrue);
    expect(src.contains('              if (_disc != null)\n                DiscoveryOverlay('), isTrue);
  });

  test('APP-3: every native layer the stay map adds itself is non-interactive (taps reach onMapClick)', () {
    final calls = RegExp(r'\.add(Fill|Line|Circle|Symbol)Layer\(').allMatches(src).toList();
    expect(calls, hasLength(3));
    for (final m in calls) {
      final end = src.indexOf(');', m.start);
      expect(src.substring(m.start, end), contains('enableInteraction: false'), reason: src.substring(m.start, end));
    }
    expect(src, contains('annotationConsumeTapEvents: const [AnnotationType.symbol]'), reason: 'the user dot circle annotation must not consume taps');
    expect(RegExp(r'\.addSymbol\(').hasMatch(src), isFalse, reason: 'symbol annotations would be interactive');
  });
}
