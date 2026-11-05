import 'dart:math' as math;

import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:bakhli/features/trip/utils/trip_day_load.dart';
import 'package:bakhli/features/trip/utils/trip_enquiry_rules.dart';
import 'package:bakhli/features/trip/utils/trip_format.dart';
import 'package:bakhli/features/trip/utils/trip_geo.dart';
import 'package:bakhli/features/trip/utils/trip_money.dart';
import 'package:bakhli/features/trip/utils/trip_stay_rank.dart';
import 'package:bakhli/features/trip/utils/trip_taxi_fit.dart';
import 'package:flutter_test/flutter_test.dart';

int _sum(List<int> xs) => xs.fold(0, (s, x) => s + x);

Map<String, dynamic> _stay(String id, double lat, double lng, {int rank = 0, bool? fits, int? quote}) => {
      'id': id,
      'latitude': lat,
      'longitude': lng,
      'priorityRank': rank,
      'fits': ?fits,
      'quotePerNight': ?quote,
    };

Map<String, dynamic> _driver(String id, int fare, int seats, {int? estimate}) => {
      'taxiId': id,
      'driverName': 'D $id',
      'vehicleTypeName': 'Car',
      'seats': seats,
      'fromName': 'A',
      'toName': 'B',
      'listedFare': fare,
      'estimatedFare': ?estimate,
    };

