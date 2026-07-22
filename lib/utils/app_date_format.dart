const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Single source of truth for the date/time strings this app hand-formats everywhere (no `intl`
/// dependency — matches the house convention). Every screen that shows a date/time should call
/// this rather than defining its own `_months`/`_formatDate` — several previously did, silently
/// drifting from each other; use this instead of copy-pasting a new one.
abstract final class AppDateFormat {
  /// "22 Jul 2026, 4:32 PM" — the full form, e.g. for a row with no surrounding date-group header.
  static String dateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}, ${time(dt)}';
  }

  /// "22 Jul 2026" — date only, no time, no "Today"/"Yesterday" relative label (unlike
  /// [dayGroupLabel]) — for a plain "submitted on"/"preferred date" field.
  static String date(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  /// "4:32 PM" only — for a row inside an already date-grouped section, where the date itself is
  /// already shown by the section's [dayGroupLabel].
  static String time(DateTime dt) {
    final local = dt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $ampm';
  }

  /// "Today" / "Yesterday" / else "22 Jul 2026" — section-header text for [groupByDay].
  static String dayGroupLabel(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return date(local);
  }
}

/// A single cell in a day-grouped, flat, index-addressable render list — either a section header or
/// one item. Flat (not nested groups) so a ListView.builder can index straight into it without every
/// caller re-flattening nested groups itself.
sealed class DayCell<T> {}

final class DayHeaderCell<T> extends DayCell<T> {
  final String label;
  DayHeaderCell(this.label);
}

final class DayItemCell<T> extends DayCell<T> {
  final T item;
  DayItemCell(this.item);
}

/// Buckets an already newest-first list into flat header+item cells, preserving order. Pure
/// rendering-time transform — never mutates or reorders [items] — so it's safe to call on every
/// build without touching how a controller stores/paginates its list.
List<DayCell<T>> groupByDay<T>(List<T> items, DateTime Function(T) dateOf) {
  final cells = <DayCell<T>>[];
  DateTime? lastDay;
  for (final item in items) {
    final local = dateOf(item).toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (lastDay == null || day != lastDay) {
      cells.add(DayHeaderCell(AppDateFormat.dayGroupLabel(local)));
      lastDay = day;
    }
    cells.add(DayItemCell(item));
  }
  return cells;
}
