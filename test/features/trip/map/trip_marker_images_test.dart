import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/trip_marker_images.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

class MemDisk implements MarkerDiskStore {
  final files = <String, Uint8List>{};
  int clears = 0;
  @override
  Future<void> clear() async {
    clears++;
    files.clear();
  }

  @override
  Future<int> count() async => files.length;
  @override
  Future<Uint8List?> read(String key) async => files[key];
  @override
  Future<void> write(String key, Uint8List bytes) async => files[key] = bytes;
  int? trimmedTo;
  @override
  Future<void> trimTo(int keep) async => trimmedTo = keep;
}

DiscoverySpot spot(String id, {int rank = 1, String? thumb}) => DiscoverySpot(
      id: id,
      lat: 30,
      lon: 78,
      category: 'temple',
      rank: rank,
      name: id,
      thumbUrl: thumb ?? 'https://res.cloudinary.com/x/image/upload/v1/$id.jpg',
    );

Future<Uint8List> pngOf(int w, int h, Color c) async {
  final r = ui.PictureRecorder();
  Canvas(r).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = c);
  final img = await r.endRecording().toImage(w, h);
  final b = await img.toByteData(format: ui.ImageByteFormat.png);
  return b!.buffer.asUint8List();
}

Future<ui.Image> decode(Uint8List png) async => (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cache key: spot, size, pixel ratio and thumb hash; unsafe characters replaced', () {
    final a = TripMarkerImages.cacheKey('w/12', 'https://a/x.jpg', DiscTuning.trip);
    expect(a, startsWith('w_12_${DiscTuning.trip.photoDp.round()}_1p00_'));
    expect(a.split('_').last.length, 8);
    expect(TripMarkerImages.cacheKey('w/12', 'https://a/y.jpg', DiscTuning.trip), isNot(a));
    expect(TripMarkerImages.cacheKey('w/12', 'https://a/x.jpg', DiscTuning.stay), startsWith('w_12_${DiscTuning.stay.photoDp.round()}_'));
    expect(TripMarkerImages.thumbHash('abc'), TripMarkerImages.thumbHash('abc'));
  });

  test('marker url uses the 288 px marker transform of the thumbnail helper', () {
    expect(TripMarkerImages.markerUrl(spot('a')), contains('/image/upload/c_fill,w_288,h_288,q_auto,f_auto/v1/a.jpg'));
    expect(TripMarkerImages.markerUrl(const DiscoverySpot(id: 'n', lat: 0, lon: 0, category: '', rank: 1, name: '')), isNull);
  });

  testWidgets('compose: round marker of photoDp + shadow pad, transparent corner, white ring', (tester) async {
    await tester.runAsync(() async {
      const painter = CanvasMarkerPainter();
      final thumb = await pngOf(96, 120, const Color(0xFF3366CC));
      final png = (await painter.photo(thumb, DiscTuning.trip))!;
      final img = await decode(png);
      final trip = DiscTuning.trip;
      final side = trip.px(CanvasMarkerPainter.canvasDp(trip.photoDp));
      expect(img.width, side);
      expect(img.height, side);
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int alphaAt(int x, int y) => bytes.getUint8((y * img.width + x) * 4 + 3);
      expect(alphaAt(0, 0), 0);
      final c = side ~/ 2;
      expect(bytes.getUint8((c * img.width + c) * 4 + 2), greaterThan(150));
      final ringX = c + (trip.photoDp / 2).floor() - 1;
      expect(bytes.getUint8((c * img.width + ringX) * 4), greaterThan(200));
      expect(await painter.valid(png), isTrue);
      final stay = await decode((await painter.photo(thumb, DiscTuning.stay))!);
      expect(stay.width, DiscTuning.stay.px(CanvasMarkerPainter.canvasDp(DiscTuning.stay.photoDp)));
      final badge = await decode(await painter.badge('temple', DiscTuning.trip));
      expect(badge.width, trip.px(CanvasMarkerPainter.canvasDp(trip.badgeDp)));
    });
  });

  testWidgets('compose: dot of dotDp, its colour in the middle, transparent corner', (tester) async {
    await tester.runAsync(() async {
      const painter = CanvasMarkerPainter();
      final t = DiscTuning.trip;
      final img = await decode(await painter.dot(const Color(0xFF3366CC), t));
      final side = t.px(t.dotDp);
      expect(img.width, side);
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int at(int x, int y, int ch) => bytes.getUint8((y * img.width + x) * 4 + ch);
      final c = side ~/ 2;
      expect(at(c, c, 2), greaterThan(150));
      expect(at(c, c, 0), lessThan(100));
      expect(at(0, 0, 3), 0);
    });
  });

  testWidgets('corrupt input: bad thumb gives null, bad cached png is invalid', (tester) async {
    await tester.runAsync(() async {
      const painter = CanvasMarkerPainter();
      expect(await painter.photo(Uint8List.fromList([1, 2, 3]), DiscTuning.trip), isNull);
      expect(await painter.valid(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0, 1])), isFalse);
      expect(await painter.valid(Uint8List(0)), isFalse);
    });
  });

  testWidgets('photoFor: disk first, corrupt cache recomposed, 404 skipped', (tester) async {
    await tester.runAsync(() async {
      final disk = MemDisk();
      var fetches = 0;
      final good = await pngOf(96, 96, const Color(0xFF22AA44));
      final img = TripMarkerImages(
        disk: disk,
        fetch: (url) async {
          fetches++;
          return url.contains('missing') ? null : good;
        },
      );
      final a = spot('a');
      final first = await img.photoFor(a, DiscTuning.trip);
      expect(first, isNotNull);
      expect(fetches, 1);
      expect(disk.files.length, 1);
      expect(await img.photoFor(a, DiscTuning.trip), first);
      expect(fetches, 1);
      disk.files.updateAll((k, v) => Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1]));
      final again = await img.photoFor(a, DiscTuning.trip);
      expect(fetches, 2);
      expect(again, first);
      expect(await img.photoFor(spot('m', thumb: 'https://res.cloudinary.com/x/image/upload/missing.jpg'), DiscTuning.trip), isNull);
    });
  });

  test('register: batches of 8, max 4 downloads at once, failures skipped, cancel stops', () async {
    var running = 0, peak = 0;
    final added = <String>[];
    final batches = <int>[];
    final img = TripMarkerImages(
      disk: MemDisk(),
      painter: _Painter(),
      fetch: (url) async {
        running++;
        if (running > peak) peak = running;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        running--;
        return url.contains('s3.') ? null : Uint8List.fromList([1]);
      },
    );
    final spots = [for (var i = 0; i < 18; i++) spot('s$i', rank: i)];
    final reg = await img.register(
      spots: spots,
      tuning: DiscTuning.trip,
      already: {'s0'},
      addImage: (name, _) async => added.add(name),
      onBatch: (r) async => batches.add(r.length),
      alive: () => true,
    );
    expect(peak, lessThanOrEqualTo(4));
    expect(added.contains('disc-p-s0'), isFalse);
    expect(added.contains('disc-p-s3'), isFalse);
    expect(added.length, 16);
    expect(batches, [8, 16, 17]);
    expect(reg.length, 17);

    var alive = true;
    final added2 = <String>[];
    await img.register(
      spots: spots,
      tuning: DiscTuning.trip,
      already: const {},
      addImage: (name, _) async {
        added2.add(name);
        if (added2.length == 3) alive = false;
      },
      onBatch: (_) async => fail('cancelled run must not publish'),
      alive: () => alive,
    );
    expect(added2.length, 3);
  });

  test('disk folder is trimmed to the newest 200 when it passes the cap', () async {
    final disk = MemDisk();
    for (var i = 0; i < 301; i++) {
      disk.files['k$i'] = Uint8List(1);
    }
    await TripMarkerImages(disk: disk, painter: _Painter(), fetch: (_) async => null).trimDisk(DiscTuning.trip);
    expect(disk.clears, 0);
    expect(disk.trimmedTo, 200);
  });

  test('folder store: writes <root>/disc_markers/<key>.png, counts, clears', () async {
    final root = Directory.systemTemp.createTempSync('disc_marker_store');
    final store = DiscMarkerFolderStore(root: () => root);
    await store.write('a_44_1p00_00000000', Uint8List.fromList([1, 2]));
    expect(File('${root.path}/disc_markers/a_44_1p00_00000000.png').existsSync(), isTrue);
    expect(await store.read('a_44_1p00_00000000'), [1, 2]);
    expect(await store.count(), 1);
    await store.clear();
    expect(Directory('${root.path}/disc_markers').existsSync(), isFalse);
    expect(await store.read('a_44_1p00_00000000'), isNull);
    root.deleteSync(recursive: true);
  });
}

class _Painter implements MarkerPainter {
  @override
  Future<Uint8List> badge(String category, DiscTuning t) async => Uint8List(1);
  @override
  Future<Uint8List> dot(Color color, DiscTuning t) async => Uint8List(1);
  @override
  Future<Uint8List?> photo(Uint8List thumb, DiscTuning t) async => Uint8List.fromList([7]);
  @override
  Future<bool> valid(Uint8List png) async => true;
}
