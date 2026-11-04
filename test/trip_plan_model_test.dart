import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('own choices JSON', () {
    test('own stay has no stayId key and round-trips name, phone, note', () {
      const own = TripStayChoice(stayId: '', name: 'Hotel Pine', isOwn: true, ownPhone: '9876543210', note: 'Late check-in');
      final json = own.toJson();
      expect(json.containsKey('stayId'), isFalse);
      expect(json['isOwn'], isTrue);
      final back = TripStayChoice.fromJson(json);
      expect(back.isOwn, isTrue);
      expect(back.stayId, '');
      expect(back.name, 'Hotel Pine');
      expect(back.ownPhone, '9876543210');
      expect(back.note, 'Late check-in');
    });

    test('own taxi has no taxiId key and keeps the per-day fare', () {
      final own = TripTaxiChoice.own(name: 'Ramesh', phone: '9876500000', note: 'White Dzire', fare: 1800);
      final json = own.toJson();
      expect(json.containsKey('taxiId'), isFalse);
      final back = TripTaxiChoice.fromJson(json);
      expect(back.isOwn, isTrue);
      expect(back.taxiId, '');
      expect(back.fare, 1800);
      expect(back.ownPhone, '9876500000');
      expect(back.note, 'White Dzire');
    });

    test('a listing choice still writes its id', () {
      const s = TripStayChoice(stayId: 'abc', name: 'Deodar');
      const t = TripTaxiChoice(taxiId: 'xyz', name: 'Mohan');
      expect(s.toJson()['stayId'], 'abc');
      expect(t.toJson()['taxiId'], 'xyz');
    });

    test('a full day with own stay and own taxi round-trips without any empty id', () {
      final day = TripDay(
        day: 2,
        stay: const TripStayChoice(stayId: '', name: 'Hotel Pine', isOwn: true, sameAsDay: 1),
        taxi: TripTaxiChoice.own(name: 'Ramesh'),
      );
      final json = day.toJson();
      final stay = json['stay'] as Map<String, dynamic>;
      final taxi = json['taxi'] as Map<String, dynamic>;
      expect(stay.containsKey('stayId'), isFalse);
      expect(taxi.containsKey('taxiId'), isFalse);
      expect(stay.values.contains(''), isFalse);
      expect(taxi.values.contains(''), isFalse);
      final back = TripDay.fromJson(json);
      expect(back.stay!.sameAsDay, 1);
      expect(back.taxi!.isOwn, isTrue);
    });
  });

  group('skipped night', () {
    test('no stay tonight writes skipped and no id', () {
      const s = TripStayChoice.skippedNight();
      final json = s.toJson();
      expect(json['skipped'], isTrue);
      expect(json.containsKey('stayId'), isFalse);
      final back = TripStayChoice.fromJson(json);
      expect(back.isSkipped, isTrue);
      expect(back.hasListing, isFalse);
    });
  });

  group('settings', () {
    test('check-out is the morning after the last day', () {
      final s = TripSettings(startDate: DateTime(2026, 11, 1));
      expect(s.dateOf(3), DateTime(2026, 11, 3));
      expect(s.checkOutDate(3), DateTime(2026, 11, 4));
      expect(s.checkOutDate(1), DateTime(2026, 11, 2));
    });

    test('maxDays round-trips and out-of-range values read as auto', () {
      const s = TripSettings(maxDays: 1);
      expect(TripSettings.fromJson(s.toJson()).maxDays, 1);
      expect(TripSettings.fromJson({'maxDays': 0}).maxDays, isNull);
      expect(TripSettings.fromJson({'maxDays': 15}).maxDays, isNull);
      expect(const TripSettings().toJson().containsKey('maxDays'), isFalse);
      expect(s.copyWith(clearMaxDays: true).maxDays, isNull);
    });
  });
}
