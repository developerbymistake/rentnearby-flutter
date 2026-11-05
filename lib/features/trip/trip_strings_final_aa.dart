import '../../models/browse_item.dart';

class TripStringsFinalAa {
  static String kmAway(double km) => '${km < 10 ? km.toStringAsFixed(1) : km.round()} km away';
  static String coverCars(int n) => 'All the way · $n cars';
  static String coverCarsAbout(int n, int total) => 'All the way · $n cars · about ${BrowseItem.inr(total)}';
  static String withCars(List<String> names) => 'With ${names.join(', ')}';
  static String coverReason(int n, int total) => '$n cars, all the way, about ${BrowseItem.inr(total)}';
}
