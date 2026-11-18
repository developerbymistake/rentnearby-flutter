import '../trip_strings_name.dart';

class TripNameRules {
  static const int max = TripStringsName.maxLength;
  static final RegExp _control = RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]');
  static final RegExp _spaces = RegExp(r'\s+');

  static String clean(String raw) => raw.replaceAll(_control, '').replaceAll(_spaces, ' ').trim();

  static bool isValid(String raw) {
    final n = clean(raw).length;
    return n >= 1 && n <= max;
  }

  static String suggest(String stateName, String cityName) {
    final s = clean(TripStringsName.suggestion(clean(stateName), clean(cityName)));
    return s.length <= max ? s : s.substring(0, max).trimRight();
  }
}
