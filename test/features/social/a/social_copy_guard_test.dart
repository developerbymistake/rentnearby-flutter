import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _literal = RegExp(r"'((?:[^'\\\n]|\\.)*)'" + '|' + r'"((?:[^"\\\n]|\\.)*)"');

List<(String, String)> _literals(String root) {
  final out = <(String, String)>[];
  final List<File> files;
  if (File(root).existsSync()) {
    files = [File(root)];
  } else if (Directory(root).existsSync()) {
    files = Directory(root).listSync(recursive: true).whereType<File>().toList();
  } else {
    return out;
  }
  for (final f in files) {
    final path = f.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart')) continue;
    for (final line in f.readAsLinesSync()) {
      final t = line.trimLeft();
      if (t.startsWith('import ') || t.startsWith('export ') || t.startsWith('part ') || t.startsWith('//')) continue;
      for (final m in _literal.allMatches(line)) {
        out.add((path, m.group(1) ?? m.group(2) ?? ''));
      }
    }
  }
  return out;
}

void main() {
  test('no social or Plus copy promises encryption, security, anonymity or mentions UPI', () {
    final banned = RegExp(r'\b(encrypted|encryption|secure|anonymous|UPI)\b', caseSensitive: false);
    final hits = [
      for (final (path, text) in _literals('lib/features/social'))
        if (banned.hasMatch(text)) '$path: $text',
    ];
    expect(hits, isEmpty);
  });

  test('chat and Plus copy never says private (Settings privacy rows in lane A are the mock copy)', () {
    final banned = RegExp(r'\bprivate\b', caseSensitive: false);
    final hits = [
      for (final (path, text) in [..._literals('lib/features/social/c'), ..._literals('lib/features/social/shared/widgets/plus_widgets.dart')])
        if (banned.hasMatch(text)) '$path: $text',
    ];
    expect(hits, isEmpty);
  });

  test('the guard sees the lane A strings', () {
    expect(_literals('lib/features/social/a').map((e) => e.$2), contains('Tap the star. They are not told.'));
  });
}
