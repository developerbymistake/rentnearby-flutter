import 'quote_text_clean.dart';

abstract final class QuoteFileName {
  static const int guestMax = 30;
  static const int max = 80;
  static final RegExp _keep = RegExp(r'[\p{L}\p{M}\p{N}]', unicode: true);

  static String guestPart(String guest) {
    final clean = QuoteTextClean.line(guest.replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001F\u007F]'), ''), 200);
    final b = StringBuffer();
    for (final r in clean.runes) {
      final ch = String.fromCharCode(r);
      b.write(_keep.hasMatch(ch) ? ch : '_');
    }
    var s = b.toString().replaceAll(RegExp('_+'), '_');
    s = s.replaceAll(RegExp(r'^[_.]+'), '').replaceAll(RegExp(r'_+$'), '');
    s = QuoteTextClean.cap(s, guestMax);
    return s.replaceAll(RegExp(r'_+$'), '');
  }

  // "Q-0042_Harshit_Mansi.pdf"; no guest part when nothing printable is left.
  static String of(String display, String guest) {
    final d = display.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
    final g = guestPart(guest);
    final base = g.isEmpty ? d : '${d}_$g';
    final room = max - '.pdf'.length;
    return '${QuoteTextClean.cap(base, room)}.pdf';
  }
}
