import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_stay_base.dart';
import 'package:bakhli/features/trip/utils/trip_wizard_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _lodge = TripStayChoice(stayId: 's1', name: 'Pine Lodge', latitude: 29.39, longitude: 79.45);

TripPlan _plan(List<TripDay> days, {List<TripCityLeg>? legs}) => TripPlan(
      legs: legs ??
          const [TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29.3919, longitude: 79.4542)],
      days: days,
      settings: TripSettings(startDate: DateTime(2030, 11, 1), pickupTime: '08:30'),
    );

TripWizardInput _in(TripPlan p, [List<TripEnquiryModel> rows = const []]) =>
    TripWizardInput(plan: p, enquiries: rows, today: DateTime(2030));

void main() {
  group('point of a night', () {
    test('a same-as chain resolves to the first night with a pin', () {
      final p = _plan([
        const TripDay(day: 1, stay: _lodge),
        const TripDay(day: 2, stay: TripStayChoice(stayId: 's1', name: 'Pine Lodge', sameAsDay: 1)),
        const TripDay(day: 3),
      ]);
      expect(TripStayBase.startOf(p, 3), (lat: 29.39, lng: 79.45));
      expect(TripStayBase.startOf(p, 1), isNull);
    });

    test('a skipped night or a city change gives no start point', () {
      final p = _plan(
        [
          const TripDay(day: 1, leg: 1, stay: TripStayChoice.skippedNight()),
          const TripDay(day: 2, leg: 1, stay: _lodge),
          const TripDay(day: 3, leg: 2),
        ],
        legs: const [
          TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29.3919, longitude: 79.4542),
          TripCityLeg(index: 2, cityKey: 2, cityName: 'Almora', latitude: 29.5971, longitude: 79.6591),
        ],
      );
      expect(TripStayBase.startOf(p, 2), isNull);
      expect(TripStayBase.startOf(p, 3), isNull);
    });
  });

  group('start card of a day', () {
    test('a confirmed stay leaves at the pickup time', () {
      final p = _plan([const TripDay(day: 1, stay: _lodge), const TripDay(day: 2)]);
      final s = TripWizardRules.startOf(_in(p, [
        TripEnquiryModel(
          id: 'e1',
          listingId: 's1',
          listingName: 'Pine Lodge',
          checkIn: DateTime(2030, 11, 1),
          checkOut: DateTime(2030, 11, 2),
          status: TripEnquiryStatuses.confirmedByBoth,
        ),
      ]), 2);
      expect(s.kind, TripStartKind.stay);
      expect(s.line, TripWizardCopy.nightStay(1, '8:30 am'));
      expect(s.point, isNotNull);
    });

    test('an own stay with a pin starts there', () {
      final p = _plan([
        const TripDay(day: 1, stay: TripStayChoice(stayId: '', name: 'Uncle', isOwn: true, latitude: 29.4, longitude: 79.46)),
        const TripDay(day: 2),
      ]);
      final s = TripWizardRules.startOf(_in(p), 2);
      expect((s.kind, s.heading, s.line), (TripStartKind.ownStay, 'Uncle', TripWizardCopy.ownStayPinned));
      expect(s.point, (lat: 29.4, lng: 79.46));
    });

    test('a chosen stay nobody confirmed still shows, marked not confirmed', () {
      final p = _plan([const TripDay(day: 1, stay: _lodge), const TripDay(day: 2)]);
      final s = TripWizardRules.startOf(_in(p), 2);
      expect(s.kind, TripStartKind.stayUnconfirmed);
      expect(s.heading, TripWizardCopy.notConfirmedYet('Pine Lodge'));
    });

    test('the changed note is carried only when given', () {
      final s = TripWizardRules.startOf(_in(_plan([const TripDay(day: 1), const TripDay(day: 2)])), 2);
      expect(s.changedNote, isNull);
      expect(s.withChangedNote('Start changed').changedNote, 'Start changed');
    });
  });
}
