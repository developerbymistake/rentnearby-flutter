import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _plateAllowed = {
  'lib/features/taxi/models/taxi_owner_model.dart',
  'lib/features/taxi/setup/taxi_vehicle_screen.dart',
};
const _uploadAllowed = {
  'lib/features/taxi/setup/taxi_repository.dart',
};

List<String> _hits(String needle, Set<String> allowed) {
  final out = <String>[];
  for (final e in Directory('lib').listSync(recursive: true)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    final path = e.path.replaceAll('\\', '/');
    if (allowed.contains(path)) continue;
    if (e.readAsStringSync().contains(needle)) out.add(path);
  }
  return out..sort();
}

void main() {
  test('the plate proof url is read only by the owner model and the Vehicle step', () {
    final hits = _hits('platePhotoUrl', _plateAllowed);
    expect(hits, isEmpty, reason: 'platePhotoUrl must stay private to the driver: ${hits.join(', ')}');
  });

  test('the plate proof upload path lives only in the taxi repository', () {
    final hits = _hits('plate-photo', _uploadAllowed);
    expect(hits, isEmpty, reason: 'plate-photo used outside the repository: ${hits.join(', ')}');
  });

  test('the allowed files exist, so the guard cannot pass on a rename', () {
    for (final p in {..._plateAllowed, ..._uploadAllowed}) {
      expect(File(p).existsSync(), isTrue, reason: p);
    }
  });
}
