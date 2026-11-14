import '../../models/trip_plan_model.dart';
import '../../utils/trip_format.dart';

class TripGuideHeaderText {
  const TripGuideHeaderText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  static const String backHome = 'Back home';

  static String to(String city) => 'To $city';
  static String hop(String from, String to) => '$from to $to';
  static String more(String first, int n) => '$first +$n more';
  static String nights(int n) => '$n ${n == 1 ? 'night' : 'nights'}';
  static String days(int n) => '$n ${n == 1 ? 'day' : 'days'}';
  static String on(String date) => 'On $date';
  static String from(String city) => 'From $city';
  static String people(int n) => '$n ${n == 1 ? 'person' : 'people'}';

  static String _joined(Iterable<String?> parts) => parts.where((p) => p != null && p.isNotEmpty).join(' · ');

  static String? _date(TripPlan p, int day) {
    final d = p.settings.dateOf(day);
    return d == null ? null : TripFormat.dayMonth(d);
  }

  static String? _range(TripPlan p, int from, int to) {
    final a = p.settings.dateOf(from);
    final b = p.settings.dateOf(to);
    return a == null || b == null ? null : TripFormat.dayMonthRange(a, b);
  }

  static String? _people(TripPlan p) {
    final n = p.settings.peopleCount;
    return p.settings.hasPeople && n > 0 ? people(n) : null;
  }

  static List<String> _cities(TripPlan p) {
    final out = <String>[];
    for (final l in p.legs) {
      final n = l.cityName.trim();
      if (n.isNotEmpty && !out.contains(n)) out.add(n);
    }
    return out.isEmpty ? [p.cityName] : out;
  }

  static String _cityOf(TripPlan p, int leg) => (p.legAt(leg)?.cityName ?? p.cityName).trim();

  static TripGuideHeaderText of(TripPlan p, TripEasyRowKey row) {
    final ppl = _people(p);
    final k = row.legIndex ?? 1;
    final total = p.days.length;
    switch (row.kind) {
      case TripEasyRowKind.gettingThere:
        return TripGuideHeaderText(title: to(_cityOf(p, 1)), subtitle: _joined([_date(p, 1), ppl]));
      case TripEasyRowKind.stay:
        final n = p.legDayCount(k);
        final start = p.legStart(k);
        return TripGuideHeaderText(
          title: _cityOf(p, k),
          subtitle: _joined([n > 0 ? nights(n) : null, n > 0 ? _range(p, start, start + n) : null, ppl]),
        );
      case TripEasyRowKind.taxi:
        final cities = _cities(p);
        final title = cities.length <= 2 ? cities.join(' & ') : more(cities.first, cities.length - 1);
        return TripGuideHeaderText(
          title: title,
          subtitle: _joined([total > 0 ? days(total) : null, total > 0 ? _range(p, 1, total) : null, ppl]),
        );
      case TripEasyRowKind.between:
        final day = _date(p, p.legStart(k));
        return TripGuideHeaderText(
          title: hop(_cityOf(p, k - 1), _cityOf(p, k)),
          subtitle: _joined([day == null ? null : on(day), ppl]),
        );
      case TripEasyRowKind.comingBack:
        final last = p.legs.isEmpty ? p.cityName : p.legs.last.cityName.trim();
        return TripGuideHeaderText(
          title: backHome,
          subtitle: _joined([from(last), total > 0 ? _date(p, total) : null, ppl]),
        );
    }
  }
}
