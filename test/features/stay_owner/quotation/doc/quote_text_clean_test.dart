import 'package:bakhli/features/stay_owner/quotation/model/quote_text_clean.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bidi and control strip', () {
    test('line strips bidi/format characters and controls, collapses spaces', () {
      expect(QuoteTextClean.line('Ali‮fdp.exe', 80), 'Alifdp.exe');
      expect(QuoteTextClean.line('a​b﻿c⁦d⁩', 80), 'abcd');
      expect(QuoteTextClean.line('a\nb\tc', 80), 'a b c');
      expect(QuoteTextClean.line('  a    b  ', 80), 'a b');
      expect(QuoteTextClean.line(null, 80), '');
    });

    test('block keeps line breaks, trims empty edges', () {
      expect(QuoteTextClean.block('\n\nLine 1\r\nLine 2‮\n\n', 400), 'Line 1\nLine 2');
    });

    test('cap counts characters, not UTF-16 units', () {
      expect(QuoteTextClean.cap('😀😀😀', 2), '😀😀');
      expect(QuoteTextClean.line('x' * 100, 60).length, 60);
    });

    test('markup stays plain text (the template writes it with textContent)', () {
      expect(QuoteTextClean.line('<script>alert(1)</script>', 80), '<script>alert(1)</script>');
    });
  });
}
