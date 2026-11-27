import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _templates = 'assets/quote_templates';
const _feature = 'lib/features/stay_owner/quotation';
const _docStrings = 'lib/features/stay_owner/strings/stay_quote_doc_strings.dart';

Iterable<File> _files(String dir, bool Function(String) keep) =>
    Directory(dir).listSync(recursive: true).whereType<File>().where((f) => keep(f.path.replaceAll('\\', '/')));

void main() {
  test('Q18 no app brand on documents: templates and document strings', () {
    final texts = [
      for (final f in _files(_templates, (p) => p.endsWith('.html') || p.endsWith('.css') || p.endsWith('.js'))) f.readAsStringSync(),
      File(_docStrings).readAsStringSync(),
    ];
    for (final t in texts) {
      expect(t.toLowerCase().contains('bakhli'), isFalse);
      expect(t.contains('PREVIEW'), isFalse);
    }
  });

  test('S8 / 9.3 the template script never builds markup from data', () {
    final js = File('$_templates/quote.js').readAsStringSync();
    for (final bad in ['innerHTML', 'outerHTML', 'insertAdjacentHTML', 'document.write', 'eval(', 'new Function', 'setAttribute(\'on', 'javascript:']) {
      expect(js.contains(bad), isFalse, reason: bad);
    }
    expect(js.contains('textContent'), isTrue);
  });

  test('9.3 every template has the CSP line, no inline script or style, only same-origin assets', () {
    for (final name in ['classic', 'band', 'modern']) {
      final html = File('$_templates/$name.html').readAsStringSync();
      expect(html, contains("default-src 'none'; img-src 'self'; style-src 'self'; font-src 'self'; script-src 'self'; base-uri 'none'; form-action 'none'"), reason: name);
      expect(html, contains('<meta name="viewport" content="width=794">'), reason: name);
      expect(RegExp(r'<script(?![^>]*src=)').hasMatch(html), isFalse, reason: name);
      expect(RegExp(r'<style').hasMatch(html), isFalse, reason: name);
      expect(RegExp(r'\sstyle="').hasMatch(html), isFalse, reason: name);
      expect(RegExp(r'\son[a-z]+=').hasMatch(html), isFalse, reason: name);
      expect(RegExp(r'(src|href)="(https?:|//|data:)').hasMatch(html), isFalse, reason: name);
    }
  });

  test('8.3 print CSS: no box-shadow, no @media print size changes, A4 page with no margin', () {
    final css = File('$_templates/quote.css').readAsStringSync();
    expect(css.contains('box-shadow'), isFalse);
    expect(css.contains('@media print'), isFalse);
    expect(css, contains('@page{size:210mm 297mm;margin:0}'));
    expect(css, contains('unicode-bidi:isolate'));
    expect(RegExp(r'url\((?!fonts/)').hasMatch(css), isFalse);
  });

  test('Q23 FONT RULE and DS scale in the feature folder; strings only in the strings files', () {
    for (final f in _files(_feature, (p) => p.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      final p = f.path;
      expect(src.contains('TextStyle('), isFalse, reason: p);
      expect(src.contains('fontFamily'), isFalse, reason: p);
      expect(RegExp(r'FontWeight\.').hasMatch(src), isFalse, reason: p);
      expect(RegExp(r'EdgeInsets\.(all|symmetric|only|fromLTRB)\(\s*\d').hasMatch(src), isFalse, reason: p);
      expect(RegExp(r'\b(print|debugPrint)\(').hasMatch(src), isFalse, reason: p);
      expect(src.contains('LogInterceptor'), isFalse, reason: p);
      expect(src.contains('share_plus'), isFalse, reason: p);
    }
  });

  test('B6 no typed plan numbers in the feature strings', () {
    final s = File('lib/features/stay_owner/strings/stay_quote_strings.dart').readAsStringSync();
    for (final n in [' 2 ', ' 20 ', ' 30 ']) {
      expect(s.contains("'$n") || s.contains("$n'") || s.contains('of$n'), isFalse, reason: n);
    }
  });
}
