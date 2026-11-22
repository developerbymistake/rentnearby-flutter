import 'dart:convert';
import 'dart:math' as math;

class MapPackSynthetic {
  static const List<String> cats = [
    'temple', 'fort', 'palace', 'museum', 'lake', 'waterfall', 'viewpoint', 'park', 'garden',
    'zoo', 'wildlife', 'bridge', 'ghat', 'cave', 'historic', 'beach', 'market',
  ];
  static const String img = 'https://res.cloudinary.com/demo/image/upload/';

  static String body({
    int rows = 1500,
    int seed = 1,
    int withThumb = 300,
    double centerLat = 30.0,
    double centerLon = 78.0,
    double spreadDeg = 1.0,
    int cities = 10,
    String state = 'synthetic-state',
    String version = 'syn-1',
  }) =>
      jsonEncode(json(
        rows: rows,
        seed: seed,
        withThumb: withThumb,
        centerLat: centerLat,
        centerLon: centerLon,
        spreadDeg: spreadDeg,
        cities: cities,
        state: state,
        version: version,
      ));

  static Map<String, dynamic> json({
    int rows = 1500,
    int seed = 1,
    int withThumb = 300,
    double centerLat = 30.0,
    double centerLon = 78.0,
    double spreadDeg = 1.0,
    int cities = 10,
    String state = 'synthetic-state',
    String version = 'syn-1',
  }) {
    final rnd = math.Random(seed);
    double round5(double v) => (v * 100000).roundToDouble() / 100000;
    final thumbEvery = withThumb <= 0 ? 0 : math.max(1, rows ~/ withThumb);
    var thumbs = 0;
    final s = <List<Object?>>[];
    for (var i = 0; i < rows; i++) {
      final hasThumb = thumbEvery > 0 && i % thumbEvery == 0 && thumbs < withThumb;
      if (hasThumb) thumbs++;
      s.add([
        'syn-$seed-$i',
        round5(centerLat + (rnd.nextDouble() * 2 - 1) * spreadDeg),
        round5(centerLon + (rnd.nextDouble() * 2 - 1) * spreadDeg),
        rnd.nextInt(cats.length),
        i + 1,
        'Place $i',
        cities <= 0 ? null : 1 + rnd.nextInt(cities),
        hasThumb ? 'v1/syn/$seed/$i.jpg' : null,
        hasThumb ? 1 + rnd.nextInt(5) : 0,
      ]);
    }
    return {
      'v': version,
      'state': state,
      'img': img,
      'cats': cats,
      'fields': ['id', 'lat', 'lon', 'cat', 'rank', 'name', 'cityKey', 'thumb', 'nPhotos'],
      's': s,
    };
  }
}
