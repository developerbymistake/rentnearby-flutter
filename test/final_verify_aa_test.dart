import 'package:bakhli/features/taxi/journeys/journey_models.dart';
import 'package:bakhli/features/taxi/journeys/journey_way_bridge.dart';
import 'package:bakhli/features/taxi/ways/models/ask_models.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_strings_final_aa.dart';
import 'package:bakhli/features/trip/utils/trip_stay_base.dart';
import 'package:bakhli/features/trip/utils/trip_taxi_fit.dart';
import 'package:bakhli/repositories/notification_repository.dart';
import 'package:bakhli/utils/keyset_page.dart';
import 'package:flutter_test/flutter_test.dart';

class _Row {
  final String id;
  const _Row(this.id);
}

_Row _row(Map<String, dynamic> j) => _Row(j['id'] as String);

TripStayChoice _stay(String id, double lat, double lng) => TripStayChoice(stayId: id, name: id, latitude: lat, longitude: lng);

TripPlan _nainital(List<TripStayChoice?> nights, {double cityLat = 29.3919, double cityLng = 79.4542}) => TripPlan.singleCity(
      cityKey: 1,
      cityName: 'Nainital',
      centreLatitude: cityLat,
      centreLongitude: cityLng,
      days: [for (var i = 0; i < nights.length; i++) TripDay(day: i + 1, stay: nights[i])],
    );

Map<String, dynamic> _driver(String id, int fare, int seats) => {
      'taxiId': id,
      'driverName': 'Driver $id',
      'vehicleTypeName': 'Car',
      'seats': seats,
      'fromName': 'Haldwani',
      'toName': 'Nainital',
      'listedFare': fare,
    };

WayLeg _coverLeg() => WayLeg.fromJson({
      'legKey': 'l1~hld~ntl',
      'index': 1,
      'from': {'key': 'hld', 'name': 'Haldwani', 'lat': 29.22, 'lng': 79.51},
      'to': {'key': 'ntl', 'name': 'Nainital', 'lat': 29.39, 'lng': 79.45},
      'listedFare': 15000,
      'carsNeeded': 2,
      'seatsNote': 'Seats 7 + 4 · 2 cars for 10',
      'coverTaxiIds': ['c', 'a'],
      'topDrivers': [_driver('a', 6000, 4), _driver('c', 9000, 7), _driver('b', 9500, 7)],
      'driverCount': 3,
    });

