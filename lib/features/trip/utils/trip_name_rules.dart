import '../trip_strings_name.dart';

// Mirrors server TripNames.Clean (contract section 3).
class TripNameRules {
  static const int max = TripStringsName.maxLength;
  static final RegExp _control = RegExp(r'(?![\t\n\v\f\r])\p{Cc}', unicode: true);
  static final RegExp _spaces = RegExp(r'\s+');
  static final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{Nd}]', unicode: true);
  static final RegExp _link = RegExp(r'(https?://\S+)|(www\.\S+)', caseSensitive: false);
  static final RegExp _hidden = RegExp(r'[\p{Cc}\p{Co}\p{Zl}\p{Zp}]', unicode: true);
  static final RegExp _format = RegExp(r'\p{Cf}', unicode: true);
  static final RegExp _symbol = RegExp(r'\p{So}', unicode: true);
  static const int _zwj = 0x200D;

  static String clean(String raw) => raw.replaceAll(_control, '').replaceAll(_spaces, ' ').trim();

  static String? problem(String raw) {
    final s = clean(raw);
    if (s.isEmpty) return TripStringsName.empty;
    if (s.length > max || !_letterOrDigit.hasMatch(s) || _link.hasMatch(s) || _invisible(s)) return TripStringsName.invalid;
    return null;
  }

  static bool isValid(String raw) => problem(raw) == null;

  static bool _invisible(String s) {
    if (_hidden.hasMatch(s)) return true;
    for (final m in _format.allMatches(s)) {
      final i = m.start;
      if (s.codeUnitAt(i) != _zwj || i == 0 || i == s.length - 1) return true;
      if (!_emojiPart(s.codeUnitAt(i - 1)) || !_emojiPart(s.codeUnitAt(i + 1))) return true;
    }
    return false;
  }

  static bool _emojiPart(int unit) =>
      (unit >= 0xD800 && unit <= 0xDFFF) || unit == 0xFE0F || _symbol.hasMatch(String.fromCharCode(unit));

  static String suggest(String stateName, String cityName) {
    final s = clean(TripStringsName.suggestion(clean(stateName), clean(cityName)));
    return s.length <= max ? s : s.substring(0, max).trimRight();
  }
}
