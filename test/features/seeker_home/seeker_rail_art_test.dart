import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/seeker_home/seeker_rail_art.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('o_sk_1 stay art follows the stay type as the frame draws it', () {
    expect(SeekerRailArt.forStay('Homestay'), SeekerRailArt.house);
    expect(SeekerRailArt.forStay('Cottage'), SeekerRailArt.house);
    expect(SeekerRailArt.forStay('Guest House'), SeekerRailArt.hotel);
    expect(SeekerRailArt.forStay('Hotel'), SeekerRailArt.hotel);
    expect(SeekerRailArt.forStay('Hostel'), ListingArt.camping);
    expect(SeekerRailArt.forStay(null), SeekerRailArt.house);
    expect(SeekerRailArt.forStay(''), SeekerRailArt.house);
  });

  test('o_sk_1 taxi art follows the vehicle type as the frame draws it', () {
    expect(SeekerRailArt.forVehicle('Sedan'), ListingArt.taxi);
    expect(SeekerRailArt.forVehicle('Tempo Traveller'), ListingArt.bus);
    expect(SeekerRailArt.forVehicle('SUV'), SeekerRailArt.car);
    expect(SeekerRailArt.forVehicle(null), ListingArt.taxi);
  });
}
