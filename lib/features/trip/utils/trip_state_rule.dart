import '../models/trip_city_model.dart';

class TripStateRule {
  static String _k(String s) => s.trim().toLowerCase();

  static List<String> statesOf(Iterable<int> legKeys, Iterable<TripCityModel> catalog) {
    final byKey = {for (final c in catalog) c.cityKey: c.stateName.trim()};
    final seen = <String>{};
    final out = <String>[];
    for (final k in legKeys) {
      final s = byKey[k] ?? '';
      if (s.isNotEmpty && seen.add(_k(s))) out.add(s);
    }
    return out;
  }

  static bool allows(List<String> states, TripCityModel city) =>
      states.isEmpty || states.any((s) => _k(s) == _k(city.stateName));

  static List<TripCityModel> filter(List<TripCityModel> items, List<String> states) =>
      states.isEmpty ? items : [for (final c in items) if (allows(states, c)) c];
}
