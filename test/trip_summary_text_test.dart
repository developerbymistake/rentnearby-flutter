import 'package:bakhli/features/trip/models/trip_summary_model.dart';
import 'package:bakhli/features/trip/trip_constants.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/trip_strings_a5.dart';
import 'package:bakhli/features/trip/utils/trip_summary_text.dart';
import 'package:bakhli/models/browse_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> night(int n, {String name = 'Deodar Homestay', String? cancellation = 'Free till 25 Oct'}) => {
        'night': n,
        'date': '2026-11-0$n',
        'listingName': name,
        'enquiryId': 'e$n',
        'isOwn': false,
        'displayStatus': 'confirmedByBoth',
        'roomLines': [
          {'roomName': 'Family room', 'units': 1, 'guests': 4},
        ],
        'agreedTotal': 3800,
        'advanceStatus': 'Received',
        'advanceAmount': 500,
        'cancellationText': cancellation,
        'gstInvoice': true,
        'confirmedBy': 'both',
        'confirmedAt': '2026-10-30T10:00:00Z',
      };

  Map<String, dynamic> taxi() => {
        'enquiryId': 't1',
        'listingName': 'Mohan Bisht',
        'vehicleTypeName': 'Sedan',
        'days': [1, 2],
        'checkIn': '2026-11-01',
        'checkOut': '2026-11-02',
        'isOwn': false,
        'displayStatus': 'bookedByYou',
        'agreedFare': 3400,
        'tollExtra': true,
        'pickupTime': '08:30',
        'pickupPlace': 'Mallital',
        'confirmedBy': 'you',
        'confirmedAt': '2026-10-30T10:00:00Z',
      };

  Map<String, dynamic> record({List<Map<String, dynamic>>? nights, List<Map<String, dynamic>>? taxis}) => {
        'tripId': 'trip1',
        'title': 'Nainital trip',
        'city': 'Nainital',
        'startDate': '2026-11-01',
        'endDate': '2026-11-03',
        'adults': 2,
        'kids': 2,
        'bookingState': 'ready',
        'agreedTotal': 7200,
        'nights': nights ?? [night(1)],
        'taxis': taxis ?? [taxi()],
      };

  test('plain text carries the stay, the taxi, the total and the footer', () {
    final text = TripSummaryText.build(TripSummaryRecord.fromJson(record()));
    expect(text, contains('Nainital'));
    expect(text, contains('Night 1'));
    expect(text, contains('Deodar Homestay'));
    expect(text, contains('Mohan Bisht'));
    expect(text, contains(BrowseItem.inr(3800)));
    expect(text, contains(BrowseItem.inr(3400)));
    expect(text, contains(TripStrings.agreedInTotal(BrowseItem.inr(7200))));
    expect(text, contains(TripStrings.summaryFooter));
  });

  test('taxi pay line only appears with a taxi', () {
    final withTaxi = TripSummaryText.build(TripSummaryRecord.fromJson(record()));
    final without = TripSummaryText.build(TripSummaryRecord.fromJson(record(taxis: [])));
    expect(withTaxi, contains(TripStrings.taxiPayLine));
    expect(without, isNot(contains(TripStrings.taxiPayLine)));
    expect(without, contains(TripStrings.summaryFooter));
  });

  test('no UPI id or payment wording leaks into the text', () {
    final text = TripSummaryText.build(TripSummaryRecord.fromJson(record())).toLowerCase();
    expect(text, isNot(contains('upi')));
    expect(text, isNot(contains('@')));
    expect(text, isNot(contains('verified')));
    expect(text, isNot(contains('guaranteed')));
  });

  test('stays under the share limit with many long nights', () {
    final nights = [
      for (var i = 1; i <= 13; i++)
        night(i % 9 + 1, name: 'A very long homestay name number $i in the hills', cancellation: 'Free cancellation till ${'x' * 120}'),
    ];
    final text = TripSummaryText.build(TripSummaryRecord.fromJson(record(nights: nights)));
    expect(text.length, lessThanOrEqualTo(TripConstants.summaryShareMax));
    expect(text, contains(TripStrings.summaryFooter));
  });

  test('empty record still builds a short text', () {
    final text = TripSummaryText.build(TripSummaryRecord.fromJson(record(nights: [], taxis: [])));
    expect(text, contains('Nainital'));
    expect(text.length, lessThan(TripConstants.summaryShareMax));
  });

  Map<String, dynamic> day(int n, List<String> spots, {int minutes = 370}) => {
        'day': n,
        'date': '2026-11-0$n',
        'spots': spots,
        'minutes': minutes,
      };

  test('plan-only record shares the itinerary and the plan-only footer', () {
    final json = record(nights: [], taxis: [])
      ..['days'] = [
        day(1, ['Kempty Falls', 'Lal Tibba', 'Mall Road']),
      ]
      ..['adults'] = 1
      ..['kids'] = 0;
    final r = TripSummaryRecord.fromJson(json);
    final text = TripSummaryText.build(r);
    expect(TripSummaryText.canShare(r), isTrue);
    expect(text, contains('Kempty Falls → Lal Tibba → Mall Road'));
    expect(text, contains('1 person'));
    expect(text, isNot(contains('1 people')));
    expect(text, contains(TripStringsA5.planOnlyFooter));
    expect(text, isNot(contains(TripStrings.summaryFooter)));
  });

  test('own-only record gets the own footer and no host or driver line', () {
    final own = {
      'night': 1,
      'date': '2026-11-01',
      'listingName': 'My cousin',
      'isOwn': true,
      'displayStatus': 'own',
    };
    final ownTaxi = {...taxi(), 'isOwn': true, 'displayStatus': 'own'};
    final text = TripSummaryText.build(TripSummaryRecord.fromJson(record(nights: [own], taxis: [ownTaxi])));
    expect(text, contains(TripStringsA5.ownFooter));
    expect(text, isNot(contains(TripStrings.summaryFooter)));
    expect(text, isNot(contains(TripStrings.taxiPayLine)));
  });

  test('skipped night reads as no stay and keeps the host line for other nights', () {
    final skipped = {'night': 2, 'date': '2026-11-02', 'listingName': 'No stay tonight', 'displayStatus': 'skipped'};
    final text = TripSummaryText.build(TripSummaryRecord.fromJson(record(nights: [night(1), skipped], taxis: [])));
    expect(text, contains(TripStringsA5.noStayTravelling));
    expect(text, contains(TripStrings.summaryFooter));
  });

  test('check-out is the morning after the night', () {
    final r = TripSummaryRecord.fromJson(record(nights: [night(3)]));
    expect(TripSummaryText.checkOutOf(r.nights.first.date), 'Wed 04 Nov');
  });

  Map<String, dynamic> leg(int i, String from, String to, String driver, int fare, {String? meeting}) => {
        'legIndex': i,
        'fromName': from,
        'toName': to,
        'meetingPlace': meeting,
        'listedFare': fare,
        'carsNeeded': 1,
        'driverAvailable': true,
        'lastKnownStatus': 'Unknown',
        'taxiId': 't$i',
        'driverName': driver,
        'phone': '9800000000',
      };

  Map<String, dynamic> journey(String role, {List<Map<String, dynamic>>? legs, String date = '2026-11-01'}) {
    final l = legs ??
        [
          leg(1, 'Delhi', 'Haridwar', 'Sunil Kumar', 4200),
          leg(2, 'Haridwar', 'Nainital', 'Mohan Bisht', 9800),
        ];
    return {
      'id': 'j-$role',
      'role': role,
      'fromName': 'Delhi',
      'fromLat': 28.6,
      'fromLng': 77.2,
      'toName': 'Nainital',
      'toLat': 29.4,
      'toLng': 79.5,
      'date': date,
      'people': 4,
      'cars': l.length,
      'status': 'Ready',
      'listedTotal': 14000,
      'legs': l,
    };
  }

  Map<String, dynamic> withSteps(Map<String, dynamic> steps, {Map<String, dynamic>? gt, Map<String, dynamic>? cb}) =>
      {
        ...record(),
        'steps': steps,
        'gettingThere': ?gt,
        'comingBack': ?cb,
      };

  test('getting there block shows route, cars, about total, car rows and the change place', () {
    final r = TripSummaryRecord.fromJson(withSteps(
      {
        'gettingThere': {'status': 'chosen', 'journeyId': 'j-gettingThere'},
      },
      gt: journey('gettingThere'),
    ));
    final text = TripSummaryText.build(r);
    expect(text, contains('Getting there'));
    expect(text, contains('Delhi → Haridwar → Nainital'));
    expect(text, contains('2 cars'));
    expect(text, contains('about ${BrowseItem.inr(14000)}'));
    expect(text, contains('Car 1 Sunil Kumar'));
    expect(text, contains('Car 2 Mohan Bisht'));
    expect(text, contains('change car at Haridwar'));
    expect(text.indexOf('Getting there'), lessThan(text.indexOf('Night 1')));
    expect(text, isNot(contains('9800000000')));
  });

  test('coming back with one car sits after the taxis', () {
    final r = TripSummaryRecord.fromJson(withSteps(
      {
        'comingBack': {'status': 'booked', 'journeyId': 'j-comingBack'},
      },
      cb: journey('comingBack', legs: [leg(1, 'Nainital', 'Delhi', 'Rajesh Kumar', 5200)], date: '2026-11-03'),
    ));
    final text = TripSummaryText.build(r);
    expect(text, contains('Coming back'));
    expect(text, contains('1 car'));
    expect(text, contains('Car 1 Rajesh Kumar'));
    expect(text.indexOf('Coming back'), greaterThan(text.indexOf('Mohan Bisht')));
  });

  test('own step is one line with the note', () {
    final r = TripSummaryRecord.fromJson(withSteps({
      'gettingThere': {'status': 'own', 'note': 'Own car, leaving 6 am'},
    }));
    final text = TripSummaryText.build(r);
    expect(text, contains('Arranged by you · Own car, leaving 6 am'));
  });

  test('skipped and not needed steps are omitted', () {
    final r = TripSummaryRecord.fromJson(withSteps({
      'gettingThere': {'status': 'skipped'},
      'comingBack': {'status': 'notNeeded'},
    }));
    final text = TripSummaryText.build(r);
    expect(text, isNot(contains('Getting there')));
    expect(text, isNot(contains('Coming back')));
    expect(TripSummaryText.hasSteps(r), isFalse);
  });

  test('a chosen journey alone brings the driver pay line', () {
    final r = TripSummaryRecord.fromJson({
      ...withSteps(
        {
          'gettingThere': {'status': 'chosen', 'journeyId': 'j-gettingThere'},
        },
        gt: journey('gettingThere'),
      ),
      'taxis': <Map<String, dynamic>>[],
    });
    expect(TripSummaryText.footer(r), contains(TripStrings.taxiPayLine));
  });
}
