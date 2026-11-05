import 'package:get/get.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_result_model.dart';
import 'package:bakhli/features/trip/utils/trip_enquiry_rules.dart';
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

TripPlan _twoLegs({int firstDays = 1}) => TripPlan.fromJson({
      'version': 4,
      'cityKey': 1,
      'cityName': 'Haridwar',
      'legs': [
        {'index': 1, 'cityKey': 1, 'cityName': 'Haridwar', 'latitude': 29.95, 'longitude': 78.16},
        {'index': 2, 'cityKey': 2, 'cityName': 'Badrinath', 'latitude': 30.74, 'longitude': 79.49},
      ],
      'settings': {'startDate': '2030-11-01', 'pickupPlace': 'Ganga View Inn'},
      'days': [
        for (var i = 1; i <= firstDays; i++) {'day': i, 'leg': 1, 'spots': [_spot('a$i').toJson()]},
        {'day': firstDays + 1, 'leg': 2, 'spots': [_spot('b').toJson()]},
        {'day': firstDays + 2, 'leg': 2, 'spots': []},
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('single-city auto replan remaps taxi booking days (#2)', () {
    final c = TripPlanController();
    const booking = TripTaxiBooking(agreedFare: 4000, days: [3, 4]);
    const taxi = TripTaxiChoice(taxiId: 'd1', name: 'Mohan', fare: 2000, booking: booking);
    final p = TripPlan.singleCity(
      cityKey: 1,
      cityName: 'Nainital',
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
      days: [
        TripDay(day: 1, spots: [_spot('a')]),
        TripDay(day: 2, spots: [_spot('b')]),
        TripDay(day: 3, spots: [_spot('c')], taxi: taxi),
        TripDay(day: 4, spots: [_spot('d')], taxi: taxi),
      ],
    );
    final r = TripPlanResult(
      days: [_resultDay(1, const ['a', 'b']), _resultDay(2, const ['c']), _resultDay(3, const ['d'])],
      warnings: const [],
      osrmAvailable: true,
      dayLimitMinutes: 450,
    );
    final out = c.applyAutoForTest(p, 1, r);
    expect(out.days.length, 3);
    for (final d in out.days) {
      for (final x in d.taxi?.booking?.days ?? const <int>[]) {
        expect(x <= out.days.length, isTrue);
      }
    }
  });

  test('a city cannot grow while a later city has bookings (#63)', () {
    final c = TripPlanController();
    addTearDown(c.onClose);
    c.plan.value = _twoLegs();
    expect(c.canSetLegDays(1, 2), TripLegEditBlock.none);
    c.enquiryList.assignAll([
      TripEnquiryModel(
        id: 'e1',
        listingId: 's1',
        status: TripEnquiryStatuses.confirmedByBoth,
        checkIn: DateTime(2030, 11, 2),
        checkOut: DateTime(2030, 11, 3),
      ),
    ]);
    expect(c.canSetLegDays(1, 2), TripLegEditBlock.bookings);
    expect(c.canSetLegDays(1, 2, keepBookings: true), TripLegEditBlock.bookings);
    expect(c.maxDaysForLeg(1), 1);
  });

  test('a no-driver gap follows its city pair and drops with a removed city (#65)', () {
    final c = TripPlanController();
    final three = TripPlan.fromJson({
      'version': 4,
      'cityKey': 1,
      'cityName': 'A',
      'legs': [
        {'index': 1, 'cityKey': 1, 'cityName': 'A', 'latitude': 1, 'longitude': 1},
        {'index': 2, 'cityKey': 2, 'cityName': 'B', 'latitude': 2, 'longitude': 2},
        {'index': 3, 'cityKey': 3, 'cityName': 'C', 'latitude': 3, 'longitude': 3},
      ],
      'days': [
        {'day': 1, 'leg': 1, 'spots': []},
        {'day': 2, 'leg': 2, 'spots': []},
        {'day': 3, 'leg': 3, 'spots': []},
      ],
    });
    final twoAC = TripPlan.fromJson({
      'version': 4,
      'cityKey': 1,
      'cityName': 'A',
      'legs': [
        {'index': 1, 'cityKey': 1, 'cityName': 'A', 'latitude': 1, 'longitude': 1},
        {'index': 2, 'cityKey': 3, 'cityName': 'C', 'latitude': 3, 'longitude': 3},
      ],
      'days': [
        {'day': 1, 'leg': 1, 'spots': []},
        {'day': 2, 'leg': 2, 'spots': []},
      ],
    });
    c.travelGaps[2] = 'Rishikesh';
    c.remapTravelGapsForTest(three, twoAC);
    expect(c.travelGaps, isEmpty);
    c.travelGaps[3] = null;
    c.remapTravelGapsForTest(three, three);
    expect(c.travelGaps.containsKey(3), isTrue);
  });

  test('the check-out day keeps the trip live but every day read-only (#50)', () {
    final c = TripPlanController();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 2);
    c.plan.value = TripPlan.singleCity(
      cityKey: 1,
      cityName: 'Nainital',
      settings: TripSettings(startDate: start),
      days: [
        TripDay(day: 1, spots: [_spot('a')]),
        TripDay(day: 2, spots: [_spot('b')]),
      ],
    );
    expect(c.isCheckOutDay, isTrue);
    expect(c.isPastTrip, isFalse);
    expect(c.isReadOnly, isFalse);
    expect(c.todayDay, isNull);
    expect(c.canEditDay(2), isFalse);
    expect(c.canAddPlaces(1), isFalse);
    expect(c.problemTaxiRows(2), isEmpty);
  });

  test('a declined driver frees a shortlist slot and is not sent again (#17)', () {
    final c = TripPlanController();
    c.plan.value = TripPlan.singleCity(
      cityKey: 1,
      cityName: 'Nainital',
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
      days: [
        TripDay(day: 1, spots: [_spot('a')], taxiShortlist: const [
          TripTaxiShortlistItem(taxiId: 'd1', name: 'Mohan'),
          TripTaxiShortlistItem(taxiId: 'd2', name: 'Ravi'),
          TripTaxiShortlistItem(taxiId: 'd3', name: 'Ajay'),
        ]),
      ],
    );
    c.enquiryList.assignAll([
      TripEnquiryModel(
        id: 't1',
        kind: TripEnquiryKinds.taxi,
        listingId: 'd1',
        status: TripEnquiryStatuses.closed,
        displayStatusWire: 'notAvailable',
        checkIn: DateTime(2030, 11, 1),
        days: const [1],
      ),
    ]);
    expect(c.taxiShortlistCount(1), 2);
    expect(c.canRemoveTaxiShortlist(1, 'd1'), isTrue);
    expect(c.canRemoveTaxiShortlist(1, 'd2'), isFalse);
    expect(c.sendableTaxiShortlist(1).map((s) => s.taxiId).toList(), ['d2', 'd3']);
  });

  test('own taxi waits for open leads to be withdrawn and keeps one city (#19, #21)', () {
    final c = TripPlanController();
    c.plan.value = _twoLegs(firstDays: 2);
    c.enquiryList.assignAll([
      TripEnquiryModel(
        id: 't1',
        kind: TripEnquiryKinds.taxi,
        listingId: 'd1',
        status: TripEnquiryStatuses.asked,
        checkIn: DateTime(2030, 11, 1),
        days: const [1, 2],
      ),
    ]);
    final res = c.setOwnTaxi(days: const [1, 2, 3], name: 'Hotel cab', legDay: 1);
    expect(res, isA<OwnNeedsWithdraw>());
    expect(c.plan.value!.dayAt(1)!.taxi, isNull);
    c.enquiryList.clear();
    expect(c.setOwnTaxi(days: const [3, 1, 2], name: 'Hotel cab', legDay: 1), isA<OwnSaved>());
    expect(c.plan.value!.dayAt(1)!.taxi?.isOwn, isTrue);
    expect(c.plan.value!.dayAt(2)!.taxi?.isOwn, isTrue);
    expect(c.plan.value!.dayAt(3)!.taxi, isNull);
    expect(c.ownTaxiDayOptions(1), [1, 2]);
  });

  test('same stay as last night needs the host when the booking ends (#7)', () {
    final c = TripPlanController();
    c.plan.value = TripPlan.singleCity(
      cityKey: 1,
      cityName: 'Nainital',
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
      days: [
        TripDay(day: 1, spots: [_spot('a')]),
        TripDay(day: 2, spots: [_spot('b')]),
        TripDay(day: 3, spots: [_spot('c')]),
      ],
    );
    c.enquiryList.assignAll([
      TripEnquiryModel(
        id: 'e1',
        listingId: 's1',
        listingName: 'Deodar Homestay',
        status: TripEnquiryStatuses.confirmedByBoth,
        displayStatusWire: 'confirmedByBoth',
        checkIn: DateTime(2030, 11, 1),
        checkOut: DateTime(2030, 11, 2),
      ),
    ]);
    expect(c.sameStayNeedsChange(2)?.id, 'e1');
    expect(c.setSameAsLastNight(2), isFalse);
    expect(c.plan.value!.dayAt(2)!.stay, isNull);
  });

  test('a host that had no room is not asked again (#53)', () {
    final failed = TripEnquiryModel(
      id: 'e1',
      listingId: 's1',
      status: TripEnquiryStatuses.closed,
      failReason: 'ProblemHostNoRoom',
      checkIn: DateTime(2030, 11, 2),
      checkOut: DateTime(2030, 11, 4),
    );
    expect(TripEnquiryRules.hostRefused(failed), isTrue);
    final c = TripPlanController();
    c.plan.value = TripPlan.singleCity(
      cityKey: 1,
      cityName: 'Nainital',
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
      days: [
        TripDay(day: 1, spots: [_spot('a')]),
        TripDay(day: 2, spots: [_spot('b')], stayShortlist: const [
          TripStayShortlistItem(stayId: 's1', name: 'Deodar'),
          TripStayShortlistItem(stayId: 's2', name: 'Pine View'),
        ]),
      ],
    );
    c.enquiryList.assignAll([failed]);
    expect(c.sendableShortlist(2).map((s) => s.stayId).toList(), ['s2']);
    expect(c.askAgainStays(2), isEmpty);
  });

  test('a later city never takes the first city pickup (#64)', () {
    final c = TripPlanController();
    c.plan.value = _twoLegs();
    expect(c.pickupPlaceFor(1), 'Ganga View Inn');
    expect(c.pickupPlaceFor(2), isNull);
    c.rememberPickup(2, time: '08:00', place: 'Badrinath Inn');
    expect(c.settings.pickupPlace, 'Ganga View Inn');
  });
}
