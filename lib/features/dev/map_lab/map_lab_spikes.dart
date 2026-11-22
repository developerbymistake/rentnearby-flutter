import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Offset, Rect, Size;

abstract class LabMapPort {
  Future<void> reset();
  Future<void> addGeoJson(String sourceId, Map<String, dynamic> data);
  Future<void> addFileSource(String sourceId, String url);
  Future<void> addCircles(String sourceId, String layerId, {required double radius, bool interactive = true});
  Future<void> addSymbols(
    String sourceId,
    String layerId, {
    required Object iconImage,
    Object? sortKey,
    bool overlap = false,
  });
  Future<void> addImage(String name, Uint8List bytes);
  Future<List<Object?>> queryPoint(double x, double y, List<String> layerIds);
  Future<List<Object?>> queryRect(Rect rect, List<String> layerIds);
  Future<({double x, double y})> toScreen(double lat, double lon);
  Future<void> panTo(double lat, double lon, {double? zoom, Duration duration = const Duration(milliseconds: 800)});
  Future<void> settle([Duration wait = const Duration(milliseconds: 1500)]);
  Future<void> clear();
  Size get viewport;
  double get devicePixelRatio;
  double get unitsPerDp;
}

class LabResult {
  final String name;
  final bool? pass;
  final String summary;
  final Map<String, String> numbers;

  const LabResult(this.name, this.pass, this.summary, [this.numbers = const {}]);

  String get verdict => pass == null ? 'MEASURED' : (pass! ? 'PASS' : 'FAIL');

  String toText() {
    final b = StringBuffer('[$verdict] $name\n$summary');
    numbers.forEach((k, v) => b.write('\n  $k: $v'));
    return b.toString();
  }
}

class LabCentre {
  static const double lat = 26.9124;
  static const double lon = 75.7873;
  static const double zoom = 13.0;
}

class LabImages {
  static Future<Uint8List> disc(int px, ui.Color fill, {ui.Color ring = const ui.Color(0xFFFFFFFF)}) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()));
    final c = px / 2;
    canvas.drawCircle(ui.Offset(c, c), c, ui.Paint()..color = fill);
    canvas.drawCircle(
      ui.Offset(c, c),
      c - px * 0.06,
      ui.Paint()
        ..color = ring
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = px * 0.08,
    );
    final img = await recorder.endRecording().toImage(px, px);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  static Future<Uint8List> square(int px, ui.Color fill) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()));
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()), ui.Paint()..color = fill);
    final img = await recorder.endRecording().toImage(px, px);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}

class LabPoints {
  static Map<String, dynamic> collection(List<Map<String, dynamic>> features) =>
      {'type': 'FeatureCollection', 'features': features};

  static Map<String, dynamic> feature(
    Object? id,
    double lat,
    double lon,
    Map<String, dynamic> properties,
  ) =>
      {
        'type': 'Feature',
        'id': ?id,
        'properties': properties,
        'geometry': {
          'type': 'Point',
          'coordinates': [lon, lat],
        },
      };

  static List<Map<String, dynamic>> scatter(
    int count, {
    required int seed,
    double halfLat = 0.02,
    double halfLon = 0.02,
    String Function(int i)? img,
  }) {
    final r = Random(seed);
    return [
      for (var i = 0; i < count; i++)
        feature('lab-$i', LabCentre.lat + (r.nextDouble() * 2 - 1) * halfLat, LabCentre.lon + (r.nextDouble() * 2 - 1) * halfLon, {
          'rank': i,
          'img': img == null ? 'lab-i-0' : img(i),
        }),
    ];
  }
}

class FrameStats {
  final int count;
  final double avgMs;
  final double p95Ms;
  final double maxMs;
  final int over16;
  final int over33;

  const FrameStats(this.count, this.avgMs, this.p95Ms, this.maxMs, this.over16, this.over33);

  factory FrameStats.fromMicros(List<int> micros) {
    if (micros.isEmpty) return const FrameStats(0, 0, 0, 0, 0, 0);
    final sorted = [...micros]..sort();
    final ms = sorted.map((e) => e / 1000).toList();
    final avg = ms.reduce((a, b) => a + b) / ms.length;
    final p95 = ms[min(ms.length - 1, (ms.length * 0.95).ceil() - 1)];
    return FrameStats(
      ms.length,
      avg,
      p95,
      ms.last,
      ms.where((e) => e > 16.7).length,
      ms.where((e) => e > 33.4).length,
    );
  }
}

class LabSearch {
  static Future<double?> maxHit(Future<bool> Function(double d) hits, {double hi = 200, double precision = 0.5}) async {
    if (!await hits(0)) return null;
    var lo = 0.0, up = hi;
    if (await hits(up)) return up;
    while (up - lo > precision) {
      final mid = (lo + up) / 2;
      if (await hits(mid)) {
        lo = mid;
      } else {
        up = mid;
      }
    }
    return lo;
  }
}

