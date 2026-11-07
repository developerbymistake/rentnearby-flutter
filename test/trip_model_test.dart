import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_summary_model.dart';
import 'package:bakhli/features/trip/utils/trip_travel_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _raw({bool legs = true}) => {
      'id': 't1',
      'title': 'Haridwar, Badrinath trip',
      'cityKey': 1,
      'cityName': 'Haridwar',
      'dayCount': 3,
      if (legs) 'legCount': 2,
      if (legs) 'legCities': ['Haridwar', 'Badrinath'],
      'plan': {
        'version': 6,
        'cityKey': 1,
        'cityName': 'Haridwar',
        'legs': [
          {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'latitude': 29.95, 'longitude': 78.16},
          {'index': 2, 'cityKey': 2, 'cityName': 'Badrinath', 'latitude': 30.74, 'longitude': 79.49},
        ],
        'days': [
          {'day': 1, 'leg': 1},
          {'day': 2, 'leg': 2},
          {'day': 3, 'leg': 2},
        ],
      },
    };

void main() {
  group('TripModel legs', () {
    test('two-leg JSON parses count, cities and route line', () {
      final t = TripModel.fromJson(_raw());
      expect(t.legCount, 2);
      expect(t.legCities, ['Haridwar', 'Badrinath']);
      expect(t.routeLine, 'Haridwar → Badrinath');
      expect(t.plan.legCount, 2);
    });

    test('a one-city JSON defaults to one leg and the city name', () {
      final t = TripModel.fromJson(_raw(legs: false));
      expect(t.legCount, 1);
      expect(t.legCities, ['Haridwar']);
      expect(t.routeLine, 'Haridwar');
    });

    test('copyWith keeps the leg fields', () {
      final t = TripModel.fromJson(_raw()).copyWith(title: 'x');
      expect(t.legCount, 2);
      expect(t.routeLine, 'Haridwar → Badrinath');
    });

    test('the raw map the offline cache stores parses back to the same legs', () {
      final t = TripModel.fromJson(_raw());
      final again = TripModel.fromJson(t.raw!);
      expect(again.plan.legs.length, 2);
      expect(again.plan.days.last.leg, 2);
      expect(again.legCities, t.legCities);
    });
  });

  group('TripSummaryModel legs', () {
    Map<String, dynamic> json({bool legs = true}) => {
          'id': 't1',
          'cityName': 'Haridwar',
          'dayCount': 3,
          if (legs) 'legCount': 2,
          if (legs) 'legCities': ['Haridwar', 'Badrinath'],
        };

    test('parses legs', () {
      final s = TripSummaryModel.fromJson(json());
      expect(s.legCount, 2);
      expect(s.routeLine, 'Haridwar → Badrinath');
      expect(s.asCompleted(null).legCount, 2);
    });

    test('old JSON defaults to one city', () {
      final s = TripSummaryModel.fromJson(json(legs: false));
      expect(s.legCount, 1);
      expect(s.legCities, ['Haridwar']);
      expect(s.routeLine, 'Haridwar');
    });

    test('summary record cities default to the city and give a route', () {
      expect(TripSummaryRecord.fromJson({'tripId': 'a', 'city': 'Nainital'}).routeLine, 'Nainital');
      final r = TripSummaryRecord.fromJson({
        'tripId': 'a',
        'city': 'Haridwar',
        'legCities': ['Haridwar', 'Badrinath'],
      });
      expect(r.cities.length, 2);
      expect(r.routeLine, 'Haridwar → Badrinath');
    });
  });

  group('progress v2 on the list', () {
    Map<String, dynamic> progress() => {
          'total': 6,
          'done': 2,
          'inProgress': 1,
          'attention': 1,
          'percent': 33,
          'needsYou': true,
          'next': {'kind': 'taxi', 'legIndex': null, 'key': 'taxi'},
          'lastEventAt': '2030-11-01T10:00:00Z',
          'rows': [
            {'key': 'gettingThere', 'kind': 'gettingThere', 'legIndex': null, 'state': 'saved', 'needsYou': false, 'askedCount': 0},
            {'key': 'stay:1', 'kind': 'stay', 'legIndex': 1, 'state': 'asked', 'needsYou': false, 'askedCount': 2},
            {'key': 'between:2', 'kind': 'between', 'legIndex': 2, 'state': 'own', 'needsYou': false, 'askedCount': 0},
            {'key': 'stay:2', 'kind': 'stay', 'legIndex': 2, 'state': 'offer', 'needsYou': true, 'askedCount': 1},
            {'key': 'taxi', 'kind': 'taxi', 'legIndex': null, 'state': 'attention', 'needsYou': false, 'askedCount': 0},
            {'key': 'comingBack', 'kind': 'comingBack', 'legIndex': null, 'state': 'skipped', 'needsYou': false, 'askedCount': 0},
          ],
        };

    test('numbers, next row and rows parse from the server DTO', () {
      final s = TripSummaryModel.fromJson({'id': 't1', 'cityName': 'Nainital', 'progress': progress()});
      final pr = s.progress;
      expect((pr.total, pr.done, pr.inProgress, pr.attention, pr.percent), (6, 2, 1, 1, 33));
      expect(pr.needsYou, isTrue);
      expect(pr.next?.key, 'taxi');
      expect(pr.next?.kind, 'taxi');
      expect(pr.next?.legIndex, isNull);
      expect(pr.next?.rowKey, const TripEasyRowKey(TripEasyRowKind.taxi));
      expect(pr.lastEventAt, isNotNull);
      expect(pr.isReady, isFalse);
      expect(pr.rows.length, 6);
      expect(pr.rows[1].key, const TripEasyRowKey(TripEasyRowKind.stay, 1));
      expect(pr.rows[1].state, TripRowState.asked);
      expect(pr.rows[1].askedCount, 2);
      expect(pr.rows[1].kind, TripEasyRowKind.stay);
      expect(pr.rows[1].legIndex, 1);
      expect(pr.rows[3].needsYou, isTrue);
      expect(pr.rows[3].state, TripRowState.offer);
      expect(pr.rows[5].state, TripRowState.skipped);
      final cover = TripEasyRowModel.tryParse(
          {'key': 'stay:1', 'state': 'booked', 'nightsTotal': 3, 'nightsCovered': 2})!;
      expect(cover.state, TripRowState.booked);
      expect((cover.nightsTotal, cover.nightsCovered), (3, 2));
      expect(pr.rows[0].nightsTotal, isNull);
      expect(s.withMuted(null).progress.done, 2);
    });

    test('dropped fields are not read back', () {
      final pr = TripProgress.tryParse({'total': 6, 'counted': 4, 'decided': 3, 'waitingForReply': 2, 'needYou': 1})!;
      expect(pr.done, 0);
      expect(pr.inProgress, 0);
      expect(pr.needsYou, isFalse);
    });

    test('an older server has no progress; bad numbers are clamped', () {
      expect(TripSummaryModel.fromJson({'id': 't1', 'cityName': 'A'}).progress.total, 0);
      expect(TripSummaryModel.fromJson({'id': 't1', 'cityName': 'A'}).progress.rows, isEmpty);
      final pr = TripProgress.tryParse({
        'total': 6,
        'done': 9,
        'next': {'key': ''},
        'rows': [
          {'key': 'nope', 'state': 'asked'},
          'x',
          {'key': 'taxi', 'state': 'weird'},
        ],
      })!;
      expect((pr.done, pr.percent, pr.next), (6, 100, null));
      expect(pr.isReady, isTrue);
      expect(pr.rows.length, 1);
      expect(pr.rows.single.state, TripRowState.todo);
    });

    test('percent falls back to done over total, an empty list is complete', () {
      expect(TripProgress.tryParse({'total': 4, 'done': 1})!.percent, 25);
      expect(TripProgress.tryParse({'total': 0})!.percent, 100);
      expect(TripProgress.tryParse('x'), isNull);
    });

    test('the check-out day is the morning after the last day', () {
      final s = TripSummaryModel.fromJson({
        'id': 't1',
        'cityName': 'A',
        'dayCount': 2,
        'startDate': '2030-11-01',
        'endDate': '2030-11-02',
      });
      expect(s.isCheckOutDay(DateTime(2030, 11, 3)), isTrue);
      expect(s.isCheckOutDay(DateTime(2030, 11, 2)), isFalse);
      expect(s.isRunningOn(DateTime(2030, 11, 3)), isFalse);
      expect(s.asCompleted(null).isCheckOutDay(DateTime(2030, 11, 3)), isFalse);
      final noEnd = TripSummaryModel.fromJson({'id': 't1', 'cityName': 'A', 'dayCount': 1, 'startDate': '2030-11-01'});
      expect(noEnd.isCheckOutDay(DateTime(2030, 11, 2)), isTrue);
    });

    test('the full trip DTO carries progress too', () {
      final t = TripModel.fromJson({
        'id': 't1',
        'cityKey': 1,
        'plan': {'cityKey': 1, 'cityName': 'A'},
        'progress': {'total': 6, 'done': 3, 'percent': 50},
      });
      expect(t.progress?.percent, 50);
      expect(t.progress?.done, 3);
      expect(t.copyWith(title: 'x').progress?.total, 6);
    });
  });

  group('offline cache shape (MC-D)', () {
    Map<String, dynamic> raw() => {
          'id': 't1',
          'title': 'Haridwar, Badrinath, Auli trip',
          'cityKey': 1,
          'cityName': 'Haridwar',
          'dayCount': 4,
          'legCount': 3,
          'legCities': ['Haridwar', 'Badrinath', 'Auli'],
          'plan': {
            'version': 6,
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
                'arrival': {'fromName': 'Haridwar', 'journeyId': 'j2', 'cars': 2, 'listedTotal': 14000},
              },
              {
                'index': 3,
                'cityKey': 3,
                'cityName': 'Auli',
                'latitude': 30.53,
                'longitude': 79.57,
                'travelMark': {'status': 'own'},
              },
            ],
            'days': [
              {'day': 1, 'leg': 1},
              {'day': 2, 'leg': 2},
              {'day': 3, 'leg': 2},
              {'day': 4, 'leg': 3},
            ],
          },
          'journeys': [
            {
              'id': 'j2',
              'role': 'segment',
              'legIndex': 2,
              'travelDay': 2,
              'fromName': 'Haridwar',
              'toName': 'Badrinath',
              'date': '2030-11-02',
              'cars': 2,
              'legs': [
                {'legIndex': 1, 'fromName': 'Haridwar', 'toName': 'Rishikesh', 'driverName': 'Sunil Kumar', 'phone': '9800000001'},
                {'legIndex': 2, 'fromName': 'Rishikesh', 'toName': 'Badrinath', 'driverName': 'Mohan Bisht', 'phone': '9800000002'},
              ],
            },
          ],
        };

    void expectSame(TripModel t) {
      final a2 = t.plan.legAt(2)!.arrival!;
      expect(a2.journeyId, 'j2');
      expect(a2.cars, 2);
      final leg3 = t.plan.legAt(3)!;
      expect(leg3.arrival, isNull);
      expect(leg3.travelMark?.isOwn, isTrue);
      final j = t.journeyById('j2')!;
      expect(j.isSegment, isTrue);
      expect(j.legs.map((l) => l.phone), ['9800000001', '9800000002']);
      expect(t.legCities, ['Haridwar', 'Badrinath', 'Auli']);
    }

    test('the raw GET json the cache stores keeps arrivals, marks and driver phones', () {
      final t = TripModel.fromJson(raw());
      expectSame(t);
      expectSame(TripModel.fromJson(t.raw!));
    });

    test('the savePlan shape (plan + journeys re-serialised) parses back the same', () {
      final t = TripModel.fromJson(raw());
      final cached = {
        ...t.raw!,
        'plan': t.plan.toJson(),
        'legCount': t.plan.legs.length,
        'legCities': t.plan.legs.map((l) => l.cityName).toList(),
        'journeys': t.journeys.map((j) => j.toJson()).toList(),
      };
      expectSame(TripModel.fromJson(cached));
    });
  });

  group('TripSummaryRecord legs (MC-D)', () {
    test('an older server has no legs and stays one-city', () {
      final r = TripSummaryRecord.fromJson({'tripId': 'a', 'city': 'Nainital'});
      expect(r.legs, isEmpty);
      expect(r.isMultiCity, isFalse);
      expect(r.hasTravelCars, isFalse);
    });

    test('legs, travel and cars parse with safe defaults', () {
      final r = TripSummaryRecord.fromJson({
        'tripId': 'a',
        'city': 'Haridwar',
        'legs': [
          {
            'index': 2,
            'cityName': 'Badrinath',
            'startDay': 2,
            'endDay': 4,
            'startDate': '2030-11-02',
            'endDate': '2030-11-04',
            'travel': {
              'mode': 'journey',
              'fromName': 'Haridwar',
              'toName': 'Badrinath',
              'day': 2,
              'date': '2030-11-02',
              'state': 'partlyBooked',
              'carCount': 2,
              'listedTotal': 14000,
              'cars': [
                {
                  'car': 2,
                  'driverName': 'Mohan Bisht',
                  'fromName': 'Rishikesh',
                  'toName': 'Badrinath',
                  'listedFare': 9800,
                  'displayStatus': 'asked',
                },
                {
                  'car': 1,
                  'driverName': 'Sunil Kumar',
                  'fromName': 'Haridwar',
                  'toName': 'Rishikesh',
                  'agreedFare': 4200,
                  'listedFare': 4000,
                  'displayStatus': 'confirmedByBoth',
                  'confirmedBy': 'both',
                  'pickupTime': '06:00',
                },
              ],
            },
          },
          {
            'index': 1,
            'cityName': 'Haridwar',
            'startDay': 1,
            'endDay': 1,
            'nights': [
              {'night': 1, 'listingName': 'Ganga View Inn'},
            ],
          },
        ],
      });
      expect(r.isMultiCity, isTrue);
      expect(r.legs.first.index, 1);
      expect(r.legs.first.travel, isNull);
      expect(r.legs.first.nights.single.listingName, 'Ganga View Inn');
      final t = r.legs[1].travel!;
      expect(t.isJourney, isTrue);
      expect(t.state, TripTravelState.partlyBooked);
      expect(t.cars.map((c) => c.car), [1, 2]);
      expect(t.places, ['Haridwar', 'Rishikesh', 'Badrinath']);
      expect(t.cars.first.isBooked, isTrue);
      expect(t.cars.first.fare, 4200);
      expect(t.cars.last.isBooked, isFalse);
      expect(t.cars.last.fare, 9800);
      expect(r.hasTravel, isTrue);
      expect(r.hasTravelCars, isTrue);
    });

    test('own travel has no cars', () {
      final t = TripSummaryTravel.fromJson({
        'mode': 'own',
        'fromName': 'Delhi',
        'toName': 'Haridwar',
        'cars': [
          {'car': 1},
        ],
      });
      expect(t.isOwn, isTrue);
      expect(t.cars, isEmpty);
      expect(t.places, ['Delhi', 'Haridwar']);
    });

    test('arrangements parse and skip bad rows', () {
      final r = TripSummaryRecord.fromJson({
        'tripId': 'a',
        'city': 'Nainital',
        'arrangements': [
          {'key': 'gettingThere', 'kind': 'gettingThere', 'title': 'Getting there', 'state': 'saved', 'detail': 'Delhi to Nainital'},
          {'key': 'stay:1', 'title': 'Stay in Nainital', 'state': 'asked', 'detail': '  '},
          {'key': 'taxi', 'title': 'Local taxi', 'state': 'own'},
          {'key': 'bad', 'title': 'x', 'state': 'own'},
        ],
      });
      expect(r.arrangements.length, 3);
      expect(r.arrangements[0].key, const TripEasyRowKey(TripEasyRowKind.gettingThere));
      expect(r.arrangements[0].state, TripRowState.saved);
      expect(r.arrangements[0].detail, 'Delhi to Nainital');
      expect(r.arrangements[1].key.legIndex, 1);
      expect(r.arrangements[1].detail, isNull);
      expect(r.arrangements[2].state, TripRowState.own);
      expect(r.isEmpty, isFalse);
      expect(r.withDayMinutes({1: 30}).arrangements.length, 3);
    });

    test('summary rows carry no own fields and a bare record is empty', () {
      final n = TripSummaryNight.fromJson({'night': 1, 'listingName': 'Deodar', 'isOwn': true, 'ownPhone': '9876543210'});
      final t = TripSummaryTaxi.fromJson({'listingName': 'Mohan', 'isOwn': true, 'ownPhone': '9876543210'});
      expect(n.listingName, 'Deodar');
      expect(t.listingName, 'Mohan');
      expect(TripSummaryRecord.fromJson({'tripId': 'a'}).isEmpty, isTrue);
    });
  });
}
