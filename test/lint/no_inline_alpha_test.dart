import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no inline numeric withValues(alpha:) outside lib/design', () {
    final pattern = RegExp(r'withValues\(\s*alpha:\s*\d');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/design/')) continue;
      final text = entity.readAsStringSync();
      for (final m in pattern.allMatches(text)) {
        final line = text.substring(0, m.start).split('\n').length;
        offenders.add('$path:$line');
      }
    }
    expect(offenders, isEmpty, reason: 'use Alpha tokens: ${offenders.join(', ')}');
  });
}
