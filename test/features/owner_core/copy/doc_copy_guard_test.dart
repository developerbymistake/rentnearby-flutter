@Tags(['gate'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Run one section: --dart-define=DOC_SECTION=6.2 (prefix match); the gate runs --dart-define=DOC_SECTION=all.
// The four doc-overruled captions are listed by the lanes in their reports (CONTRACT_APP 7.1).
const _section = String.fromEnvironment('DOC_SECTION');

String _norm(String t) => t
    .replaceAll('’', "'")
    .replaceAll('‘', "'")
    .replaceAll('–', '-')
    .replaceAll('—', '-')
    .replaceAll(RegExp(r'\$\{[^}]*\}|\$[a-zA-Z_]\w*|\{[^}]*\}'), '{}')
    .replaceAll(RegExp(r'\d'), '0')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

Set<String> _appLiterals() {
  final lit = RegExp(r"'((?:[^'\\]|\\.)*)'" '|' r'"((?:[^"\\]|\\.)*)"');
  final out = <String>{};
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
    for (final m in lit.allMatches(f.readAsStringSync())) {
      out.add(_norm((m.group(1) ?? m.group(2) ?? '').replaceAll(r"\'", "'")));
    }
  }
  return out;
}

bool _found(String quote, Set<String> literals) {
  if (literals.contains(quote)) return true;
  final parts = quote.split('{}').map((p) => p.trim()).where((p) => p.length >= 4).toList();
  if (parts.isEmpty) return true;
  return parts.every((p) => literals.any((l) => l.contains(p)));
}

void main() {
  final quotes = (jsonDecode(File('test/features/owner_core/copy/doc_quotes.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();

  test('doc quotes file is present and covers sections 3 to 7', () {
    expect(quotes.length, greaterThan(100));
    expect(quotes.map((q) => (q['section'] as String).split('.').first).toSet(), containsAll(['3', '4', '5', '6', '7']));
  });

  test('every doc quote of the chosen section is a string in lib/', () {
    if (_section.isEmpty) return;
    final literals = _appLiterals();
    final missing = <String>[
      for (final q in quotes)
        if ((_section == 'all' || (q['section'] as String).startsWith(_section)) && !_found(_norm(q['text'] as String), literals))
          '${q['section']} line ${q['line']}: "${q['text']}"',
    ];
    expect(missing, isEmpty, reason: '${missing.length} doc strings not found in lib/');
  });
}
