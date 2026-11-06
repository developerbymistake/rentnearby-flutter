import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_journey_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_step_rules.dart';
import 'package:bakhli/features/trip/utils/trip_wizard_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _delhi = TripStartFrom(name: 'Delhi', lat: 28.6139, lon: 77.2090);
final _start = DateTime(2030, 11, 13);

TripSpotRef _spot(String id) =>
    TripSpotRef(id: id, name: id, latitude: 29.39, longitude: 79.45, category: 'attraction', visitMinutes: 60);

const _nainital = TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29.3919, longitude: 79.4542);
const _almora = TripCityLeg(index: 2, cityKey: 2, cityName: 'Almora', latitude: 29.5971, longitude: 79.6591);

TripPlan _twoCity({
  List<TripDay>? days,
  TripSteps steps = const TripSteps(startFrom: _delhi),
  TripTravel? arrival,
  List<String> dismissed = const [],
}) =>
    TripPlan(
      legs: [_nainital, _almora.copyWith(arrival: arrival)],
      days: days ??
          [
            TripDay(day: 1, leg: 1, spots: [_spot('a')]),
            TripDay(day: 2, leg: 1, spots: [_spot('b')]),
            TripDay(day: 3, leg: 2, spots: [_spot('c')]),
          ],
      settings: TripSettings(startDate: _start, adults: 2),
      steps: steps,
      dismissedEnquiryIds: dismissed,
    );

TripPlan _oneCity(List<TripDay> days, {TripSteps steps = const TripSteps(startFrom: _delhi)}) => TripPlan(
      legs: const [_nainital],
      days: days,
      settings: TripSettings(startDate: _start, adults: 2),
      steps: steps,
    );

DateTime _d(int day) => DateTime(_start.year, _start.month, _start.day + day - 1);

TripEnquiryModel _stayRow(String id, int night, String status, {int nights = 1, int? total, String? fail, DateTime? at}) =>
    TripEnquiryModel(
      id: id,
      tripId: 't1',
      listingId: 'stay-$id',
      listingName: 'Stay $id',
      day: night,
      checkIn: _d(night),
      checkOut: _d(night + nights),
      status: status,
      failReason: fail,
      agreedTotal: total,
      createdAt: at ?? DateTime(2030, 1, 1),
    );

TripEnquiryModel _taxiRow(String id, int day, String status, {int? fare, String? fail}) => TripEnquiryModel(
      id: id,
      tripId: 't1',
      kind: TripEnquiryKinds.taxi,
      listingId: 'taxi-$id',
      listingName: 'Driver $id',
      checkIn: _d(day),
      days: [day],
      status: status,
      failReason: fail,
      taxi: fare == null ? null : TripTaxiModel(agreedFare: fare, driverFare: fare),
      createdAt: DateTime(2030, 1, 1),
    );

TripEnquiryModel _carRow(String journeyId, int car, String status, DateTime date, {int fare = 3000}) => TripEnquiryModel(
      id: 'car-$journeyId-$car',
      tripId: 't1',
      kind: TripEnquiryKinds.taxi,
      listingId: 'driver-$car',
      listingName: 'Driver $car',
      day: 1,
      checkIn: date,
      checkOut: date,
      days: const [1],
      status: status,
      taxi: TripTaxiModel(agreedFare: fare),
      context: TripEnquiryContext(journeyId: journeyId, journeyLegIndex: car),
      createdAt: DateTime(2030, 1, 1),
    );

TripJourney _journey(String id, DateTime date, {int cars = 2, bool asked = false, String? free}) => TripJourney(
      id: id,
      fromName: 'Delhi',
      fromLat: 28.6139,
      fromLng: 77.2090,
      toName: 'Nainital',
      toLat: 29.3919,
      toLng: 79.4542,
      date: date,
      cars: cars,
      legs: [
        for (var c = 1; c <= cars; c++)
          TripJourneyLeg(
            legIndex: c,
            fromName: c == 1 ? 'Delhi' : 'Haldwani',
            toName: c == cars ? 'Nainital' : 'Haldwani',
            driverName: 'Driver $c',
            lastEnquiryId: asked ? 'x$c' : null,
            lastKnownStatus: free ?? 'Unknown',
          ),
      ],
    );

TripWizardInput _in(TripPlan p, {List<TripEnquiryModel> rows = const [], List<TripJourney> journeys = const []}) =>
    TripWizardInput(plan: p, enquiries: rows, journeys: journeys, today: DateTime(2030, 1, 1));

TripStepInfo _info(List<TripStepInfo> s, String id) => s.firstWhere((x) => x.key.id == id);

const _gtChosen = TripSteps(
  startFrom: _delhi,
  gettingThere: TripStep(status: TripStepStatus.chosen, journeyId: 'j1'),
);

TripDay _withTaxi(TripDay d, TripTaxiChoice t) => d.copyWith(taxi: t);

