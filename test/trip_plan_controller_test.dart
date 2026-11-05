import 'package:bakhli/features/taxi/journeys/journey_models.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/data/trip_segment_geometry_cache.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_journey_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_result_model.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/trip_strings_mca_a1.dart';
import 'package:bakhli/features/trip/utils/trip_map_rules.dart';
import 'package:bakhli/features/trip/utils/trip_travel_rules.dart';
import 'package:bakhli/models/browse_item.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
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

TripPlan _plan({DateTime? start}) => TripPlan.singleCity(
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('night rule: the last day keeps its night', () {
    test('auto plan keeps the last-day stay and shortlist (#1, #34)', () {
      final c = TripPlanController();
      final withDays = TripPlanResult(
        days: [_resultDay(1, const ['a']), _resultDay(2, const ['b'])],
        warnings: const [],
        osrmAvailable: true,
        dayLimitMinutes: 450,
      );
      final out = c.applyAutoForTest(_plan(), 1, withDays);
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
      final p = TripPlan.singleCity(
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

  group('multi-city legs', () {
    TripPlan twoLegs() => TripPlan.fromJson({
          'version': 4,
          'cityKey': 1,
          'cityName': 'Haridwar',
          'legs': [
            {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'latitude': 29.95, 'longitude': 78.16},
            {'index': 2, 'cityKey': 2, 'cityName': 'Badrinath', 'latitude': 30.74, 'longitude': 79.49},
          ],
          'settings': {'startDate': '2030-11-01'},
          'days': [
            {'day': 1, 'leg': 1, 'spots': [_spot('a').toJson()]},
            {'day': 2, 'leg': 2, 'spots': []},
            {'day': 3, 'leg': 2, 'spots': [_spot('b').toJson()]},
          ],
        });

    TripPlanController withPlan(TripPlan p) {
      final c = TripPlanController();
      addTearDown(c.onClose);
      c.plan.value = p;
      c.trip.value = _trip(p);
      return c;
    }

    test('applyAuto on one leg keeps the other legs and renumbers', () {
      final c = TripPlanController();
      final r = TripPlanResult(
        days: [_resultDay(2, const ['b']), _resultDay(3, const ['c'])],
        warnings: const [],
        osrmAvailable: true,
        dayLimitMinutes: 450,
      );
      final out = c.applyAutoForTest(twoLegs(), 2, r);
      expect(out.legCount, 2);
      expect(out.days.first.leg, 1);
      expect(out.days.first.spots.single.id, 'a');
      expect(out.days.where((d) => d.leg == 2).length, greaterThanOrEqualTo(1));
      expect(out.days.map((d) => d.day).toList(), [for (var i = 1; i <= out.days.length; i++) i]);
    });

    test('renumber keeps one day per leg and clears a cross-leg sameAsDay', () {
      final c = TripPlanController();
      const stay = TripStayChoice(stayId: 's1', name: 'Hotel');
      final days = [
        const TripDay(day: 1, leg: 1, stay: stay),
        const TripDay(day: 2, leg: 2, stay: TripStayChoice(stayId: 's1', name: 'Hotel', sameAsDay: 1)),
      ];
      final out = c.renumberForTest(days);
      expect(out.map((d) => d.leg).toList(), [1, 2]);
      expect(out.last.stay?.sameAsDay, isNull);
    });

    test('removeLeg without bookings shifts later legs', () {
      final c = withPlan(twoLegs());
      expect(c.canRemoveLeg(1), TripLegEditBlock.none);
      expect(c.removeLegMode(1), TripLegRemoveMode.shift);
      expect(c.removeLeg(1), TripLegEditBlock.none);
      expect(c.plan.value!.legCount, 1);
      expect(c.plan.value!.cityName, 'Badrinath');
    });

    test('the only leg cannot be removed and the edge legs cannot move', () {
      final single = withPlan(_plan(start: DateTime(2030, 11, 1)));
      expect(single.canRemoveLeg(1), TripLegEditBlock.onlyLeg);
      final c = withPlan(twoLegs());
      expect(c.canMoveLeg(1, true), TripLegEditBlock.edge);
      expect(c.canMoveLeg(2, false), TripLegEditBlock.edge);
      expect(c.canMoveLeg(1, false), TripLegEditBlock.none);
    });

    test('moveLeg swaps the day blocks and re-indexes', () {
      final c = withPlan(twoLegs());
      expect(c.moveLeg(1, false), TripLegEditBlock.none);
      final p = c.plan.value!;
      expect(p.legs.first.cityName, 'Badrinath');
      expect(p.legs.last.cityName, 'Haridwar');
      expect(p.legs.map((l) => l.index).toList(), [1, 2]);
      expect(p.cityName, 'Badrinath');
    });

    test('setLegDays refuses zero and beyond the trip cap', () async {
      final c = withPlan(twoLegs());
      expect(c.canSetLegDays(2, 0), isNot(TripLegEditBlock.none));
      expect(c.canSetLegDays(2, 14), isNot(TripLegEditBlock.none));
      expect(await c.setLegDays(2, 0), isFalse);
      expect(await c.setLegDays(2, 14), isFalse);
    });

    test('moveSpot across legs does nothing', () {
      final c = withPlan(twoLegs());
      expect(c.moveSpot('a', 3), isFalse);
      expect(c.plan.value!.days.first.spots.single.id, 'a');
    });

    TripPlan paddedSecondLeg() => TripPlan.fromJson({
          'version': 4,
          'cityKey': 1,
          'cityName': 'Haridwar',
          'legs': [
            {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'latitude': 29.95, 'longitude': 78.16},
            {'index': 2, 'cityKey': 2, 'cityName': 'Badrinath', 'latitude': 30.74, 'longitude': 79.49, 'notReady': true},
          ],
          'settings': {'startDate': '2030-11-01'},
          'days': [
            {'day': 1, 'leg': 1, 'spots': [_spot('a').toJson(), _spot('b').toJson()]},
            {'day': 2, 'leg': 1, 'spots': [_spot('c').toJson()]},
            {'day': 3, 'leg': 2, 'spots': []},
            {'day': 4, 'leg': 2, 'spots': []},
            {'day': 5, 'leg': 2, 'spots': []},
          ],
        });

    test('a reorder in one city keeps the other city\'s empty days (#MCA1, #MCA5)', () {
      final c = withPlan(paddedSecondLeg());
      c.reorder(1, 0, 2);
      final p = c.plan.value!;
      expect(p.days.length, 5);
      expect(p.legDayCount(2), 3);
      expect(p.dayAt(1)!.spots.map((s) => s.id).toList(), ['b', 'a']);
    });

    test('a spot edit trims only the edited city (#MCA1, #MCA5)', () {
      final c = withPlan(paddedSecondLeg());
      c.removeSpot('c');
      final p = c.plan.value!;
      expect(p.legDayCount(1), 1);
      expect(p.legDayCount(2), 3);
      expect(p.days.length, 4);
      expect(c.trimmedLegsForTest(paddedSecondLeg(), [
        for (final d in paddedSecondLeg().days) d.day == 1 ? d.copyWith(spots: d.spots.reversed.toList()) : d,
      ]), isEmpty);
    });

    test('a NotReady city cannot take places', () {
      final c = withPlan(paddedSecondLeg());
      expect(c.canAddPlaces(1), isTrue);
      expect(c.canAddPlaces(2), isFalse);
      expect(c.legUnavailable(2), isFalse);
      c.unavailableCities.add(1);
      expect(c.legUnavailable(1), isTrue);
      expect(c.canAddPlaces(1), isFalse);
    });

    TripPlan stayAcrossLegs() => TripPlan.fromJson({
          'version': 4,
          'cityKey': 1,
          'cityName': 'Haridwar',
          'legs': [
            {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'latitude': 29.95, 'longitude': 78.16},
            {'index': 2, 'cityKey': 2, 'cityName': 'Badrinath', 'latitude': 30.74, 'longitude': 79.49},
          ],
          'settings': {'startDate': '2030-11-01'},
          'days': [
            {'day': 1, 'leg': 1, 'spots': [_spot('a').toJson()]},
            {'day': 2, 'leg': 1, 'spots': []},
            {'day': 3, 'leg': 2, 'spots': []},
          ],
        });

    test('a booked stay running into the next city starts a new first night there (#MCA6)', () {
      final c = withPlan(stayAcrossLegs());
      c.enquiryList.assignAll([
        TripEnquiryModel(
          id: 'e1',
          listingId: 's1',
          listingName: 'Ganga View',
          status: TripEnquiryStatuses.confirmedByBoth,
          displayStatusWire: 'confirmedByBoth',
          checkIn: DateTime(2030, 11, 1),
          checkOut: DateTime(2030, 11, 4),
          agreedTotal: 3000,
        ),
      ]);
      c.reconcilePlan();
      final p = c.plan.value!;
      expect(p.dayAt(1)!.stay?.sameAsDay, isNull);
      expect(p.dayAt(2)!.stay?.sameAsDay, 1);
      expect(p.dayAt(3)!.stay?.stayId, 's1');
      expect(p.dayAt(3)!.stay?.sameAsDay, isNull);
    });

    test('a booked taxi covering two cities is not written into the plan (MC-C D7)', () {
      final c = withPlan(stayAcrossLegs());
      c.enquiryList.assignAll([
        TripEnquiryModel(
          id: 't1',
          kind: TripEnquiryKinds.taxi,
          listingId: 'x1',
          listingName: 'Ravi',
          status: TripEnquiryStatuses.bookedByTraveller,
          displayStatusWire: 'bookedByYou',
          checkIn: DateTime(2030, 11, 2),
          days: const [2, 3],
          taxi: const TripTaxiModel(agreedFare: 4000),
        ),
      ]);
      c.reconcilePlan();
      final p = c.plan.value!;
      expect(p.dayAt(2)!.taxi, isNull);
      expect(p.dayAt(3)!.taxi, isNull);
      expect(c.bookedTaxiEnquiryFor(2)?.id, 't1');
    });

    test('a journey to the old first city needs attention after a city move (#MCA7)', () {
      final c = withPlan(twoLegs().copyWith(
        steps: const TripSteps(gettingThere: TripStep(status: TripStepStatus.booked, journeyId: 'j1')),
      ));
      c.trip.value = c.trip.value!.copyWith(journeys: [
        TripJourney(
          id: 'j1',
          fromName: 'Delhi',
          fromLat: 28.6139,
          fromLng: 77.2090,
          toName: 'Haridwar',
          toLat: 29.95,
          toLng: 78.16,
          date: DateTime(2030, 11, 1),
        ),
      ], journeysKnown: true);
      expect(c.journeyFor(TripStepRole.gettingThere)?.needsAttention, isFalse);
      expect(c.moveLeg(1, false), TripLegEditBlock.none);
      expect(c.journeyFor(TripStepRole.gettingThere)?.startChanged, isTrue);
      expect(c.journeyCityChanged(TripStepRole.gettingThere), isTrue);
    });

    test('default title lists the cities like the server', () {
      expect(TripStringsMcaA1.defaultTitle(['Haridwar']), 'Haridwar trip');
      expect(TripStringsMcaA1.defaultTitle(['Haridwar', 'Badrinath']), 'Haridwar, Badrinath trip');
      final long = TripStringsMcaA1.defaultTitle(['A' * 30, 'B' * 30, 'C' * 30]);
      expect(long.length, lessThanOrEqualTo(80));
      expect(long.endsWith('more trip'), isTrue);
    });
  });

  group('travel between cities (MC-B)', () {
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    const journeyArrival = {'mode': 'journey', 'fromName': 'Haridwar', 'journeyId': 'j2', 'cars': 1};

    TripPlan legsPlan({DateTime? start, Map<String, dynamic>? arrival, int? adults, int? kids}) => TripPlan.fromJson({
          'version': 4,
          'cityKey': 1,
          'cityName': 'Haridwar',
          'legs': [
            {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'latitude': 29.95, 'longitude': 78.16},
            {'index': 2, 'cityKey': 2, 'cityName': 'Badrinath', 'latitude': 30.74, 'longitude': 79.49, 'arrival': ?arrival},
          ],
          'settings': {'startDate': ?(start == null ? null : iso(start)), 'adults': ?adults, 'kids': ?kids},
          'days': [
            {'day': 1, 'leg': 1},
            {'day': 2, 'leg': 2},
            {'day': 3, 'leg': 2},
          ],
        });

    TripJourney segJourney(String id, {bool asked = false}) => TripJourney(
          id: id,
          fromName: 'Haridwar',
          toName: 'Badrinath',
          date: DateTime(2030, 11, 2),
          anyAsked: asked,
          legs: [
            TripJourneyLeg(legIndex: 1, fromName: 'Haridwar', toName: 'Badrinath', lastEnquiryId: asked ? 'x' : null),
          ],
        );

    TripEnquiryModel segRow(String journeyId, String status) => TripEnquiryModel(
          id: 'r-$journeyId-$status',
          tripId: 't1',
          kind: TripEnquiryKinds.taxi,
          listingId: 'taxi1',
          day: 2,
          checkIn: DateTime(2030, 11, 2),
          days: const [2],
          status: status,
          context: TripEnquiryContext(journeyId: journeyId, journeyLegIndex: 1),
        );

    SavedJourney saved(String id) => SavedJourney(
          id: id,
          fromName: 'Haridwar',
          toName: 'Badrinath',
          date: DateTime(2030, 11, 2),
          people: 2,
          planKey: 'k1',
          cars: 1,
          status: JourneyStatus.notAsked,
          listedTotal: 7000,
          createdAt: DateTime(2030, 1, 1),
          updatedAt: DateTime(2030, 1, 1),
        );

    TripPlanController ctl(TripPlan p, {List<TripJourney> journeys = const [], List<TripEnquiryModel> rows = const []}) {
      final c = TripPlanController();
      addTearDown(c.onClose);
      c.plan.value = p;
      c.trip.value = _trip(p).copyWith(journeys: journeys, journeysKnown: true, enquiries: rows);
      c.enquiryList.assignAll(rows);
      c.needsUpdate.value = true;
      return c;
    }

    test('linkSegmentJourney writes the arrival and inserts the local journey', () async {
      final c = ctl(legsPlan(start: DateTime(2030, 11, 1)));
      expect(await c.linkSegmentJourney(2, saved('j3')), TripLinkResult.notSaved);
      final a = c.plan.value!.legAt(2)!.arrival!;
      expect(a.isJourney, isTrue);
      expect(a.journeyId, 'j3');
      expect(a.fromName, 'Haridwar');
      expect(a.listedTotal, 7000);
      final j = c.segmentJourney(2);
      expect(j?.isSegment, isTrue);
      expect(j?.travelDay, 2);
      expect(c.travelDateOf(2), DateTime(2030, 11, 2));
      expect(c.travelStateOf(2), TripTravelState.saved);
      expect(c.plan.value!.segmentLegOf('j3'), 2);
    });

    test('replacing a journey with booked cars needs a confirm, then swaps it', () async {
      final c = ctl(
        legsPlan(start: DateTime(2030, 11, 1), arrival: journeyArrival),
        journeys: [segJourney('j2', asked: true)],
        rows: [segRow('j2', TripEnquiryStatuses.bookedByTraveller)],
      );
      expect(await c.linkSegmentJourney(2, saved('j3')), TripLinkResult.needsConfirm);
      expect(c.plan.value!.legAt(2)!.arrival!.journeyId, 'j2');
      c.enquiryList.clear();
      await c.linkSegmentJourney(2, saved('j3'));
      expect(c.plan.value!.legAt(2)!.arrival!.journeyId, 'j3');
      expect(c.journeys.map((j) => j.id), ['j3']);
    });

    test('a journey linked to a step is moved, never linked twice', () async {
      final p = legsPlan(start: DateTime(2030, 11, 1))
          .copyWith(steps: const TripSteps(gettingThere: TripStep(status: TripStepStatus.chosen, journeyId: 'j3')));
      final c = ctl(p);
      await c.linkSegmentJourney(2, saved('j3'));
      expect(c.stepOf(TripStepRole.gettingThere).journeyId, isNull);
      expect(c.plan.value!.segmentLegOf('j3'), 2);
    });

    test('removeTravel refuses with booked cars unless told, then clears the arrival', () async {
      final c = ctl(
        legsPlan(start: DateTime(2030, 11, 1), arrival: journeyArrival),
        journeys: [segJourney('j2', asked: true)],
        rows: [segRow('j2', TripEnquiryStatuses.bookedByTraveller)],
      );
      expect(c.travelImpact(2).bookedRows, 1);
      expect(await c.removeTravel(2), isFalse);
      expect(c.plan.value!.legAt(2)!.arrival?.journeyId, 'j2');
      c.enquiryList.clear();
      expect(await c.removeTravel(2), isTrue);
      expect(c.plan.value!.legAt(2)!.arrival, isNull);
      expect(c.journeys, isEmpty);
    });

    test('unlinkSegmentJourney clears only the matching leg', () {
      final c = ctl(legsPlan(start: DateTime(2030, 11, 1), arrival: journeyArrival), journeys: [segJourney('j2')]);
      c.unlinkSegmentJourney('other');
      expect(c.plan.value!.legAt(2)!.arrival?.journeyId, 'j2');
      c.unlinkSegmentJourney('j2');
      expect(c.plan.value!.legAt(2)!.arrival, isNull);
    });

    test('travel people default 2 and clamp 12', () {
      expect(ctl(legsPlan()).travelPeople, 2);
      expect(ctl(legsPlan(adults: 3, kids: 1)).travelPeople, 4);
      final big = ctl(legsPlan(adults: 14));
      expect(big.travelPeople, 12);
      expect(big.travelPeopleCapped, isTrue);
    });

    test('findWayBlock matrix', () {
      final now = DateTime.now();
      final soon = DateTime(now.year, now.month, now.day + 10);
      final c = ctl(legsPlan(start: soon));
      c.needsUpdate.value = false;
      expect(c.findWayBlock(2), TravelFindBlock.none);
      expect(c.findWayBlock(1), TravelFindBlock.readOnly);
      c.offline.value = true;
      expect(c.findWayBlock(2), TravelFindBlock.offline);
      c.offline.value = false;
      c.taxiTabOff.value = true;
      expect(c.findWayBlock(2), TravelFindBlock.taxiOff);
      c.taxiTabOff.value = false;
      c.needsUpdate.value = true;
      expect(c.findWayBlock(2), TravelFindBlock.readOnly);

      final noDates = ctl(legsPlan());
      noDates.needsUpdate.value = false;
      expect(noDates.findWayBlock(2), TravelFindBlock.noDates);

      final far = ctl(legsPlan(start: DateTime(now.year + 2, now.month, now.day)));
      far.needsUpdate.value = false;
      expect(far.findWayBlock(2), TravelFindBlock.tooFarAhead);
    });

    test('reconcileTravel clears a missing journey only online and keeps a pending one', () async {
      final c = ctl(legsPlan(start: DateTime(2030, 11, 1), arrival: journeyArrival));
      c.offline.value = true;
      c.reconcileTravel();
      expect(c.plan.value!.legAt(2)!.arrival?.journeyId, 'j2');
      c.offline.value = false;
      c.reconcileTravel();
      expect(c.plan.value!.legAt(2)!.arrival, isNull);

      await c.linkSegmentJourney(2, saved('j4'));
      c.trip.value = c.trip.value!.copyWith(journeys: const []);
      c.reconcileTravel();
      expect(c.plan.value!.legAt(2)!.arrival?.journeyId, 'j4');
    });

    test('server-dropped arrival is adopted only while the leg still holds it', () {
      final c = ctl(legsPlan(start: DateTime(2030, 11, 1), arrival: journeyArrival), journeys: [segJourney('j2')]);
      final sent = c.plan.value!;
      final serverPlan = sent.withArrival(2, null);
      final saved = TripModel.fromJson({'id': 't1', 'cityKey': 1, 'plan': serverPlan.toJson(), 'journeys': const []});
      c.adoptServerArrivalsForTest(sent, saved);
      expect(c.plan.value!.legAt(2)!.arrival, isNull);
    });

    test('segment rows stay out of the day taxi surfaces but count as dated bookings', () {
      final c = ctl(
        legsPlan(start: DateTime(2030, 11, 1), arrival: journeyArrival),
        journeys: [segJourney('j2', asked: true)],
        rows: [segRow('j2', TripEnquiryStatuses.bookedByTraveller)],
      );
      expect(c.taxiEnquiriesForDay(2), isEmpty);
      expect(c.hasTaxiActivity(2), isFalse);
      expect(c.bookedTaxiEnquiryFor(2), isNull);
      expect(c.taxiStep.sorted, 1);
      expect(c.taxiStep.firstUnsorted, 1);
      expect(c.segmentRows(2).length, 1);
      expect(c.carBooking(2, 1), isNotNull);
      expect(c.travelStateOf(2), TripTravelState.booked);
      expect(c.bookingsOutsideDates(DateTime(2030, 12, 1)).length, 1);
      c.reconcilePlan();
      expect(c.plan.value!.dayAt(2)!.taxi, isNull);
    });

    test('a journey travel day hides the local taxi; own travel keeps it', () {
      final c = ctl(legsPlan(start: DateTime(2030, 11, 1), arrival: journeyArrival), journeys: [segJourney('j2')]);
      expect(c.hidesLocalTaxi(2), isTrue);
      expect(c.hidesLocalTaxi(3), isFalse);
      expect(c.hasLocalTaxiOn(2), isFalse);
      final own = ctl(legsPlan(
        start: DateTime(2030, 11, 1),
        arrival: {'mode': 'own', 'fromName': 'Haridwar', 'how': 'bus'},
      ));
      expect(own.hidesLocalTaxi(2), isFalse);
      expect(own.travelStateOf(2), TripTravelState.own);
    });

    test('a session gap shows until travel is saved', () {
      final c = ctl(legsPlan(start: DateTime(2030, 11, 1)));
      expect(c.travelStateOf(2), TripTravelState.notPlanned);
      c.markTravelGap(2, 'Rishikesh');
      expect(c.travelStateOf(2), TripTravelState.gap);
      expect(c.travelGaps[2], 'Rishikesh');
      c.clearTravelGap(2);
      expect(c.travelStateOf(2), TripTravelState.notPlanned);
    });

    test('a journey travel day counts as sorted for the local taxi step', () {
      final p = legsPlan(start: DateTime(2030, 11, 1), arrival: journeyArrival);
      final days = [
        for (final d in p.days)
          d.day == 2 ? d : d.copyWith(taxi: const TripTaxiChoice(taxiId: 'tx', name: 'Sunil', fare: 2000)),
      ];
      final c = ctl(p.copyWith(days: days), journeys: [segJourney('j2')]);
      expect(c.taxiStep.sorted, 3);
      expect(c.taxiStep.firstUnsorted, isNull);
    });

    test('journey arrival road minutes: given, clamped, else previous own or a whole day', () async {
      final c = ctl(legsPlan(start: DateTime(2030, 11, 1)));
      await c.linkSegmentJourney(2, saved('j3'), roadMinutes: 600);
      expect(c.plan.value!.legAt(2)!.arrival!.roadMinutes, 600);
      await c.linkSegmentJourney(2, saved('j4'), roadMinutes: 2000);
      expect(c.plan.value!.legAt(2)!.arrival!.roadMinutes, 900);

      final none = ctl(legsPlan(start: DateTime(2030, 11, 1)));
      await none.linkSegmentJourney(2, saved('j3'));
      expect(none.plan.value!.legAt(2)!.arrival!.roadMinutes, 450);

      final own = ctl(legsPlan(
        start: DateTime(2030, 11, 1),
        arrival: {'mode': 'own', 'fromName': 'Haridwar', 'how': 'bus', 'roadMinutes': 240},
      ));
      await own.linkSegmentJourney(2, saved('j3'));
      expect(own.plan.value!.legAt(2)!.arrival!.roadMinutes, 240);
    });

    test('an unavailable city blocks the link before anything changes', () async {
      final c = ctl(legsPlan(start: DateTime(2030, 11, 1)));
      c.needsUpdate.value = false;
      c.unavailableCities.add(2);
      expect(await c.prepareSegmentLink(2), TripStrings.cityUnavailable);
      expect(await c.linkSegmentJourney(2, saved('j3')), TripLinkResult.notSaved);
      expect(c.plan.value!.legAt(2)!.arrival, isNull);
    });

    test('releaseJourneyLink drops only a journey the plan does not hold', () async {
      final c = ctl(
        legsPlan(start: DateTime(2030, 11, 1), arrival: journeyArrival),
        journeys: [segJourney('j2'), segJourney('j9')],
      );
      await c.releaseJourneyLink('j2');
      await c.releaseJourneyLink('j9');
      expect(c.journeys.map((j) => j.id), ['j2']);
      expect(c.segmentLegOf('j2'), 2);
      expect(c.segmentLegOf('j9'), isNull);
    });

    test('travelMatches only for the same plan, date and people', () {
      final c = ctl(
        legsPlan(start: DateTime(2030, 11, 1), arrival: {...journeyArrival, 'planKey': 'k1'}),
        journeys: [segJourney('j2')],
      );
      final people = c.segmentJourney(2)!.people;
      expect(c.travelMatches(2, 'k1', DateTime(2030, 11, 2), people), isTrue);
      expect(c.travelMatches(2, 'k2', DateTime(2030, 11, 2), people), isFalse);
      expect(c.travelMatches(2, 'k1', DateTime(2030, 11, 3), people), isFalse);
    });
  });

  group('bookings per leg (MC-C)', () {
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    TripPlan legsPlan({
      DateTime? start,
      List<int> legOfDay = const [1, 2, 2],
      Map<String, dynamic>? arrival,
    }) =>
        TripPlan.fromJson({
          'version': 4,
          'cityKey': 1,
          'cityName': 'Haridwar',
          'legs': [
            {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'latitude': 29.95, 'longitude': 78.16},
            {'index': 2, 'cityKey': 2, 'cityName': 'Badrinath', 'latitude': 30.74, 'longitude': 79.49, 'arrival': ?arrival},
          ],
          'settings': {'startDate': iso(start ?? DateTime(2030, 11, 1))},
          'days': [
            for (var i = 0; i < legOfDay.length; i++) {'day': i + 1, 'leg': legOfDay[i]},
          ],
        });

    TripPlanController ctl(TripPlan p, {List<TripEnquiryModel> rows = const [], List<TripJourney> journeys = const []}) {
      final c = TripPlanController();
      addTearDown(c.onClose);
      c.plan.value = p;
      c.trip.value = _trip(p).copyWith(journeys: journeys, journeysKnown: true, enquiries: rows);
      c.enquiryList.assignAll(rows);
      return c;
    }

    TripEnquiryModel stayRow(String id, int night, String status, {int nights = 1, String city = 'Haridwar'}) =>
        TripEnquiryModel(
          id: id,
          tripId: 't1',
          listingId: 'l-$id',
          listingName: id,
          status: status,
          displayStatusWire: status == TripEnquiryStatuses.confirmedByBoth ? 'confirmedByBoth' : 'asked',
          checkIn: DateTime(2030, 11, night),
          checkOut: DateTime(2030, 11, night + nights),
          agreedTotal: status == TripEnquiryStatuses.confirmedByBoth ? 2000 : null,
          context: TripEnquiryContext(city: city),
        );

    TripEnquiryModel taxiRow(String id, List<int> days, String status) => TripEnquiryModel(
          id: id,
          tripId: 't1',
          kind: TripEnquiryKinds.taxi,
          listingId: 'x-$id',
          status: status,
          checkIn: DateTime(2030, 11, days.first),
          days: days,
          context: const TripEnquiryContext(city: 'Haridwar'),
        );

    TripEnquiryModel carRow(String status) => TripEnquiryModel(
          id: 'car',
          tripId: 't1',
          kind: TripEnquiryKinds.taxi,
          listingId: 'taxi1',
          day: 2,
          checkIn: DateTime(2030, 11, 2),
          days: const [2],
          status: status,
          context: const TripEnquiryContext(journeyId: 'j2', journeyLegIndex: 1),
        );

    const journeyArrival = {'mode': 'journey', 'fromName': 'Haridwar', 'journeyId': 'j2', 'cars': 1};

    TripJourney segJourney() => TripJourney(
          id: 'j2',
          fromName: 'Haridwar',
          toName: 'Badrinath',
          date: DateTime(2030, 11, 2),
          anyAsked: true,
          legs: [TripJourneyLeg(legIndex: 1, fromName: 'Haridwar', toName: 'Badrinath', lastEnquiryId: 'x')],
        );

    test('remove impact: own-leg rows by date, cars of the next leg, counts', () {
      final c = ctl(
        legsPlan(arrival: journeyArrival),
        journeys: [segJourney()],
        rows: [
          stayRow('s1', 1, TripEnquiryStatuses.asked),
          taxiRow('t1', const [1], TripEnquiryStatuses.bookedByTraveller),
          stayRow('s2', 2, TripEnquiryStatuses.asked, city: 'Badrinath'),
          carRow(TripEnquiryStatuses.bookedByTraveller),
        ],
      );
      final i = c.legRemoveImpact(1);
      expect(i.open.map((e) => e.id), ['s1']);
      expect(i.booked.map((e) => e.id), ['t1']);
      expect(i.cars.map((e) => e.id), ['car']);
      expect(i.travelLegs, [2]);
      expect(i.hosts, 1);
      expect(i.drivers, 2);
      expect(i.bookedCount, 2);
      expect(i.openCount, 1);
      expect(i.hasBooked, isTrue);
      expect(i.isEmpty, isFalse);
      expect(i.laterKeepDates, isTrue);
      expect(i.laterCities, ['Badrinath']);
    });

    test('removeLeg asks first, keepBookings applies; canRemoveLeg never says bookings', () {
      final c = ctl(legsPlan(), rows: [stayRow('s1', 1, TripEnquiryStatuses.confirmedByBoth)]);
      expect(c.canRemoveLeg(1), TripLegEditBlock.none);
      expect(c.removeLeg(1), TripLegEditBlock.bookings);
      expect(c.plan.value!.legCount, 2);
      expect(c.removeLeg(1, keepBookings: true), TripLegEditBlock.none);
      expect(c.plan.value!.legCount, 1);
    });

    test('reorder stays blocked by a dated row', () {
      final c = ctl(legsPlan(), rows: [stayRow('s2', 2, TripEnquiryStatuses.asked, city: 'Badrinath')]);
      expect(c.canMoveLeg(1, false), TripLegEditBlock.bookings);
      expect(c.moveLeg(1, false), TripLegEditBlock.bookings);
      expect(c.plan.value!.legs.first.cityName, 'Haridwar');
    });

    test('shrink impact counts dropped days only; later legs join when they shift', () async {
      final c = ctl(legsPlan(legOfDay: const [1, 2, 2, 2]), rows: [
        stayRow('kept', 2, TripEnquiryStatuses.confirmedByBoth, city: 'Badrinath'),
        stayRow('dropped', 4, TripEnquiryStatuses.asked, city: 'Badrinath'),
      ]);
      final last = c.legShrinkImpact(2, 2);
      expect(last.open.map((e) => e.id), ['dropped']);
      expect(last.booked, isEmpty);
      expect(last.laterKeepDates, isFalse);
      expect(c.legShrinkImpact(2, 3).isEmpty, isTrue);
      expect(c.canSetLegDays(2, 2), TripLegEditBlock.bookings);
      expect(await c.setLegDays(2, 2), isFalse);
      expect(c.plan.value!.legDayCount(2), 3);

      final first = ctl(legsPlan(legOfDay: const [1, 1, 2]), rows: [
        stayRow('later', 3, TripEnquiryStatuses.confirmedByBoth, city: 'Badrinath'),
      ]);
      final i = first.legShrinkImpact(1, 1);
      expect(i.laterKeepDates, isTrue);
      expect(i.booked.map((e) => e.id), ['later']);
      expect(i.laterCities, ['Badrinath']);
    });

    test('cancel paths do nothing offline and leave the plan alone', () async {
      final c = ctl(legsPlan(), rows: [stayRow('s1', 1, TripEnquiryStatuses.confirmedByBoth)]);
      c.offline.value = true;
      final r = await c.cancelLegRows(c.legRemoveImpact(1));
      expect(r.ok, isFalse);
      expect(r.failed, 1);
      expect(r.closed, 0);
      expect(await c.cancelAndRemoveLeg(1), TripLegEditBlock.bookings);
      expect(c.plan.value!.legCount, 2);
      expect((await c.cancelLegRows(const LegImpact.empty())).ok, isTrue);
    });

    test('a running leg cannot be removed, moved or shrunk past today; a later leg stays free', () async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final c = ctl(legsPlan(start: yesterday, legOfDay: const [1, 1, 2, 2]));
      expect(c.legRunning(1), isTrue);
      expect(c.legRunning(2), isFalse);
      expect(c.canRemoveLeg(1), TripLegEditBlock.running);
      expect(c.canMoveLeg(1, false), TripLegEditBlock.running);
      expect(c.minDaysForLeg(1), 2);
      expect(c.minDaysForLeg(2), 1);
      expect(c.canSetLegDays(1, 1), TripLegEditBlock.running);
      expect(await c.setLegDays(1, 1), isFalse);
      expect(c.canRemoveLeg(2), TripLegEditBlock.none);
    });

    test('No stay tonight is refused while the night has a stay, and clears the shortlist', () {
      final p = legsPlan();
      final days = [
        for (final d in p.days)
          d.day == 3 ? d.copyWith(stayShortlist: const [TripStayShortlistItem(stayId: 'x', name: 'X')]) : d,
      ];
      final c = ctl(p.copyWith(days: days), rows: [stayRow('s2', 2, TripEnquiryStatuses.asked, city: 'Badrinath')]);
      expect(c.canSkipNight(2), NoStayBlock.hasEnquiry);
      expect(c.setSkippedNight(2), NoStayBlock.hasEnquiry);
      expect(c.plan.value!.dayAt(2)!.stay, isNull);
      expect(c.canSkipNight(3), NoStayBlock.none);
      expect(c.setSkippedNight(3), NoStayBlock.none);
      expect(c.plan.value!.dayAt(3)!.stay?.isSkipped, isTrue);
      expect(c.plan.value!.dayAt(3)!.stayShortlist, isEmpty);
      expect(c.canSkipNight(9), NoStayBlock.readOnly);
    });

    test('the enquiry run stops before a skipped night and at the leg end', () {
      final p = legsPlan(legOfDay: const [1, 1, 2, 2, 2]);
      final days = [
        for (final d in p.days) d.day == 4 ? d.copyWith(stay: const TripStayChoice.skippedNight()) : d,
      ];
      final c = ctl(p.copyWith(days: days));
      expect(c.enquiryNightsRun(1), [1, 2]);
      expect(c.enquiryNightsRun(3), [3]);
      expect(c.enquiryNightsRun(5), [5]);
    });

    test('reconcile never copies a wrong-city stay into the plan choice', () {
      final c = ctl(legsPlan(), rows: [
        stayRow('home', 1, TripEnquiryStatuses.confirmedByBoth),
        stayRow('wrong', 2, TripEnquiryStatuses.confirmedByBoth),
      ]);
      c.reconcilePlan();
      final p = c.plan.value!;
      expect(p.dayAt(1)!.stay?.stayId, 'l-home');
      expect(p.dayAt(2)!.stay, isNull);
      expect(c.wrongCityForDay(2)?.id, 'wrong');
      expect(c.wrongCityForDay(1), isNull);
      expect(c.wrongCityRows.map((e) => e.id), ['wrong']);
      expect(c.wrongCityOf(c.enquiryList.firstWhere((e) => e.id == 'wrong'))?.dayCity, 'Badrinath');
    });

    test('a one-city trip flags only a city that is not in the trip', () {
      final c = ctl(_plan(start: DateTime(2030, 11, 1)),
          rows: [stayRow('s', 2, TripEnquiryStatuses.confirmedByBoth, city: 'Nainital')]);
      expect(c.wrongCityRows, isEmpty);
      expect(c.wrongCityForDay(2), isNull);
      final gone = ctl(_plan(start: DateTime(2030, 11, 1)),
          rows: [stayRow('s', 2, TripEnquiryStatuses.confirmedByBoth, city: 'Elsewhere')]);
      expect(gone.wrongCityForDay(2)?.id, 's');
      expect(gone.wrongCityOf(gone.enquiryList.single)?.cityRemoved, isTrue);
    });

    test('remove with kept bookings down to one city: the removed city row is not the new night stay', () {
      final c = ctl(legsPlan(legOfDay: const [1, 1, 2, 2]),
          rows: [stayRow('h', 1, TripEnquiryStatuses.confirmedByBoth)]);
      expect(c.removeLegMode(1), TripLegRemoveMode.shift);
      expect(c.removeLeg(1, keepBookings: true), TripLegEditBlock.none);
      final p = c.plan.value!;
      expect(p.legCount, 1);
      expect(p.dayAt(1)!.stay, isNull);
      expect(c.wrongCityForDay(1)?.id, 'h');
      final info = c.wrongCityOf(c.enquiryList.single)!;
      expect(info.cityRemoved, isTrue);
      expect(c.wrongCityHomeLeg(info), isNull);
    });

    test('a kept row of a removed middle city is unknown, never the nearest city', () {
      final p = TripPlan.fromJson({
        'version': 4,
        'cityKey': 1,
        'cityName': 'Rishikesh',
        'legs': [
          {'index': 1, 'cityKey': 1, 'cityName': 'Rishikesh', 'latitude': 30.08, 'longitude': 78.26},
          {'index': 2, 'cityKey': 2, 'cityName': 'Haridwar', 'latitude': 29.95, 'longitude': 78.16},
          {'index': 3, 'cityKey': 3, 'cityName': 'Mussoorie', 'latitude': 30.45, 'longitude': 78.07},
        ],
        'settings': {'startDate': iso(DateTime(2030, 11, 1))},
        'days': [
          {'day': 1, 'leg': 1},
          {'day': 2, 'leg': 2},
          {'day': 3, 'leg': 3},
        ],
      });
      final c = ctl(p, rows: [
        stayRow('h', 2, TripEnquiryStatuses.confirmedByBoth),
        stayRow('m', 3, TripEnquiryStatuses.confirmedByBoth, city: 'Mussoorie'),
      ]);
      expect(c.removeLegMode(2), TripLegRemoveMode.keepLaterDates);
      expect(c.removeLeg(2, keepBookings: true), TripLegEditBlock.none);
      expect(c.plan.value!.dayAt(2)!.leg, 1);
      expect(c.plan.value!.dayAt(2)!.stay, isNull);
      expect(c.wrongCityForDay(2)?.id, 'h');
    });

    test('keep bookings is refused while journey cars would lose their travel', () {
      final c = ctl(
        legsPlan(arrival: journeyArrival),
        journeys: [segJourney()],
        rows: [carRow(TripEnquiryStatuses.bookedByTraveller)],
      );
      final i = c.legRemoveImpact(1);
      expect(i.carsBlockKeep, isTrue);
      expect(i.laterKeepDates, isFalse);
      expect(c.removeLegMode(1), TripLegRemoveMode.shift);
      expect(c.removeLeg(1, keepBookings: true), TripLegEditBlock.bookings);
      expect(c.plan.value!.legCount, 2);
      expect(c.plan.value!.legAt(2)!.arrival?.journeyId, 'j2');
      expect(c.legShrinkImpact(1, 1).carsBlockKeep, isFalse);
    });

    test('a removed leg row reaching into the next leg does not switch to keep later dates', () {
      final c = ctl(legsPlan(legOfDay: const [1, 2, 2]),
          rows: [stayRow('span', 1, TripEnquiryStatuses.asked, nights: 2)]);
      final i = c.legRemoveImpact(1);
      expect(i.open.map((e) => e.id), ['span']);
      expect(i.laterKeepDates, isFalse);
      expect(c.removeLegMode(1), TripLegRemoveMode.shift);
    });

    test('growing a leg never pulls later bookings into the impact', () async {
      final c = ctl(legsPlan(legOfDay: const [1, 2, 2]),
          rows: [stayRow('later', 2, TripEnquiryStatuses.confirmedByBoth, city: 'Badrinath')]);
      expect(c.legShrinkImpact(1, 2).isEmpty, isTrue);
      expect(c.legShrinkImpact(1, 2).laterKeepDates, isFalse);
      expect(c.canSetLegDays(1, 2), TripLegEditBlock.none);
      expect(await c.setLegDays(1, 2), isTrue);
      expect(c.plan.value!.legDayCount(1), 2);
      expect(c.plan.value!.legDayCount(2), 2);
    });

    test('Change days on a wrong-city strip opens the home city', () {
      final c = ctl(legsPlan(), rows: [stayRow('wrong', 2, TripEnquiryStatuses.confirmedByBoth)]);
      final info = c.wrongCityOf(c.enquiryList.single)!;
      expect(info.dayLegIndex, 2);
      expect(c.wrongCityHomeLeg(info), 1);
    });

    test('without a plan the server flags are the fallback', () {
      final c = TripPlanController();
      addTearDown(c.onClose);
      final e = TripEnquiryModel.fromJson({
        'id': 'e1',
        'kind': 'Stay',
        'wrongCity': true,
        'wrongNights': 1,
        'wrongTotal': 2,
        'wrongFirstDay': 3,
        'wrongDayCity': 'Badrinath',
        'outsideTrip': true,
      });
      final w = c.wrongCityOf(e)!;
      expect(w.wrong, 1);
      expect(w.total, 2);
      expect(w.firstWrongDay, 3);
      expect(w.dayCity, 'Badrinath');
      expect(c.isOutsideTrip(e), isTrue);
    });
  });

  group('map per leg (MC-D)', () {
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    Map<String, dynamic> spot(String id, double lat, double lon) =>
        TripSpotRef(id: id, name: id, latitude: lat, longitude: lon, category: 'attraction', visitMinutes: 60).toJson();

    TripPlan legsPlan({DateTime? start, Map<String, dynamic>? arrival, bool points = true}) => TripPlan.fromJson({
          'version': 4,
          'cityKey': 1,
          'cityName': 'Haridwar',
          'legs': [
            {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'latitude': points ? 29.95 : 0, 'longitude': points ? 78.16 : 0},
            {
              'index': 2,
              'cityKey': 2,
              'cityName': 'Badrinath',
              'latitude': 30.74,
              'longitude': 79.49,
              'arrival': ?arrival,
            },
          ],
          'settings': {'startDate': ?(start == null ? null : iso(start))},
          'days': [
            {
              'day': 1,
              'leg': 1,
              'spots': [spot('a', 29.96, 78.17)],
              'stay': {'stayId': 's1', 'name': 'Ganga View', 'latitude': 29.94, 'longitude': 78.15},
            },
            {'day': 2, 'leg': 2, 'spots': []},
            {
              'day': 3,
              'leg': 2,
              'spots': [spot('b', 30.75, 79.50)],
              'stay': {'stayId': 's2', 'name': 'Alaknanda View', 'latitude': 30.73, 'longitude': 79.48},
            },
          ],
        });

    TripPlan oneLeg({DateTime? start}) => TripPlan.singleCity(
          cityKey: 1,
          cityName: 'Nainital',
          settings: TripSettings(startDate: start),
          days: [
            TripDay(
              day: 1,
              spots: [TripSpotRef.fromJson(spot('a', 29.38, 79.45)), TripSpotRef.fromJson(spot('b', 29.39, 79.46))],
              stay: const TripStayChoice(stayId: 's1', name: 'Lake Inn', latitude: 29.37, longitude: 79.44),
            ),
            TripDay(
              day: 2,
              spots: [TripSpotRef.fromJson(spot('c', 29.40, 79.47))],
              stay: const TripStayChoice(stayId: 's1', name: 'Lake Inn', sameAsDay: 1),
            ),
            TripDay(day: 3, spots: [TripSpotRef.fromJson(spot('d', 29.41, 79.48))]),
          ],
        );

    TripPlanController ctl(TripPlan p) {
      final c = TripPlanController();
      addTearDown(c.onClose);
      c.plan.value = p;
      c.trip.value = _trip(p);
      return c;
    }

    List<String> keys(List<LatLng> points) => [for (final p in points) '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}']..sort();

    List<LatLng> todaysSet(TripPlan p, int selected) {
      final all = selected == TripPlanController.mapAll;
      final points = <LatLng>[
        for (final s in all ? p.allSpots : (p.dayAt(selected)?.spots ?? const <TripSpotRef>[]))
          LatLng(s.latitude, s.longitude),
      ];
      final stay = all ? null : p.dayAt(selected)?.stay;
      final pinDay = all ? null : (stay == null ? null : (stay.sameAsDay ?? selected));
      for (final day in p.days) {
        if (!all && day.day != pinDay) continue;
        final s = day.stay;
        if (s == null || s.isSameStay || !s.hasCoordinates) continue;
        points.add(LatLng(s.latitude!, s.longitude!));
      }
      return points;
    }

    setUp(TripSegmentGeometryCache.clear);

    test('defaultMapDay: All on a not-running two-city trip, Day 1 on one city, today while running', () {
      expect(ctl(legsPlan(start: DateTime(2030, 11, 1))).defaultMapDay, TripPlanController.mapAll);
      expect(ctl(legsPlan()).defaultMapDay, TripPlanController.mapAll);
      expect(ctl(oneLeg(start: DateTime(2030, 11, 1))).defaultMapDay, 1);
      expect(ctl(oneLeg()).defaultMapDay, 1);
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      expect(ctl(legsPlan(start: yesterday)).defaultMapDay, 2);
      expect(ctl(oneLeg(start: yesterday)).defaultMapDay, 2);
    });

    test('selectMapLeg clears the day and selectMapDay clears the leg', () {
      final c = ctl(legsPlan());
      c.selectMapLeg(2);
      expect(c.selectedMapLeg.value, 2);
      expect(c.selectedMapDay.value, TripPlanController.mapAll);
      expect(c.mapFocus, TripMapFocus.city);
      c.selectMapDay(3);
      expect(c.selectedMapLeg.value, 0);
      expect(c.selectedMapDay.value, 3);
      expect(c.mapFocus, TripMapFocus.day);
      c.selectMapAll();
      expect(c.mapFocus, TripMapFocus.all);
      c.selectMapLeg(9);
      expect(c.selectedMapLeg.value, 0);
      expect(c.mapFocus, TripMapFocus.all);
      c.selectMapLeg(1);
      c.resetMap();
      expect(c.selectedMapLeg.value, 0);
      expect(c.selectedMapDay.value, 1);
    });

    test('a day written straight to selectedMapDay wins over a stale leg', () {
      final c = ctl(legsPlan());
      c.selectMapLeg(2);
      c.selectedMapDay.value = 1;
      expect(c.mapFocus, TripMapFocus.day);
    });

    test('mapShowsDay and mapShowsSegment matrix', () {
      final c = ctl(legsPlan());
      c.selectMapAll();
      expect([1, 2, 3].map(c.mapShowsDay), [true, true, true]);
      expect(c.mapShowsSegment(2), isTrue);
      c.selectMapLeg(1);
      expect([1, 2, 3].map(c.mapShowsDay), [true, false, false]);
      expect(c.mapShowsSegment(2), isTrue);
      c.selectMapLeg(2);
      expect([1, 2, 3].map(c.mapShowsDay), [false, true, true]);
      expect(c.mapShowsSegment(2), isTrue);
      expect(c.mapShowsSegment(3), isFalse);
      c.selectMapDay(2);
      expect([1, 2, 3].map(c.mapShowsDay), [false, true, false]);
      expect(c.mapShowsSegment(2), isTrue);
      c.selectMapDay(3);
      expect(c.mapShowsSegment(2), isFalse);
      c.selectMapDay(1);
      expect(c.mapShowsSegment(2), isFalse);
      expect(c.mapShowsSegment(1), isFalse);
    });

    test('segmentLine: straight line without a cached plan, cached points after put, null without coordinates', () {
      const arrival = {'mode': 'journey', 'fromName': 'Haridwar', 'journeyId': 'j2', 'planKey': 'pk', 'cars': 2};
      final c = ctl(legsPlan(arrival: arrival));
      final straight = c.segmentLine(2)!;
      expect(straight.length, 2);
      expect(straight.first.latitude, 29.95);
      expect(straight.last.latitude, 30.74);
      TripSegmentGeometryCache.put('pk', [(lat: 29.9, lng: 78.1), (lat: 30.2, lng: 78.6), (lat: 30.7, lng: 79.4)]);
      expect(c.segmentLine(2)!.length, 3);
      expect(c.segmentLine(1), isNull);
      expect(ctl(legsPlan(points: false)).segmentLine(2), isNull);
      expect(ctl(oneLeg()).segmentLine(2), isNull);
    });

    test('mapFocusPoints on one city equals the map screen set for All and every day', () {
      final p = oneLeg();
      final c = ctl(p);
      c.selectedMapDay.value = TripPlanController.mapAll;
      expect(keys(c.mapFocusPoints()), keys(todaysSet(p, TripPlanController.mapAll)));
      for (final d in [1, 2, 3]) {
        c.selectMapDay(d);
        expect(keys(c.mapFocusPoints()), keys(todaysSet(p, d)), reason: 'day $d');
      }
    });

    test('mapFocusPoints per leg: All adds centres, a city keeps its own, a travel day adds the road ends', () {
      final c = ctl(legsPlan());
      c.selectMapAll();
      final all = keys(c.mapFocusPoints());
      expect(all.map((s) => s.split(',').map((x) => double.parse(x).toStringAsFixed(2)).join(',')), containsAll(['29.95,78.16', '30.74,79.49', '29.96,78.17', '30.75,79.50', '29.94,78.15', '30.73,79.48']));
      c.selectMapLeg(1);
      expect(keys(c.mapFocusPoints()), keys([const LatLng(29.96, 78.17), const LatLng(29.94, 78.15)]));
      c.selectMapLeg(2);
      expect(keys(c.mapFocusPoints()), keys([const LatLng(30.75, 79.50), const LatLng(30.73, 79.48)]));
      c.selectMapDay(2);
      expect(keys(c.mapFocusPoints()), keys([const LatLng(29.95, 78.16), const LatLng(30.74, 79.49)]));
    });

    test('mapFocusPoints on a travel day fits every point of a cached road, not only its ends', () {
      const arrival = {'mode': 'journey', 'fromName': 'Haridwar', 'journeyId': 'j2', 'planKey': 'pk', 'cars': 2};
      final c = ctl(legsPlan(arrival: arrival));
      TripSegmentGeometryCache.put('pk', [(lat: 29.9, lng: 78.1), (lat: 30.2, lng: 77.2), (lat: 30.7, lng: 79.4)]);
      c.selectMapDay(2);
      expect(keys(c.mapFocusPoints()), contains('30.2000,77.2000'));
      c.selectMapAll();
      expect(keys(c.mapFocusPoints()), contains('30.2000,77.2000'));
    });

    test('segmentChangePlaces come from the cached plan of a journey segment only', () {
      WayLeg leg(int i, String to, double lat) => WayLeg(
            legKey: 'l$i',
            index: i,
            from: const WayPlace(key: 'a', name: 'A', lat: 0, lng: 0),
            to: WayPlace(key: to, name: to, lat: lat, lng: 78.3),
            listedFare: 1000,
            geometry: [(lat: lat - 0.2, lng: 78.3), (lat: lat, lng: 78.3)],
          );
      const arrival = {'mode': 'journey', 'fromName': 'Haridwar', 'journeyId': 'j2', 'planKey': 'pk', 'cars': 2};
      final c = ctl(legsPlan(arrival: arrival));
      expect(c.segmentChangePlaces(2), isEmpty);
      TripSegmentGeometryCache.putPlan(WayPlan(planKey: 'pk', cars: 2, total: 0, legs: [leg(1, 'Rishikesh', 30.1), leg(2, 'Badrinath', 30.7)]));
      expect(c.segmentChangePlaces(2).map((p) => p.name), ['Rishikesh']);
      expect(c.segmentChangePlaces(1), isEmpty);
      const own = {'mode': 'own', 'fromName': 'Haridwar', 'how': 'bus', 'leavesAt': '06:00'};
      expect(ctl(legsPlan(arrival: own)).segmentChangePlaces(2), isEmpty);
    });

    test('travel headline, km, minutes, travel days and road minutes', () {
      const journey = {'mode': 'journey', 'fromName': 'Haridwar', 'journeyId': 'j2', 'cars': 2, 'listedTotal': 14000, 'roadMinutes': 600};
      final c = ctl(legsPlan(arrival: journey));
      expect(c.travelHeadline(2), '2 cars · about ${BrowseItem.inr(14000)}');
      expect(c.travelHeadline(1), isNull);
      expect(c.roadMinutesOf(2), 600);
      expect(c.travelDays, 1);
      expect(c.cityKm(2), 0);
      expect(c.cityMinutes(2), c.dayTotalMinutes(2) + c.dayTotalMinutes(3));
      const noTotal = {'mode': 'journey', 'fromName': 'Haridwar', 'journeyId': 'j2', 'cars': 1};
      expect(ctl(legsPlan(arrival: noTotal)).travelHeadline(2), '1 car');
      const own = {'mode': 'own', 'fromName': 'Haridwar', 'how': 'bus', 'leavesAt': '06:00'};
      expect(ctl(legsPlan(arrival: own)).travelHeadline(2), 'Own travel · Bus · 6:00 am');
      expect(ctl(legsPlan()).travelHeadline(2), isNull);
      expect(ctl(oneLeg()).travelDays, 0);
    });

    test('carLeg finds the journey car by index', () {
      const arrival = {'mode': 'journey', 'fromName': 'Haridwar', 'journeyId': 'j2', 'cars': 2};
      final p = legsPlan(start: DateTime(2030, 11, 1), arrival: arrival);
      final c = ctl(p);
      c.trip.value = _trip(p).copyWith(journeysKnown: true, journeys: [
        TripJourney(
          id: 'j2',
          fromName: 'Haridwar',
          toName: 'Badrinath',
          date: DateTime(2030, 11, 2),
          legs: const [
            TripJourneyLeg(legIndex: 1, fromName: 'Haridwar', toName: 'Rishikesh', driverName: 'Sunil Kumar'),
            TripJourneyLeg(legIndex: 2, fromName: 'Rishikesh', toName: 'Badrinath', driverName: 'Mohan Bisht'),
          ],
        ),
      ]);
      expect(c.carLeg(2, 2)?.driverName, 'Mohan Bisht');
      expect(c.carLeg(2, 3), isNull);
      expect(c.legAt(2)?.cityName, 'Badrinath');
    });
  });
}
