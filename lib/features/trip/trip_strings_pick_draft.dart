import 'trip_constants.dart';

class TripStringsPickDraft {
  static String title(int day) => 'Add places to Day $day';
  static String subtitle(String city, int count) => '$city · $count/${TripConstants.maxSpotsPerDay} places';
  static String summary(int day, int count) => 'Day $day · $count/${TripConstants.maxSpotsPerDay} places';
  static String add(int n) => 'Add $n ${n == 1 ? 'place' : 'places'}';
  static String dayFull(int day) => 'Day $day is full. Remove a place to add more.';
  static const String pickHint = 'Pick the places to add';

  static String categoryChip(String label) {
    final l = label.toLowerCase();
    if (l.endsWith('s') || l.endsWith('x') || l.endsWith('ch') || l.endsWith('sh')) return '${label}es';
    if (l.length > 1 && l.endsWith('y') && !'aeiou'.contains(l[l.length - 2])) return '${label.substring(0, label.length - 1)}ies';
    return '${label}s';
  }
}