void main() {
  group('TripMoney (server MoneySplit vectors)', () {
    test('apportion sums exactly, leftovers to the largest fractions', () {
      expect(TripMoney.apportion(100, [1, 1, 1]), [34, 33, 33]);
      expect(TripMoney.apportion(100, []), isEmpty);
      expect(TripMoney.apportion(0, [3, 4]), [0, 0]);
      expect(TripMoney.apportion(7, [5]), [7]);
      expect(TripMoney.apportion(7, [0, 0]), [4, 3]);
      expect(TripMoney.apportion(7, [0, 9]), [0, 7]);
    });

    test('proRata rounds half up', () {
      expect(TripMoney.proRata(7500, 1, 3), 2500);
      expect(TripMoney.proRata(1001, 1, 2), 501);
      expect(TripMoney.proRata(1000, 3, 3), 1000);
      expect(TripMoney.proRata(1000, 0, 3), 0);
      expect(TripMoney.proRata(1000, 1, 0), 0);
    });

    test('finding 76: dropping a day keeps exact shares', () {
      final shares = TripMoney.even(2500, 3);
      expect(shares, [834, 833, 833]);
      expect(_sum(shares), 2500);
      expect(TripMoney.keptOf(2500, 3, [0, 1]), 1667);
      expect(TripMoney.keptOf(2500, 3, [1, 2]) + TripMoney.shareOf(2500, 3, 0), 2500);
      expect(TripMoney.keptOf(1000, 3, [0, 1]), 667);
      expect(_sum(TripMoney.even(5000, 3)), 5000);
      expect(TripMoney.shareOf(1000, 3, 5), 0);
      expect(TripMoney.even(1000, 0), isEmpty);
      expect(TripMoney.keptOf(1000, 3, [0, 0]), 334);
    });

    test('finding 81: counter lines keep the exact total', () {
      final a = TripMoney.unitPrices(3300, [1, 2], [1000, 1500])!;
      expect(a, [826, 1237]);
      expect(a[0] + 2 * a[1], 3300);
      final b = TripMoney.unitPrices(6000, [1, 2], [3000, 2000])!;
      expect(b, [2572, 1714]);
      expect((b[0] + 2 * b[1]) * 3, 18000);
      expect(TripMoney.counterPerNight(2000, [1, 2], [3000, 2000]) * 3, 18000);
    });

    test('unitPrices: negative move, flat price, nulls', () {
      expect(TripMoney.unitPrices(5 * 1001, [2, 3], [1000, 1003]), [998, 1003]);
      expect(TripMoney.unitPrices(1234 * 6, [1, 2, 3], [900, 900, 900]), [1234, 1234, 1234]);
      expect(TripMoney.unitPrices(100, [], []), isNull);
      expect(TripMoney.unitPrices(100, [1], [0]), isNull);
    });

    test('unitPrices: many mixes always hit the exact total', () {
      final rnd = math.Random(7);
      for (var run = 0; run < 80; run++) {
        final count = rnd.nextInt(5) + 1;
        final units = [for (var i = 0; i < count; i++) rnd.nextInt(4) + 1];
        final prices = [for (var i = 0; i < count; i++) 500 + rnd.nextInt(19500)];
        final x = 100 + rnd.nextInt(14900);
        final total = _sum(units);
        final q = TripMoney.unitPrices(x * total, units, prices);
        final perNight = q == null ? x * total : _sum([for (var i = 0; i < count; i++) units[i] * q[i]]);
        expect(perNight, x * total);
        if (q != null) expect(q.every((p) => p >= 1), isTrue);
      }
    });
  });

  group('TripDayLoad (finding 5)', () {
    test('travel day: reserve + route over the limit, same as the server', () {
      final load = TripDayLoad.load(reserved: 180, route: 300);
      expect(load, 480);
      expect(TripDayLoad.isOver(load, 450), isTrue);
      expect(TripDayLoad.isOver(TripDayLoad.load(reserved: 180, route: 270), 450), isFalse);
      expect(TripDayLoad.load(reserved: -5, route: 60), 60);
      expect(TripDayLoad.route(serverTotal: null, visitMinutes: 120), 120);
      expect(TripDayLoad.route(serverTotal: 150, visitMinutes: 120), 150);
    });

    test('estimate mirrors the server fallback', () {
      expect(TripDayLoad.estimateMinutes((lat: 29.0, lng: 79.0), (lat: 29.0, lng: 79.0)), 0);
      final km = TripGeo.km((lat: 29.3919, lng: 79.4542), (lat: 29.3478, lng: 79.5590));
      expect(TripDayLoad.estimateMinutes((lat: 29.3919, lng: 79.4542), (lat: 29.3478, lng: 79.5590)), (km / 30 * 60 * 2).ceil());
    });

    test('cheapest insertion picks the gap with the least added drive', () {
      const pos = [0, 10, 20, 30];
      int m(int a, int b) => (a - b).abs();
      const x = 12;
      final r = TripDayLoad.cheapestInsertion(
        count: pos.length,
        toNew: (i) => m(pos[i], x),
        fromNew: (i) => m(x, pos[i]),
        legAfter: (i) => m(pos[i], pos[i + 1]),
      );
      expect(r.index, 2);
      expect(r.deltaMinutes, 0);
      final empty = TripDayLoad.cheapestInsertion(count: 0, toNew: (_) => 0, fromNew: (_) => 0, legAfter: (_) => 0);
      expect(empty.index, 0);
      final tie = TripDayLoad.cheapestInsertion(count: 1, toNew: (_) => 5, fromNew: (_) => 5, legAfter: (_) => 0);
      expect(tie.index, 1);
    });
  });

  group('Trip stay search (findings 7, 17, 18)', () {
    const nainital = [(lat: 29.3919, lng: 79.4542), (lat: 29.3943, lng: 79.4521)];
    const bhimtal = [(lat: 29.3478, lng: 79.5590), (lat: 29.3540, lng: 79.5480)];
    final night = TripStayNight(spots: [...nainital, ...bhimtal]);

    test('a two-cluster day is covered by two discs, not one centroid', () {
      final discs = TripGeo.cover(night.points, 5);
      expect(discs.length, 2);
      expect(discs.every((d) => d.radiusKm <= 5), isTrue);
      expect(TripGeo.cover(nainital, 5).length, 1);
      expect(TripGeo.cover(const [], 5), isEmpty);
      expect(TripGeo.cover(const [(lat: 0.0, lng: 0.0)], 5), isEmpty);
    });

    test('a stay next to a spot is kept, middle ground is dropped', () {
      final ranked = TripStayRank.rank([
        _stay('bhowali', 29.383, 79.505),
        _stay('lakeside', 29.346, 79.560),
        _stay('lakeside', 29.346, 79.560),
      ], night, 5);
      expect(ranked.map((f) => f.id), ['lakeside']);
      expect(ranked.single.nearestKm, closeTo(0.22, 0.05));
    });

    test('paid rank first, distance only inside a rank', () {
      final n = TripStayNight(spots: [nainital.first]);
      final ranked = TripStayRank.rank([
        _stay('f', 29.3960, 79.4580),
        _stay('p', 29.4070, 79.4560, rank: 2),
      ], n, 5);
      expect(ranked.map((f) => f.id), ['p', 'f']);
    });

    test('a stay that fits the party comes first', () {
      final n = TripStayNight(spots: [nainital.first]);
      final ranked = TripStayRank.rank([
        _stay('small', 29.3920, 79.4545, rank: 3, fits: false),
        _stay('big', 29.3990, 79.4600, fits: true, quote: 6000),
        _stay('unknown', 29.3950, 79.4550),
      ], n, 5);
      expect(ranked.map((f) => f.id), ['big', 'unknown', 'small']);
      expect(TripStayRank.priceOf(ranked.first, 1500), 6000);
      expect(TripStayRank.priceOf(null, 1500), 1500);
    });

    test('the night ranks by the detour towards the next morning', () {
      const tiffin = (lat: 29.379, lng: 79.441);
      const lake = (lat: 29.344, lng: 79.553);
      const n = TripStayNight(spots: [tiffin], next: lake);
      final ranked = TripStayRank.rank([
        _stay('s1', 29.395, 79.448),
        _stay('s2', 29.383, 79.505),
      ], n, 12);
      expect(ranked.map((f) => f.id), ['s2', 's1']);
      expect(ranked.first.detourKm, closeTo(1.05, 0.1));
      expect(ranked.last.detourKm, closeTo(2.02, 0.1));
      expect(TripStayRank.rank([_stay('s2', 29.383, 79.505)], n, 5), isEmpty);
    });

    test('rows without coordinates are skipped', () {
      expect(TripStayRank.rank([{'id': 'x'}], night, 5), isEmpty);
    });
  });

  group('TripClock (findings 56, 78)', () {
    test('IST midnight edge', () {
      final checkIn = DateTime(2026, 11, 5);
      final before = TripClock.checkInRelative(checkIn, DateTime.utc(2026, 11, 4, 18, 29));
      final after = TripClock.checkInRelative(checkIn, DateTime.utc(2026, 11, 4, 18, 31));
      expect(before.when, TripCheckInWhen.tomorrow);
      expect(after.when, TripCheckInWhen.tonight);
      expect(TripClock.checkInRelative(DateTime(2026, 10, 28), DateTime.utc(2026, 11, 5, 6)).when, TripCheckInWhen.past);
      final later = TripClock.checkInRelative(DateTime(2026, 11, 9), DateTime.utc(2026, 11, 5, 6));
      expect(later.when, TripCheckInWhen.later);
      expect(later.days, 4);
    });

    test('one label for every surface', () {
      final now = DateTime.utc(2026, 11, 5, 6);
      expect(TripEnquiryRules.checkInLabel(DateTime(2026, 11, 5), now), 'Tonight');
      expect(TripEnquiryRules.checkInLabel(DateTime(2026, 11, 6), now), 'Tomorrow');
      expect(TripEnquiryRules.checkInLabel(DateTime(2026, 11, 7), now), 'In 2 days');
      expect(TripEnquiryRules.checkInLabel(DateTime(2026, 10, 28), now), isNull);
      expect(TripEnquiryRules.checkInLabel(null, now), isNull);
    });

    test('date-only maths ignores wall-clock DST', () {
      expect(TripClock.nightOf(DateTime(2026, 11, 2), 3, DateTime(2026, 11, 3)), 2);
      expect(TripClock.nightOf(DateTime(2026, 11, 2), 3, DateTime(2026, 11, 9)), 3);
      expect(TripClock.dayIndex(DateTime(2026, 11, 2), 3, DateTime(2026, 11, 3)), 2);
      expect(TripClock.dayIndex(DateTime(2026, 11, 2), 3, DateTime(2026, 11, 5)), isNull);
      expect(TripClock.dayIndex(DateTime(2026, 11, 2), 0, DateTime(2026, 11, 2)), isNull);
      expect(TripClock.today(DateTime.utc(2026, 11, 4, 18, 31)), DateTime(2026, 11, 5));
    });
  });

  group('Taxi service days (finding 77)', () {
    test('a date set reads as runs', () {
      expect(TripFormat.dateSet([DateTime(2026, 11, 7)]), 'Sat 07 Nov');
      expect(TripFormat.dateSet([DateTime(2026, 11, 9), DateTime(2026, 11, 7)]), '07 Nov, 09 Nov');
      expect(TripFormat.dateSet([DateTime(2026, 11, 7), DateTime(2026, 11, 8), DateTime(2026, 11, 8)]),
          'Sat 07 Nov - Sun 08 Nov');
      expect(TripFormat.dateSet([DateTime(2026, 10, 31), DateTime(2026, 11, 1)]), 'Sat 31 Oct - Sun 01 Nov');
      expect(TripFormat.dateSet(const []), '');
    });
  });

  group('Taxi group prices (findings 23, 27)', () {
    test('a 4-seat driver for 6 people costs two cars', () {
      final a = WayDriver.fromJson(_driver('a', 7000, 4));
      expect(a.carsFor(6), 2);
      expect(a.groupFare(6), 14000);
      final r = TaxiWaysResult.fromJson({
        'allTheWay': [_driver('a', 7000, 4)],
        'plans': [
          {'planKey': 'p', 'cars': 2, 'total': 10000, 'legs': []},
        ],
      });
      final rows = sortedRows(r, WaysSort.lowestPrice, people: 6);
      expect(rows.first, isA<WayPlan>());
      final one = sortedRows(r, WaysSort.lowestPrice, people: 4);
      expect(one.first, isA<WayDriver>());
    });

    test('totalWith uses the chosen driver seats', () {
      final plan = WayPlan.fromJson({
        'planKey': 'p',
        'cars': 1,
        'total': 9000,
        'legs': [
          {'legKey': 'l1', 'index': 1, 'listedFare': 9000, 'carsNeeded': 1},
        ],
      });
      final chosen = {1: WayDriver.fromJson(_driver('a', 6000, 4))};
      expect(plan.totalWith(chosen, people: 6), 12000);
      expect(plan.totalWith(const {}, people: 6), 9000);
    });

    test('a partial stretch is priced on the estimate', () {
      final d = WayDriver.fromJson(_driver('a', 6500, 7, estimate: 5800));
      expect(d.fare, 5800);
      expect(d.isEstimate, isTrue);
      expect(d.groupFare(6), 5800);
    });

    test('local taxi need and fit', () {
      final need = TripTaxiNeed.of(people: 7, km: 141.2, lat: 29.39, lng: 79.45);
      expect(need.params, {'people': 7, 'dayKm': 142, 'lat': 29.39, 'lng': 79.45});
      expect(const TripTaxiNeed().isEmpty, isTrue);
      expect(const TripTaxiNeed().params, isEmpty);
      expect(TripTaxiNeed.of(people: 40, km: double.nan).params, {'people': 12});
      final fit = TripTaxiFit.fromJson({'tripSeatsFit': false, 'tripCars': 2, 'tripDayCost': 5000, 'tripExtraKm': 62});
      expect(fit.costFor(2500), 5000);
      expect(fit.extraKm, 62);
      expect(const TripTaxiFit(cars: 2).costFor(2500), 5000);
      expect(const TripTaxiFit().costFor(null), isNull);
      expect(TripTaxiFit.fromJson(const {}).isEmpty, isTrue);
    });
  });
}
