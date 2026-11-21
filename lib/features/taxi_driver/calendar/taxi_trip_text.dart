import '../../../utils/money_format.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/money/money_note_math.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../strings/taxi_calendar_strings.dart';

abstract final class TaxiTripText {
  static String? _clean(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  static String title(CalendarEntry e) {
    if (e.isManual) return e.label;
    final from = _clean(e.fromPlace);
    final to = _clean(e.toPlace);
    if (from != null && to != null && from != to) return TaxiCalendarStrings.routeTo(from, to);
    if (from != null) return TaxiCalendarStrings.pickupOf(from);
    return traveller(e);
  }

  static String traveller(CalendarEntry e) => e.travellerRemoved ? TaxiCalendarStrings.travellerRemoved : e.label;

  static ({int hour, int minute})? _time(CalendarEntry e) => e.isAuto ? null : OwnerDates.time(e.timeOfDay);

  static String? time(CalendarEntry e) {
    final t = _time(e);
    return t == null ? null : TaxiCalendarStrings.timeAm(t.hour, t.minute);
  }

  static String route(CalendarEntry e) {
    final from = _clean(e.fromPlace);
    final to = _clean(e.toPlace);
    if (from != null && to != null) return TaxiCalendarStrings.routeTo(from, to);
    if (from != null) return from;
    if (to != null) return TaxiCalendarStrings.toPlaceLower(to);
    return '';
  }

  static int days(CalendarEntry e) {
    final a = e.dateFrom;
    final b = e.lastDay;
    if (a == null || b == null || !b.isAfter(a)) return 1;
    return OwnerDates.daysBetween(a, b) + 1;
  }

  static String dateSpan(CalendarEntry e) {
    final a = e.dateFrom;
    final b = e.lastDay;
    if (a == null) return '';
    if (b == null || days(e) == 1) return OwnerSharedStrings.dayMonth(a);
    return TaxiCalendarStrings.dateRange(a, b);
  }

  static String _amount(CalendarEntry e) => e.finalAmount == null ? '' : Money.exact(e.finalAmount!);

  static String upcomingLine(CalendarEntry e) {
    if (e.isAuto) {
      final a = e.dateFrom;
      if (a == null) return traveller(e);
      if (days(e) == 1) return TaxiCalendarStrings.joinDot(['${OwnerSharedStrings.dayMonth(a)}, ${TaxiCalendarStrings.allDay}', traveller(e)]);
      return TaxiCalendarStrings.joinDot([dateSpan(e), TaxiCalendarStrings.days(days(e)), traveller(e)]);
    }
    return TaxiCalendarStrings.joinDot([time(e) ?? '', route(e)]);
  }

  static String dayLine(CalendarEntry e) {
    if (e.isAuto) {
      final to = _clean(e.toPlace);
      return TaxiCalendarStrings.joinDot([to == null ? '' : TaxiCalendarStrings.toPlace(to), traveller(e)]);
    }
    return TaxiCalendarStrings.joinDot([route(e), _amount(e)]);
  }

  static String monthLine(CalendarEntry e) {
    if (e.isAuto) return TaxiCalendarStrings.joinDot([TaxiCalendarStrings.allDayCap, _amount(e)]);
    return TaxiCalendarStrings.joinDot([time(e) ?? route(e), _amount(e)]);
  }

  static String pastLine(CalendarEntry e) {
    if (e.isAuto) return TaxiCalendarStrings.joinDot([TaxiCalendarStrings.allDayCap, traveller(e)]);
    return TaxiCalendarStrings.joinDot([route(e), time(e) ?? '']);
  }

  static String collectLine(CalendarEntry e) {
    final f = e.finalAmount;
    String place;
    if (e.isAuto) {
      final to = _clean(e.toPlace);
      place = to == null ? traveller(e) : TaxiCalendarStrings.toPlace(to);
    } else {
      place = route(e);
    }
    return f == null ? place : TaxiCalendarStrings.ofFinal(place, f);
  }

  static String paidLine(CalendarEntry e) => e.isAuto ? traveller(e) : route(e);

  static String summaryLine(CalendarEntry e) {
    final a = e.dateFrom;
    return TaxiCalendarStrings.joinDot([a == null ? '' : OwnerSharedStrings.dayMonth(a), badge(e)]);
  }

  static String badge(CalendarEntry e) => e.isAuto ? OwnerSharedStrings.fromApp : OwnerSharedStrings.addedByYou;

  static ({String top, String bottom}) dateTile(CalendarEntry e) {
    final a = e.dateFrom;
    if (a == null) return (top: TaxiCalendarStrings.dash, bottom: '');
    return (top: '${a.day}', bottom: TaxiCalendarStrings.tileMonth(a));
  }

  static ({String top, String bottom}) timeTile(CalendarEntry e) {
    final t = _time(e);
    if (t == null) return (top: TaxiCalendarStrings.tileAll, bottom: TaxiCalendarStrings.tileDay);
    return (top: TaxiCalendarStrings.tileTime(t.hour, t.minute), bottom: TaxiCalendarStrings.tileAmPm(t.hour));
  }

  static MoneyChip chip(CalendarEntry e) {
    if (e.cancelled) return MoneyNoteMath.received(e.money) > 0 ? MoneyChip.received : MoneyChip.none;
    return MoneyNoteMath.chip(e.money);
  }

  static int chipAmount(CalendarEntry e) {
    if (e.cancelled) return MoneyNoteMath.received(e.money);
    return MoneyNoteMath.chipAmount(e.money);
  }

  static String semantics(CalendarEntry e) => [title(e), dateSpan(e), badge(e), if (e.cancelled) OwnerSharedStrings.cancelled].where((s) => s.isNotEmpty).join(', ');
}
