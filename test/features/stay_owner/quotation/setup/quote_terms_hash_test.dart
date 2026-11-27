import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/stay_owner/strings/stay_quote_terms_strings.dart';
import 'package:crypto/crypto.dart'; // ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';

const _dir = 'test/features/stay_owner/quotation/setup/fixtures';

String _lf(String s) => const LineSplitter().convert(s).join(String.fromCharCode(10));

void main() {
  test('terms text hashes to the server constant of its version (shared fixture)', () {
    expect(QuoteTermsStrings.version, 1);
    final pinned = File('$_dir/quote_terms_v1.sha256').readAsStringSync().trim();
    expect(sha256.convert(utf8.encode(QuoteTermsStrings.text)).toString(), pinned);
  });

  test('terms text is the fixture text, line for line', () {
    expect(QuoteTermsStrings.text, _lf(File('$_dir/quote_terms_v1.txt').readAsStringSync()));
    expect(QuoteTermsStrings.lines, hasLength(5));
  });

  test('terms cover logo, signature and tax numbers (S10)', () {
    expect(QuoteTermsStrings.text, contains('logo, signature, stamp and tax numbers'));
  });
}