void main() {
  group('Keyset paging (findings 5, 23)', () {
    test('a keyset page reads the cursor and has more only with one', () {
      final p = KeysetPage.parse({
        'items': [
          {'id': '1'},
          {'id': '2'},
        ],
        'hasMore': true,
        'nextCursor': 'abc',
      }, _row);
      expect(p.items.map((r) => r.id), ['1', '2']);
      expect(p.nextCursor, 'abc');
      expect(p.hasMoreAfter(20), isTrue);
      final last = KeysetPage.parse({'items': List.generate(20, (i) => {'id': '$i'}), 'hasMore': false, 'nextCursor': null}, _row);
      expect(last.hasMoreAfter(20), isFalse);
    });

    test('load more sends the cursor, never an offset', () {
      expect(KeysetPage.nextParams(cursor: 'abc', loaded: 20, limit: 20), {'cursor': 'abc', 'limit': 20});
      expect(KeysetPage.nextParams(cursor: null, loaded: 20, limit: 20), {'offset': 20, 'limit': 20});
    });

    test('the inbox sends the cursor on load more, the page only without one', () {
      expect(NotificationRepository.paramsFor(cursor: 'xyz', page: 2), {'cursor': 'xyz', 'pageSize': 20});
      expect(NotificationRepository.paramsFor(), {'page': 1, 'pageSize': 20});
    });

    test('an old server without cursors pages as before', () {
      expect(KeysetPage.parse({'items': [], 'hasMore': true}, _row).hasMoreAfter(20), isTrue);
      expect(KeysetPage.parse({'items': List.generate(20, (i) => {'id': '$i'})}, _row).hasMoreAfter(20), isTrue);
      expect(KeysetPage.parse({'items': [{'id': '1'}]}, _row).hasMoreAfter(20), isFalse);
      expect(KeysetPage.parse(null, _row).items, isEmpty);
    });

    test('3 chats jump to the top: the next page adds no duplicate tile', () {
      final shown = [for (var i = 1; i <= 20; i++) _Row('c$i')];
      final page = [_Row('c18'), _Row('c19'), _Row('c20'), _Row('c21'), _Row('c21')];
      expect(KeysetPage.appendNew(shown, page, (r) => r.id).map((r) => r.id), ['c21']);
      expect(KeysetPage.appendNew(<_Row>[], const <_Row>[], (r) => r.id), isEmpty);
    });
  });

  group('Stay base anchor (finding 12)', () {
    test('every night at one Bhimtal stay: that stay is the anchor', () {
      final bhimtal = _stay('s1', 29.3467, 79.5536);
      final p = _nainital([bhimtal, bhimtal, bhimtal]);
      expect(TripStayBase.of(p, 1), (lat: 29.3467, lng: 79.5536));
      expect(TripStayBase.bodyOf(p, 1), {'anchorLatitude': 29.3467, 'anchorLongitude': 79.5536});
    });

    test('the last day has a night too: a different last-night stay mixes the base', () {
      final p = _nainital([_stay('s1', 29.3467, 79.5536), _stay('s2', 29.3800, 79.4600)]);
      expect(TripStayBase.of(p, 1), isNull);
    });

    test('same-as nights without a point resolve through the first night', () {
      final p = _nainital([
        _stay('s1', 29.3467, 79.5536),
        const TripStayChoice(stayId: 's1', name: 's1', sameAsDay: 1),
        null,
      ]);
      expect(TripStayBase.of(p, 1), (lat: 29.3467, lng: 79.5536));
    });

    test('no stay, a skipped night, a point-less own stay or a far stay: no anchor', () {
      expect(TripStayBase.of(_nainital([null, null]), 1), isNull);
      expect(TripStayBase.bodyOf(_nainital([null]), 1), isEmpty);
      expect(TripStayBase.of(_nainital([_stay('s1', 29.3467, 79.5536), const TripStayChoice.skippedNight()]), 1), isNull);
      expect(TripStayBase.of(_nainital([const TripStayChoice(stayId: '', name: 'Own', isOwn: true)]), 1), isNull);
      expect(TripStayBase.of(_nainital([_stay('s1', 28.6139, 77.2090)]), 1), isNull);
      expect(TripStayBase.of(_nainital([_stay('s1', 29.3467, 79.5536)], cityLat: 0, cityLng: 0), 1), isNull);
      expect(TripStayBase.of(_nainital([_stay('s1', 29.3467, 79.5536)]), 2), isNull);
    });

    test('the plan request carries the anchor, and none without a stay', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final c = TripPlanController();
      final bhimtal = _stay('s1', 29.3467, 79.5536);
      final body = c.planBodyForTest(_nainital([bhimtal, bhimtal]), 1, 'recalculate');
      expect(body['anchorLatitude'], 29.3467);
      expect(body['anchorLongitude'], 79.5536);
      final plain = c.planBodyForTest(_nainital([null, null]), 1, 'auto');
      expect(plain.containsKey('anchorLatitude'), isFalse);
    });

    test('a same-as loop never hangs', () {
      final p = _nainital([
        const TripStayChoice(stayId: 'x', name: 'x', sameAsDay: 2),
        const TripStayChoice(stayId: 'x', name: 'x', sameAsDay: 1),
      ]);
      expect(TripStayBase.of(p, 1), isNull);
    });

    test('day d starts at the stay of night d - 1 in the same leg', () {
      final p = _nainital([_stay('s1', 29.3467, 79.5536), null]);
      expect(TripStayBase.startOf(p, 2), (lat: 29.3467, lng: 79.5536));
      expect(TripStayBase.startOf(p, 1), isNull);
      final multi = TripPlan(
        legs: const [
          TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29.39, longitude: 79.45),
          TripCityLeg(index: 2, cityKey: 2, cityName: 'Almora', latitude: 29.59, longitude: 79.65),
        ],
        days: [TripDay(day: 1, stay: _stay('s1', 29.3467, 79.5536)), const TripDay(day: 2, leg: 2)],
      );
      expect(TripStayBase.startOf(multi, 2), isNull);
      expect(TripStayBase.of(multi, 2), isNull);
      expect(TripStayBase.of(multi, 1), (lat: 29.3467, lng: 79.5536));
    });
  });

  group('Trip local taxi fit (finding 16)', () {
    test('7 people, 142 km: the 4-seat driver costs 2 cars and 42 km extra', () {
      final a = TripTaxiFit.fromJson({'tripSeatsFit': false, 'tripCars': 2, 'tripDayCost': 5000, 'tripExtraKm': 42, 'tripPickupKm': 3.24});
      expect(a.costFor(2500), 5000);
      expect(a.carCount, 2);
      expect(a.extraKm, 42);
      expect(TripStringsFinalAa.kmAway(a.pickupKm!), '3.2 km away');
      expect(TripStringsFinalAa.kmAway(12.6), '13 km away');
      expect(const TripTaxiFit(cars: 2).costFor(2500), 5000);
      expect(const TripTaxiFit().costFor(null), isNull);
      final need = TripTaxiNeed.of(people: 7, km: 141.2, lat: 29.39, lng: 79.45);
      expect(need.params, {'people': 7, 'dayKm': 142, 'lat': 29.39, 'lng': 79.45});
    });
  });

  group('Seat cover everywhere (finding 17)', () {
    test('10 people, A 4 seats Rs 6,000 + C 7 seats Rs 9,000: Rs 15,000 in 2 cars', () {
      final leg = _coverLeg();
      final plan = WayPlan(planKey: 'p1~hld~ntl', cars: 1, total: 15000, legs: [leg]);
      expect(plan.totalWith(const {}, people: 10), 15000);
      expect(plan.carHires, 2);
      expect(plan.isDirectCover, isTrue);
      expect(rowCars(plan, 10), 2);
      expect(leg.driverFor(null)?.taxiId, 'c');
      expect(leg.coverOthersFor(null), ['a']);
      expect(leg.carsWith(null, 10), 2);
    });

    test('a manual pick carries the group alone: A x 3 cars = Rs 18,000', () {
      final leg = _coverLeg();
      final a = leg.driverById('a')!;
      expect(leg.coverOthersFor(a), isEmpty);
      expect(leg.carsWith(a, 10), 3);
      expect(leg.fareWith(a, 10), 18000);
    });

    test('the ask asks every cover car first, then backups', () {
      final leg = _coverLeg();
      final plan = WayPlan(planKey: 'p1~hld~ntl', cars: 1, total: 15000, legs: [leg]);
      final req = AskDriversRequest.fromPlan(
        plan: plan,
        chosen: const {},
        date: DateTime(2026, 11, 20),
        people: 10,
        journeyId: 'j1',
        fromName: 'Haldwani',
        toName: 'Nainital',
      )!;
      expect(req.legs.single.taxiIds, ['c', 'a', 'b']);
    });

    test('cars per asked driver mirror JourneyLegPricing.CarsFor', () {
      expect(WayCover.carsFor('a', 4, 10, 'c', ['a']), 1);
      expect(WayCover.carsFor('c', 7, 10, 'c', ['a']), 1);
      expect(WayCover.carsFor('b', 7, 10, 'c', ['a']), 2);
      expect(WayCover.carsFor('a', 4, 10, 'a', const []), 3);
      expect(WayCover.carsOfLeg(10, 7, ['a']), 2);
      expect(WayCover.carsOfLeg(10, 4, const []), 3);
      expect(WayCover.carsOfLeg(3, null, const []), 1);
      expect(WayCover.distinct(['a', '', 'a', 'b']), ['a', 'b']);
      expect(WayCover.askIds('c', ['a', 'd', 'e'], ['b'], 3), ['c', 'a', 'd']);
    });

    test('a leg without a cover keeps the top driver and his own cars', () {
      final leg = WayLeg.fromJson({
        'legKey': 'l1~x~y',
        'index': 1,
        'listedFare': 6000,
        'topDrivers': [_driver('a', 6000, 4)],
      });
      expect(leg.driverFor(null)?.taxiId, 'a');
      expect(leg.coverOthersFor(null), isEmpty);
      expect(WayPlan(planKey: 'p', cars: 1, total: 6000, legs: [leg]).isDirectCover, isFalse);
    });

    test('a saved cover leg reads its cars and asks the cover, priced as saved', () {
      final j = SavedJourney.fromJson({
        'id': 'j1',
        'fromName': 'Haldwani',
        'toName': 'Nainital',
        'date': '2026-11-20',
        'people': 10,
        'planKey': 'p1~hld~ntl',
        'cars': 1,
        'status': 'NotAsked',
        'listedTotal': 15000,
        'legs': [
          {
            'legIndex': 1,
            'legKey': 'l1~hld~ntl',
            'fromName': 'Haldwani',
            'toName': 'Nainital',
            'driver': {'taxiId': 'c', 'driverName': 'C', 'seats': 7},
            'coverTaxiIds': ['a'],
            'coverDrivers': [
              {'taxiId': 'a', 'driverName': 'A', 'seats': 4},
            ],
            'carsNeeded': 2,
            'listedFare': 15000,
            'seatsNote': 'Seats 7 + 4 · 2 cars for 10',
          },
        ],
      });
      final leg = j.legs.single;
      expect(leg.carsOf(10), 2);
      expect(leg.coverOthers, ['a']);
      final back = SavedJourneyLeg.fromJson(leg.toJson());
      expect(back.coverTaxiIds, ['a']);
      expect(back.coverDrivers.single.taxiId, 'a');
      expect(back.carsNeeded, 2);
      final plan = j.toWayPlan();
      expect(j.chosenDrivers(), isEmpty);
      expect(plan.totalWith(j.chosenDrivers(), people: 10), 15000);
      expect(plan.legs.single.carsNeeded, 2);
      final req = AskDriversRequest.fromPlan(
        plan: plan,
        chosen: j.chosenDrivers(),
        date: j.date,
        people: 10,
        journeyId: j.id,
        fromName: j.fromName,
        toName: j.toName,
      )!;
      expect(req.legs.single.taxiIds, ['c', 'a']);
    });

    test('an old saved leg without a cover keeps the driver count and an exact per-car fare', () {
      final j = SavedJourney.fromJson({
        'id': 'j2',
        'fromName': 'A',
        'toName': 'B',
        'date': '2026-11-20',
        'people': 10,
        'status': 'Ready',
        'legs': [
          {
            'legIndex': 1,
            'legKey': 'l1~a~b',
            'fromName': 'A',
            'toName': 'B',
            'driver': {'taxiId': 'a', 'driverName': 'A', 'seats': 4},
            'listedFare': 18000,
          },
        ],
      });
      expect(j.legs.single.carsOf(10), 3);
      final leg = j.legs.single;
      expect(j.wayDriver(leg, leg.driver).listedFare, 6000);
      expect(j.wayLeg(leg).coverOthersFor(null), isEmpty);
    });
  });
}
