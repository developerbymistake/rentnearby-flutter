import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripOwnPhone.normalise', () {
    test('keeps a valid 10 digit number', () {
      expect(TripOwnPhone.normalise('9876543210'), '9876543210');
    });

    test('strips +91, 91, 0 and separators', () {
      expect(TripOwnPhone.normalise('+91 98765 43210'), '9876543210');
      expect(TripOwnPhone.normalise('919876543210'), '9876543210');
      expect(TripOwnPhone.normalise('09876543210'), '9876543210');
      expect(TripOwnPhone.normalise('98765-43210'), '9876543210');
    });

    test('drops anything else', () {
      expect(TripOwnPhone.normalise('12345'), isNull);
      expect(TripOwnPhone.normalise('5876543210'), isNull);
      expect(TripOwnPhone.normalise('  '), isNull);
      expect(TripOwnPhone.normalise(null), isNull);
    });
  });

  test('flight is a known travel mode', () {
    expect(TripTravelHow.parse('flight'), TripTravelHow.flight);
    expect(TripTravelHow.flight.wire, 'flight');
  });
}
