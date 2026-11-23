import 'widgets/trip_spot_row.dart';

class TripMapDiscStrings {
  static String addToDay(int n) => 'Add to Day $n';
  static const String details = TripSpotRow.details;
  static String inDay(int n) => 'In Day $n';
  static const String removeFromDay = 'Remove from day';
  static const String loadingPlaces = 'Loading places';
  static String scaleMeters(int m) => '$m m';
  static String scaleKm(num km) => '${km % 1 == 0 ? km.toInt() : km} km';

  static const String semShowPlaces = 'Show places';
  static const String semHidePlaces = 'Hide places';
  static const String semZoomIn = 'Zoom in';
  static const String semZoomOut = 'Zoom out';
  static const String semLocate = 'My location';
  static const String semClose = 'Close';
}
