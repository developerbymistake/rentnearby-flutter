import 'dart:convert';

import 'package:bakhli/features/map_discovery/pack/map_pack_constants.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_models.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_parser.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_synthetic.dart';
import 'package:flutter_test/flutter_test.dart';

const _img = 'https://res.cloudinary.com/x/image/upload/';

String _body(List<String> fields, List<Object?> rows, {Object? cats = const ['temple', 'lake'], Object? img = _img, Object? v = 'v1', Object? state = 'st-1'}) =>
    jsonEncode({
      'v': ?v,
      'state': ?state,
      'img': ?img,
      'cats': ?cats,
      'fields': fields,
      's': rows,
    });

void main() {
  group('header driven', () {
    test('shuffled columns, unknown column and missing optional columns', () {
      final p = MapPackParser.parse(_body(
        ['name', 'zzz', 'lon', 'id', 'lat', 'cat'],
        [
          ['Kedar', 'junk', 79.1, 'a', 30.7, 0],
        ],
      ))!;
      expect(p.version, 'v1');
      expect(p.stateId, 'st-1');
      final s = p.spots.single;
      expect(s.id, 'a');
      expect(s.name, 'Kedar');
      expect(s.lat, 30.7);
      expect(s.lon, 79.1);
      expect(s.category, 'temple');
      expect(s.rank, MapPackConstants.unrankedBase);
      expect(s.cityKey, isNull);
      expect(s.thumbUrl, isNull);
      expect(s.nPhotos, 0);
      expect(s.stateId, 'st-1');
    });

    test('vm (visit minutes, optional last column): positive int kept, missing or bad cell = null', () {
      final p = MapPackParser.parse(_body(
        ['id', 'lat', 'lon', 'name', 'vm'],
        [
          ['a', 30.1, 78.1, 'A', 120],
          ['b', 30.1, 78.1, 'B', 0],
          ['c', 30.1, 78.1, 'C', 'x'],
          ['d', 30.1, 78.1, 'D', -5],
          ['e', 30.1, 78.1, 'E', 90.0],
          ['f', 30.1, 78.1, 'F'],
        ],
      ))!;
      expect([for (final s in p.spots) s.visitMinutes], [120, null, null, null, 90, null]);
      expect(p.spots.first.withStateId('other').visitMinutes, 120);
      expect(MapPackConstants.requiredColumns.contains(MapPackConstants.colVm), isFalse);
      final old = MapPackParser.parse(_body(['id', 'lat', 'lon', 'name'], [['a', 30.1, 78.1, 'A']]))!;
      expect(old.spots.single.visitMinutes, isNull);
    });

    test('state and version numbers are stringified', () {
      final p = MapPackParser.parse(_body(['id', 'lat', 'lon', 'name'], [], v: 7, state: 12))!;
      expect(p.version, '7');
      expect(p.stateId, '12');
      expect(p.isEmpty, isTrue);
    });

    test('short row reads missing trailing columns as null', () {
      final p = MapPackParser.parse(_body(['id', 'lat', 'lon', 'name', 'rank', 'cityKey'], [
        ['a', 1, 2, 'A'],
      ]))!;
      expect(p.spots.single.rank, MapPackConstants.unrankedBase);
      expect(p.spots.single.cityKey, isNull);
    });
  });

  group('rows', () {
    const fields = ['id', 'lat', 'lon', 'cat', 'rank', 'name', 'cityKey', 'thumb', 'nPhotos'];

    test('bad rows skipped or defaulted, rest kept', () {
      final p = MapPackParser.parse(_body(fields, [
        ['', 30, 78, 0, 1, 'Empty id', 1, null, 0],
        ['lat', 91, 78, 0, 2, 'Lat 91', 1, null, 0],
        ['lon', 30, 'NaN', 0, 3, 'Lon NaN', 1, null, 0],
        ['blank', 30, 78, 0, 4, '   ', 1, null, 0],
        ['ok', 30, 78, 1, 5, ' Lake ', 3, 'v1/a.jpg', 2],
        ['ok', 31, 79, 0, 6, 'Duplicate', 1, null, 0],
        ['cat', 30, 78, 9, 7, 'Cat out of range', 1, null, 0],
        ['rank', 30, 78, 0, 'top', 'Rank text', 1, null, 0],
        [42, 30, 78, 0, 9, 'Numeric id', '5', '', -3],
        'not a row',
        ['neg', 30, 78, 0, 0, 'Rank zero', 1, null, 0],
      ]))!;
      final ids = p.spots.map((s) => s.id).toList();
      expect(ids, ['ok', 'cat', 'rank', '42', 'neg']);
      final ok = p.spots.first;
      expect(ok.name, 'Lake');
      expect(ok.category, 'lake');
      expect(ok.rank, 5);
      expect(ok.cityKey, 3);
      expect(ok.thumbUrl, '${_img}v1/a.jpg');
      expect(ok.nPhotos, 2);
      expect(p.spots[1].category, '');
      expect(p.spots[2].rank, MapPackConstants.unrankedBase + 7);
      expect(p.spots[3].cityKey, 5);
      expect(p.spots[3].thumbUrl, isNull);
      expect(p.spots[3].nPhotos, 0);
      expect(p.spots[4].rank, MapPackConstants.unrankedBase + 10);
    });

    test('thumb: full url kept, relative joined, relative without img is null', () {
      expect(MapPackParser.thumbUrl(_img, 'https://cdn.example/a.jpg'), 'https://cdn.example/a.jpg');
      expect(MapPackParser.thumbUrl(_img, '/v1/a.jpg'), '${_img}v1/a.jpg');
      expect(MapPackParser.thumbUrl('https://h/image/upload', 'a.jpg'), 'https://h/image/upload/a.jpg');
      expect(MapPackParser.thumbUrl(null, 'a.jpg'), isNull);
      expect(MapPackParser.thumbUrl(_img, 5), isNull);
      final p = MapPackParser.parse(_body(fields, [
        ['a', 1, 2, 0, 1, 'A', 1, 'a.jpg', 1],
      ], img: null))!;
      expect(p.spots.single.thumbUrl, isNull);
    });

    test('rows over the cap are dropped', () {
      final rows = [for (var i = 0; i < MapPackConstants.maxRows + 5; i++) ['r$i', 1, 2, 'N']];
      final p = MapPackParser.parse(_body(['id', 'lat', 'lon', 'name'], rows))!;
      expect(p.spots.length, MapPackConstants.maxRows);
    });
  });

  group('corrupt', () {
    test('returns null for broken bodies', () {
      expect(MapPackParser.parse(''), isNull);
      expect(MapPackParser.parse('not json'), isNull);
      expect(MapPackParser.parse('[1,2]'), isNull);
      expect(MapPackParser.parse(_body(['lat', 'lon', 'name'], [])), isNull);
      expect(MapPackParser.parse(jsonEncode({'fields': ['id', 'lat', 'lon', 'name'], 's': {}})), isNull);
      expect(MapPackParser.parse(jsonEncode({'s': []})), isNull);
      expect(MapPackParser.parse(' ' * (MapPackConstants.maxBodyChars + 1)), isNull);
    });

    test('missing cats, img and v still parse', () {
      final p = MapPackParser.parse(_body(['id', 'lat', 'lon', 'name', 'cat'], [
        ['a', 1, 2, 'A', 0],
      ], cats: null, img: null, v: null, state: null))!;
      expect(p.version, '');
      expect(p.stateId, '');
      expect(p.spots.single.category, '');
      final f = p.withFallback(version: 'ref-v', stateId: '9');
      expect(f.version, 'ref-v');
      expect(f.stateId, '9');
      expect(f.spots.single.stateId, '9');
    });

    test('empty pack is valid', () {
      final p = MapPackParser.parse(_body(['id', 'lat', 'lon', 'name'], []))!;
      expect(p.spots, isEmpty);
    });
  });

  group('refs and flag', () {
    test('refs parse defensively', () {
      final refs = MapPackParser.refs({
        'packs': [
          {'stateId': 5, 'stateName': ' Uttar  ', 'version': 'abc', 'path': '/trips/map-packs/5/abc', 'bbox': [77, 28, 81, 31], 'count': 12},
          {'stateId': 'g-2', 'version': 'x', 'path': '/p', 'bbox': [1, 2, 3]},
          {'stateId': 'g-3', 'version': 'x', 'path': '/p', 'bbox': [3, 2, 1, 4]},
          {'stateId': 5, 'version': 'dup', 'path': '/p'},
          {'stateId': '', 'version': 'x', 'path': '/p'},
          {'stateId': 'g-4', 'version': '', 'path': '/p'},
          {'stateId': 'g-5', 'version': 'x'},
          'junk',
        ],
      });
      expect(refs.map((r) => r.stateId), ['5', 'g-2', 'g-3']);
      expect(refs[0].stateName, 'Uttar');
      expect(refs[0].bbox, [77.0, 28.0, 81.0, 31.0]);
      expect(refs[0].count, 12);
      expect(refs[0].contains(30, 79), isTrue);
      expect(refs[0].contains(32, 79), isFalse);
      expect(refs[1].bbox, isNull);
      expect(refs[1].contains(2, 1), isFalse);
      expect(refs[2].bbox, isNull);
    });

    test('refs round trip through toJson', () {
      final refs = MapPackParser.refs({
        'packs': [
          {'stateId': 'a', 'stateName': 'A', 'version': '1', 'path': '/p', 'bbox': [0, 0, 1, 1], 'count': 3},
          {'stateId': 'b', 'version': '2', 'path': '/q'},
        ],
      });
      final again = MapPackParser.refs(jsonDecode(jsonEncode([for (final r in refs) r.toJson()])));
      expect(again, refs);
    });

    test('refs and flag of wrong shapes', () {
      expect(MapPackParser.refs(null), isEmpty);
      expect(MapPackParser.refs({'packs': 'x'}), isEmpty);
      expect(MapPackParser.flag({'mapDiscovery': true}), isTrue);
      expect(MapPackParser.flag({'mapDiscovery': 'true'}), isFalse);
      expect(MapPackParser.flag({}), isFalse);
      expect(MapPackParser.flag(null), isFalse);
    });
  });

  test('synthetic 1,500 rows parse fully and deterministically', () {
    final raw = MapPackSynthetic.body(rows: 1500, withThumb: 300);
    expect(raw, MapPackSynthetic.body(rows: 1500, withThumb: 300));
    final sw = Stopwatch()..start();
    final p = MapPackParser.parse(raw)!;
    sw.stop();
    // ignore: avoid_print
    print('parse 1500 rows: ${sw.elapsedMilliseconds} ms, ${raw.length} chars');
    expect(p.spots.length, 1500);
    expect(p.spots.where((s) => s.hasThumb).length, 300);
    expect(p.version, 'syn-1');
    expect(p.spots.every((s) => s.cityKey != null && s.rank >= 1), isTrue);
    expect(p.spots, isA<List<MapPackSpot>>());
  });
}
