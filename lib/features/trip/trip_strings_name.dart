class TripStringsName {
  static const int maxLength = 60;
  static const String label = 'Trip name';
  static const String hint = 'Trip name';
  static const String empty = 'Add a name to continue';
  static const String invalid = 'Use letters or numbers. No links.';

  static String counter(int n) => '$n/$maxLength';
}
