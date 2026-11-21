import '../../design/design.dart';

abstract final class SeekerRailArt {
  static const String _dir = 'assets/images/design/travel3d/';
  static const String house = '${_dir}house_with_garden.png';
  static const String hotel = ListingArt.hotelBuilding;
  static const String car = '${_dir}automobile.png';

  static String forStay(String? typeName) {
    final t = (typeName ?? '').toLowerCase();
    if (t.contains('guest') || t.contains('hotel') || t.contains('resort') || t.contains('lodge')) return hotel;
    if (t.contains('hostel') || t.contains('camp') || t.contains('tent')) return ListingArt.camping;
    return house;
  }

  static String forVehicle(String? typeName) {
    final t = (typeName ?? '').toLowerCase();
    if (t.contains('suv') || t.contains('innova') || t.contains('jeep') || t.contains('muv')) return car;
    return ListingArt.forVehicle(typeName);
  }
}
