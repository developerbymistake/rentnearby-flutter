class TripStringsName {
  static const int maxLength = 60;
  static const String title = 'Name your trip';
  static const String label = 'Trip name';
  static const String hint = 'Trip name';
  static const String empty = 'Add a name to continue';
  static const String next = 'Continue';
  static const List<String> _hillStates = ['uttarakhand', 'himachal pradesh'];

  static String counter(int n) => '$n/$maxLength';

  static String suggestion(String stateName, String cityName) {
    final state = stateName.trim();
    final city = cityName.trim();
    if (state.isEmpty) return '$city Trip';
    final hills = _hillStates.contains(state.toLowerCase());
    return hills ? '$state Hills Trip' : '$state Trip';
  }
}
