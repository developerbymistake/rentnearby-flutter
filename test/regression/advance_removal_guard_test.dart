import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _allowedFiles = [
  'lib/features/buddy/',
  'lib/screens/terms_of_service_screen.dart',
  // The private money note's server field and doc 6.2 line only (owner roles, REVIEW point 1); no payment flow.
  'lib/features/owner_core/money/money_wire.dart',
  // The stay quotation document may record an advance received (a printed line, approved mock Q-frames); no in-app payment flow.
  'lib/features/stay_owner/quotation/',
  'lib/features/stay_owner/strings/stay_quote_strings.dart',
];

final _word = RegExp(r'advance|proofsent|proof sent|holduntil|holdexpired', caseSensitive: false);
final _advanced = RegExp(r'advanced', caseSensitive: false);

bool _allowedLine(String line) => _word.allMatches(line.replaceAll(_advanced, '')).isEmpty;

Iterable<File> _dart() =>
    Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

String _path(File f) => f.path.replaceAll(Platform.pathSeparator, '/');

void main() {
  test('lib has no advance, proof or hold flow left', () {
    final hits = <String>[];
    for (final f in _dart()) {
      final path = _path(f);
      if (_allowedFiles.any(path.startsWith)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_word.hasMatch(lines[i]) && !_allowedLine(lines[i])) hits.add('$path:${i + 1}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('no advance route or advance-details path in lib', () {
    final hits = <String>[];
    for (final f in _dart()) {
      final text = f.readAsStringSync();
      if (text.contains('/advance/') || text.contains('advance-details')) hits.add(_path(f));
    }
    expect(hits, isEmpty);
  });

  test('stay share details use the new route and the old files are gone', () {
    expect(File('lib/features/stay/setup/stay_repository.dart').readAsStringSync(), contains("'/stays/me/share-details'"));
    expect(File('lib/features/stay/setup/stay_advance_details_screen.dart').existsSync(), isFalse);
    expect(File('lib/widgets/trip_advance_cards.dart').existsSync(), isFalse);
    expect(File('lib/features/stay/enquiries/trip_ask_advance_sheet.dart').existsSync(), isFalse);
  });
}
