import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_result_model.dart';
import 'package:get/get.dart';
import 'package:flutter_test/flutter_test.dart';

TripSpotRef _spot(String id) =>
    TripSpotRef(id: id, name: id, latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60);

TripPlanDay _resultDay(int day, List<String> ids) => TripPlanDay(
      day: day,
      spotIds: ids,
      visitMinutes: 60,
      driveMinutes: 0,
      totalMinutes: 60,
      km: 0,
      overLimit: false,
      isEstimate: false,
      legs: const [],
    );

TripModel _trip(TripPlan plan, {String status = TripStatuses.planned}) => TripModel(
      id: 't1',
      title: 'Nainital trip',
      status: status,
      cityKey: 1,
      cityName: 'Nainital',
      cityLatitude: 29.4,
      cityLongitude: 79.4,
      dayCount: plan.days.length,
      spotCount: plan.spotCount,
      plan: plan,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

const _lastStay = TripStayChoice(stayId: 's9', name: 'Deodar Homestay', pricePerNight: 1900);

TripPlan _plan({DateTime? start}) => TripPlan(
      cityKey: 1,
      cityName: 'Nainital',
      settings: TripSettings(startDate: start),
      days: [
        TripDay(day: 1, spots: [_spot('a')]),
        TripDay(
          day: 2,
          spots: [_spot('b')],
          stay: _lastStay,
          stayShortlist: const [TripStayShortlistItem(stayId: 's8', name: 'Pine Lodge')],
        ),
      ],
    );

void main() {
  group('night rule: the last day keeps its night', () {
    test('auto plan keeps the last-day stay and shortlist (#1, #34)', () {
      final c = TripPlanController();
      final withDays = TripPlanResult(
        days: [_resultDay(1, const ['a']), _resultDay(2, const ['b'])],
        warnings: const [],
        osrmAvailable: true,
        dayLimitMinutes: 450,
      );
      final out = c.applyAutoForTest(_plan(), withDays);
      expect(out.days.last.stay?.stayId, 's9');
      expect(out.days.last.stayShortlist.single.stayId, 's8');
    });

    test('renumber keeps the last-day stay (#1, #34)', () {
      final c = TripPlanController();
      final out = c.renumberForTest(_plan().days);
      expect(out.length, 2);
      expect(out.last.stay?.stayId, 's9');
      expect(out.last.stayShortlist, isNotEmpty);
    });

    test('a one-day trip keeps its only night', () {
      final c = TripPlanController();
      final out = c.renumberForTest([TripDay(day: 1, spots: [_spot('a')], stay: _lastStay)]);
      expect(out.single.stay?.stayId, 's9');
    });

    test('a plan read from JSON keeps the last-day stay', () {
      final t = TripModel.fromJson({
        'id': 't1',
        'cityKey': 1,
        'plan': _plan().toJson(),
      });
      expect(t.plan.days.last.stay?.stayId, 's9');
    });

    test('keepEmptyDays keeps a trailing rest day with its booking', () {
      final c = TripPlanController();
      final days = [
        TripDay(day: 1, spots: [_spot('a'), _spot('b')]),
        const TripDay(day: 2, stay: _lastStay),
      ];
      expect(c.renumberForTest(days).length, 1);
      expect(c.renumberForTest(days, keepEmptyDays: true).length, 2);
    });
  });

  group('outside dates', () {
    TripPlanController withEnquiries(List<TripEnquiryModel> rows) {
      final c = TripPlanController();
      c.plan.value = _plan(start: DateTime(2030, 11, 1));
      c.enquiryList.assignAll(rows);
      return c;
    }

    test('a last-night stay is never outside the trip (#S12)', () {
      final c = withEnquiries([
        TripEnquiryModel(
          id: 'e1',
          status: TripEnquiryStatuses.asked,
          checkIn: DateTime(2030, 11, 2),
          checkOut: DateTime(2030, 11, 3),
        ),
      ]);
      expect(c.checkOutDate, DateTime(2030, 11, 3));
      expect(c.enquiriesOutsideDates, isEmpty);
    });

    test('a stay running past check-out is outside', () {
      final c = withEnquiries([
        TripEnquiryModel(
          id: 'e1',
          status: TripEnquiryStatuses.confirmedByBoth,
          checkIn: DateTime(2030, 11, 2),
          checkOut: DateTime(2030, 11, 4),
        ),
      ]);
      expect(c.enquiriesOutsideDates.single.id, 'e1');
    });

    test('taxi rows are matched by date and listed when outside (#S9)', () {
      final c = withEnquiries([
        TripEnquiryModel(
          id: 't1',
          kind: TripEnquiryKinds.taxi,
          status: TripEnquiryStatuses.bookedByTraveller,
          checkIn: DateTime(2030, 10, 25),
          days: const [1, 2],
        ),
      ]);
      expect(c.taxiEnquiriesForDay(1), isEmpty);
      expect(c.enquiriesOutsideDates.single.id, 't1');
    });

    test('date change lists booked and open rows that fall outside (#S13)', () {
      final c = withEnquiries([
        TripEnquiryModel(
          id: 'open',
          status: TripEnquiryStatuses.asked,
          checkIn: DateTime(2030, 11, 1),
          checkOut: DateTime(2030, 11, 2),
        ),
        TripEnquiryModel(
          id: 'booked',
          kind: TripEnquiryKinds.taxi,
          status: TripEnquiryStatuses.bookedByTraveller,
          checkIn: DateTime(2030, 11, 1),
          days: const [1, 2],
        ),
      ]);
      final same = c.dateChangeImpact(DateTime(2030, 11, 1));
      expect(same.isEmpty, isTrue);
      final moved = c.dateChangeImpact(DateTime(2030, 11, 8));
      expect(moved.open.single.id, 'open');
      expect(moved.booked.single.id, 'booked');
    });
  });

  group('taxi dates', () {
    test('taxiDates follow check-in and the day gaps', () {
      final e = TripEnquiryModel(
        id: 't1',
        kind: TripEnquiryKinds.taxi,
        checkIn: DateTime(2030, 11, 2),
        days: const [2, 4],
      );
      expect(e.taxiDates, [DateTime(2030, 11, 2), DateTime(2030, 11, 4)]);
    });
  });

  group('read-only flags (#S4)', () {
    test('a completed trip is read-only', () {
      final c = TripPlanController();
      c.plan.value = _plan(start: DateTime(2030, 11, 1));
      c.trip.value = _trip(c.plan.value!, status: TripStatuses.completed);
      expect(c.isReadOnly, isTrue);
      expect(c.canComplete, isFalse);
    });

    test('a trip whose every day has passed is a past trip', () {
      final c = TripPlanController();
      c.plan.value = _plan(start: DateTime(2020, 1, 1));
      c.trip.value = _trip(c.plan.value!);
      expect(c.isPastTrip, isTrue);
      expect(c.isReadOnly, isTrue);
      expect(c.isDayPast(1), isTrue);
    });

    test('a future trip is editable and a no-dates trip can be completed', () {
      final c = TripPlanController();
      c.plan.value = _plan(start: DateTime(2030, 11, 1));
      c.trip.value = _trip(c.plan.value!);
      expect(c.isReadOnly, isFalse);
      expect(c.isDayPast(1), isFalse);
      expect(c.canComplete, isFalse);
      c.plan.value = _plan();
      expect(c.canComplete, isTrue);
    });
  });
}
