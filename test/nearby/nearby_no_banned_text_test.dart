import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no banned text or hardcoded colours in the nearby layer', () {
    final files = Directory('lib/features/nearby').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    for (final f in files) {
      final s = f.readAsStringSync();
      expect(s.contains('Ask for a price'), false, reason: f.path);
      expect(s.contains('Color(0x'), false, reason: f.path);
      expect(RegExp(r'(?<![A-Za-z])Colors[.]').hasMatch(s), false, reason: f.path);
    }
  });
}
