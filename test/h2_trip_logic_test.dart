import 'package:bakhli/features/taxi/journeys/journeys_controller.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/trip/data/trip_popular_routes.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_summary_model.dart';
import 'package:bakhli/features/trip/trip_constants.dart';
import 'package:bakhli/features/trip/utils/trip_summary_text.dart';
import 'package:bakhli/features/trip/utils/trip_wizard_rules.dart';
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

TripCityModel _c(int key, String name, {String status = TripCityStatus.ready, bool popular = false}) =>
    TripCityModel(cityKey: key, name: name, latitude: 29, longitude: 79, status: status, isPopularDestination: popular);

TripPlan _plan(String? stayName) => TripPlan.singleCity(
      cityKey: 1,
      cityName: 'Nainital',
      days: [
        TripDay(day: 1, stay: stayName == null ? null : TripStayChoice(stayId: 's', name: stayName)),
        const TripDay(day: 2),
      ],
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

  group('pickupPlaceOf', () {
    test('long names are clipped to the limit', () {
      final long = 'H' * (TripConstants.pickupPlaceMax + 30);
      final r = TripWizardRules.pickupPlaceOf(_plan(long), 2)!;
      expect(r.length, TripConstants.pickupPlaceMax);
    });

    test('blank names give null', () {
      expect(TripWizardRules.pickupPlaceOf(_plan('   '), 2), isNull);
      expect(TripWizardRules.pickupPlaceOf(_plan(null), 2), isNull);
    });
  });

  group('TripPopularRoutes.resolve', () {
    test('empty catalog gives nothing', () {
      expect(TripPopularRoutes.resolve(const []), isEmpty);
    });

    test('route needs both cities ready and distinct', () {
      final cat = [
        _c(1, 'Nainital'),
        _c(2, 'Almora'),
        _c(3, 'Shimla'),
        _c(4, 'Manali', status: TripCityStatus.notReady),
        _c(5, 'Dehradun'),
      ];
      final r = TripPopularRoutes.resolve(cat);
      expect(r.map((e) => '${e.from.name}>${e.to.name}'), ['Nainital>Almora']);
    });

    test('prefers the popular duplicate', () {
      final cat = [_c(1, 'Nainital'), _c(9, 'Nainital', popular: true), _c(2, 'Almora')];
      final r = TripPopularRoutes.resolve(cat);
      expect(r.single.from.cityKey, 9);
      expect(r.length, lessThanOrEqualTo(TripPopularRoutes.maxShown));
    });
  });

  group('own arrangement with every field null', () {
    test('own travel round trips with flight and with nothing', () {
      const full = TripTravel.own(fromName: 'Delhi', how: TripTravelHow.flight);
      final back = TripTravel.fromJson(full.toJson());
      expect(back.isOwn, isTrue);
      expect(back.how, TripTravelHow.flight);
      expect(back.ownName, isNull);
      expect(back.ownPhone, isNull);
      expect(back.note, isNull);
      expect(back.hasPhone, isFalse);
      final bare = TripTravel.fromJson({'mode': 'own'});
      expect(bare.isOwn, isTrue);
      expect(bare.fromName, '');
      expect(bare.toJson().containsKey('how'), isFalse);
    });

    test('own step with all null fields round trips', () {
      const s = TripStep(status: TripStepStatus.own);
      final j = s.toJson();
      expect(j['status'], 'own');
      expect(j.containsKey('how'), isFalse);
      final back = TripStep.fromJson(j);
      expect(back.status, TripStepStatus.own);
      expect(back.how, isNull);
      expect(back.ownName, isNull);
      const f = TripStep(status: TripStepStatus.own, how: TripTravelHow.flight);
      expect(TripStep.fromJson(f.toJson()).how, TripTravelHow.flight);
    });

    test('own stay without name or phone round trips', () {
      const st = TripStayChoice(stayId: '', name: '', isOwn: true);
      final j = st.toJson();
      expect(j.containsKey('stayId'), isFalse);
      final back = TripStayChoice.fromJson(j);
      expect(back.isOwn, isTrue);
      expect(back.name, '');
      expect(back.ownPhone, isNull);
      expect(back.hasListing, isFalse);
    });
  });

  group('summary text with zero amounts', () {
    test('zero fares never print as a price and blank own names get labels', () {
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
            'listingName': '',
            'isOwn': true,
            'displayStatus': 'own',
            'agreedTotal': 0,
            'advanceAmount': 0,
          },
        ],
        'taxis': [
          {
            'enquiryId': 't1',
            'listingName': '',
            'days': [1],
            'checkIn': '2026-11-01',
            'checkOut': '2026-11-01',
            'isOwn': true,
            'displayStatus': 'own',
            'agreedFare': 0,
          },
        ],
      });
      final text = TripSummaryText.build(r);
      expect(text, contains('Own stay'));
      expect(text, contains('Own taxi'));
      expect(text, isNot(contains(BrowseItem.inr(0))));
      expect(TripSummaryText.fareLine(r.taxis.first), '');
    });
  });
}
