import '../../../owner_core/calendar/month_grid_data.dart';
import '../../../owner_core/calendar/models/calendar_models.dart';
import '../../../owner_core/json/owner_dates.dart';
import '../../../owner_core/money/money_note_math.dart';

class TaxiMonthSection {
  const TaxiMonthSection({required this.month, required this.rows});

  final DateTime month;
  final List<CalendarEntry> rows;
}

abstract final class TaxiSections {
  static List<TaxiMonthSection> byMonth(List<CalendarEntry> rows, {bool byLastDay = false}) {
    final out = <TaxiMonthSection>[];
    for (final e in rows) {
      final d = byLastDay ? (e.lastDay ?? e.dateFrom) : e.dateFrom;
      if (d == null) continue;
      final m = OwnerDates.firstOfMonth(d);
      if (out.isNotEmpty && out.last.month == m) {
        out.last.rows.add(e);
      } else {
        out.add(TaxiMonthSection(month: m, rows: [e]));
      }
    }
    return List.unmodifiable(out);
  }
}

class TaxiMonthView {
  const TaxiMonthView({
    this.month,
    this.monthRows = const [],
    this.ownActive = 0,
    this.appCount = 0,
    this.tripCount = 0,
    this.festival,
    this.balanceRows = const [],
    this.paidRows = const [],
    this.ownVisible = const [],
    this.hiddenCount = 0,
  });

  static const empty = TaxiMonthView();

  final DateTime? month;
  final List<CalendarEntry> monthRows;
  final int ownActive;
  final int appCount;
  final int tripCount;
  final FestivalRow? festival;
  final List<CalendarEntry> balanceRows;
  final List<CalendarEntry> paidRows;
  final List<CalendarEntry> ownVisible;
  final int hiddenCount;

  static bool inMonth(DateTime? d, DateTime month) => d != null && d.year == month.year && d.month == month.month;

  static int balanceOrder(CalendarEntry a, CalendarEntry b) {
    final c = (MoneyNoteMath.balance(b.money) ?? 0).compareTo(MoneyNoteMath.balance(a.money) ?? 0);
    return c != 0 ? c : b.id.compareTo(a.id);
  }

  static int dateOrder(CalendarEntry a, CalendarEntry b) {
    final fa = a.dateFrom;
    final fb = b.dateFrom;
    if (fa != null && fb != null && fa != fb) return fa.compareTo(fb);
    return MonthGridData.dayOrder(a, b);
  }

  factory TaxiMonthView.build(DateTime month, CalendarMonth data, {required DateTime today}) {
    final first = OwnerDates.firstOfMonth(month);
    final rows = data.entries.where((e) => inMonth(e.dateFrom, first)).toList()..sort(dateOrder);
    final live = rows.where((e) => !e.cancelled).toList();
    final own = data.entries.where((e) => e.isManual && !e.cancelled).toList()
      ..sort((a, b) {
        final la = a.lastDay;
        final lb = b.lastDay;
        if (la != null && lb != null && la != lb) return la.compareTo(lb);
        return a.id.compareTo(b.id);
      });
    final active = own.where((e) {
      final l = e.lastDay;
      return l != null && !l.isBefore(today);
    }).toList();
    FestivalRow? festival;
    final last = OwnerDates.lastOfMonth(first);
    for (final f in data.festivals) {
      final a = f.dateFrom;
      final b = f.dateTo;
      if (a != null && b != null && !b.isBefore(first) && !a.isAfter(last)) {
        festival = f;
        break;
      }
    }
    return TaxiMonthView(
      month: first,
      monthRows: List.unmodifiable(rows),
      ownActive: active.length,
      appCount: live.where((e) => e.isAuto).length,
      tripCount: live.length,
      festival: festival,
      balanceRows: List.unmodifiable(live.where((e) => (MoneyNoteMath.balance(e.money) ?? 0) > 0).toList()..sort(balanceOrder)),
      paidRows: List.unmodifiable(live.where((e) => e.finalAmount != null && MoneyNoteMath.balance(e.money) == 0).toList()..sort((a, b) => dateOrder(b, a))),
      ownVisible: List.unmodifiable(active),
      hiddenCount: data.hiddenCount,
    );
  }
}
