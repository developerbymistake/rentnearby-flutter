import 'social_models.dart';
import 'social_strings.dart';

abstract final class SocialFormats {
  static const List<String> monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const int moreDays = 11;
  static const int moreSeats = 11;

  static String monthName(int month) => month >= 1 && month <= 12 ? monthNames[month - 1] : '';

  static String when(TripWhen w) {
    if (w.kind == TripWhen.monthKind) return monthName(w.month % 100);
    final n = w.months < 1 ? 1 : w.months;
    return n == 1 ? 'Within a month' : 'Within $n months';
  }

  static String days(int d) {
    if (d >= moreDays) return '10+ days';
    return d == 1 ? '1 day' : '$d days';
  }

  static String whoCanJoin(String g) => switch (g) {
        'M' => SocialStrings.menOnly,
        'F' => SocialStrings.womenOnly,
        _ => 'Anyone',
      };

  static String seatsLeft(int left, int seats) {
    if (left <= 0) return 'Full';
    if (seats >= moreSeats && left >= 4) return '4+ seats left';
    return left == 1 ? '1 seat left' : '$left seats left';
  }

  static String cities(List<String> names) {
    final n = [for (final c in names) if (c.trim().isNotEmpty) c.trim()];
    if (n.isEmpty) return '';
    if (n.length == 1) return n.first;
    return '${n.sublist(0, n.length - 1).join(', ')} and ${n.last}';
  }

  static String maskPhone(String phone) {
    final p = phone.trim();
    if (p.length <= 4) return p;
    return '${p.substring(0, 2)}${'x' * (p.length - 4)}${p.substring(p.length - 2)}';
  }

  static String shortName(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last.substring(0, 1).toUpperCase()}.';
  }
}