class LabFeatureRef {
  final Object? id;
  final Object? propId;
  final Object? rank;

  const LabFeatureRef(this.id, this.propId, this.rank);

  static List<LabFeatureRef> parse(List<Object?> raw) {
    final out = <LabFeatureRef>[];
    for (final e in raw) {
      Object? v = e;
      if (v is String) {
        try {
          v = jsonDecode(v);
        } catch (_) {
          continue;
        }
      }
      if (v is! Map) continue;
      final props = v['properties'];
      out.add(LabFeatureRef(v['id'], props is Map ? props['id'] : null, props is Map ? props['rank'] : null));
    }
    return out;
  }
}

typedef LabLog = void Function(String line);
typedef LabFrameSource = Future<FrameStats> Function(Future<void> Function() action);

class MapLabSpikes {
  final LabMapPort port;
  final LabFrameSource frames;
  final LabLog log;
  final Directory tempDir;

  MapLabSpikes(this.port, this.frames, this.log, {Directory? tempDir}) : tempDir = tempDir ?? Directory.systemTemp;

  Future<LabResult> featureIdRoundTrip() async {
    await port.reset();
    final feats = [
      LabPoints.feature(101, LabCentre.lat, LabCentre.lon - 0.012, {'tag': 'numeric-top-level'}),
      LabPoints.feature('spot-abc', LabCentre.lat, LabCentre.lon, {'tag': 'string-top-level'}),
      LabPoints.feature(null, LabCentre.lat, LabCentre.lon + 0.012, {'id': 'prop-only', 'tag': 'property-only'}),
    ];
    await port.addGeoJson('lab-s1', LabPoints.collection(feats));
    await port.addCircles('lab-s1', 'lab-s1-c', radius: 10);
    await port.settle();
    final numbers = <String, String>{};
    var stringOk = false;
    for (final f in feats) {
      final p = (f['geometry'] as Map)['coordinates'] as List;
      final s = await port.toScreen(p[1] as double, p[0] as double);
      final tag = (f['properties'] as Map)['tag'] as String;
      final hits = LabFeatureRef.parse(await port.queryPoint(s.x, s.y, ['lab-s1-c']));
      if (hits.isEmpty) {
        numbers[tag] = 'no feature returned';
        continue;
      }
      final h = hits.first;
      numbers[tag] = 'id=${h.id} (${h.id.runtimeType}), properties.id=${h.propId}';
      if (tag == 'string-top-level' && h.id == 'spot-abc') stringOk = true;
    }
    return LabResult(
      '1 Feature id round trip',
      stringOk,
      stringOk
          ? 'A top-level string id came back unchanged from a query.'
          : 'A top-level string id did NOT come back. Read the ids below; the layer must then read ids from properties.',
      {...numbers, 'also': 'tap a dot on the map: the tap id is written to the log'},
    );
  }

  Future<LabResult> declutter() async {
    await port.reset();
    const imgCount = 20;
    for (var i = 0; i < imgCount; i++) {
      await port.addImage('lab-i-$i', await LabImages.disc(48, ui.Color(0xFF000000 | (i * 0x0C1F37 & 0xFFFFFF))));
    }
    final feats = LabPoints.scatter(200, seed: 7, halfLat: 0.015, halfLon: 0.015, img: (i) => 'lab-i-${i % imgCount}');
    await port.addGeoJson('lab-s2', LabPoints.collection(feats));
    await port.addSymbols('lab-s2', 'lab-s2-y', iconImage: ['get', 'img'], sortKey: ['get', 'rank']);
    await port.settle();
    final hits = LabFeatureRef.parse(await port.queryRect(_screenRect(), ['lab-s2-y']));
    final ranks = hits.map((h) => h.rank).whereType<num>().map((e) => e.toInt()).toSet().toList()..sort();
    if (ranks.isEmpty) {
      return const LabResult('2 Rank declutter', false, 'No symbol was rendered or the query returned nothing.');
    }
    final top10 = ranks.where((r) => r < 10).length;
    final mean = ranks.reduce((a, b) => a + b) / ranks.length;
    final ok = ranks.first == 0 && ranks.length < 200 && mean < 99.5;
    return LabResult(
      '2 Rank declutter',
      ok,
      ok
          ? 'Overlapping icons were dropped and the best rank (0) was kept.'
          : 'Rank 0 was dropped, nothing was dropped, or the kept set is not biased to good ranks.',
      {
        'points': '200, images: $imgCount',
        'rendered': '${ranks.length}',
        'best rank rendered': '${ranks.first}',
        'ranks 0-9 rendered': '$top10 of 10',
        'mean rank rendered': mean.toStringAsFixed(1),
        'expected mean if unbiased': '99.5',
      },
    );
  }

