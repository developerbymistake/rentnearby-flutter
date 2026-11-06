import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
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

  group('trip steps JSON', () {
    test('steps key is always written as an object', () {
      final plan = TripPlan.singleCity(cityKey: 1, cityName: 'Nainital');
      final json = plan.toJson();
      expect(json['steps'], isA<Map<String, dynamic>>());
      expect((json['steps'] as Map).isEmpty, isTrue);
    });

    test('steps round-trip with start, journey, note and date', () {
      final plan = TripPlan.singleCity(
        cityKey: 1,
        cityName: 'Nainital',
        steps: TripSteps(
          startFrom: const TripStartFrom(name: 'Delhi', lat: 28.61, lon: 77.21),
          gettingThere: TripStep(status: TripStepStatus.chosen, journeyId: 'j1', date: DateTime(2026, 11, 1)),
          comingBack: const TripStep(status: TripStepStatus.own, note: 'Own car, leaving 6 am'),
        ),
      );
      final steps = plan.toJson()['steps'] as Map<String, dynamic>;
      expect((steps['gettingThere'] as Map)['date'], '2026-11-01');
      final back = TripPlan.fromJson(plan.toJson()).steps;
      expect(back.startFrom?.name, 'Delhi');
      expect(back.startFrom?.lat, 28.61);
      expect(back.gettingThere.status, TripStepStatus.chosen);
      expect(back.gettingThere.journeyId, 'j1');
      expect(back.gettingThere.date, DateTime(2026, 11, 1));
      expect(back.comingBack.status, TripStepStatus.own);
      expect(back.comingBack.note, 'Own car, leaving 6 am');
    });

    test('journeyId is never written empty and reads empty as null', () {
      const s = TripStep(status: TripStepStatus.chosen, journeyId: '');
      expect(s.toJson().containsKey('journeyId'), isFalse);
      const none = TripStep(status: TripStepStatus.skipped);
      expect(none.toJson().containsKey('journeyId'), isFalse);
      final read = TripStep.fromJson({'status': 'chosen', 'journeyId': ''});
      expect(read.journeyId, isNull);
      expect(read.hasJourney, isFalse);
    });

    test('an old plan without steps reads defaults and an unknown status reads not started', () {
      final p = TripPlan.fromJson({'cityKey': 1, 'cityName': 'Nainital'});
      expect(p.steps.startFrom, isNull);
      expect(p.steps.gettingThere.status, TripStepStatus.notStarted);
      expect(TripStep.fromJson({'status': 'weird'}).status, TripStepStatus.notStarted);
    });

    test('a default step is omitted, a set one is written', () {
      const s = TripSteps(comingBack: TripStep(status: TripStepStatus.skipped));
      final json = s.toJson();
      expect(json.containsKey('gettingThere'), isFalse);
      expect((json['comingBack'] as Map)['status'], 'skipped');
    });
  });

  group('skipped taxi day', () {
    test('no taxi this day writes skipped and no taxiId', () {
      const t = TripTaxiChoice.skippedDay();
      final json = t.toJson();
      expect(json['skipped'], isTrue);
      expect(json.containsKey('taxiId'), isFalse);
      expect(json.values.contains(''), isFalse);
      final back = TripTaxiChoice.fromJson(json);
      expect(back.isSkipped, isTrue);
      expect(back.isOwn, isFalse);
      expect(back.fare, isNull);
    });

    test('skipped survives copyWith and a day round trip', () {
      final day = TripDay(day: 1, taxi: const TripTaxiChoice.skippedDay().copyWith());
      final back = TripDay.fromJson(day.toJson());
      expect(back.taxi?.isSkipped, isTrue);
    });
  });

  group('plan v5 fields', () {
    test('dismissed ids, rest day and a skipped taxi note round trip', () {
      final p = TripPlan.singleCity(
        cityKey: 1,
        cityName: 'Nainital',
        days: const [
          TripDay(day: 1, restDay: true, taxi: TripTaxiChoice.skippedDay(note: 'Walking day')),
          TripDay(day: 2, stay: TripStayChoice.skippedNight(note: 'Night bus')),
        ],
      ).withDismissed('e1').withDismissed('e1').withDismissed('e2');
      final json = p.toJson();
      expect(json['version'], 5);
      expect(json['dismissedEnquiryIds'], ['e1', 'e2']);
      expect((json['days'] as List).first['restDay'], isTrue);
      expect(((json['days'] as List).first['taxi'] as Map)['note'], 'Walking day');
      final back = TripPlan.fromJson(json);
      expect(back.dismissedEnquiryIds, ['e1', 'e2']);
      expect(back.dayAt(1)!.restDay, isTrue);
      expect(back.dayAt(1)!.taxi!.isSkipped, isTrue);
      expect(back.dayAt(1)!.taxi!.note, 'Walking day');
      expect(back.dayAt(2)!.stay!.note, 'Night bus');
      expect(back.dayAt(2)!.restDay, isFalse);
    });

    test('dismissed list keeps the newest 100', () {
      var p = TripPlan.singleCity(cityKey: 1, cityName: 'Nainital');
      for (var i = 0; i < 105; i++) {
        p = p.withDismissed('e$i');
      }
      expect(p.dismissedEnquiryIds.length, 100);
      expect(p.dismissedEnquiryIds.first, 'e5');
    });

    test('leave-on and own cars round trip; notNeeded is written back as notStarted', () {
      const steps = TripSteps(
        gettingThere: TripStep(status: TripStepStatus.chosen, journeyId: 'j1', ownCars: [2]),
        comingBack: TripStep(status: TripStepStatus.notNeeded, leaveOn: TripLeaveOn.lastDayEvening),
      );
      final json = steps.toJson();
      expect((json['gettingThere'] as Map)['ownCars'], [2]);
      expect((json['comingBack'] as Map)['leaveOn'], 'lastDayEvening');
      expect((json['comingBack'] as Map)['status'], 'notStarted');
      final back = TripSteps.fromJson(json);
      expect(back.gettingThere.ownCars, [2]);
      expect(back.comingBack.leaveOn, TripLeaveOn.lastDayEvening);
      expect(TripStep.fromJson({'status': 'notStarted', 'leaveOn': 'later', 'ownCars': [0, 2, 2, 9]}).ownCars, [2]);
      expect(TripStep.fromJson({'leaveOn': 'later'}).leaveOn, isNull);
      expect(const TripStep(leaveOn: TripLeaveOn.checkOut).isDefault, isFalse);
      expect(const TripStep(leaveOn: TripLeaveOn.lastDayEvening, ownCars: [1]).cleared.ownCars, isEmpty);
      expect(const TripStep(leaveOn: TripLeaveOn.lastDayEvening).cleared.leaveOn, TripLeaveOn.lastDayEvening);
    });

    test('a segment keeps own cars until the journey changes', () {
      const a = TripTravel.journey(fromName: 'Nainital', journeyId: 'j1', cars: 2);
      final own = a.withOwnCar(2, true);
      expect(own.ownCars, [2]);
      expect(TripTravel.fromJson(own.toJson()).ownCars, [2]);
      expect(own.copyWith(journeyId: 'j2').ownCars, isEmpty);
      expect(const TripTravel.own(fromName: 'Nainital').withOwnCar(1, true).ownCars, isEmpty);
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

  group('plan v4 legs', () {
    Map<String, dynamic> twoLegJson() => {
          'version': 4,
          'cityKey': 1,
          'cityName': 'Haridwar',
          'centreLatitude': 29.95,
          'centreLongitude': 78.16,
          'legs': [
            {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'districtId': 'd1', 'latitude': 29.95, 'longitude': 78.16},
            {
              'index': 2,
              'cityKey': 2,
              'cityName': 'Badrinath',
              'latitude': 30.74,
              'longitude': 79.49,
              'notReady': true,
              'arrival': {'mode': 'own', 'fromName': 'Haridwar', 'how': 'bus', 'leavesAt': '06:45', 'roadMinutes': 450},
            },
          ],
          'days': [
            {'day': 1, 'leg': 1},
            {'day': 2, 'leg': 2},
            {'day': 3, 'leg': 2},
          ],
          'settings': {'startDate': '2026-11-01'},
        };

    test('a v3 document reads as one leg and every day is leg 1', () {
      final p = TripPlan.fromJson({
        'version': 3,
        'cityKey': 1,
        'cityName': 'Nainital',
        'days': [
          {'day': 1},
          {'day': 2},
        ],
      });
      expect(p.legCount, 1);
      expect(p.isMultiCity, isFalse);
      expect(p.cityName, 'Nainital');
      expect(p.days.every((d) => d.leg == 1), isTrue);
    });

    test('empty legs read as one leg from the city fields', () {
      final p = TripPlan.fromJson({
        'cityKey': 5,
        'cityName': 'Almora',
        'legs': [],
        'days': [
          {'day': 1},
        ],
      });
      expect(p.legs.length, 1);
      expect(p.legs.first.cityKey, 5);
    });

    test('a day without leg takes the previous leg and a decreasing leg is raised', () {
      final json = twoLegJson();
      (json['days'] as List)[2] = {'day': 3};
      var p = TripPlan.fromJson(json);
      expect(p.days.map((d) => d.leg).toList(), [1, 2, 2]);
      final dec = twoLegJson();
      (dec['days'] as List)[2] = {'day': 3, 'leg': 1};
      p = TripPlan.fromJson(dec);
      expect(p.days.map((d) => d.leg).toList(), [1, 2, 2]);
    });

    test('two legs round trip keeps legs, leg, arrival and the leg 1 copies', () {
      final p = TripPlan.fromJson(twoLegJson());
      final json = p.toJson();
      expect(json['version'], 5);
      expect(json['cityName'], 'Haridwar');
      expect((json['legs'] as List).length, 2);
      expect(((json['days'] as List)[2] as Map)['leg'], 2);
      final back = TripPlan.fromJson(json);
      final arrival = back.legs[1].arrival;
      expect(arrival?.how, TripTravelHow.bus);
      expect(arrival?.leavesAt, '06:45');
      expect(arrival?.roadMinutes, 450);
      expect(back.legs[1].notReady, isTrue);
      expect(back.legs.first.districtId, 'd1');
    });

    test('toJson always writes legs for a single-city plan', () {
      final json = TripPlan.singleCity(cityKey: 1, cityName: 'Nainital', days: const [TripDay(day: 1)]).toJson();
      expect((json['legs'] as List).length, 1);
      expect(json['version'], 5);
    });

    test('leg helpers', () {
      final p = TripPlan.fromJson(twoLegJson());
      expect(p.legStart(1), 1);
      expect(p.legEnd(1), 1);
      expect(p.legStart(2), 2);
      expect(p.legEnd(2), 3);
      expect(p.legDayCount(2), 2);
      expect(p.daysOf(2).map((d) => d.day).toList(), [2, 3]);
      expect(p.isTravelDay(1), isFalse);
      expect(p.isTravelDay(2), isTrue);
      expect(p.isTravelDay(3), isFalse);
      expect(p.cityNameOf(3), 'Badrinath');
      expect(p.legCities, ['Haridwar', 'Badrinath']);
    });

    test('steps survive a v4 round trip', () {
      final json = twoLegJson();
      json['steps'] = {
        'startFrom': {'name': 'Delhi', 'lat': 28.61, 'lon': 77.21},
      };
      final back = TripPlan.fromJson(TripPlan.fromJson(json).toJson());
      expect(back.steps.startFrom?.name, 'Delhi');
    });
  });

  group('travel between cities (MC-B)', () {
    test('journey arrival round trip writes mode journey and no own fields', () {
      const t = TripTravel.journey(fromName: 'Haridwar', journeyId: 'j1', planKey: 'k1', cars: 2, listedTotal: 14000, roadMinutes: 600);
      final json = t.toJson();
      expect(json['mode'], 'journey');
      expect(json['journeyId'], 'j1');
      expect(json.containsKey('how'), isFalse);
      expect(json.containsKey('hubName'), isFalse);
      final back = TripTravel.fromJson(json);
      expect(back.isJourney, isTrue);
      expect(back.isOwn, isFalse);
      expect(back.cars, 2);
      expect(back.listedTotal, 14000);
      expect(back.roadMinutes, 600);
    });

    test('journey mode without an id reads as own; own keeps the hub and never writes journeyId', () {
      expect(TripTravel.fromJson({'mode': 'journey', 'fromName': 'Haridwar', 'journeyId': ''}).isOwn, isTrue);
      const own = TripTravel.own(fromName: 'Haridwar', how: TripTravelHow.train, hubName: 'Rishikesh');
      final json = own.toJson();
      expect(json.containsKey('journeyId'), isFalse);
      expect(TripTravel.fromJson(json).hubName, 'Rishikesh');
    });

    test('segmentLegOf finds the leg of a journey, steps never count', () {
      final p = TripPlan.fromJson({
        'version': 4,
        'cityKey': 1,
        'cityName': 'Haridwar',
        'legs': [
          {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'latitude': 29.95, 'longitude': 78.16},
          {
            'index': 2,
            'cityKey': 2,
            'cityName': 'Badrinath',
            'latitude': 30.74,
            'longitude': 79.49,
            'arrival': {'mode': 'journey', 'fromName': 'Haridwar', 'journeyId': 'j2', 'cars': 2},
          },
        ],
        'steps': {
          'gettingThere': {'status': 'chosen', 'journeyId': 'j1'},
        },
        'days': [
          {'day': 1, 'leg': 1},
          {'day': 2, 'leg': 2},
        ],
      });
      expect(p.segmentLegOf('j2'), 2);
      expect(p.segmentLegOf('j1'), isNull);
      expect(p.segmentLegOf(''), isNull);
      expect(p.segmentJourneyIds, ['j2']);
      expect(TripPlan.fromJson(p.toJson()).legs[1].arrival?.journeyId, 'j2');
    });

    test('a segment row is a dated taxi row of the trip that carries a journey', () {
      const seg = TripEnquiryModel(
        id: 'e1',
        tripId: 't1',
        kind: TripEnquiryKinds.taxi,
        day: 2,
        context: TripEnquiryContext(journeyId: 'j2', journeyLegIndex: 1),
      );
      const local = TripEnquiryModel(id: 'e2', tripId: 't1', kind: TripEnquiryKinds.taxi, days: [2]);
      expect(seg.isSegment, isTrue);
      expect(local.isSegment, isFalse);
      expect(TripEnquiryModel.fromJson({'id': 'e3', 'kind': 'Taxi', 'isSegment': true}).isSegment, isTrue);
      final parsed = TripEnquiryModel.fromJson({
        'id': 'e4',
        'kind': 'Taxi',
        'context': {'journeyId': 'j2', 'journeyLegIndex': 2},
      });
      expect(parsed.context.journeyId, 'j2');
      expect(parsed.context.journeyLegIndex, 2);
    });
  });
}
