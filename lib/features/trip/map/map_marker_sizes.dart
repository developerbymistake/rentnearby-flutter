import 'package:bakhli/design/design.dart';

/// The one size source for every map marker: trip map, stay map, itinerary stops and the invited-person viewer.
abstract final class MapMarkerSizes {
  static const double base = 3;
  static const double growth = 1.15;
  static const double scale = base * growth;

  // dp at zoom 10 / 14 / 17 before scale and DS; the zoomed-in size is what the image is drawn at.
  static const double photoMin = 55;
  static const double photoMid = 75;
  static const double photoFull = 90;
  static const double badgeMin = 37.5;
  static const double badgeMid = 50;
  static const double badgeFull = 60;
  static const double dotMin = 22.5;
  static const double dotMid = 35;
  static const double dotFull = 42.5;
  static const double selDotMin = 32.5;
  static const double selDotMid = 45;
  static const double selDotFull = 53.75;
  static const double haloPhoto = 127;
  static const double haloDot = 76;
  static const double stopBadge = 54;
  static const double stopRing = 3;
  static const double viewerHaloGap = 7;
  static const double thumb = 96;

  static double dp(double n) => DS.s(n * scale);

  static int get thumbPx => (thumb * scale).round();
}
