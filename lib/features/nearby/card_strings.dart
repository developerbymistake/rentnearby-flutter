import 'models/nearby_models.dart';
import 'nearby_strings.dart';

abstract final class CardStrings {
  static const String forStay = 'FOR STAY';
  static const String taxi = 'TAXI';
  static const String from = 'From';
  static const String perNight = '/night';
  static const String featured = 'Featured';
  static const String call = 'Call';
  static const String whatsApp = 'WhatsApp';
  static const String onRequest = 'On request';
  static const String askForFare = 'Ask for fare';

  static String percentOff(int p) => '$p% off';

  static String inPlace(String c) => 'In $c';

  static String placeAbout(String? c, double km) => (c == null || c.trim().isEmpty)
      ? 'About ${NearbyStrings.kmText(km)} km'
      : '${c.trim()}. About ${NearbyStrings.kmText(km)} km';

  static String addressFor(NearbyDistance d) =>
      d.label == NearbyLabel.inCity && (d.city ?? '').trim().isNotEmpty ? inPlace(d.city!.trim()) : placeAbout(d.city, d.km);
}
