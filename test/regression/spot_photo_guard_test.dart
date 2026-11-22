import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dart(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

String _name(File f) => f.path.replaceAll(r'\', '/').split('/').last;

void main() {
  const allowed = {'trip_spot_row.dart', 'spot_gallery_collage.dart', 'spot_photo_viewer.dart'};
  const spotMarkers = ['TripSpotModel', 'TripSpotMedia', 'spot.photos', 'SpotPhotoUrl'];

  test('every CachedNetworkImage showing a spot photo sits in an allowed file with SpotPhotoUrl and memCacheWidth', () {
    final bad = <String>[];
    for (final f in _dart('lib/features/trip')) {
      final src = f.readAsStringSync();
      if (!src.contains('CachedNetworkImage(')) continue;
      final name = _name(f);
      if (allowed.contains(name)) {
        if (!src.contains('SpotPhotoUrl.') || !src.contains('memCacheWidth')) bad.add('$name misses SpotPhotoUrl or memCacheWidth');
        continue;
      }
      if (spotMarkers.any(src.contains)) bad.add('$name shows a spot photo outside the allowed files');
    }
    expect(bad, isEmpty);
  });

  test('the spot model has no gallery getter (spot photos are photos)', () {
    final model = File('lib/features/trip/models/trip_spot_model.dart').readAsStringSync();
    expect(model.contains('get gallery'), isFalse);
    expect(model.contains('get photos'), isTrue);
  });

  test('no file calls .gallery on a spot model', () {
    final call = RegExp(r'\b(spot|s|_spot|widget\.spot)\.gallery\b');
    final bad = [
      for (final f in _dart('lib'))
        if (call.hasMatch(f.readAsStringSync())) _name(f),
    ];
    expect(bad, isEmpty);
  });

  test('no file under lib/features/trip imports an image picker', () {
    final bad = [
      for (final f in _dart('lib/features/trip'))
        if (RegExp(r'''import\s+['"]package:(image_picker|image_cropper)/''').hasMatch(f.readAsStringSync()) ||
            f.readAsStringSync().contains('app_photo_pick.dart'))
          _name(f),
    ];
    expect(bad, isEmpty);
  });

  test('the spot detail path lives in one place', () {
    final hits = [
      for (final f in _dart('lib'))
        if (f.readAsStringSync().contains(r"/spots/${Uri.encodeComponent(spotId)}")) _name(f),
    ];
    expect(hits, ['trip_repository.dart']);
  });
}
