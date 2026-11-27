import 'package:bakhli/features/stay_owner/quotation/model/quote_file_name.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_text_clean.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Q12 file name', () {
    test('mock form: <number>_<guest>.pdf', () {
      expect(QuoteFileName.of('Q-0042', 'Harshit & Mansi'), 'Q-0042_Harshit_Mansi.pdf');
      expect(QuoteFileName.of('PI-0007', 'Neha Joshi'), 'PI-0007_Neha_Joshi.pdf');
    });

    test('empty guest gives only the number', () {
      expect(QuoteFileName.of('Q-0042', ''), 'Q-0042.pdf');
      expect(QuoteFileName.of('Q-0042', '  /:*?  '), 'Q-0042.pdf');
    });

    test('letters of any script are kept', () {
      expect(QuoteFileName.of('Q-0001', 'मीना बिष्ट'), 'Q-0001_मीना_बिष्ट.pdf');
    });

    test('forbidden, control, bidi characters and leading dots are removed', () {
      final name = QuoteFileName.of('Q-0001', '..Ali‮fdp.exe<>|"\\/:*?\u0007');
      expect(name.startsWith('Q-0001_Ali'), isTrue);
      expect(QuoteTextClean.hasBidi(name), isFalse);
      for (final c in ['\\', '/', ':', '*', '?', '"', '<', '>', '|', '\u0007']) {
        expect(name.contains(c), isFalse, reason: c);
      }
      expect(name.endsWith('.pdf'), isTrue);
      expect(name.contains('__'), isFalse);
    });

    test('guest part max 30, whole name max 80', () {
      final g = QuoteFileName.guestPart('A' * 200);
      expect(g.length, QuoteFileName.guestMax);
      expect(QuoteFileName.of('Q-0042', 'B' * 500).length, lessThanOrEqualTo(QuoteFileName.max));
    });
  });
}