  Future<LabResult> pixelDensity() async {
    await port.reset();
    await port.addImage('lab-sq-100', await LabImages.square(100, const ui.Color(0xFF3F51B5)));
    final symLon = LabCentre.lon - 0.02, circLon = LabCentre.lon + 0.02;
    await port.addGeoJson('lab-s3-sym', LabPoints.collection([LabPoints.feature('sym', LabCentre.lat, symLon, {})]));
    await port.addGeoJson('lab-s3-circ', LabPoints.collection([LabPoints.feature('circ', LabCentre.lat, circLon, {})]));
    await port.addSymbols('lab-s3-sym', 'lab-s3-y', iconImage: 'lab-sq-100', overlap: true);
    await port.addCircles('lab-s3-circ', 'lab-s3-c', radius: 49);
    await port.settle();
    final sym = await port.toScreen(LabCentre.lat, symLon);
    final circ = await port.toScreen(LabCentre.lat, circLon);
    Future<bool> symHit(double d) async => (await port.queryPoint(sym.x + d, sym.y, ['lab-s3-y'])).isNotEmpty;
    Future<bool> circHit(double d) async => (await port.queryPoint(circ.x + d, circ.y, ['lab-s3-c'])).isNotEmpty;
    final u = port.unitsPerDp;
    final s = await LabSearch.maxHit(symHit, hi: 200 * u);
    final c = await LabSearch.maxHit(circHit, hi: 200 * u);
    if (s == null || c == null || c == 0) {
      return LabResult('3 Pixel density', false, 'The query did not find the test shapes (symbol: $s, circle reference: $c).');
    }
    final ratio = s / c;
    return LabResult(
      '3 Pixel density',
      null,
      'A 100 px image was measured against a circle of radius 49 plus a 1 dp stroke (diameter 100 dp). '
          'Set DiscTuning.pxPerDp to 1 / ratio (1.00 means 1 image px = 1 dp, as the stay pin).',
      {
        'symbol half width (query units)': s.toStringAsFixed(1),
        'circle half width (query units)': c.toStringAsFixed(1),
        'ratio symbol / circle': ratio.toStringAsFixed(2),
        'suggested pxPerDp': (1 / ratio).toStringAsFixed(2),
        'device pixel ratio': port.devicePixelRatio.toStringAsFixed(2),
        'query units per dp (assumed / measured)': '${u.toStringAsFixed(2)} / ${(c / 50).toStringAsFixed(2)}',
        'eye check': 'the indigo square on the left and the 100 dp frame in the centre use the same dp',
      },
    );
  }

