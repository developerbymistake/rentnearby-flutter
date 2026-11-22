import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/map_discovery/pack/map_pack_parser.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_synthetic.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/discovery_geojson.dart';
import 'package:bakhli/features/trip/map/discovery_tiers.dart';
import 'package:bakhli/features/trip/trip_strings_map_disc.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_row.dart';
import 'package:flutter_test/flutter_test.dart';

MapPackSpot _s(String id, {int rank = 1, String cat = 'lake', bool thumb = false}) => MapPackSpot(
      id: id,
      lat: 30.5,
      lon: 78.25,
      category: cat,
      rank: rank,
      name: id,
      thumbUrl: thumb ? 'https://h/image/upload/$id.jpg' : null,
    );

List<Map<String, dynamic>> _features(Map<String, dynamic> fc) => (fc['features'] as List).cast<Map<String, dynamic>>();

void main() {
  test('empty is a fresh empty collection', () {
    final a = DiscGeoJson.empty;
    (a['features'] as List).add(1);
    expect(DiscGeoJson.empty['features'], isEmpty);
    expect(DiscGeoJson.all(const [], const {}), {'type': 'FeatureCollection', 'features': []});
  });

  test('disc-all: top-level string id, point lon/lat, properties cat grp rank tier, no img', () {
    final fc = DiscGeoJson.all([_s('a', rank: 3), _s('b', cat: 'market'), _s('a')], {'a': 1});
    final f = _features(fc);
    expect(f.length, 2);
    expect(f[0]['type'], 'Feature');
    expect(f[0]['id'], 'a');
    expect(f[0]['geometry'], {
      'type': 'Point',
      'coordinates': [78.25, 30.5],
    });
    expect(f[0]['properties'], {'cat': 'lake', 'grp': DiscTiers.grpWater, 'rank': 3, 'tier': 1});
    expect(f[1]['properties']['cat'], 'place');
    expect(f[1]['properties']['tier'], DiscTiers.dot);
    expect(f[0]['properties'].containsKey('id'), isFalse);
    expect(jsonEncode(fc).contains('promoteId'), isFalse);
  });

  test('disc-photo: only registered ids, img = photo image name', () {
    final fc = DiscGeoJson.photo([_s('a', thumb: true), _s('b', thumb: true)], {'b'});
    final f = _features(fc).single;
    expect(f['id'], 'b');
    expect(f['properties']['img'], 'disc-p-b');
    expect(f['properties']['tier'], DiscTiers.photo);
  });

  test('disc-sel: one feature with kind and img per kind', () {
    final photo = _features(DiscGeoJson.sel(_s('a'), DiscSelKind.photo)).single;
    expect(photo['properties']['kind'], 'photo');
    expect(photo['properties']['img'], 'disc-p-a');
    final badge = _features(DiscGeoJson.sel(_s('a', cat: 'fort'), DiscSelKind.badge)).single;
    expect(badge['properties']['img'], 'disc-b-fort');
    final dot = _features(DiscGeoJson.sel(_s('a'), DiscSelKind.dot)).single;
    expect(dot['properties'].containsKey('img'), isFalse);
    expect(dot['properties']['kind'], 'dot');
    final planned = _features(DiscGeoJson.sel(_s('a'), DiscSelKind.planned)).single;
    expect(planned['properties']['kind'], 'planned');
  });

  test('planned filter: sorted literal ids, null when empty; badge keeps its tier filter', () {
    expect(DiscGeoJson.plannedFilter(const []), isNull);
    final f = DiscGeoJson.plannedFilter(['b', 'a', 'b']);
    expect(f, [
      '!',
      [
        'in',
        ['id'],
        [
          'literal',
          ['a', 'b'],
        ],
      ],
    ]);
    expect(DiscGeoJson.layerFilter(DiscIds.layerDots, const []), isNull);
    expect(DiscGeoJson.layerFilter(DiscIds.layerBadge, const []), DiscLayers.badgeTierFilter);
    expect(DiscGeoJson.layerFilter(DiscIds.layerBadge, ['a']), ['all', DiscLayers.badgeTierFilter, DiscGeoJson.plannedFilter(['a'])]);
    expect(DiscGeoJson.layerFilter(DiscIds.layerPhoto, ['a']), DiscGeoJson.plannedFilter(['a']));
  });

  test('refsOf reads maps and json strings, numeric ids, skips malformed', () {
    final refs = DiscGeoJson.refsOf([
      {
        'id': 'a',
        'geometry': {
          'coordinates': [78.1, 30.1],
        },
      },
      jsonEncode({
        'id': 7,
        'geometry': {
          'coordinates': [78.2, 30.2],
        },
      }),
      {
        'properties': {'id': 'p'},
        'geometry': {
          'coordinates': [78.3, 30.3],
        },
      },
      {'id': 'nogeom'},
      {
        'id': 'bad',
        'geometry': {
          'coordinates': ['x', 1],
        },
      },
      'not json',
      null,
      5,
    ]);
    expect(refs.map((r) => r.id), ['a', '7', 'p']);
    expect(refs.first.lat, 30.1);
    expect(refs.first.lon, 78.1);
  });

  test('nearest by screen distance, ties by id, empty = null', () {
    expect(DiscGeoJson.nearest(const [], 0, 0), isNull);
    final pts = [
      (id: 'far', x: 30.0, y: 0.0),
      (id: 'b', x: 3.0, y: 4.0),
      (id: 'a', x: 4.0, y: 3.0),
      (id: 'nan', x: double.nan, y: 0.0),
    ];
    expect(DiscGeoJson.nearest(pts, 0, 0), 'a');
  });

  test('1,500 rows build all three sources', () {
    final p = MapPackParser.parse(MapPackSynthetic.body(rows: 1500, withThumb: 300))!;
    final tiers = DiscTiers.assign(p.spots, photoMax: 40);
    final top = DiscTiers.topPhotos(p.spots, 40);
    final sw = Stopwatch()..start();
    final all = DiscGeoJson.all(p.spots, tiers);
    final photo = DiscGeoJson.photo(p.spots, {for (final s in top) s.id}, tiers: tiers);
    final sel = DiscGeoJson.sel(top.first, DiscSelKind.photo);
    sw.stop();
    // ignore: avoid_print
    print('geojson 1500 rows: ${sw.elapsedMilliseconds} ms, ${jsonEncode(all).length} chars');
    expect(_features(all).length, 1500);
    expect(_features(photo).length, 40);
    expect(_features(sel).length, 1);
    expect(_features(all).every((f) => f['id'] is String && (f['id'] as String).isNotEmpty), isTrue);
  });

  test('layer specs: order, sources, filters and interaction', () {
    final specs = DiscLayers.specs(DiscTuning.trip);
    expect(specs.map((s) => s.id), DiscIds.layers);
    expect(specs[0].sourceId, DiscIds.srcAll);
    expect(specs[0].interactive, isFalse);
    expect(specs[1].filter, DiscLayers.badgeTierFilter);
    expect(specs[1].minZoom, 12);
    expect(specs[2].sourceId, DiscIds.srcPhoto);
    expect(specs.skip(3).every((s) => s.sourceId == DiscIds.srcSel && !s.interactive), isTrue);
  });

  test('host read-only constructor has no day actions', () {
    const host = DiscoveryHost.readOnly();
    expect(host.anchorLayerId(), isNull);
    expect(host.plannedDayOf('x'), isNull);
    expect(host.targetDayFor, isNull);
    expect(host.onAdd, isNull);
    expect(host.onRemove, isNull);
    expect(host.topInset(), 0);
  });

  test('strings: Details reuses the existing constant, approved labels only', () {
    expect(TripMapDiscStrings.details, TripSpotRow.details);
    expect(TripMapDiscStrings.addToDay(2), 'Add to Day 2');
    expect(TripMapDiscStrings.inDay(2), 'In Day 2');
    expect(TripMapDiscStrings.removeFromDay, 'Remove from day');
    expect(TripMapDiscStrings.loadingPlaces, 'Loading places');
  });

  test('reuse guard: foundation files import no plan controller, stay file, routes or plugin', () {
    final files = [
      for (final n in ['discovery_ids', 'discovery_tiers', 'discovery_geojson', 'discovery_api']) File('lib/features/trip/map/$n.dart'),
      ...Directory('lib/features/map_discovery/pack').listSync().whereType<File>().where((f) => f.path.endsWith('.dart')),
    ];
    final banned = RegExp(r"import '[^']*(trip_plan|/stay/|app_routes|trip_routes|maplibre_gl)");
    for (final f in files) {
      expect(f.existsSync(), isTrue, reason: f.path);
      expect(banned.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
    for (final f in Directory('lib/features/map_discovery/pack').listSync().whereType<File>()) {
      final src = f.readAsStringSync();
      expect(src.contains("package:flutter/"), isFalse, reason: f.path);
      expect(src.contains("package:get/"), isFalse, reason: f.path);
    }
  });
}
