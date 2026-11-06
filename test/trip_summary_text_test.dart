import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_summary_model.dart';
import 'package:bakhli/features/trip/trip_constants.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/trip_strings_a5.dart';
import 'package:bakhli/features/trip/utils/trip_summary_text.dart';
import 'package:bakhli/features/trip/utils/trip_wizard_rules.dart';
import 'package:bakhli/features/trip/widgets/trip_status.dart';
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

  test('skipped and legacy not needed steps are omitted', () {
    final r = TripSummaryRecord.fromJson(withSteps({
      'gettingThere': {'status': 'skipped'},
      'comingBack': {'status': 'notNeeded'},
    }));
    final text = TripSummaryText.build(r);
    expect(text, isNot(contains('Getting there')));
    expect(text, isNot(contains('Coming back')));
    expect(TripSummaryText.hasSteps(r), isFalse);
    expect(TripSummaryText.stepState(r, TripStepRole.comingBack), TripStepState.todo);
  });

  test('a saved journey nobody asked is waiting, not done', () {
    final r = TripSummaryRecord.fromJson(withSteps(
      {
        'gettingThere': {'status': 'chosen', 'journeyId': 'j-gettingThere'},
      },
      gt: journey('gettingThere'),
    ));
    final state = TripSummaryText.stepState(r, TripStepRole.gettingThere);
    expect(state, TripStepState.waiting);
    expect(TripSummaryText.pillStatus(state), TripDisplayStatus.asked);
    expect(TripSummaryText.stepInfo(r, TripStepRole.gettingThere)?.counted, isFalse);
  });

  test('own step reads own and counts', () {
    final r = TripSummaryRecord.fromJson(withSteps({
      'gettingThere': {'status': 'own', 'note': 'By bus'},
    }));
    final info = TripSummaryText.stepInfo(r, TripStepRole.gettingThere);
    expect(info?.state, TripStepState.own);
    expect(info?.counted, isTrue);
    expect(TripSummaryText.pillStatus(info?.state), TripDisplayStatus.own);
  });

  test('pill status has one look per state', () {
    expect(TripSummaryText.pillStatus(TripStepState.done), TripDisplayStatus.confirmedByBoth);
    expect(TripSummaryText.pillStatus(TripStepState.skipped), TripDisplayStatus.own);
    expect(TripSummaryText.pillStatus(TripStepState.attention), TripDisplayStatus.notAvailable);
    expect(TripSummaryText.pillStatus(TripStepState.todo), TripDisplayStatus.none);
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

  group('multi-city (MC-D)', () {
    Map<String, dynamic> car(int i, String driver, String from, String to,
            {int? agreed, int? listed, String status = 'none', String? confirmedBy, String? enquiryId}) =>
        {
          'car': i,
          'driverName': driver,
          'fromName': from,
          'toName': to,
          'agreedFare': ?agreed,
          'listedFare': ?listed,
          'displayStatus': status,
          'confirmedBy': ?confirmedBy,
          'enquiryId': ?enquiryId,
          'taxiId': 'x$i',
        };

    Map<String, dynamic> journeyTravel() => {
          'mode': 'journey',
          'fromName': 'Haridwar',
          'toName': 'Badrinath',
          'day': 2,
          'date': '2026-11-02',
          'state': 'partlyBooked',
          'carCount': 2,
          'listedTotal': 14000,
          'cars': [
            car(1, 'Sunil Kumar', 'Haridwar', 'Rishikesh',
                agreed: 4200, listed: 4000, status: 'confirmedByBoth', confirmedBy: 'both', enquiryId: 'q1'),
            car(2, 'Mohan Bisht', 'Rishikesh', 'Badrinath', listed: 9800),
          ],
        };

    Map<String, dynamic> twoLegs({Map<String, dynamic>? travel, List<Map<String, dynamic>>? nights}) {
      final n = nights ?? [night(1, name: 'Ganga View Inn'), night(2, name: 'Alaknanda View'), night(3, name: 'Alaknanda View')];
      return {
        ...record(nights: n, taxis: []),
        'title': 'Haridwar, Badrinath trip',
        'city': 'Haridwar',
        'legCities': ['Haridwar', 'Badrinath'],
        'legs': [
          {
            'index': 1,
            'cityName': 'Haridwar',
            'startDay': 1,
            'endDay': 1,
            'startDate': '2026-11-01',
            'endDate': '2026-11-01',
            'nights': n.take(1).toList(),
          },
          {
            'index': 2,
            'cityName': 'Badrinath',
            'startDay': 2,
            'endDay': 3,
            'startDate': '2026-11-02',
            'endDate': '2026-11-03',
            'nights': n.skip(1).toList(),
            'travel': travel ?? journeyTravel(),
          },
        ],
      };
    }

    test('a one-leg record with legs[] reads exactly as before', () {
      final flat = record();
      final withLeg = {
        ...record(),
        'legs': [
          {'index': 1, 'cityName': 'Nainital', 'startDay': 1, 'endDay': 3, 'nights': flat['nights'], 'taxis': flat['taxis']},
        ],
      };
      final a = TripSummaryText.build(TripSummaryRecord.fromJson(flat));
      final b = TripSummaryText.build(TripSummaryRecord.fromJson(withLeg));
      expect(b, a);
      expect(b, contains(TripStringsA5.staysSection));
    });

    test('groups by leg with the headers in order and the travel block before leg 2', () {
      final text = TripSummaryText.build(TripSummaryRecord.fromJson(twoLegs()));
      final h1 = text.indexOf('HARIDWAR · Sun 01 Nov');
      final travel = text.indexOf('→ Badrinath · 2 cars · Mon 02 Nov');
      final h2 = text.indexOf('BADRINATH · Mon 02 – Tue 03 Nov');
      expect(h1, greaterThanOrEqualTo(0));
      expect(travel, greaterThan(h1));
      expect(h2, greaterThan(travel));
      expect(text.indexOf('Ganga View Inn'), inInclusiveRange(h1, travel));
      expect(text.indexOf('Alaknanda View'), greaterThan(h2));
      expect(text, isNot(contains(TripStringsA5.staysSection)));
      expect(text, contains('Haridwar → Badrinath'));
    });

    test('car lines at level 0 carry fare and status', () {
      final text = TripSummaryText.build(TripSummaryRecord.fromJson(twoLegs()));
      expect(text, contains('  Car 1 Sunil Kumar · ${BrowseItem.inr(4200)} · ${TripStrings.confirmedBothPill}'));
      expect(text, contains('  Car 2 Mohan Bisht · ${BrowseItem.inr(9800)} · Not asked'));
    });

    test('at level 2 the cars fold into one state line', () {
      final r = TripSummaryRecord.fromJson(twoLegs());
      final t = r.legs[1].travel!;
      final lines = TripSummaryText.travelLines(t, 2);
      expect(lines, contains('  2 cars · Partly booked'));
      expect(lines.any((l) => l.contains('Sunil Kumar')), isFalse);
    });

    test('own travel is one line and adds no driver line', () {
      final own = {
        'mode': 'own',
        'fromName': 'Haridwar',
        'toName': 'Badrinath',
        'day': 2,
        'date': '2026-11-02',
        'state': 'own',
        'how': 'bus',
        'leavesAt': '06:00',
        'ownName': 'Shatabdi',
      };
      final text = TripSummaryText.build(TripSummaryRecord.fromJson(twoLegs(travel: own)));
      expect(text, contains('→ Badrinath · Own travel · Mon 02 Nov'));
      expect(text, contains('  Own travel · Bus · 6:00 am · Shatabdi'));
      expect(text, isNot(contains(TripStrings.taxiPayLine)));
    });

    test('a journey car alone brings the driver pay line', () {
      final r = TripSummaryRecord.fromJson(twoLegs(nights: [
        {'night': 1, 'date': '2026-11-01', 'listingName': 'My cousin', 'isOwn': true, 'displayStatus': 'own'},
        {'night': 2, 'date': '2026-11-02', 'listingName': 'Friend', 'isOwn': true, 'displayStatus': 'own'},
      ]));
      expect(r.taxis, isEmpty);
      expect(TripSummaryText.footer(r), contains(TripStrings.taxiPayLine));
      expect(TripSummaryText.footer(r), isNot(contains(TripStrings.summaryFooter)));
    });

    test('a long multi-city record stays under the share limit and ends with the footer', () {
      final nights = [
        for (var i = 1; i <= 9; i++)
          night(i, name: 'A very long homestay name number $i in the hills', cancellation: 'Free cancellation till ${'x' * 160}'),
      ];
      final json = twoLegs(nights: nights);
      final r = TripSummaryRecord.fromJson(json);
      final text = TripSummaryText.build(r);
      expect(text.length, lessThanOrEqualTo(TripConstants.summaryShareMax));
      expect(text.endsWith(TripSummaryText.footer(r)), isTrue);
    });

    test('nightGroups joins consecutive nights of one stay enquiry only', () {
      Map<String, dynamic> base(int n, String enquiry, {int? agreed}) => {
            ...night(n, name: 'Alaknanda View'),
            'enquiryId': enquiry,
            'agreedTotal': agreed,
          };
      final nights = [
        night(1, name: 'Ganga View Inn'),
        base(2, 'q2', agreed: 4200),
        base(3, 'q2'),
        base(4, 'q2'),
        {'night': 5, 'date': '2026-11-05', 'listingName': 'My cousin', 'isOwn': true, 'displayStatus': 'own'},
        base(6, 'q2'),
      ].map(TripSummaryNight.fromJson).toList();
      final groups = TripSummaryText.nightGroups(nights);
      expect(groups.map((g) => g.nights.map((n) => n.night).toList()).toList(), [
        [1],
        [2, 3, 4],
        [5],
        [6],
      ]);
      expect(groups[1].isRange, isTrue);
      expect(groups[1].agreedTotal, 4200);
      expect(TripSummaryText.checkOutOf(groups[1].last.date), 'Thu 05 Nov');
      expect(groups[0].isRange, isFalse);
    });

    test('nightGroups never joins skipped nights or nights without an enquiry', () {
      final nights = [
        {'night': 1, 'date': '2026-11-01', 'listingName': 'A', 'enquiryId': 'q', 'displayStatus': TripSummaryText.skippedStatus},
        {'night': 2, 'date': '2026-11-02', 'listingName': 'A', 'enquiryId': 'q', 'displayStatus': TripSummaryText.skippedStatus},
        {'night': 3, 'date': '2026-11-03', 'listingName': 'B'},
        {'night': 4, 'date': '2026-11-04', 'listingName': 'B'},
      ].map(TripSummaryNight.fromJson).toList();
      expect(TripSummaryText.nightGroups(nights).every((g) => !g.isRange), isTrue);
      expect(TripSummaryText.nightGroups(const []), isEmpty);
    });

    test('travel alone makes the record shareable', () {
      final json = twoLegs(nights: [])..['days'] = <Map<String, dynamic>>[];
      final r = TripSummaryRecord.fromJson(json);
      expect(TripSummaryText.canShare(r), isTrue);
      expect(TripSummaryText.hasContent(r), isTrue);
    });
  });
}
