import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/features/trip/trip_strings_mcc_a3.dart';

void main() {
  test('legLine ranges', () {
    expect(TripStringsMccA3.legLine('Badrinath', 2, 4), 'Badrinath · Days 2-4');
    expect(TripStringsMccA3.legLine('Badrinath', 3, 3), 'Badrinath · Day 3');
    expect(TripStringsMccA3.legLine('', 1, 2), 'Days 1-2');
  });

  test('oldDatesLine with and without price', () {
    expect(TripStringsMccA3.oldDatesLine('01 – 02 Nov'), 'Old dates · 01 – 02 Nov');
    expect(TripStringsMccA3.oldDatesLine('01 – 02 Nov', price: 'Rs 3,800'), 'Old dates · 01 – 02 Nov · Rs 3,800');
  });
}
