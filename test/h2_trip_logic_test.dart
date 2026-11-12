import 'package:bakhli/features/taxi/journeys/journeys_controller.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_summary_model.dart';
import 'package:bakhli/features/trip/utils/trip_summary_text.dart';
import 'package:bakhli/models/browse_item.dart';
import 'package:flutter_test/flutter_test.dart';

WayDriver _driver(String id, {int fare = 0}) => WayDriver(
      taxiId: id,
      driverName: 'D$id',
      vehicleTypeName: 'Sedan',
      fromName: '',
      toName: '',
      listedFare: fare,
    );

WayLeg _leg(int i, WayPlace from, WayPlace to, List<WayDriver> drivers) => WayLeg(
      legKey: 'l$i~${from.key}~${to.key}',
      index: i,
      from: from,
      to: to,
      listedFare: 0,
      drivers: drivers,
    );

void main() {
  group('journey save body', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final ctrl = JourneysController();
    const from = WayPlace(key: 'v:1:2', name: '', lat: 1, lng: 2);
    const mid = WayPlace(key: 'a7', name: '  ', lat: 3, lng: 4);
    const to = WayPlace(key: 'm:5:6', name: '', lat: 5, lng: 6);

    Map<String, dynamic>? body(WayPlan plan, {String fromName = '', String toName = ''}) => ctrl.saveBodyOf(
          plan: plan,
          chosen: const {},
          date: DateTime(2030, 1, 2),
          people: 3,
          fromName: fromName,
          fromLat: 1,
          fromLng: 2,
          toName: toName,
          toLat: 5,
          toLng: 6,
        );

    test('blank names always get labels and zero fare is omitted', () {
      final plan = WayPlan(planKey: 'p', cars: 2, total: 0, legs: [
        _leg(1, from, mid, [_driver('a')]),
        _leg(2, mid, to, [_driver('b', fare: 900)]),
      ]);
      final b = body(plan)!;
      final legs = b['legs'] as List;
      final l1 = legs[0] as Map;
      final l2 = legs[1] as Map;
      expect(l1['fromName'], 'Pickup point');
      expect(l1['toName'], 'Stop');
      expect(l2['fromName'], 'Stop');
      expect(l2['toName'], 'My location');
      expect(l1.containsKey('listedFare'), isFalse);
      expect(l2['listedFare'], 900);
      for (final m in [b, l1, l2]) {
        expect((m['fromName'] as String).trim(), isNotEmpty);
        expect((m['toName'] as String).trim(), isNotEmpty);
      }
    });

    test('names are cut to 80 and typed names are kept', () {
      final plan = WayPlan(planKey: 'p', cars: 1, total: 0, legs: [_leg(1, from, to, [_driver('a')])]);
      final b = body(plan, fromName: 'K' * 120, toName: ' Nainital ')!;
      expect((b['fromName'] as String).length, 80);
      expect(b['toName'], 'Nainital');
      expect(b.containsKey('tripId'), isFalse);
      expect(b.containsKey('legIndex'), isFalse);
    });

    test('no driver on a leg gives no body', () {
      final plan = WayPlan(planKey: 'p', cars: 1, total: 0, legs: [_leg(1, from, to, const [])]);
      expect(body(plan, fromName: 'a', toName: 'b'), isNull);
    });
  });

  group('own marks carry only a status', () {
    test('own travel mark writes only the status and never an arrival', () {
      final plan = TripPlan(
        legs: const [
          TripCityLeg(index: 1, cityKey: 1, cityName: 'Delhi', latitude: 28, longitude: 77),
          TripCityLeg(index: 2, cityKey: 2, cityName: 'Nainital', latitude: 29, longitude: 79, travelMark: TripRowMark.own()),
        ],
        days: const [TripDay(day: 1), TripDay(day: 2, leg: 2)],
      );
      final leg = (plan.toJson()['legs'] as List)[1] as Map;
      expect(leg['travelMark'], {'status': 'own'});
      expect(leg.containsKey('arrival'), isFalse);
      final back = TripPlan.fromJson(plan.toJson());
      expect(back.legs[1].travelMark?.isOwn, isTrue);
      expect(back.legs[1].arrival, isNull);
    });

    test('own step with no other field round trips', () {
      const s = TripStep(status: TripStepStatus.own);
      final j = s.toJson();
      expect(j, {'status': 'own'});
      expect(TripStep.fromJson(j).status, TripStepStatus.own);
    });

    test('own stay mark on a leg round trips with nothing else', () {
      const leg = TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29, longitude: 79, stayMark: TripRowMark.own());
      final j = leg.toJson();
      expect(j['stayMark'], {'status': 'own'});
      expect(TripCityLeg.fromJson(j).stayMark?.isOwn, isTrue);
    });
  });

  group('summary text with zero amounts', () {
    test('zero fares never print as a price', () {
      final r = TripSummaryRecord.fromJson({
        'tripId': 't',
        'title': 'Nainital trip',
        'city': 'Nainital',
        'startDate': '2026-11-01',
        'endDate': '2026-11-03',
        'adults': 2,
        'kids': 0,
        'bookingState': 'ready',
        'agreedTotal': 0,
        'nights': [
          {
            'night': 1,
            'date': '2026-11-01',
            'listingName': 'Deodar',
            'displayStatus': 'asked',
            'agreedTotal': 0,
            'advanceAmount': 0,
          },
        ],
        'taxis': [
          {
            'enquiryId': 't1',
            'listingName': 'Mohan',
            'days': [1],
            'checkIn': '2026-11-01',
            'checkOut': '2026-11-01',
            'displayStatus': 'asked',
            'agreedFare': 0,
          },
        ],
      });
      final text = TripSummaryText.build(r);
      expect(text, isNot(contains(BrowseItem.inr(0))));
      expect(TripSummaryText.fareLine(r.taxis.first), '');
    });
  });
}
