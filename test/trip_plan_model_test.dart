import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_constants.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _spot(String id) => {
      'id': id,
      'name': 'Spot $id',
      'latitude': 29.39,
      'longitude': 79.46,
      'category': 'lake',
      'visitMinutes': 90,
    };

Map<String, dynamic> _contractPlan() => {
      'version': 6,
      'cityKey': 210000123,
      'districtId': '56d120de',
      'cityName': 'Nainital',
      'centreLatitude': 29.38,
      'centreLongitude': 79.45,
      'legs': [
        {
          'index': 1,
          'cityKey': 210000123,
          'cityName': 'Nainital',
          'districtId': '56d120de',
          'latitude': 29.38,
          'longitude': 79.45,
          'stayMark': {'status': 'own'},
        },
        {
          'index': 2,
          'cityKey': 210000456,
          'cityName': 'Almora',
          'latitude': 29.59,
          'longitude': 79.65,
          'notReady': true,
          'arrival': {
            'fromName': 'Nainital',
            'journeyId': 'b2c3',
            'planKey': 'd:1',
            'cars': 2,
            'listedTotal': 5600,
            'roadMinutes': 100,
            'ownCars': [2],
          },
        },
      ],
      'days': [
        {
          'day': 1,
          'leg': 1,
          'spots': [_spot('Q1')],
        },
        {'day': 2, 'leg': 1, 'restDay': true, 'spots': []},
        {
          'day': 3,
          'leg': 2,
          'spots': [_spot('Q2'), _spot('Q3')],
        },
      ],
      'settings': {'dayLimitMinutes': 300, 'startDate': '2026-11-20', 'adults': 2, 'kids': 0},
      'steps': {
        'startFrom': {'name': 'Delhi', 'lat': 28.61, 'lon': 77.21},
        'gettingThere': {'status': 'chosen', 'journeyId': 'a1b2', 'ownCars': []},
        'comingBack': {'status': 'skipped', 'leaveOn': 'checkOut'},
      },
      'taxiMark': {'status': 'skipped'},
      'dismissedEnquiryIds': ['e1'],
    };

