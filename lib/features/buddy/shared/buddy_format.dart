import '../../../utils/money_format.dart';
import 'models/person_models.dart';

abstract final class BuddyFormat {
  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const String deletedName = 'Deleted user';

  static String rupees(int amount) => Money.exact(amount);

  static String last4(String? username) {
    final u = username ?? '';
    final digits = u.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
  }

  static String moneyName(MoneyPerson p) {
    if (p.isDeleted) return deletedName;
    return p.last4.isEmpty ? p.name : '${p.name} ${p.last4}';
  }

  static String month(DateTime d) => _months[d.month - 1];

  static String dayMonth(DateTime d) => '${d.day} ${month(d)}';

  static String dateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    if (start == null) return dayMonth(end!);
    if (end == null) return dayMonth(start);
    if (start.year == end.year && start.month == end.month) {
      return start.day == end.day ? dayMonth(start) : '${start.day} – ${dayMonth(end)}';
    }
    return '${dayMonth(start)} – ${dayMonth(end)}';
  }

  static String dayHeader(int day, DateTime? date) =>
      date == null ? 'DAY $day' : 'DAY $day · ${date.day} ${month(date).toUpperCase()}';

  static String weekdayDate(DateTime d) => '${_days[d.weekday - 1]} ${dayMonth(d)}';

  static (String, String) agoParts(DateTime? time, {DateTime? now}) {
    if (time == null) return ('', '');
    final diff = (now ?? DateTime.now()).toUtc().difference(time.toUtc());
    if (diff.inMinutes < 1) return ('', 'Just now');
    if (diff.inMinutes < 60) return ('${diff.inMinutes}', 'min ago');
    if (diff.inHours < 24) return ('${diff.inHours}', 'h ago');
    if (diff.inDays < 7) return ('${diff.inDays}', diff.inDays == 1 ? 'day ago' : 'days ago');
    final weeks = diff.inDays ~/ 7;
    if (weeks < 5) return ('$weeks', weeks == 1 ? 'week ago' : 'weeks ago');
    final months = diff.inDays ~/ 30;
    if (months < 12) return ('$months', months == 1 ? 'month ago' : 'months ago');
    final years = diff.inDays ~/ 365;
    return ('$years', years == 1 ? 'year ago' : 'years ago');
  }

  static String ago(DateTime? time, {DateTime? now}) {
    final (n, unit) = agoParts(time, now: now);
    return n.isEmpty ? unit : '$n $unit';
  }

  static String time12(String? hhmm) {
    if (hhmm == null) return '';
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hhmm;
    final suffix = h < 12 ? 'am' : 'pm';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:${m.toString().padLeft(2, '0')} $suffix';
  }

  static String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

  static String expiresIn(DateTime? at, {DateTime? now}) {
    if (at == null) return '';
    final local = at.toLocal();
    final today = now ?? DateTime.now();
    final a = DateTime(local.year, local.month, local.day);
    final b = DateTime(today.year, today.month, today.day);
    final days = a.difference(b).inDays;
    if (days <= 0) return 'Expires today';
    return 'Expires in ${plural(days, 'day', 'days')}';
  }
}
