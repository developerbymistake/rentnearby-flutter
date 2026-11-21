import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _dirs = <RegExp>[
  RegExp(r'^lib/features/owner_core/.*/models/'),
  RegExp(r'^lib/features/owner_core/home/owner_home_models\.dart$'),
  RegExp(r'^lib/features/owner_core/json/'),
  RegExp(r'^lib/features/stay_owner/.*/models/'),
  RegExp(r'^lib/features/taxi_driver/.*/models/'),
  RegExp(r'^lib/features/seeker_home/'),
];

const _banned = [' as String', ' as int', ' as Map', ' as List', 'DateTime.parse(', 'int.parse(', '!.'];

void main() {
  test('owner models parse without casts, parse() or null assertions', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || !_dirs.any((r) => r.hasMatch(path))) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final b in _banned) {
          if (lines[i].contains(b)) bad.add('$path:${i + 1} "$b"');
        }
      }
    }
    expect(bad, isEmpty);
  });

  test('new owner lists use builders, not ListView(children:)', () {
    final bad = <String>[];
    for (final dir in ['lib/features/owner_core', 'lib/features/stay_owner', 'lib/features/taxi_driver', 'lib/features/seeker_home']) {
      final d = Directory(dir);
      if (!d.existsSync()) continue;
      for (final f in d.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        final s = f.readAsStringSync();
        if (RegExp(r'ListView\(\s*children:').hasMatch(s)) bad.add(f.path);
      }
    }
    expect(bad, isEmpty);
  });
}
