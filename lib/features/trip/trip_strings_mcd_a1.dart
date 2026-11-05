class TripStringsMcdA1 {
  static String travelCount(int settled, int total) => 'Travel $settled of $total';

  static String legSection(String city, String? dates) {
    final head = city.toUpperCase();
    return dates == null || dates.isEmpty ? head : '$head · $dates';
  }

  static String _cars(int n) => n == 1 ? '1 car' : '$n cars';

  static String travelHeading(String to, String? date, int cars) =>
      ['→ $to', if (cars > 0) _cars(cars), if (date != null && date.isNotEmpty) date].join(' · ');

  static String travelHeadingOwn(String to, String? date) =>
      ['→ $to', ownTravel, if (date != null && date.isNotEmpty) date].join(' · ');

  static String carLine(int i, String driver, String? fare, String status) =>
      ['Car $i $driver'.trim(), ?fare, status].where((e) => e.isNotEmpty).join(' · ');

  static String carsState(int n, String label) => '${_cars(n)} · $label';

  static String ownTravelLine(String? how, String? leavesAt, String? name) =>
      [ownTravel, ?how, ?leavesAt, ?name].where((e) => e.isNotEmpty).join(' · ');

  static const String ownTravel = 'Own travel';
}
