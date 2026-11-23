import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every asset path literal in lib/ exists on disk', () {
    final literal = RegExp(r'''['"](assets/[^'"\s]+\.(?:png|jpg|jpeg|webp|gif|svg|json))['"]''');
    final missing = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in literal.allMatches(source)) {
        final path = match.group(1)!;
        if (path.contains(r'$')) continue;
        if (!File(path).existsSync()) missing.add('${file.path}: $path');
      }
    }
    expect(missing, isEmpty, reason: 'Missing asset files:\n${missing.join('\n')}');
  });
}