  Future<LabResult> addImageTiming() async {
    await port.reset();
    const n = 40;
    final compose = Stopwatch()..start();
    final images = <Uint8List>[];
    for (var i = 0; i < n; i++) {
      images.add(await LabImages.disc(96, ui.Color(0xFF000000 | ((i + 3) * 0x051F2B & 0xFFFFFF))));
    }
    compose.stop();
    final each = <int>[];
    final total = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      final w = Stopwatch()..start();
      await port.addImage('lab-p-$i', images[i]);
      each.add(w.elapsedMicroseconds);
    }
    total.stop();
    final avg = each.reduce((a, b) => a + b) / n / 1000;
    final mx = each.reduce(max) / 1000;
    return LabResult(
      '4 addImage x $n',
      null,
      'Time of $n addImage calls with 96 px images (compose time is separate).',
      {
        'compose total': '${compose.elapsedMilliseconds} ms',
        'addImage total': '${total.elapsedMilliseconds} ms',
        'addImage average': '${avg.toStringAsFixed(1)} ms',
        'addImage slowest': '${mx.toStringAsFixed(1)} ms',
      },
    );
  }

  Future<LabResult> frameTime() async {
    await port.reset();
    await port.addImage('lab-i-0', await LabImages.disc(48, const ui.Color(0xFF3F51B5)));
    final feats = LabPoints.scatter(1500, seed: 11, halfLat: 0.08, halfLon: 0.08);
    await port.addGeoJson('lab-s5', LabPoints.collection(feats));
    await port.addCircles('lab-s5', 'lab-s5-c', radius: 4.5, interactive: false);
    await port.addSymbols('lab-s5', 'lab-s5-y', iconImage: 'lab-i-0', sortKey: ['get', 'rank']);
    await port.settle();
    final wall = Stopwatch()..start();
    final stats = await frames(() async {
      const steps = 6;
      for (var i = 0; i < steps; i++) {
        final a = i * pi / 3;
        await port.panTo(
          LabCentre.lat + 0.05 * sin(a),
          LabCentre.lon + 0.05 * cos(a),
          zoom: i.isEven ? 13 : 14,
          duration: const Duration(milliseconds: 800),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    wall.stop();
    return LabResult(
      '5 1,500 points, auto pan',
      null,
      'Flutter frame times while the camera pans over 1,500 points (circles plus a symbol layer). '
          'Native map thread time is not included.',
      {
        'frames': '${stats.count}',
        'average': '${stats.avgMs.toStringAsFixed(1)} ms',
        'p95': '${stats.p95Ms.toStringAsFixed(1)} ms',
        'worst': '${stats.maxMs.toStringAsFixed(1)} ms',
        'frames over 16.7 ms': '${stats.over16}',
        'frames over 33.4 ms': '${stats.over33}',
        'wall time': '${wall.elapsedMilliseconds} ms',
      },
    );
  }

  Point<double>? _tapTarget;
  Point<double>? get tapTarget => _tapTarget;

  Future<LabResult> tapBox() async {
    await port.reset();
    await port.addGeoJson('lab-s6', LabPoints.collection([LabPoints.feature('dot', LabCentre.lat, LabCentre.lon, {})]));
    await port.addCircles('lab-s6', 'lab-s6-c', radius: 4.5);
    await port.settle();
    final p = await port.toScreen(LabCentre.lat, LabCentre.lon);
    final u = port.unitsPerDp;
    _tapTarget = Point(p.x, p.y);
    Future<bool> pointHit(double d) async => (await port.queryPoint(p.x + d, p.y, ['lab-s6-c'])).isNotEmpty;
    Future<bool> rectHit(double d) async =>
        (await port.queryRect(Rect.fromCenter(center: Offset(p.x + d, p.y), width: 44 * u, height: 44 * u), ['lab-s6-c'])).isNotEmpty;
    final ptUnits = await LabSearch.maxHit(pointHit, hi: 80 * u);
    final rcUnits = await LabSearch.maxHit(rectHit, hi: 80 * u);
    final pt = ptUnits == null ? null : ptUnits / u;
    final rc = rcUnits == null ? null : rcUnits / u;
    return LabResult(
      '6 Tap box on a 9 dp dot',
      rc == null ? false : null,
      rc == null
          ? 'The 44 dp rect query did not find the dot.'
          : 'Largest distance from the dot centre that still hits. Ideal rect hit = 22 + 4.5 radius + 1 stroke = 27.5 dp. '
              'Then tap the dot by hand: each tap writes its distance to the log.',
      {
        'point query reach': pt == null ? 'no hit at centre' : '${pt.toStringAsFixed(1)} dp',
        'rect 44 query reach': rc == null ? 'no hit' : '${rc.toStringAsFixed(1)} dp',
        'dot centre on screen (query units)': '${p.x.toStringAsFixed(0)}, ${p.y.toStringAsFixed(0)}',
        'query units per dp': u.toStringAsFixed(2),
      },
    );
  }

  Future<LabResult> fileSource() async {
    await port.reset();
    final feats = LabPoints.scatter(50, seed: 5, halfLat: 0.015, halfLon: 0.015);
    final file = File('${tempDir.path}${Platform.pathSeparator}lab_points.geojson');
    await file.writeAsString(jsonEncode(LabPoints.collection(feats)));
    final url = Uri.file(file.path).toString();
    await port.addFileSource('lab-s7', url);
    await port.addCircles('lab-s7', 'lab-s7-c', radius: 6, interactive: false);
    await port.settle(const Duration(milliseconds: 2500));
    final hits = await port.queryRect(_screenRect(), ['lab-s7-c']);
    final ok = hits.isNotEmpty;
    return LabResult(
      '7 Local file GeoJSON source',
      ok,
      ok
          ? 'A GeoJSON source loaded from a file url and rendered.'
          : 'Nothing rendered from the file url; the layer must use inline data.',
      {'url': url, 'features rendered': '${hits.length} of 50'},
    );
  }

  Rect _screenRect() {
    final v = port.viewport * port.unitsPerDp;
    return Rect.fromLTWH(0, 0, v.width, v.height);
  }

  void noteTap(String id, String layerId, double x, double y) {
    final t = _tapTarget;
    final dist = t == null ? '' : ', distance from dot ${sqrt(pow(x - t.x, 2) + pow(y - t.y, 2)).toStringAsFixed(1)}';
    log('tap id=$id layer=$layerId at ${x.toStringAsFixed(0)},${y.toStringAsFixed(0)}$dist');
  }

  Future<List<LabResult>> runAll() async {
    final out = <LabResult>[];
    for (final run in [featureIdRoundTrip, declutter, pixelDensity, addImageTiming, frameTime, tapBox, fileSource]) {
      out.add(await guarded(run));
    }
    return out;
  }

  Future<LabResult> guarded(Future<LabResult> Function() run) async {
    try {
      return await run();
    } catch (e, st) {
      return LabResult('spike failed', false, 'Exception: $e\n${st.toString().split('\n').take(3).join('\n')}');
    }
  }
}
