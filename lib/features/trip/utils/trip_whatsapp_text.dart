import 'trip_format.dart';

class TripWhatsAppText {
  static String build({
    required String driverName,
    required String cityName,
    required int day,
    required List<String> stops,
    required double km,
    required int minutes,
  }) {
    final stopLine = [for (var i = 0; i < stops.length; i++) '${i + 1}. ${stops[i]}'].join(' ');
    return 'Hi $driverName, I need a taxi for Day $day of my $cityName trip.\n'
        'Stops: $stopLine\n'
        'About ${TripFormat.number(km)} km, ${TripFormat.duration(minutes)}.\n'
        'Is your taxi available?';
  }

  static String update({
    required String driverName,
    required String cityName,
    required int day,
    DateTime? date,
    required String start,
    required List<String> stops,
  }) {
    final when = date == null ? 'Day $day' : 'Day $day (${TripFormat.dayMonth(date)})';
    final stopLine = stops.isEmpty
        ? 'No fixed stops yet'
        : [for (var i = 0; i < stops.length; i++) '${i + 1}. ${stops[i]}'].join(' ');
    return 'Hi $driverName, my plan for $when of my $cityName trip changed.\n'
        '$start\n'
        'Stops: $stopLine\n'
        'Please note the change.';
  }
}
