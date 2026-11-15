import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baselinePath = 'test/lint/raw_layout_baseline.json';

const _skip = [
  'lib/design/tokens/design_scale.dart',
  'lib/design/extra/template_nav.dart',
  'lib/design/tokens/bar_metrics.dart',
  'lib/design/template/',
];

final _patterns = <String, RegExp>{
  'fontSize': RegExp(r'fontSize:\s*\d'),
  'sizedBox': RegExp(r'SizedBox\([^()]*?(?:height|width):\s*\d'),
  'edgeInsets': RegExp(r'EdgeInsets\.(?:all|symmetric|only|fromLTRB)\([^()]*\d'),
  'borderRadius': RegExp(r'BorderRadius\.circular\(\s*\d'),
  'iconSize': RegExp(r'Icon\([^()]*?size:\s*\d'),
};

Map<String, int> _scan() {
  final out = <String, int>{};
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
    final path = f.path.replaceAll(Platform.pathSeparator, '/');
    if (!path.endsWith('.dart') || _skip.any(path.contains)) continue;
    final text = f.readAsStringSync();
    var n = 0;
    for (final re in _patterns.values) {
      n += re.allMatches(text).length;
    }
    if (n > 0) out[path] = n;
  }
  return out;
}

void main() {
  test('no new raw layout literals: use DS.s / DS.f / DS.gv / DS.gh / Gap', () {
    final current = _scan();
    if (const String.fromEnvironment('UPDATE_LAYOUT_BASELINE') == '1') {
      final sorted = Map.fromEntries(current.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
      File(_baselinePath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(sorted));
      return;
    }
    final baseline = (jsonDecode(File(_baselinePath).readAsStringSync()) as Map<String, dynamic>).cast<String, int>();
    final worse = <String>[];
    current.forEach((file, n) {
      final allowed = baseline[file] ?? 0;
      if (n > allowed) worse.add('$file: $n raw layout literals, baseline $allowed');
    });
    expect(worse, isEmpty, reason: 'Wrap new layout numbers with the DS scale API (see CONTRACT_SCALE.md).');
  });
}
