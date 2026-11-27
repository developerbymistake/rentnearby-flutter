abstract final class QuoteTextClean {
  static final RegExp _bidi = RegExp('[​-‏‪-‮⁦-⁩﻿]');
  static final RegExp _controlKeepNewline = RegExp('[\u0000-\u0009\u000B-\u001F\u007F-\u009F]');
  static final RegExp _control = RegExp('[\u0000-\u001F\u007F-\u009F]');

  static String line(String? v, int max) {
    final s = (v ?? '').replaceAll(_bidi, '').replaceAll(_control, ' ').replaceAll(RegExp(r' {2,}'), ' ').trim();
    return cap(s, max);
  }

  static String block(String? v, int max) {
    final s = (v ?? '').replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll(_bidi, '').replaceAll(_controlKeepNewline, ' ');
    final lines = s.split('\n').map((l) => l.replaceAll(RegExp(r' {2,}'), ' ').trim()).toList();
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    while (lines.isNotEmpty && lines.first.isEmpty) {
      lines.removeAt(0);
    }
    return cap(lines.join('\n'), max);
  }

  static String cap(String s, int max) {
    if (s.runes.length <= max) return s;
    return String.fromCharCodes(s.runes.take(max)).trimRight();
  }

  static bool hasBidi(String s) => _bidi.hasMatch(s);
}
