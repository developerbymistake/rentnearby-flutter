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
}
