import 'package:bakhli/features/trip/controllers/trip_supply_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FX-24 the stay list asks for the nights on screen', () {
    test('no asked nights: the leg start and all its nights', () {
      expect(TripSupplyController.partyWindow(3, 4, const []), (firstDay: 3, nights: 4));
    });

    test('Ask last night: the first asked night and one night', () {
      expect(TripSupplyController.partyWindow(3, 4, const [6]), (firstDay: 6, nights: 1));
    });

    test('two asked nights out of order, duplicates and days outside the leg are ignored', () {
      expect(TripSupplyController.partyWindow(3, 4, const [5, 4, 4, 9, 1]), (firstDay: 4, nights: 2));
    });

    test('a leg of zero days still asks one night', () {
      expect(TripSupplyController.partyWindow(1, 0, const []), (firstDay: 1, nights: 1));
    });
  });
}
