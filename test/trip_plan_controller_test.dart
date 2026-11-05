import 'package:bakhli/features/taxi/journeys/journey_models.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_journey_model.dart';
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

  group('trip steps', () {
    const delhi = TripStartFrom(name: 'Delhi', lat: 28.6139, lon: 77.2090);

    SavedJourney journey(String id, DateTime date) => SavedJourney(
          id: id,
          fromName: 'Delhi',
          fromLat: 28.6139,
          fromLng: 77.2090,
          toName: 'Nainital',
          toLat: 29.4,
          toLng: 79.4,
          date: date,
          people: 4,
          cars: 1,
          status: JourneyStatus.notAsked,
          createdAt: DateTime(2030, 1, 1),
          updatedAt: DateTime(2030, 1, 1),
        );

    TripPlanController withPlan({TripSteps steps = const TripSteps(), DateTime? start}) {
      final c = TripPlanController();
      addTearDown(c.onClose);
      final p = TripPlan(
        cityKey: 1,
        cityName: 'Nainital',
        centreLatitude: 29.4,
        centreLongitude: 79.4,
        settings: TripSettings(startDate: start ?? DateTime(2030, 11, 1)),
        days: const [TripDay(day: 1), TripDay(day: 2)],
        steps: steps,
      );
      c.plan.value = p;
      c.trip.value = _trip(p);
      return c;
    }

    test('link stores no date when it matches the default and inserts the local journey', () {
      final c = withPlan(steps: const TripSteps(startFrom: delhi));
      c.linkJourney(TripStepRole.gettingThere, journey('j1', DateTime(2030, 11, 1)));
      final s = c.stepOf(TripStepRole.gettingThere);
      expect(s.status, TripStepStatus.chosen);
      expect(s.journeyId, 'j1');
      expect(s.date, isNull);
      expect(c.journeyFor(TripStepRole.gettingThere)?.id, 'j1');
      expect(c.stepDisplay(TripStepRole.gettingThere), TripStepDisplay.chosen);
    });

    test('coming back default is check-out, another day is stored', () {
      final c = withPlan(steps: const TripSteps(startFrom: delhi));
      c.linkJourney(TripStepRole.comingBack, journey('j2', DateTime(2030, 11, 3)));
      expect(c.stepOf(TripStepRole.comingBack).date, isNull);
      expect(c.stepDate(TripStepRole.comingBack), DateTime(2030, 11, 3));
      c.linkJourney(TripStepRole.comingBack, journey('j3', DateTime(2030, 11, 4)));
      expect(c.stepOf(TripStepRole.comingBack).date, DateTime(2030, 11, 4));
      expect(c.journeys.map((j) => j.id), ['j3']);
    });

    test('one journey id per trip: linking it to the other role clears the first', () {
      final c = withPlan(steps: const TripSteps(startFrom: delhi));
      c.linkJourney(TripStepRole.gettingThere, journey('j1', DateTime(2030, 11, 1)));
      c.linkJourney(TripStepRole.comingBack, journey('j1', DateTime(2030, 11, 3)));
      expect(c.stepOf(TripStepRole.gettingThere).journeyId, isNull);
      expect(c.stepOf(TripStepRole.comingBack).journeyId, 'j1');
    });

    test('booked toggle, unlink, own and skip clear the link', () {
      final c = withPlan(steps: const TripSteps(startFrom: delhi));
      c.linkJourney(TripStepRole.gettingThere, journey('j1', DateTime(2030, 11, 1)));
      c.markStepBooked(TripStepRole.gettingThere);
      expect(c.stepDisplay(TripStepRole.gettingThere), TripStepDisplay.booked);
      c.linkJourney(TripStepRole.gettingThere, journey('j1', DateTime(2030, 11, 1)));
      expect(c.stepOf(TripStepRole.gettingThere).status, TripStepStatus.booked);
      c.unmarkStepBooked(TripStepRole.gettingThere);
      expect(c.stepOf(TripStepRole.gettingThere).status, TripStepStatus.chosen);
      c.unlinkJourney(TripStepRole.gettingThere);
      expect(c.stepOf(TripStepRole.gettingThere).status, TripStepStatus.notStarted);
      expect(c.journeys, isEmpty);

      c.linkJourney(TripStepRole.gettingThere, journey('j1', DateTime(2030, 11, 1)));
      c.markStepOwn(TripStepRole.gettingThere, note: '  Own car  ');
      expect(c.stepOf(TripStepRole.gettingThere).status, TripStepStatus.own);
      expect(c.stepOf(TripStepRole.gettingThere).note, 'Own car');
      expect(c.stepOf(TripStepRole.gettingThere).journeyId, isNull);
      expect(c.journeys, isEmpty);

      c.linkJourney(TripStepRole.comingBack, journey('j2', DateTime(2030, 11, 3)));
      c.skipStep(TripStepRole.comingBack);
      expect(c.stepOf(TripStepRole.comingBack).status, TripStepStatus.skipped);
      expect(c.stepOf(TripStepRole.comingBack).journeyId, isNull);
      c.resetStep(TripStepRole.comingBack);
      expect(c.stepOf(TripStepRole.comingBack).status, TripStepStatus.notStarted);
    });

    test('not needed when starting inside the city, back when moved out', () async {
      final c = withPlan();
      await c.setStartFrom(const TripStartFrom(name: 'Nainital', lat: 29.401, lon: 79.401));
      expect(c.startsInsideCity, isTrue);
      expect(c.stepOf(TripStepRole.gettingThere).status, TripStepStatus.notNeeded);
      expect(c.stepOf(TripStepRole.comingBack).status, TripStepStatus.notNeeded);
      await c.setStartFrom(delhi);
      expect(c.stepOf(TripStepRole.gettingThere).status, TripStepStatus.notStarted);
      expect(c.stepOf(TripStepRole.comingBack).status, TripStepStatus.notStarted);
    });

    test('a new start city flags a linked journey', () async {
      final c = withPlan(steps: const TripSteps(startFrom: delhi));
      c.linkJourney(TripStepRole.gettingThere, journey('j1', DateTime(2030, 11, 1)));
      expect(await c.setStartFrom(const TripStartFrom(name: 'Dehradun', lat: 30.3165, lon: 78.0322)), isTrue);
      expect(c.startChangedRole, TripStepRole.gettingThere);
      expect(c.stepNeedsAttention(TripStepRole.gettingThere), isTrue);
    });

    test('a start date change clears both step dates and flags the journey', () async {
      final c = withPlan(
        steps: TripSteps(
          startFrom: delhi,
          gettingThere: const TripStep(status: TripStepStatus.chosen, journeyId: 'j1'),
          comingBack: TripStep(status: TripStepStatus.own, date: DateTime(2030, 11, 4)),
        ),
      );
      c.trip.value = c.trip.value!.copyWith(journeys: [
        TripJourney.fromSaved(journey('j1', DateTime(2030, 11, 1)), TripStepRole.gettingThere),
      ], journeysKnown: true);
      await c.saveSettings(c.settings.copyWith(startDate: DateTime(2030, 11, 8)));
      expect(c.stepOf(TripStepRole.comingBack).date, isNull);
      expect(c.journeyFor(TripStepRole.gettingThere)?.dateChanged, isTrue);
    });

    test('adopts server-dropped journeys only when the local step still holds them', () {
      final c = withPlan(steps: const TripSteps(startFrom: delhi));
      c.linkJourney(TripStepRole.gettingThere, journey('j1', DateTime(2030, 11, 1)));
      final sent = c.plan.value!;
      final serverPlan = sent.copyWith(steps: const TripSteps(startFrom: delhi));
      final saved = TripModel.fromJson({'id': 't1', 'cityKey': 1, 'plan': serverPlan.toJson(), 'journeys': const []});
      c.adoptServerStepsForTest(sent, saved);
      expect(c.stepOf(TripStepRole.gettingThere).journeyId, isNull);
      expect(c.stepOf(TripStepRole.gettingThere).status, TripStepStatus.notStarted);

      c.linkJourney(TripStepRole.gettingThere, journey('j2', DateTime(2030, 11, 1)));
      c.adoptServerStepsForTest(sent, saved);
      expect(c.stepOf(TripStepRole.gettingThere).journeyId, 'j2');
    });

    test('reconcile drops a link whose journey is gone, but not offline', () {
      final c = withPlan(
        steps: const TripSteps(gettingThere: TripStep(status: TripStepStatus.chosen, journeyId: 'gone')),
      );
      c.trip.value = c.trip.value!.copyWith(journeysKnown: true);
      c.offline.value = true;
      c.reconcileSteps();
      expect(c.stepOf(TripStepRole.gettingThere).journeyId, 'gone');
      c.offline.value = false;
      c.reconcileSteps();
      expect(c.stepOf(TripStepRole.gettingThere).status, TripStepStatus.notStarted);
    });

    test('skipped taxi day counts as sorted and costs nothing', () {
      final c = withPlan();
      c.setSkippedTaxiDay(1);
      expect(c.plan.value!.dayAt(1)!.taxi!.isSkipped, isTrue);
      expect(c.hasTaxiActivity(1), isTrue);
      expect(c.priceSoFar, 0);
      expect(c.taxiStep.sorted, 1);
      expect(c.taxiStep.firstUnsorted, 2);
      c.skipRemainingTaxiDays();
      expect(c.taxiStep.display, TripStepDisplay.skipped);
      c.clearSkippedTaxiDay(1);
      expect(c.plan.value!.dayAt(1)!.taxi, isNull);
    });

    test('skip remaining nights marks every open night', () {
      final c = withPlan();
      c.skipRemainingNights();
      expect(c.stayStep.display, TripStepDisplay.skipped);
      expect(c.stayStep.sorted, 2);
    });

    test('journey today on the travel day', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final c = withPlan(start: today, steps: const TripSteps(startFrom: delhi));
      c.linkJourney(TripStepRole.gettingThere, journey('j1', today));
      expect(c.journeyToday?.id, 'j1');
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
