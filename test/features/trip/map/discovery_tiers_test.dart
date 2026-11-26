import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_models.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_parser.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_synthetic.dart';
import 'package:bakhli/features/trip/map/discovery_ids.dart';
import 'package:bakhli/features/trip/map/discovery_tiers.dart';
import 'package:flutter_test/flutter_test.dart';

MapPackSpot _s(String id, int rank, {bool thumb = false, double lat = 30, double lon = 78, String cat = 'temple'}) => MapPackSpot(
      id: id,
      lat: lat,
      lon: lon,
      category: cat,
      rank: rank,
      name: id,
      thumbUrl: thumb ? 'https://h/image/upload/$id.jpg' : null,
    );

void main() {
  test('empty input', () {
    expect(DiscTiers.assign(const [], photoMax: 40), isEmpty);
    expect(DiscTiers.topPhotos(const [], 40), isEmpty);
  });

  test('photo tier = best ranked spots with a thumb, badge = next by rank, rest dots', () {
    final spots = [
      _s('a', 1),
      _s('b', 2, thumb: true),
      _s('c', 3, thumb: true),
      _s('d', 4),
      _s('e', 5, thumb: true),
      _s('f', 6),
    ];
    final t = DiscTiers.assign(spots, photoMax: 2, badgeMax: 2);
    expect(t, {'b': 1, 'c': 1, 'a': 2, 'd': 2, 'e': 3, 'f': 3});
  });

  test('ties on rank break by id, duplicates counted once', () {
    final spots = [_s('z', 1, thumb: true), _s('m', 1, thumb: true), _s('m', 1, thumb: true), _s('a', 1, thumb: true)];
    expect(DiscTiers.topPhotos(spots, 2).map((s) => s.id), ['a', 'm']);
    expect(DiscTiers.assign(spots, photoMax: 2, badgeMax: 0), {'a': 1, 'm': 1, 'z': 3});
  });

  test('stay area limits photos to the area', () {
    final spots = [
      _s('far', 1, thumb: true, lat: 31),
      _s('near', 2, thumb: true, lat: 30.01),
    ];
    final area = const DiscArea(30, 78, 10);
    expect(DiscTiers.topPhotos(spots, 12, area: area).map((s) => s.id), ['near']);
    expect(DiscTiers.assign(spots, photoMax: 12, area: area), {'near': 1, 'far': 2});
    expect(const DiscArea(30, 78, 0).valid, isFalse);
  });

  test('1,500 rows: 40 photo markers with thumbs only, every other spot a badge', () {
    final p = MapPackParser.parse(MapPackSynthetic.body(rows: 1500, withThumb: 300))!;
    final sw = Stopwatch()..start();
    final t = DiscTiers.assign(p.spots, photoMax: DiscTuning.trip.photoMax, badgeMax: DiscTuning.trip.badgeMax);
    sw.stop();
    // ignore: avoid_print
    print('tiers 1500 rows: ${sw.elapsedMilliseconds} ms');
    expect(t.length, 1500);
    final photos = DiscTiers.topPhotos(p.spots, DiscTuning.trip.photoMax);
    expect(photos.length, 40);
    expect(photos.every((s) => s.hasThumb), isTrue);
    expect(t.values.where((v) => v == DiscTiers.photo).length, 40);
    expect(t.values.where((v) => v == DiscTiers.badge).length, 1460);
    expect(t.values.where((v) => v == DiscTiers.dot).length, 0);
  });

  test('groupOf follows TripSpotCategory colours: 4 groups', () {
    expect(DiscTiers.groupOf('lake'), DiscTiers.grpWater);
    expect(DiscTiers.groupOf('beach'), DiscTiers.grpWater);
    expect(DiscTiers.groupOf('park'), DiscTiers.grpNature);
    expect(DiscTiers.groupOf('viewpoint'), DiscTiers.grpNature);
    expect(DiscTiers.groupOf('temple'), DiscTiers.grpHeritage);
    expect(DiscTiers.groupOf('cave'), DiscTiers.grpHeritage);
    expect(DiscTiers.groupOf(''), DiscTiers.grpOther);
    expect(DiscTiers.groupOf('market'), DiscTiers.grpOther);
  });

  test('badge keys: known categories keep their name, unknown fall back to the default image', () {
    expect(DiscIds.badgeImage('temple'), 'disc-b-temple');
    expect(DiscIds.badgeImage('market'), 'disc-b-market');
    expect(DiscIds.badgeImage('Temple'), 'disc-b-temple');
    expect(DiscIds.badgeImage('mystery'), 'disc-b-place');
    expect(DiscIds.badgeImage(''), 'disc-b-place');
    expect(DiscIds.badgeCategories.toSet().length, DiscIds.badgeCategories.length);
    expect(DiscIds.spotIdOfPhotoImage(DiscIds.photoImage('abc')), 'abc');
    expect(DiscIds.spotIdOfPhotoImage('disc-b-temple'), isNull);
  });

  test('tuning: trip and stay values', () {
    expect(DiscTuning.trip.photoMax, 40);
    expect(DiscTuning.trip.photoDp, DS.s(90 * DiscTuning.markerScale));
    expect(DiscTuning.stay.photoMax, 24);
    expect(DiscTuning.stay.photoDp, DS.s(90 * DiscTuning.markerScale));
    expect(DiscTuning.trip.px(44), 44);
  });
}
