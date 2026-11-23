import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:bakhli/features/buddy/viewer/data/viewer_spot_photos.dart';
import 'package:bakhli/features/map_discovery/data/map_pack_service.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_index.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_models.dart';

const _url = 'https://res.cloudinary.com/x/image/upload/v1/atlas/spots/a.jpg';

MapPackIndex _index() => MapPackIndex.of([
      const MapPack(version: 'v1', stateId: 's1', spots: [
        MapPackSpot(id: 'osm:W226843462', lat: 30.7, lon: 79.0, category: 'temple', rank: 1, name: 'Kedarnath Temple', thumbUrl: _url),
        MapPackSpot(id: 'wd:Q633415', lat: 32.3, lon: 77.2, category: 'attraction', rank: 2, name: 'Rohtang Pass'),
      ]),
    ]);

void main() {
  tearDown(() {
    ViewerSpotPhotos.indexForTest = null;
    Get.reset();
  });

  test('a known id returns its thumbnail url', () {
    final index = _index();
    ViewerSpotPhotos.indexForTest = () => index;
    expect(ViewerSpotPhotos.urlFor('osm:W226843462'), _url);
  });

  test('a row without a thumbnail returns null', () {
    final index = _index();
    ViewerSpotPhotos.indexForTest = () => index;
    expect(ViewerSpotPhotos.urlFor('wd:Q633415'), isNull);
  });

  test('an unknown or empty id returns null', () {
    final index = _index();
    ViewerSpotPhotos.indexForTest = () => index;
    expect(ViewerSpotPhotos.urlFor('osm:N1'), isNull);
    expect(ViewerSpotPhotos.urlFor(''), isNull);
  });

  test('an index that is not loaded returns null', () {
    ViewerSpotPhotos.indexForTest = () => null;
    expect(ViewerSpotPhotos.urlFor('osm:W226843462'), isNull);
  });

  test('without a registered pack service it returns null and registers nothing', () {
    expect(ViewerSpotPhotos.urlFor('osm:W226843462'), isNull);
    expect(Get.isRegistered<MapPackService>(), isFalse);
  });

  test('a registered service with packs off returns null', () {
    Get.put(MapPackService());
    expect(ViewerSpotPhotos.urlFor('osm:W226843462'), isNull);
  });
}