void main() {
  group('plan round trip (contract 2.1)', () {
    test('every field survives and the version is 7', () {
      final p = TripPlan.fromJson(_contractPlan());
      final json = p.toJson();
      expect(json['version'], 7);
      final back = TripPlan.fromJson(json);
      expect(back.legs.length, 2);
      expect(back.legs[0].stayMark?.isOwn, isTrue);
      expect(back.legs[1].arrival?.journeyId, 'b2c3');
      expect(back.legs[1].arrival?.ownCars, [2]);
      expect(back.legs[1].notReady, isTrue);
      expect(back.days.length, 3);
      expect(back.dayAt(2)!.restDay, isTrue);
      expect(back.dayAt(3)!.spots.length, 2);
      expect(back.settings.dayLimitMinutes, 300);
      expect(back.settings.startDate, DateTime(2026, 11, 20));
      expect(back.settings.adults, 2);
      expect(back.settings.kids, 0);
      expect(back.steps.gettingThere.status, TripStepStatus.chosen);
      expect(back.steps.comingBack.status, TripStepStatus.skipped);
      expect(back.taxiMark?.isSkipped, isTrue);
      expect(back.dismissedEnquiryIds, ['e1']);
      expect(back.cityName, 'Nainital');
    });

    test('an old version in the document is written back as 7', () {
      final json = _contractPlan()..['version'] = 3;
      expect(TripPlan.fromJson(json).toJson()['version'], TripConstants.planVersion);
      expect(TripConstants.planVersion, 7);
    });

    test('no dead v5 keys are written', () {
      final json = TripPlan.fromJson(_contractPlan()
            ..['days'] = [
              {
                'day': 1,
                'leg': 1,
                'taxi': {'taxiId': 'x', 'name': 'T'},
                'stay': {'stayId': 's', 'name': 'S'},
                'stayShortlist': [
                  {'stayId': 's', 'name': 'S'}
                ],
                'taxiShortlist': [
                  {'taxiId': 'x', 'name': 'T'}
                ],
                'spots': [_spot('Q1')],
              }
            ]
            ..['settings'] = {'dayLimitMinutes': 450, 'rooms': 2, 'needs': ['no_stairs'], 'pickupTime': '08:30', 'pickupPlace': 'Gate'}
            ..['steps'] = {
              'gettingThere': {'status': 'own', 'note': 'x', 'how': 'bus', 'ownName': 'A', 'ownPhone': '9876543210', 'leavesAt': '06:00'},
              'comingBack': {'status': 'notNeeded'},
            })
          .toJson();
      final day = (json['days'] as List).first as Map;
      for (final k in ['taxi', 'stay', 'stayShortlist', 'taxiShortlist']) {
        expect(day.containsKey(k), isFalse, reason: k);
      }
      final settings = json['settings'] as Map;
      for (final k in ['rooms', 'needs', 'pickupTime', 'pickupPlace']) {
        expect(settings.containsKey(k), isFalse, reason: k);
      }
      final steps = json['steps'] as Map;
      final g = steps['gettingThere'] as Map;
      for (final k in ['note', 'how', 'ownName', 'ownPhone', 'leavesAt']) {
        expect(g.containsKey(k), isFalse, reason: k);
      }
      expect(g['status'], 'own');
      expect(steps.containsKey('comingBack'), isFalse);
    });

    test('dates and people may all be missing', () {
      final p = TripPlan.singleCity(cityKey: 1, cityName: 'Nainital', days: const [TripDay(day: 1)]);
      final s = p.toJson()['settings'] as Map;
      expect(s.containsKey('startDate'), isFalse);
      expect(s.containsKey('adults'), isFalse);
      expect(s['dayLimitMinutes'], 300);
      expect(p.settings.hasDates, isFalse);
      expect(p.settings.hasPeople, isFalse);
      expect(p.settings.dateOf(1), isNull);
    });
  });

  group('row marks', () {
    test('mark JSON carries only the status', () {
      expect(const TripRowMark.own().toJson(), {'status': 'own'});
      expect(const TripRowMark.skipped().toJson(), {'status': 'skipped'});
      expect(TripRowMark.fromJson({'status': 'own'}).isOwn, isTrue);
      expect(TripRowMark.fromJson({'status': 'skipped'}).isSkipped, isTrue);
      expect(TripRowMark.tryParse({'status': 'weird'}), isNull);
      expect(TripRowMark.tryParse('own'), isNull);
      expect(const TripRowMark.own(), const TripRowMark.own());
    });

    test('stay mark is written on any leg, travel mark only on legs 2 and up without an arrival', () {
      final p = TripPlan.fromJson(_contractPlan());
      final marked = p.withStayMark(2, const TripRowMark.skipped()).withTravelMark(2, const TripRowMark.own());
      final legs = marked.toJson()['legs'] as List;
      expect((legs[0] as Map)['stayMark'], {'status': 'own'});
      expect((legs[1] as Map)['stayMark'], {'status': 'skipped'});
      expect((legs[1] as Map)['travelMark'], {'status': 'own'});
      expect((legs[1] as Map).containsKey('arrival'), isFalse);
      expect((legs[0] as Map).containsKey('travelMark'), isFalse);
    });

    test('a travel mark on leg 1 is refused and leg 1 never reads one', () {
      final p = TripPlan.fromJson(_contractPlan());
      expect(identical(p.withTravelMark(1, const TripRowMark.own()), p), isTrue);
      final read = TripCityLeg.fromJson({'index': 1, 'cityKey': 1, 'cityName': 'A', 'travelMark': {'status': 'own'}});
      expect(read.travelMark, isNull);
    });

    test('marking travel own clears the arrival and an undo clears the mark', () {
      final p = TripPlan.fromJson(_contractPlan());
      final own = p.withTravelMark(2, const TripRowMark.own());
      expect(own.legAt(2)!.arrival, isNull);
      expect(own.legAt(2)!.travelMark?.isOwn, isTrue);
      final undone = own.withTravelMark(2, null);
      expect(undone.legAt(2)!.travelMark, isNull);
      expect(undone.withStayMark(1, null).legAt(1)!.stayMark, isNull);
    });

    test('taxi mark set, written and cleared', () {
      var p = TripPlan.singleCity(cityKey: 1, cityName: 'Nainital');
      expect(p.toJson().containsKey('taxiMark'), isFalse);
      p = p.withTaxiMark(const TripRowMark.own());
      expect(p.toJson()['taxiMark'], {'status': 'own'});
      expect(TripPlan.fromJson(p.toJson()).taxiMark?.isOwn, isTrue);
      expect(p.withTaxiMark(null).taxiMark, isNull);
      expect(p.copyWith(days: const [TripDay(day: 1)]).taxiMark?.isOwn, isTrue);
    });

    test('the first leg drops a travel mark on reindex', () {
      const leg = TripCityLeg(index: 2, cityKey: 2, cityName: 'B', latitude: 0, longitude: 0, travelMark: TripRowMark.own());
      expect(TripPlan.reindex([leg]).first.travelMark, isNull);
    });
  });

  group('row keys and states', () {
    test('key id and parse', () {
      expect(const TripEasyRowKey(TripEasyRowKind.gettingThere).id, 'gettingThere');
      expect(const TripEasyRowKey(TripEasyRowKind.stay, 2).id, 'stay:2');
      expect(TripEasyRowKey.parse('between:3'), const TripEasyRowKey(TripEasyRowKind.between, 3));
      expect(TripEasyRowKey.parse('taxi'), const TripEasyRowKey(TripEasyRowKind.taxi));
      expect(TripEasyRowKey.parse('comingBack')?.kind, TripEasyRowKind.comingBack);
      expect(TripEasyRowKey.parse('stay:x'), isNull);
      expect(TripEasyRowKey.parse('stay:0'), isNull);
      expect(TripEasyRowKey.parse('stay:1:2'), isNull);
      expect(TripEasyRowKey.parse('nope'), isNull);
      expect(TripEasyRowKey.parse(''), isNull);
      expect(TripEasyRowKey.parse(null), isNull);
      expect(const TripEasyRowKey(TripEasyRowKind.stay, 1).hashCode, const TripEasyRowKey(TripEasyRowKind.stay, 1).hashCode);
      expect(const TripEasyRowKey(TripEasyRowKind.stay, 1) == const TripEasyRowKey(TripEasyRowKind.stay, 2), isFalse);
    });

    test('state done, in progress and parse', () {
      for (final s in [TripRowState.confirmed, TripRowState.own, TripRowState.saved]) {
        expect(s.isDone, isTrue, reason: s.name);
        expect(s.inProgress, isFalse);
      }
      for (final s in [TripRowState.asked, TripRowState.offer]) {
        expect(s.inProgress, isTrue, reason: s.name);
        expect(s.isDone, isFalse);
      }
      for (final s in [TripRowState.todo, TripRowState.skipped, TripRowState.attention]) {
        expect(s.isDone || s.inProgress, isFalse, reason: s.name);
      }
      expect(TripRowState.parse('offer'), TripRowState.offer);
      expect(TripRowState.parse('attention'), TripRowState.attention);
      expect(TripRowState.parse('weird'), TripRowState.todo);
      expect(TripRowState.parse(null), TripRowState.todo);
    });

    test('mark result family', () {
      const TripMarkResult a = TripMarked();
      expect(a, isA<TripMarked>());
      const e = TripEnquiryModel(id: 'e1');
      final n = TripMarkNeedsWithdraw(const [e]);
      expect(n.open.single.id, 'e1');
      expect(const TripMarkBlocked(e).confirmed.id, 'e1');
    });
  });

  group('trip steps JSON', () {
    test('steps key is always written as an object', () {
      final plan = TripPlan.singleCity(cityKey: 1, cityName: 'Nainital');
      final json = plan.toJson();
      expect(json['steps'], isA<Map<String, dynamic>>());
      expect((json['steps'] as Map).isEmpty, isTrue);
    });

    test('steps round-trip with start, journey and date', () {
      final plan = TripPlan.singleCity(
        cityKey: 1,
        cityName: 'Nainital',
        steps: TripSteps(
          startFrom: const TripStartFrom(name: 'Delhi', lat: 28.61, lon: 77.21),
          gettingThere: TripStep(status: TripStepStatus.chosen, journeyId: 'j1', date: DateTime(2026, 11, 1)),
          comingBack: const TripStep(status: TripStepStatus.own),
        ),
      );
      final steps = plan.toJson()['steps'] as Map<String, dynamic>;
      expect((steps['gettingThere'] as Map)['date'], '2026-11-01');
      expect(steps['comingBack'], {'status': 'own'});
      final back = TripPlan.fromJson(plan.toJson()).steps;
      expect(back.startFrom?.name, 'Delhi');
      expect(back.gettingThere.status, TripStepStatus.chosen);
      expect(back.gettingThere.journeyId, 'j1');
      expect(back.gettingThere.date, DateTime(2026, 11, 1));
      expect(back.comingBack.status, TripStepStatus.own);
    });

    test('journeyId is never written empty and reads empty as null', () {
      const s = TripStep(status: TripStepStatus.chosen, journeyId: '');
      expect(s.toJson().containsKey('journeyId'), isFalse);
      final read = TripStep.fromJson({'status': 'chosen', 'journeyId': ''});
      expect(read.journeyId, isNull);
      expect(read.hasJourney, isFalse);
    });

    test('an unknown or removed status reads not started', () {
      expect(TripStep.fromJson({'status': 'weird'}).status, TripStepStatus.notStarted);
      expect(TripStep.fromJson({'status': 'notNeeded'}).status, TripStepStatus.notStarted);
      expect(TripStepStatus.values.map((s) => s.name), ['notStarted', 'chosen', 'booked', 'own', 'skipped']);
    });

    test('leave-on and own cars round trip, a default step is omitted', () {
      const steps = TripSteps(
        gettingThere: TripStep(status: TripStepStatus.chosen, journeyId: 'j1', ownCars: [2]),
        comingBack: TripStep(status: TripStepStatus.skipped, leaveOn: TripLeaveOn.lastDayEvening),
      );
      final json = steps.toJson();
      expect((json['gettingThere'] as Map)['ownCars'], [2]);
      expect((json['comingBack'] as Map)['leaveOn'], 'lastDayEvening');
      final back = TripSteps.fromJson(json);
      expect(back.gettingThere.ownCars, [2]);
      expect(back.comingBack.leaveOn, TripLeaveOn.lastDayEvening);
      expect(TripStep.fromJson({'status': 'notStarted', 'ownCars': [0, 2, 2, 9]}).ownCars, [2]);
      expect(const TripStep(leaveOn: TripLeaveOn.checkOut).isDefault, isFalse);
      expect(const TripStep(leaveOn: TripLeaveOn.lastDayEvening, ownCars: [1]).cleared.ownCars, isEmpty);
      expect(const TripSteps().toJson().containsKey('gettingThere'), isFalse);
    });

    test('copyWith keeps the journey link only until it is cleared', () {
      const s = TripStep(status: TripStepStatus.chosen, journeyId: 'j1', ownCars: [1]);
      final own = s.copyWith(status: TripStepStatus.own, clearJourney: true);
      expect(own.status, TripStepStatus.own);
      expect(own.journeyId, isNull);
      expect(own.ownCars, isEmpty);
    });
  });

  group('plan v6 fields', () {
    test('dismissed ids and rest day round trip', () {
      final p = TripPlan.singleCity(
        cityKey: 1,
        cityName: 'Nainital',
        days: const [TripDay(day: 1, restDay: true), TripDay(day: 2)],
      ).withDismissed('e1').withDismissed('e1').withDismissed('e2');
      final back = TripPlan.fromJson(p.toJson());
      expect(back.dismissedEnquiryIds, ['e1', 'e2']);
      expect(back.dayAt(1)!.restDay, isTrue);
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

    test('a segment keeps own cars until the journey changes', () {
      const a = TripTravel(fromName: 'Nainital', journeyId: 'j1', cars: 2);
      final own = a.withOwnCar(2, true);
      expect(own.ownCars, [2]);
      expect(TripTravel.tryParse(own.toJson())!.ownCars, [2]);
      expect(own.copyWith(journeyId: 'j2').ownCars, isEmpty);
    });

    test('a day carries only places, leg and rest flag', () {
      const d = TripDay(day: 2, leg: 2, restDay: true);
      expect(d.toJson(), {'day': 2, 'leg': 2, 'spots': <dynamic>[], 'restDay': true});
    });
  });

  group('settings', () {
    test('check-out is the morning after the last day', () {
      final s = TripSettings(startDate: DateTime(2026, 11, 1));
      expect(s.dateOf(3), DateTime(2026, 11, 3));
      expect(s.checkOutDate(3), DateTime(2026, 11, 4));
      expect(s.checkOutDate(1), DateTime(2026, 11, 2));
      expect(s.endDate(3), DateTime(2026, 11, 3));
    });

    test('pace default is relaxed and the flag follows the minutes', () {
      expect(const TripSettings().dayLimitMinutes, TripPace.relaxed);
      expect(const TripSettings().isRelaxed, isTrue);
      expect(const TripSettings(dayLimitMinutes: TripPace.normal).isRelaxed, isFalse);
      expect(const TripSettings().copyWith(dayLimitMinutes: TripPace.normal).dayLimitMinutes, 450);
    });

    test('people helpers', () {
      const s = TripSettings(adults: 2, kids: 1);
      expect(s.hasPeople, isTrue);
      expect(s.peopleCount, 3);
      expect(s.peopleSummary, '2 adults, 1 kid');
      expect(const TripSettings(adults: 1).peopleSummary, '1 adult');
      expect(const TripSettings().peopleSummary, isNull);
    });

    test('maxDays round-trips and out-of-range values read as auto', () {
      const s = TripSettings(maxDays: 1);
      expect(TripSettings.fromJson(s.toJson()).maxDays, 1);
      expect(TripSettings.fromJson({'maxDays': 0}).maxDays, isNull);
      expect(TripSettings.fromJson({'maxDays': 15}).maxDays, isNull);
      expect(const TripSettings().toJson().containsKey('maxDays'), isFalse);
      expect(s.copyWith(clearMaxDays: true).maxDays, isNull);
    });

    test('max places per day constant', () {
      expect(TripConstants.maxSpotsPerDay, 6);
    });
  });

  group('legs', () {
    Map<String, dynamic> twoLegJson() => {
          'version': 6,
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
              'arrival': {'fromName': 'Haridwar', 'journeyId': 'j9', 'roadMinutes': 450},
            },
          ],
          'days': [
            {'day': 1, 'leg': 1},
            {'day': 2, 'leg': 2},
            {'day': 3, 'leg': 2},
          ],
          'settings': {'startDate': '2026-11-01'},
        };

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
      expect(p.isMultiCity, isFalse);
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
      expect(json['cityName'], 'Haridwar');
      expect((json['legs'] as List).length, 2);
      expect(((json['days'] as List)[2] as Map)['leg'], 2);
      final back = TripPlan.fromJson(json);
      expect(back.legs[1].arrival?.journeyId, 'j9');
      expect(back.legs[1].arrival?.roadMinutes, 450);
      expect(back.legs[1].notReady, isTrue);
      expect(back.legs.first.districtId, 'd1');
    });

    test('an arrival without a journey id is dropped', () {
      final json = twoLegJson();
      ((json['legs'] as List)[1] as Map)['arrival'] = {'fromName': 'Haridwar', 'journeyId': ''};
      expect(TripPlan.fromJson(json).legs[1].arrival, isNull);
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

    test('segmentLegOf finds the leg of a journey, steps never count', () {
      final json = twoLegJson();
      json['steps'] = {
        'gettingThere': {'status': 'chosen', 'journeyId': 'j1'},
      };
      final p = TripPlan.fromJson(json);
      expect(p.segmentLegOf('j9'), 2);
      expect(p.segmentLegOf('j1'), isNull);
      expect(p.segmentLegOf(''), isNull);
      expect(p.segmentJourneyIds, ['j9']);
      expect(TripPlan.fromJson(p.toJson()).legs[1].arrival?.journeyId, 'j9');
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
    });
  });

  group('guide (plan v7)', () {
    test('a v6 document parses with no guide and writes version 7', () {
      final p = TripPlan.fromJson(_contractPlan());
      expect(p.guide, isNull);
      expect(p.toJson().containsKey('guide'), isFalse);
      expect(p.toJson()['version'], 7);
    });

    test('guide round-trips step, choices and overview', () {
      final json = _contractPlan()
        ..['version'] = 7
        ..['guide'] = {
          'step': 'stay:2',
          'choices': {'gettingThere': 'find', 'stay:1': 'skip', 'taxi': 'own'},
          'overview': true,
        };
      final g = TripPlan.fromJson(json).guide!;
      expect(g.step, 'stay:2');
      expect(g.overview, isTrue);
      expect(g.choices['stay:1'], TripGuideChoice.skip);
      final back = TripPlan.fromJson(TripPlan.fromJson(json).toJson()).guide!;
      expect(back, g);
    });

    test('unknown step and choice values are dropped on read', () {
      final json = _contractPlan()
        ..['guide'] = {
          'step': 'finish',
          'choices': {'gettingThere': 'maybe', 'bogus': 'find', 'taxi': 'skip'},
        };
      final g = TripPlan.fromJson(json).guide!;
      expect(g.step, isEmpty);
      expect(g.choices.keys, ['taxi']);
    });

    test('a default guide is not written', () {
      final p = TripPlan.fromJson(_contractPlan()).withGuide(const TripGuide());
      expect(p.guide, isNull);
      expect(p.toJson().containsKey('guide'), isFalse);
    });

    test('at most 30 choices are kept', () {
      var g = const TripGuide();
      for (var i = 2; i < 40; i++) {
        g = g.withChoice('stay:$i', TripGuideChoice.skip);
      }
      expect(g.choices.length, TripGuide.maxChoices);
    });
  });
}