void main() {
  group('step list (no auto not needed)', () {
    test('1-day trip has 6 steps in order', () {
      final p = _oneCity([TripDay(day: 1, spots: [_spot('a')])]);
      final ids = [for (final s in TripWizardRules.steps(_in(p))) s.key.id];
      expect(ids, ['basics', 'gettingThere', 'places:1:1', 'taxi:1:1', 'stay:1:1', 'comingBack']);
    });

    test('3-day 2-city trip has 13 steps with the city change between the days', () {
      final ids = [for (final s in TripWizardRules.steps(_in(_twoCity()))) s.key.id];
      expect(ids, [
        'basics',
        'gettingThere',
        'places:1:1',
        'taxi:1:1',
        'stay:1:1',
        'places:1:2',
        'taxi:1:2',
        'stay:1:2',
        'travel:2',
        'places:2:1',
        'taxi:2:1',
        'stay:2:1',
        'comingBack',
      ]);
    });

    test('14-day 4-city trip has 48 steps', () {
      final legs = [
        for (var k = 1; k <= 4; k++) TripCityLeg(index: k, cityKey: k, cityName: 'C$k', latitude: 29 + k / 10, longitude: 79),
      ];
      final days = [
        for (var d = 1; d <= 14; d++) TripDay(day: d, leg: d <= 4 ? 1 : (d <= 8 ? 2 : (d <= 11 ? 3 : 4))),
      ];
      final p = TripPlan(legs: legs, days: days, settings: TripSettings(startDate: _start));
      final s = TripWizardRules.steps(_in(p));
      expect(s.length, 48);
      expect(s.where((x) => x.kind == TripWizardStepKind.travel).map((x) => x.key.id), ['travel:2', 'travel:3', 'travel:4']);
      expect(s.last.key.id, 'comingBack');
    });

    test('a start inside the city still offers Getting there and Coming back', () {
      const inside = TripSteps(startFrom: TripStartFrom(name: 'Nainital', lat: 29.392, lon: 79.454));
      final s = TripWizardRules.steps(_in(_twoCity(steps: inside)));
      expect(_info(s, 'gettingThere').state, TripStepState.todo);
      expect(_info(s, 'comingBack').state, TripStepState.todo);
    });

    test('keys round trip and reject bad ids', () {
      for (final id in ['basics', 'gettingThere', 'comingBack', 'stay:1:2', 'taxi:2:1', 'places:3:4', 'travel:2']) {
        expect(TripStepKey.parse(id)?.id, id);
      }
      for (final id in ['', 'travel:1', 'stay:1', 'stay:0:1', 'foo:1:1', 'basics:1', 'stay:a:1']) {
        expect(TripStepKey.parse(id), isNull, reason: id);
      }
      expect(TripStepKey.parse('stay:1:2'), const TripStepKey.stay(1, 2));
    });

    test('infoOf resolves a day key and refuses a missing day', () {
      final i = _in(_twoCity());
      expect(TripWizardRules.infoOf(i, const TripStepKey.stay(2, 1))?.day, 3);
      expect(TripWizardRules.infoOf(i, const TripStepKey.stay(2, 2)), isNull);
      expect(TripWizardRules.infoOf(i, const TripStepKey.travel(3)), isNull);
    });
  });

  group('shared vectors', () {
    List<TripStepInfo> v2Steps({bool v3 = false}) {
      final p = _twoCity(
        steps: _gtChosen,
        days: [
          _withTaxi(TripDay(day: 1, leg: 1, spots: [_spot('a')]), TripTaxiChoice.own(name: 'Ravi')),
          TripDay(day: 2, leg: 1, spots: [_spot('b')]),
          TripDay(day: 3, leg: 2, spots: [_spot('c')]),
        ],
      );
      final rows = v3
          ? [
              _stayRow('n1', 1, TripEnquiryStatuses.confirmedByBoth, total: 2400),
              _carRow('j1', 1, TripEnquiryStatuses.confirmedByBoth, _d(1)),
              _carRow('j1', 2, TripEnquiryStatuses.confirmedByBoth, _d(1)),
            ]
          : [_stayRow('n1', 1, TripEnquiryStatuses.asked)];
      return TripWizardRules.steps(_in(p, rows: rows, journeys: [_journey('j1', _d(1))]));
    }

    test('V1 fresh auto split', () {
      final s = TripWizardRules.steps(_in(_twoCity()));
      final pr = TripWizardRules.progress(s);
      expect((pr.counted, pr.total, pr.percent, pr.decided), (4, 13, 30, 0));
      expect(TripWizardRules.nextStep(s)?.key.id, 'gettingThere');
    });

    test('V2 saved journey needs you, an asked night waits for a reply', () {
      final s = v2Steps();
      final pr = TripWizardRules.progress(s);
      expect((pr.counted, pr.total, pr.percent), (5, 13, 38));
      expect(pr.needYou, 1);
      expect(pr.waitingForReply, 1);
      expect(_info(s, 'gettingThere').needsYou, isTrue);
      expect(_info(s, 'stay:1:1').state, TripStepState.waiting);
      expect(TripWizardRules.nextStep(s)?.key.id, 'gettingThere');
    });

    test('V3 confirmed night and both cars confirmed', () {
      final s = v2Steps(v3: true);
      final pr = TripWizardRules.progress(s);
      expect((pr.counted, pr.percent), (7, 53));
      expect(_info(s, 'gettingThere').state, TripStepState.done);
      expect(_info(s, 'gettingThere').agreedRupees, 6000);
      expect(TripWizardRules.nextStep(s)?.key.id, 'taxi:1:2');
    });

    TripPlan v4Plan({bool v5 = false}) => _twoCity(
          steps: v5
              ? const TripSteps(
                  startFrom: _delhi,
                  gettingThere: TripStep(status: TripStepStatus.chosen, journeyId: 'j1'),
                  comingBack: TripStep(status: TripStepStatus.own),
                )
              : _gtChosen,
          arrival: v5 ? const TripTravel.own(fromName: 'Nainital', how: TripTravelHow.bus) : null,
          days: [
            _withTaxi(TripDay(day: 1, leg: 1, spots: [_spot('a')]), TripTaxiChoice.own(name: 'Ravi')),
            TripDay(day: 2, leg: 1, spots: [_spot('b')]),
            TripDay(day: 3, leg: 2, spots: [_spot('c')]),
          ],
        );

    List<TripEnquiryModel> v4Rows({bool v5 = false}) => [
          _stayRow('n1', 1, TripEnquiryStatuses.confirmedByBoth, total: 2400),
          _carRow('j1', 1, TripEnquiryStatuses.confirmedByBoth, _d(1)),
          _carRow('j1', 2, TripEnquiryStatuses.confirmedByBoth, _d(1)),
          _stayRow('n2', 2, TripEnquiryStatuses.confirmedByTraveller),
          _taxiRow('t2', 2, TripEnquiryStatuses.bookedByTraveller, fare: 2000),
          if (v5) ...[
            _taxiRow('t3', 3, TripEnquiryStatuses.confirmedByBoth, fare: 2200),
            _stayRow('n3', 3, TripEnquiryStatuses.confirmedByBoth, total: 1800),
          ],
        ];

    test('V4 booked by you is waiting for a reply, not counted', () {
      final s = TripWizardRules.steps(_in(v4Plan(), rows: v4Rows(), journeys: [_journey('j1', _d(1))]));
      final pr = TripWizardRules.progress(s);
      expect((pr.counted, pr.percent), (7, 53));
      expect(_info(s, 'stay:1:2').state, TripStepState.waiting);
      expect(_info(s, 'stay:1:2').needsYou, isFalse);
      expect(_info(s, 'taxi:1:2').state, TripStepState.waiting);
      expect(_info(s, 'taxi:1:2').needsYou, isFalse);
      expect(TripWizardRules.nextStep(s)?.key.id, 'travel:2');
    });

    test('V5 then the first other waiting step is next', () {
      final s = TripWizardRules.steps(_in(v4Plan(v5: true), rows: v4Rows(v5: true), journeys: [_journey('j1', _d(1))]));
      final pr = TripWizardRules.progress(s);
      expect((pr.counted, pr.percent), (11, 84));
      expect(TripWizardRules.nextStep(s)?.key.id, 'taxi:1:2');
      expect(TripWizardRules.runningCost(s), 2400 + 6000 + 2200 + 1800);
    });

    test('V6 everything counted is ready', () {
      final rows = [
        for (final e in v4Rows(v5: true))
          if (e.id == 'n2' || e.id == 't2')
            TripEnquiryModel(
              id: e.id,
              tripId: e.tripId,
              kind: e.kind,
              listingId: e.listingId,
              listingName: e.listingName,
              day: e.day,
              checkIn: e.checkIn,
              checkOut: e.checkOut,
              days: e.days,
              taxi: e.taxi,
              status: TripEnquiryStatuses.confirmedByBoth,
            )
          else
            e,
      ];
      final s = TripWizardRules.steps(_in(v4Plan(v5: true), rows: rows, journeys: [_journey('j1', _d(1))]));
      final pr = TripWizardRules.progress(s);
      expect((pr.counted, pr.total, pr.percent), (13, 13, 100));
      expect(TripWizardRules.nextStep(s), isNull);
      expect(TripWizardRules.wishlist(s), isEmpty);
    });

    test('V7 one-day trip leaving the same evening', () {
      final p = _oneCity(
        [const TripDay(day: 1, stay: TripStayChoice.skippedNight())],
        steps: const TripSteps(
          startFrom: _delhi,
          comingBack: TripStep(status: TripStepStatus.own, leaveOn: TripLeaveOn.lastDayEvening),
        ),
      );
      final s = TripWizardRules.steps(_in(p));
      final pr = TripWizardRules.progress(s);
      expect((pr.counted, pr.total, pr.percent), (3, 6, 50));
      expect(TripWizardRules.nextStep(s)?.key.id, 'gettingThere');
    });

    test('V8 a dismissed problem night is todo, not attention', () {
      final p = _oneCity([TripDay(day: 1, spots: [_spot('a')])]);
      final rows = [_stayRow('e1', 1, TripEnquiryStatuses.expired)];
      expect(TripWizardRules.stayState(_in(p, rows: rows), 1), TripStepState.attention);
      final dismissed = p.withDismissed('e1');
      expect(TripWizardRules.stayState(_in(dismissed, rows: rows), 1), TripStepState.todo);
    });

    test('V9 stored notNeeded reads as todo', () {
      final p = _twoCity(steps: const TripSteps(startFrom: _delhi, comingBack: TripStep(status: TripStepStatus.notNeeded)));
      expect(TripWizardRules.journeyStepState(_in(p), TripStepRole.comingBack), TripStepState.todo);
    });

    TripPlan sameAsPlan() => _oneCity([
          TripDay(day: 1, spots: [_spot('a')]),
          TripDay(day: 2, spots: [_spot('b')], stay: const TripStayChoice(stayId: 'stay-n2', name: 'Stay n2')),
          TripDay(
              day: 3,
              spots: [_spot('c')],
              stay: const TripStayChoice(stayId: 'stay-n2', name: 'Stay n2', sameAsDay: 2)),
        ]);

    test('V10 same as last night covered by the booking is done', () {
      final rows = [_stayRow('n2', 2, TripEnquiryStatuses.confirmedByBoth, nights: 2, total: 4000)];
      final i = _in(sameAsPlan(), rows: rows);
      expect(TripWizardRules.stayState(i, 3), TripStepState.done);
      expect(TripWizardRules.infoOf(i, const TripStepKey.stay(1, 3))?.agreedRupees, 2000);
    });

    test('V11 same as last night not covered needs you', () {
      final rows = [_stayRow('n2', 2, TripEnquiryStatuses.confirmedByBoth, total: 2000)];
      final info = TripWizardRules.infoOf(_in(sameAsPlan(), rows: rows), const TripStepKey.stay(1, 3))!;
      expect(info.state, TripStepState.waiting);
      expect(info.needsYou, isTrue);
    });

    test('V12 own stay plus a confirmed booking is two plans', () {
      final p = _oneCity([
        TripDay(day: 1, spots: [_spot('a')]),
        TripDay(day: 2, spots: [_spot('b')], stay: const TripStayChoice(stayId: '', name: 'Uncle', isOwn: true)),
      ]);
      final info = TripWizardRules.infoOf(
          _in(p, rows: [_stayRow('n2', 2, TripEnquiryStatuses.confirmedByBoth)]), const TripStepKey.stay(1, 2))!;
      expect(info.state, TripStepState.attention);
      expect(info.needsYou, isTrue);
      expect(info.counted, isFalse);
      expect(info.enquiryId, 'n2');
    });

    test('V13 car 1 confirmed, car 2 booked by you', () {
      final info = TripWizardRules.infoOf(
        _in(_twoCity(steps: _gtChosen), rows: [
          _carRow('j1', 1, TripEnquiryStatuses.confirmedByBoth, _d(1)),
          _carRow('j1', 2, TripEnquiryStatuses.bookedByTraveller, _d(1)),
        ], journeys: [
          _journey('j1', _d(1))
        ]),
        TripStepKey.gettingThere,
      )!;
      expect(info.state, TripStepState.waiting);
      expect(info.needsYou, isFalse);
      expect(info.cars.map((c) => c.state), [TripCarState.confirmed, TripCarState.bookedByYou]);
      expect(info.line, 'Car 1 confirmed · Car 2 booked by you, driver not confirmed');
    });

    test('V14 car 1 confirmed and car 2 your own is done', () {
      const steps = TripSteps(
        startFrom: _delhi,
        gettingThere: TripStep(status: TripStepStatus.chosen, journeyId: 'j1', ownCars: [2]),
      );
      final info = TripWizardRules.infoOf(
        _in(_twoCity(steps: steps),
            rows: [_carRow('j1', 1, TripEnquiryStatuses.confirmedByBoth, _d(1), fare: 3500)],
            journeys: [_journey('j1', _d(1))]),
        TripStepKey.gettingThere,
      )!;
      expect(info.state, TripStepState.done);
      expect(info.agreedRupees, 3500);
      expect(info.cars.map((c) => c.state), [TripCarState.confirmed, TripCarState.own]);
    });

    test('V15 leave on the last evening moves the expected date', () {
      TripStepInfo back(TripLeaveOn leaveOn) {
        final steps = TripSteps(
          startFrom: _delhi,
          comingBack: TripStep(status: TripStepStatus.chosen, journeyId: 'j9', leaveOn: leaveOn),
        );
        final p = _twoCity(steps: steps);
        final j = TripJourney(
          id: 'j9',
          fromName: 'Almora',
          fromLat: 29.5971,
          fromLng: 79.6591,
          toName: 'Delhi',
          toLat: 28.6139,
          toLng: 77.2090,
          date: _d(3),
          legs: const [TripJourneyLeg(legIndex: 1, fromName: 'Almora', toName: 'Delhi')],
        );
        return TripWizardRules.infoOf(_in(p, journeys: [j]), TripStepKey.comingBack)!;
      }

      const evening = TripSteps(comingBack: TripStep(leaveOn: TripLeaveOn.lastDayEvening));
      expect(TripWizardRules.comingBackDate(TripSettings(startDate: _start), evening, 3), _d(3));
      expect(back(TripLeaveOn.lastDayEvening).state, TripStepState.waiting);
      expect(back(TripLeaveOn.checkOut).state, TripStepState.attention);
      expect(back(TripLeaveOn.checkOut).line, TripWizardCopy.leaveMoved);
    });

    test('V16 an unasked shortlist needs you and comes first', () {
      final p = _twoCity(days: [
        TripDay(day: 1, leg: 1, spots: [_spot('a')], stayShortlist: const [
          TripStayShortlistItem(stayId: 's1', name: 'One'),
          TripStayShortlistItem(stayId: 's2', name: 'Two'),
        ]),
        TripDay(day: 2, leg: 1, spots: [_spot('b')]),
        TripDay(day: 3, leg: 2, spots: [_spot('c')]),
      ]);
      final s = TripWizardRules.steps(_in(p));
      final night = _info(s, 'stay:1:1');
      expect(night.state, TripStepState.waiting);
      expect(night.needsYou, isTrue);
      expect(night.line, 'Shortlisted 2 · not asked');
      expect(TripWizardRules.nextStep(s)?.key.id, 'stay:1:1');
    });
  });

  group('stay table', () {
    TripStepInfo night(List<TripEnquiryModel> rows, {TripStayChoice? stay}) => TripWizardRules.infoOf(
          _in(_oneCity([TripDay(day: 1, spots: [_spot('a')], stay: stay)]), rows: rows),
          const TripStepKey.stay(1, 1),
        )!;

    test('offer needs you, phone booking waits, ask waits', () {
      expect(night([_stayRow('o', 1, TripEnquiryStatuses.offered)]).needsYou, isTrue);
      final phone = night([_stayRow('p', 1, TripEnquiryStatuses.confirmedByTraveller)]);
      expect((phone.state, phone.needsYou, phone.line), (TripStepState.waiting, false, TripWizardCopy.bookedByYouHost));
      expect(night([_stayRow('a', 1, TripEnquiryStatuses.asked), _stayRow('b', 1, TripEnquiryStatuses.countered)]).line,
          'Asked 2 hosts · waiting');
    });

    test('confirmed by both is done with its night share', () {
      final i = night([_stayRow('c', 1, TripEnquiryStatuses.confirmedByBoth, total: 2400)]);
      expect(i.state, TripStepState.done);
      expect(i.agreedRupees, 2400);
    });

    test('host problems are attention, own decline or cancel is a neutral todo', () {
      expect(night([_stayRow('x', 1, TripEnquiryStatuses.notAvailable)]).line, TripWizardCopy.hostFull);
      expect(night([_stayRow('x', 1, TripEnquiryStatuses.expired)]).line, TripWizardCopy.noReply);
      expect(night([_stayRow('x', 1, TripEnquiryStatuses.failed, fail: TripFailReasons.holdExpired)]).line,
          TripWizardCopy.holdExpired);
      expect(night([_stayRow('x', 1, TripEnquiryStatuses.failed, fail: TripFailReasons.hostDenied)]).line,
          TripWizardCopy.hostNotMe);
      expect(night([_stayRow('x', 1, TripEnquiryStatuses.cancelledByOwner)]).state, TripStepState.attention);
      final declined = night([_stayRow('x', 1, TripEnquiryStatuses.declined)]);
      expect((declined.state, declined.note), (TripStepState.todo, TripWizardCopy.youDeclinedStay));
      final cancelled = night([_stayRow('x', 1, TripEnquiryStatuses.cancelledByTraveller)]);
      expect((cancelled.state, cancelled.note), (TripStepState.todo, TripWizardCopy.youCancelledStay));
    });

    test('own and No stay count grey, with the note', () {
      final own = night(const [], stay: const TripStayChoice(stayId: '', name: 'Uncle', isOwn: true));
      expect((own.state, own.counted), (TripStepState.own, true));
      final none = night(const [], stay: const TripStayChoice.skippedNight(note: 'Night bus'));
      expect((none.state, none.note, none.line), (TripStepState.skipped, 'Night bus', TripWizardCopy.noStay));
    });

    test('a chosen stay without a row is not asked yet', () {
      final i = night(const [], stay: const TripStayChoice(stayId: 's1', name: 'Pine Lodge'));
      expect((i.state, i.needsYou, i.line), (TripStepState.waiting, true, 'Pine Lodge · not asked'));
    });

    test('advance pending stays done and needs you', () {
      final row = TripEnquiryModel(
        id: 'c',
        listingName: 'Hill View',
        checkIn: _d(1),
        checkOut: _d(2),
        status: TripEnquiryStatuses.confirmedByBoth,
        agreedTotal: 2000,
        advance: const TripAdvanceModel(status: TripAdvanceStatuses.pending),
      );
      final i = night([row]);
      expect((i.state, i.needsYou, i.note), (TripStepState.done, true, TripWizardCopy.advanceDue));
    });
  });

  group('taxi table', () {
    TripStepInfo day1(List<TripEnquiryModel> rows, {TripTaxiChoice? taxi, List<TripTaxiShortlistItem> list = const []}) =>
        TripWizardRules.infoOf(
          _in(_oneCity([TripDay(day: 1, spots: [_spot('a')], taxi: taxi, taxiShortlist: list)]), rows: rows),
          const TripStepKey.taxi(1, 1),
        )!;

    test('use for day N is chosen, not done', () {
      final i = day1(const [], taxi: const TripTaxiChoice(taxiId: 'x', name: 'Sunil', fare: 2000));
      expect((i.state, i.needsYou), (TripStepState.waiting, true));
    });

    test('fare needs you, booked by you waits, confirmed is done', () {
      expect(day1([_taxiRow('f', 1, TripEnquiryStatuses.fareSent, fare: 2500)]).needsYou, isTrue);
      final booked = day1([_taxiRow('b', 1, TripEnquiryStatuses.bookedByTraveller, fare: 2500)]);
      expect((booked.state, booked.needsYou), (TripStepState.waiting, false));
      final done = day1([_taxiRow('c', 1, TripEnquiryStatuses.confirmedByBoth, fare: 2500)]);
      expect((done.state, done.agreedRupees), (TripStepState.done, 2500));
    });

    test('driver problems are attention', () {
      expect(day1([_taxiRow('n', 1, TripEnquiryStatuses.notAvailable)]).line, TripWizardCopy.driverBusy);
      expect(day1([_taxiRow('n', 1, TripEnquiryStatuses.failed, fail: TripFailReasons.driverDenied)]).line,
          TripWizardCopy.driverNotMe);
    });

    test('no taxi this day keeps the note, own taxi plus a booking is two plans', () {
      final none = day1(const [], taxi: const TripTaxiChoice.skippedDay(note: 'Walking'));
      expect((none.state, none.note), (TripStepState.skipped, 'Walking'));
      final both = day1([_taxiRow('b', 1, TripEnquiryStatuses.bookedByTraveller)],
          taxi: TripTaxiChoice.own(name: 'Ravi'));
      expect((both.state, both.needsYou), (TripStepState.attention, true));
    });

    test('a journey car is never a sightseeing taxi', () {
      final i = day1([_carRow('j1', 1, TripEnquiryStatuses.confirmedByBoth, _d(1))]);
      expect(i.state, TripStepState.todo);
    });

    test('an unasked shortlist needs you', () {
      final i = day1(const [], list: const [TripTaxiShortlistItem(taxiId: 'a', name: 'A')]);
      expect((i.state, i.needsYou), (TripStepState.waiting, true));
    });
  });

  group('journey table', () {
    TripStepInfo gt(TripStep step, {List<TripEnquiryModel> rows = const [], List<TripJourney> journeys = const []}) =>
        TripWizardRules.infoOf(
          _in(_twoCity(steps: TripSteps(startFrom: _delhi, gettingThere: step)), rows: rows, journeys: journeys),
          TripStepKey.gettingThere,
        )!;

    const chosen = TripStep(status: TripStepStatus.chosen, journeyId: 'j1');

    test('own, legacy skipped, not started and missing journey', () {
      expect(gt(const TripStep(status: TripStepStatus.own, note: 'bus')).state, TripStepState.own);
      expect(gt(const TripStep(status: TripStepStatus.skipped)).state, TripStepState.skipped);
      expect(gt(const TripStep()).state, TripStepState.todo);
      expect(gt(chosen).state, TripStepState.todo);
    });

    test('saved needs you, asked waits, all free needs you', () {
      final saved = gt(chosen, journeys: [_journey('j1', _d(1))]);
      expect((saved.state, saved.needsYou, saved.line), (TripStepState.waiting, true, TripWizardCopy.planSaved));
      final asked = gt(chosen, journeys: [_journey('j1', _d(1), asked: true)]);
      expect((asked.state, asked.needsYou), (TripStepState.waiting, false));
      final free = gt(chosen, journeys: [_journey('j1', _d(1), asked: true, free: 'Free')]);
      expect((free.state, free.needsYou), (TripStepState.waiting, true));
    });

    test('no driver, date moved and start moved are attention', () {
      final missing = gt(chosen, journeys: [_journey('j1', _d(1), asked: true, free: 'NotFree')]);
      expect(missing.state, TripStepState.attention);
      final moved = gt(chosen, journeys: [_journey('j1', _d(2))]);
      expect((moved.state, moved.line), (TripStepState.attention, TripWizardCopy.dateMoved));
      final start = TripWizardRules.infoOf(
        _in(
            _twoCity(
                steps: const TripSteps(
                    startFrom: TripStartFrom(name: 'Dehradun', lat: 30.3165, lon: 78.0322), gettingThere: chosen)),
            journeys: [_journey('j1', _d(1))]),
        TripStepKey.gettingThere,
      )!;
      expect((start.state, start.line), (TripStepState.attention, TripWizardCopy.startMoved));
    });

    test('city change: own counts, nothing is todo, a gap names the hub', () {
      expect(TripWizardRules.travelState(_in(_twoCity()), 2), TripStepState.todo);
      expect(
        TripWizardRules.travelState(_in(_twoCity(arrival: const TripTravel.own(fromName: 'Nainital'))), 2),
        TripStepState.own,
      );
      final gap = TripWizardRules.infoOf(
        TripWizardInput(plan: _twoCity(), today: DateTime(2030), travelGaps: const {2: 'Haldwani'}),
        const TripStepKey.travel(2),
      )!;
      expect(gap.line, TripWizardCopy.reachHub('Haldwani'));
    });
  });

  group('places and basics', () {
    test('rest day is skipped, empty day is todo, not-ready city says so', () {
      final p = _twoCity(days: [
        TripDay(day: 1, leg: 1, spots: [_spot('a')]),
        const TripDay(day: 2, leg: 1, restDay: true),
        const TripDay(day: 3, leg: 2),
      ]);
      final i = TripWizardInput(plan: p, today: DateTime(2030), notReadyLegs: const {2});
      expect(TripWizardRules.placesState(i, 1), TripStepState.done);
      expect(TripWizardRules.placesState(i, 2), TripStepState.skipped);
      expect(TripWizardRules.infoOf(i, const TripStepKey.places(2, 1))?.line, TripWizardCopy.cityNotReady);
    });

    test('over the day limit is still done with a note', () {
      final i = TripWizardInput(plan: _twoCity(), today: DateTime(2030), overLimit: (d) => d == 1);
      final info = TripWizardRules.infoOf(i, const TripStepKey.places(1, 1))!;
      expect((info.state, info.note), (TripStepState.done, TripWizardCopy.overLimit));
    });

    test('basics needs dates, people and a start', () {
      expect(TripWizardRules.basicsState(_in(_twoCity())), TripStepState.done);
      final noStart = _twoCity(steps: const TripSteps());
      expect(TripWizardRules.infoOf(_in(noStart), TripStepKey.basics)?.line, TripWizardCopy.addStart);
      final noDates = TripPlan(legs: const [_nainital], days: const [TripDay(day: 1)]);
      expect(TripWizardRules.infoOf(_in(noDates), TripStepKey.basics)?.line, TripWizardCopy.addDates);
    });
  });

  group('progress helpers', () {
    test('percent floors, running cost counts done only, wishlist keeps order', () {
      const k = TripStepKey.basics;
      final s = [
        const TripStepInfo(key: k, state: TripStepState.done, title: '', line: '', agreedRupees: 100),
        const TripStepInfo(key: k, state: TripStepState.waiting, title: '', line: '', agreedRupees: 999),
        const TripStepInfo(key: k, state: TripStepState.todo, title: '', line: ''),
      ];
      expect(TripWizardRules.progress(s).percent, 33);
      expect(TripWizardRules.runningCost(s), 100);
      expect(TripWizardRules.wishlist(s).map((x) => x.state), [TripStepState.waiting, TripStepState.todo]);
    });

    test('coming back date follows leave-on and an own date wins', () {
      final settings = TripSettings(startDate: _start);
      expect(TripWizardRules.comingBackDate(settings, const TripSteps(), 2), _d(3));
      expect(
        TripWizardRules.comingBackDate(settings, const TripSteps(comingBack: TripStep(leaveOn: TripLeaveOn.lastDayEvening)), 2),
        _d(2),
      );
      expect(
        TripStepRules.expectedDate(TripStepRole.comingBack, TripStep(date: _d(5), leaveOn: TripLeaveOn.lastDayEvening), settings, 2),
        _d(5),
      );
    });
  });

  group('start of the day', () {
    test('day 1 starts with Getting there, day 2 at night 1, a new city at its arrival', () {
      final p = _twoCity(days: [
        TripDay(
            day: 1,
            leg: 1,
            spots: [_spot('a')],
            stay: const TripStayChoice(stayId: 'stay-n1', name: 'Stay n1', latitude: 29.39, longitude: 79.45)),
        TripDay(day: 2, leg: 1, spots: [_spot('b')], stay: const TripStayChoice.skippedNight()),
        TripDay(day: 3, leg: 2, spots: [_spot('c')]),
      ]);
      final i = _in(p, rows: [_stayRow('n1', 1, TripEnquiryStatuses.confirmedByBoth)]);
      expect(TripWizardRules.startOf(i, 1).kind, TripStartKind.arrival);
      final d2 = TripWizardRules.startOf(i, 2);
      expect((d2.kind, d2.heading), (TripStartKind.stay, 'Stay n1'));
      expect(d2.point, (lat: 29.39, lng: 79.45));
      expect(TripWizardRules.startOf(i, 3).kind, TripStartKind.arrival);
      expect(TripWizardRules.startOf(i, 3).heading, TripWizardCopy.arriveIn('Almora'));
    });

    test('unconfirmed, own without a pin, no stay and nothing chosen', () {
      TripStartInfo day2(TripStayChoice? stay, [List<TripEnquiryModel> rows = const []]) => TripWizardRules.startOf(
            _in(_oneCity([TripDay(day: 1, stay: stay), const TripDay(day: 2)]), rows: rows),
            2,
          );
      expect(day2(const TripStayChoice(stayId: 'stay-p', name: 'Stay p'), [_stayRow('p', 1, TripEnquiryStatuses.confirmedByTraveller)]).kind,
          TripStartKind.stayUnconfirmed);
      final own = day2(const TripStayChoice(stayId: '', name: 'Uncle', isOwn: true));
      expect((own.kind, own.line), (TripStartKind.ownStay, TripWizardCopy.ownStayNoPin));
      expect(day2(const TripStayChoice.skippedNight()).kind, TripStartKind.noStay);
      expect(day2(null).kind, TripStartKind.notChosen);
    });

    test('coming back starts from the last night or the last evening', () {
      final p = _oneCity([const TripDay(day: 1, stay: TripStayChoice(stayId: '', name: 'Uncle', isOwn: true))]);
      final own = TripWizardRules.comingBackStart(_in(p));
      expect((own.heading, own.kind), ('Uncle', TripStartKind.ownStay));
      final asked = _oneCity([const TripDay(day: 1, stay: TripStayChoice(stayId: 'stay-p', name: 'Stay p'))]);
      expect(TripWizardRules.comingBackStart(_in(asked)).kind, TripStartKind.stayUnconfirmed);
      final evening = _oneCity(
        [const TripDay(day: 1)],
        steps: const TripSteps(comingBack: TripStep(leaveOn: TripLeaveOn.lastDayEvening)),
      );
      expect(TripWizardRules.comingBackStart(_in(evening)).line, startsWith('Day 1 evening'));
    });
  });

  group('fix round 1', () {
    test('a done stay with an offer from another host needs you and names the swap', () {
      final p = _oneCity([TripDay(day: 1, spots: [_spot('a')], stay: const TripStayChoice(stayId: 'stay-a', name: 'Stay a'))]);
      final rows = [
        _stayRow('a', 1, TripEnquiryStatuses.confirmedByBoth),
        _stayRow('c', 1, TripEnquiryStatuses.offered),
      ];
      final i = _info(TripWizardRules.steps(_in(p, rows: rows)), 'stay:1:1');
      expect((i.state, i.needsYou), (TripStepState.done, true));
      expect(i.note, TripWizardCopy.offerReplaces('Stay c', 'Stay a'));
      final asked = _info(
          TripWizardRules.steps(_in(p, rows: [rows.first, _stayRow('c', 1, TripEnquiryStatuses.asked)])), 'stay:1:1');
      expect((asked.state, asked.needsYou), (TripStepState.done, false));
      expect(asked.note, TripWizardCopy.askedReplaces(1, 'Stay a'));
    });

    test('a car nobody was asked needs you even when the other car is booked', () {
      final date = _start;
      final j = _journey('j1', date, asked: false);
      final booked = j.withLegs([
        j.legs.first.copyWith(lastEnquiryId: 'x1'),
        j.legs.last,
      ]);
      final i = _info(
        TripWizardRules.steps(_in(_oneCity([TripDay(day: 1, spots: [_spot('a')])], steps: _gtChosen),
            rows: [_carRow('j1', 1, TripEnquiryStatuses.confirmedByBoth, date)], journeys: [booked])),
        'gettingThere',
      );
      expect((i.state, i.needsYou), (TripStepState.waiting, true));
    });

    test('places or start changed after a taxi was asked asks to tell the driver', () {
      final p = _oneCity([
        TripDay(day: 1, spots: [_spot('a')], stay: const TripStayChoice(stayId: 'stay-n1', name: 'Stay n1')),
        TripDay(day: 2, spots: [_spot('b')]),
      ]);
      TripEnquiryModel taxi(List<String> spots, {String? start}) => TripEnquiryModel(
            id: 'tx',
            tripId: 't1',
            kind: TripEnquiryKinds.taxi,
            listingId: 'taxi-tx',
            listingName: 'Driver tx',
            checkIn: _d(2),
            days: const [2],
            status: TripEnquiryStatuses.asked,
            context: TripEnquiryContext(days: [TripContextDay(day: 2, date: _d(2), spots: spots, start: start)]),
            createdAt: DateTime(2030, 1, 2),
          );
      final moved = taxi(['old']);
      expect(TripWizardRules.driverUpdates(_in(p, rows: [moved]), 2, [moved])['tx'], TripDriverUpdate.places);
      expect(TripWizardRules.dayStartKey(p, 2), 'stay:stay-n1');
      final told = taxi(['b'], start: 'stay:stay-n1');
      final later = TripEnquiryModel(
        id: 'n1',
        tripId: 't1',
        listingId: 'stay-n1',
        listingName: 'Stay n1',
        day: 1,
        checkIn: _d(1),
        checkOut: _d(2),
        status: TripEnquiryStatuses.confirmedByBoth,
        createdAt: DateTime(2030, 1, 1),
        updatedAt: DateTime(2030, 1, 3),
      );
      expect(TripWizardRules.driverUpdates(_in(p, rows: [told, later]), 2, [told]), isEmpty);
      final before = taxi(['b'], start: 'none');
      final i = _in(p, rows: [before, later]);
      expect(TripWizardRules.driverUpdates(i, 2, [before])['tx'], TripDriverUpdate.start);
      expect(_info(TripWizardRules.steps(i), 'taxi:1:2').note, TripWizardCopy.startChangedTell);
      final own = _oneCity([
        TripDay(day: 1, spots: [_spot('a')], stay: const TripStayChoice(stayId: '', name: 'Uncle', isOwn: true)),
        TripDay(day: 2, spots: [_spot('b')]),
      ]);
      expect(TripWizardRules.driverUpdates(_in(own, rows: [told]), 2, [told])['tx'], TripDriverUpdate.start);
      expect(TripWizardRules.driverUpdates(_in(p, rows: [taxi(['b'])]), 2, [taxi(['b'])]), isEmpty);
    });

    test('the start card says where the route is planned from', () {
      final p = _oneCity([
        const TripDay(day: 1, stay: TripStayChoice(stayId: 'stay-a', name: 'Stay a', latitude: 29.39, longitude: 79.45)),
        const TripDay(day: 2, stay: TripStayChoice(stayId: 'stay-b', name: 'Stay b', latitude: 29.40, longitude: 79.46)),
        const TripDay(day: 3),
      ]);
      expect(TripWizardRules.startOf(_in(p), 3).routeNote, isNull);
      final noPin = _oneCity([
        const TripDay(day: 1, stay: TripStayChoice(stayId: 'stay-a', name: 'Stay a', latitude: 29.39, longitude: 79.45)),
        const TripDay(day: 2, stay: TripStayChoice(stayId: 'stay-b', name: 'Stay b')),
        const TripDay(day: 3),
      ]);
      expect(TripWizardRules.startOf(_in(noPin), 3).routeNote, isNull);
      expect(TripWizardRules.startOf(_in(noPin), 3).line, TripWizardCopy.fromCityCentre);
      final same = _oneCity([
        const TripDay(day: 1, stay: TripStayChoice(stayId: 'stay-a', name: 'Stay a', latitude: 29.39, longitude: 79.45)),
        const TripDay(day: 2, stay: TripStayChoice(stayId: 'stay-a', name: 'Stay a', sameAsDay: 1)),
      ]);
      expect(TripWizardRules.startOf(_in(same), 2).routeNote, isNull);
    });
  });

  group('fix round 2', () {
    test('a booking of another city whose dates moved onto this night is a problem, not done', () {
      final almora = TripEnquiryModel(
        id: 'alm',
        tripId: 't1',
        listingId: 'stay-alm',
        listingName: 'Almora hotel',
        day: 3,
        checkIn: _d(2),
        checkOut: _d(3),
        status: TripEnquiryStatuses.confirmedByBoth,
        context: const TripEnquiryContext(city: 'Almora'),
        createdAt: DateTime(2030, 1, 1),
      );
      final i = _in(_twoCity(), rows: [almora]);
      final steps = TripWizardRules.steps(i);
      final night2 = _info(steps, 'stay:1:2');
      expect((night2.state, night2.line, night2.needsYou), (TripStepState.attention, TripWizardCopy.bookedElsewhere('Almora'), true));
      expect(night2.counted, isFalse);
      expect(TripWizardRules.nightRows(i, 2), isEmpty);
      expect(TripWizardRules.nightStartOf(i, 2).kind, isNot(TripStartKind.stay));
    });

    test('a taxi ask that saw the same start never nudges after a booking update', () {
      final p = _oneCity([
        TripDay(day: 1, spots: [_spot('a')], stay: const TripStayChoice(stayId: 'stay-n1', name: 'Stay n1')),
        TripDay(day: 2, spots: [_spot('b')]),
      ]);
      expect(TripWizardRules.dayStartKey(p, 1), 'arrival');
      expect(TripWizardRules.dayStartKey(_oneCity([const TripDay(day: 1, stay: TripStayChoice.skippedNight()), const TripDay(day: 2)]), 2), 'skipped');
    });
  });

  group('fix round 3', () {
    test('every car arranged by the traveller is own, not confirmed', () {
      const step = TripStep(status: TripStepStatus.chosen, journeyId: 'j1', ownCars: [1, 2]);
      final i = TripWizardRules.infoOf(
        _in(_twoCity(steps: const TripSteps(startFrom: _delhi, gettingThere: step)), journeys: [_journey('j1', _d(1))]),
        TripStepKey.gettingThere,
      )!;
      expect((i.state, i.counted), (TripStepState.own, true));
    });

    test('a confirmed taxi with another driver fare needs you', () {
      final i = TripWizardRules.infoOf(
        _in(_oneCity([TripDay(day: 1, spots: [_spot('a')])]), rows: [
          _taxiRow('a', 1, TripEnquiryStatuses.confirmedByBoth, fare: 2500),
          _taxiRow('b', 1, TripEnquiryStatuses.fareSent, fare: 2200),
        ]),
        const TripStepKey.taxi(1, 1),
      )!;
      expect((i.state, i.needsYou), (TripStepState.done, true));
      expect(i.note, TripWizardCopy.fareReplaces('Driver b', 'Driver a'));
    });
  });
}
