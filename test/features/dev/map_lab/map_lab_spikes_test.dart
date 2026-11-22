import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:bakhli/features/dev/map_lab/map_lab_spikes.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePort implements LabMapPort {
  final List<String> calls = [];
  final bool stringIdWorks;
  _FakePort({this.stringIdWorks = true});

  @override
  Size get viewport => const Size(360, 400);
  @override
  double get devicePixelRatio => 2.75;
  @override
  Future<void> reset() async => calls.add('reset');
  @override
  Future<void> addGeoJson(String sourceId, Map<String, dynamic> data) async => calls.add('src:$sourceId');
  @override
  Future<void> addFileSource(String sourceId, String url) async => calls.add('file:$url');
  @override
  Future<void> addCircles(String sourceId, String layerId, {required double radius, bool interactive = true}) async =>
      calls.add('circ:$layerId:$radius');
  @override
  Future<void> addSymbols(String sourceId, String layerId, {required Object iconImage, Object? sortKey, bool overlap = false}) async =>
      calls.add('sym:$layerId');
  @override
  Future<void> addImage(String name, Uint8List bytes) async => calls.add('img:$name');
  @override
  Future<void> clear() async => calls.add('clear');
  @override
  Future<void> settle([Duration wait = const Duration(milliseconds: 1500)]) async {}
  @override
  Future<void> panTo(double lat, double lon, {double? zoom, Duration duration = const Duration(milliseconds: 800)}) async =>
      calls.add('pan');
  @override
  Future<({double x, double y})> toScreen(double lat, double lon) async => (x: 180 + (lon - LabCentre.lon) * 5000, y: 200.0);

  bool _hits(double px, double py, double cx, double r) => (px - cx).abs() <= r && (py - 200).abs() <= r;

  @override
  Future<List<Object?>> queryPoint(double x, double y, List<String> layerIds) async {
    if (layerIds.contains('lab-s1-c')) {
      final Object? id = x < 150 ? 101 : (x < 210 ? 'spot-abc' : null);
      final f = {
        'id': (id is String && !stringIdWorks) ? null : id,
        'properties': {if (id == null) 'id': 'prop-only'},
      };
      return [f];
    }
    if (layerIds.contains('lab-s3-y')) return _hits(x, y, 180 - 100, 75) ? ['{}'] : [];
    if (layerIds.contains('lab-s3-c')) return _hits(x, y, 180 + 100, 50) ? [<String, dynamic>{}] : [];
    if (layerIds.contains('lab-s6-c')) return _hits(x, y, 180, 4.5) ? [<String, dynamic>{}] : [];
    return [];
  }

  @override
  Future<List<Object?>> queryRect(Rect rect, List<String> layerIds) async {
    if (layerIds.contains('lab-s6-c')) return rect.contains(const Offset(180, 200)) ? [<String, dynamic>{}] : [];
    if (layerIds.contains('lab-s2-y')) {
      return [
        for (final r in [0, 1, 3, 8, 20, 77]) {'properties': {'rank': r}},
      ];
    }
    if (layerIds.contains('lab-s7-c')) return [<String, dynamic>{}];
    return [];
  }
}

class _Boom extends _FakePort {
  @override
  Future<void> reset() async => throw StateError('native down');
}

FrameStats _frames(List<int> m) => FrameStats.fromMicros(m);

void main() {
  test('FrameStats counts jank and percentiles', () {
    final s = _frames([8000, 9000, 17000, 40000, 10000]);
    expect(s.count, 5);
    expect(s.over16, 2);
    expect(s.over33, 1);
    expect(s.maxMs, 40);
    expect(FrameStats.fromMicros(const []).count, 0);
  });

  test('LabSearch.maxHit finds the edge and handles no hit', () async {
    expect(await LabSearch.maxHit((d) async => d <= 26.5), closeTo(26.5, 0.5));
    expect(await LabSearch.maxHit((d) async => false), isNull);
    expect(await LabSearch.maxHit((d) async => true, hi: 50), 50);
  });

  test('LabFeatureRef parses maps and json strings and skips junk', () {
    final r = LabFeatureRef.parse([
      {'id': 'a', 'properties': {'rank': 3}},
      '{"id": 7, "properties": {"id": "p"}}',
      'not json',
      42,
    ]);
    expect(r.length, 2);
    expect(r.first.id, 'a');
    expect(r.first.rank, 3);
    expect(r.last.propId, 'p');
  });

  test('LabPoints is deterministic and sized', () {
    final a = LabPoints.scatter(1500, seed: 11);
    final b = LabPoints.scatter(1500, seed: 11);
    expect(a.length, 1500);
    expect(a[10]['geometry'], b[10]['geometry']);
    expect(a.first['id'], 'lab-0');
  });

  group('spikes against a fake port', () {
    late _FakePort port;
    late MapLabSpikes spikes;
    final logs = <String>[];

    setUp(() {
      port = _FakePort();
      logs.clear();
      spikes = MapLabSpikes(
        port,
        (action) async {
          await action();
          return _frames([8000, 9000]);
        },
        logs.add,
        tempDir: Directory.systemTemp.createTempSync('lab'),
      );
    });

    test('feature id', () async {
      final r = await spikes.featureIdRoundTrip();
      expect(r.pass, isTrue);
      expect(r.numbers['string-top-level'], contains('spot-abc'));
    });

    test('feature id fails when the string id is lost', () async {
      final bad = MapLabSpikes(_FakePort(stringIdWorks: false), (a) async => _frames([]), logs.add);
      expect((await bad.featureIdRoundTrip()).pass, isFalse);
    });

    test('declutter', () async {
      final r = await spikes.declutter();
      expect(r.pass, isTrue);
      expect(r.numbers['rendered'], '6');
    });

    test('pixel density ratio', () async {
      final r = await spikes.pixelDensity();
      expect(r.pass, isNull);
      expect(double.parse(r.numbers['ratio symbol / circle']!), closeTo(1.5, 0.05));
    });

    test('addImage timing makes 40 calls', () async {
      final r = await spikes.addImageTiming();
      expect(port.calls.where((c) => c.startsWith('img:lab-p-')).length, 40);
      expect(r.numbers.containsKey('addImage total'), isTrue);
    });

    test('frame time runs a pan and reports', () async {
      final r = await spikes.frameTime();
      expect(port.calls.where((c) => c == 'pan').length, 6);
      expect(r.numbers['frames'], '2');
    });

    test('tap box and tap note', () async {
      final r = await spikes.tapBox();
      expect(double.parse(r.numbers['rect 44 query reach']!.split(' ').first), closeTo(22, 0.6));
      spikes.noteTap('dot', 'lab-s6-c', 180, 210);
      expect(logs.single, contains('distance from dot 10.0'));
    });

    test('file source', () async {
      final r = await spikes.fileSource();
      expect(r.pass, isTrue);
      expect(port.calls.any((c) => c.startsWith('file:file:///')), isTrue);
    });

    test('runAll survives a throwing port', () async {
      final boom = MapLabSpikes(_Boom(), (a) async => _frames([]), logs.add);
      final out = await boom.runAll();
      expect(out.length, 7);
      expect(out.every((e) => e.pass == false), isTrue);
    });
  });
}
