import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_journey_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_offer_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_strings_v2_easy.dart';
import 'package:bakhli/features/trip/utils/trip_easy_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _stay1 = TripEasyRowKey(TripEasyRowKind.stay, 1);
const _stay2 = TripEasyRowKey(TripEasyRowKind.stay, 2);
const _between2 = TripEasyRowKey(TripEasyRowKind.between, 2);
const _taxi = TripEasyRowKey(TripEasyRowKind.taxi);
const _going = TripEasyRowKey(TripEasyRowKind.gettingThere);
const _back = TripEasyRowKey(TripEasyRowKind.comingBack);

TripSpotRef _spot(String id) =>
    TripSpotRef(id: id, name: id, latitude: 29.4, longitude: 79.4, category: 'lake', visitMinutes: 60);

TripPlan _plan({
  int legs = 1,
  bool dates = true,
  TripSteps steps = const TripSteps(),
  TripRowMark? taxiMark,
  TripRowMark? stayMark1,
  TripRowMark? stayMark2,
  TripRowMark? travelMark2,
  TripTravel? arrival2,
  List<String> dismissed = const [],
}) {
  final days = legs == 1
      ? [for (var d = 1; d <= 3; d++) TripDay(day: d, spots: [_spot('s$d')])]
      : [
          TripDay(day: 1, leg: 1, spots: [_spot('a')]),
          TripDay(day: 2, leg: 1, spots: [_spot('b')]),
          TripDay(day: 3, leg: 2, spots: [_spot('c')]),
        ];
  return TripPlan(
    legs: [
      TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29, longitude: 79, stayMark: stayMark1),
      if (legs > 1)
        TripCityLeg(
          index: 2,
          cityKey: 2,
          cityName: 'Almora',
          latitude: 29.5,
          longitude: 79.6,
          stayMark: stayMark2,
          travelMark: travelMark2,
          arrival: arrival2,
        ),
    ],
    days: days,
    settings: TripSettings(startDate: dates ? DateTime(2026, 11, 20) : null, adults: dates ? 2 : null),
    steps: steps,
    taxiMark: taxiMark,
    dismissedEnquiryIds: dismissed,
  );
}

TripEnquiryModel _stay(
  String id,
  String status, {
  DateTime? checkIn,
  DateTime? checkOut,
  int? day,
  TripAdvanceModel advance = const TripAdvanceModel(),
  TripOfferModel? revised,
  String name = 'Deodar Homestay',
  DateTime? updatedAt,
}) =>
    TripEnquiryModel(
      id: id,
      tripId: 't1',
      status: status,
      listingName: name,
      day: day,
      checkIn: checkIn ?? DateTime(2026, 11, 20),
      checkOut: checkOut ?? DateTime(2026, 11, 22),
      advance: advance,
      pendingRevised: revised,
      updatedAt: updatedAt,
    );

TripEnquiryModel _taxiRow(String id, String status, {String name = 'Mohan', DateTime? updatedAt}) => TripEnquiryModel(
      id: id,
      tripId: 't1',
      kind: TripEnquiryKinds.taxi,
      status: status,
      listingName: name,
      days: const [1, 2],
      checkIn: DateTime(2026, 11, 20),
      updatedAt: updatedAt,
    );

TripEnquiryModel _segmentRow(String id, String status, {String journeyId = 'j1', int car = 1}) => TripEnquiryModel(
      id: id,
      tripId: 't1',
      kind: TripEnquiryKinds.taxi,
      status: status,
      day: 1,
      context: TripEnquiryContext(journeyId: journeyId, journeyLegIndex: car),
    );

TripJourney _journey(String id, {List<TripJourneyLeg> legs = const [], DateTime? date}) =>
    TripJourney(id: id, fromName: 'Delhi', toName: 'Nainital', date: date ?? DateTime(2026, 11, 20), legs: legs);

TripEasyRowInfo _row(List<TripEasyRowInfo> rows, TripEasyRowKey key) => TripEasyRules.rowOf(rows, key)!;

List<TripEasyRowInfo> _rows(TripPlan p, [List<TripEnquiryModel> e = const [], List<TripJourney> j = const []]) =>
    TripEasyRules.rows(p, e, j);

void main() {
  group('row keys and order', () {
    test('single city', () {
      expect([for (final k in TripEasyRules.keys(_plan())) k.id], ['gettingThere', 'stay:1', 'taxi', 'comingBack']);
    });

    test('two cities put between before the stay of the next city', () {
      expect([for (final k in TripEasyRules.keys(_plan(legs: 2))) k.id],
          ['gettingThere', 'stay:1', 'between:2', 'stay:2', 'taxi', 'comingBack']);
    });

    test('rows come out in key order with titles', () {
      final rows = _rows(_plan(legs: 2));
      expect([for (final r in rows) r.key.id], ['gettingThere', 'stay:1', 'between:2', 'stay:2', 'taxi', 'comingBack']);
      expect(_row(rows, _going).title, TripStringsV2Easy.gettingThere);
      expect(_row(rows, _stay1).title, 'Stay in Nainital');
      expect(_row(rows, _between2).title, 'Between cities');
      expect(_row(rows, _stay2).title, 'Stay in Almora');
      expect(_row(rows, _taxi).title, TripStringsV2Easy.localTaxi);
      expect(_row(rows, _back).title, TripStringsV2Easy.comingBack);
    });

    test('rowOf is null for a key that is not in the list', () {
      expect(TripEasyRules.rowOf(_rows(_plan()), _stay2), isNull);
    });
  });

  group('stay row states', () {
    test('nothing asked is to do', () {
      final r = _row(_rows(_plan()), _stay1);
      expect(r.state, TripRowState.todo);
      expect(r.needsYou, isFalse);
      expect(r.canMark, isTrue);
    });

    test('own mark and skipped mark win over any ask', () {
      final asked = [_stay('e1', TripEnquiryStatuses.asked)];
      expect(_row(_rows(_plan(stayMark1: const TripRowMark.own()), asked), _stay1).state, TripRowState.own);
      expect(_row(_rows(_plan(stayMark1: const TripRowMark.skipped()), asked), _stay1).state, TripRowState.skipped);
    });

    test('asked rows are asked, a traveller-confirmed row is booked', () {
      final a = _row(_rows(_plan(), [_stay('e1', TripEnquiryStatuses.asked), _stay('e2', TripEnquiryStatuses.asked)]), _stay1);
      expect(a.state, TripRowState.asked);
      expect(a.askedCount, 2);
      expect(a.needsYou, isFalse);
      expect(_row(_rows(_plan(), [_stay('e1', TripEnquiryStatuses.confirmedByTraveller)]), _stay1).state, TripRowState.booked);
      final other = _rows(_plan(), [
        _stay('e1', TripEnquiryStatuses.confirmedByTraveller),
        _stay('e2', TripEnquiryStatuses.offered),
      ]);
      expect(_row(other, _stay1).state, TripRowState.booked);
      expect(_row(other, _stay1).needsYou, isTrue);
      expect(_row(_rows(_plan(), [_stay('e1', TripEnquiryStatuses.confirmedByTraveller)]), _stay1).askedCount, 0);
    });

    test('an offer makes the row an offer that needs you', () {
      final r = _row(_rows(_plan(), [_stay('e1', TripEnquiryStatuses.offered)]), _stay1);
      expect(r.state, TripRowState.offer);
      expect(r.needsYou, isTrue);
    });

    test('a counter reads asked and waiting', () {
      final r = _row(_rows(_plan(), [_stay('e1', TripEnquiryStatuses.countered)]), _stay1);
      expect(r.state, TripRowState.asked);
      expect(r.needsYou, isFalse);
    });

    test('an offer beats a plain ask', () {
      final r = _row(
          _rows(_plan(), [_stay('e1', TripEnquiryStatuses.asked), _stay('e2', TripEnquiryStatuses.offered)]), _stay1);
      expect(r.state, TripRowState.offer);
    });

    test('confirmed by both is confirmed and shows the listing name', () {
      final r = _row(_rows(_plan(), [_stay('e1', TripEnquiryStatuses.confirmedByBoth, checkOut: DateTime(2026, 11, 23))]), _stay1);
      expect(r.state, TripRowState.confirmed);
      expect(r.subtitle, 'Deodar Homestay');
      expect(r.needsYou, isFalse);
      expect(r.state.isDone, isTrue);
    });

    test('confirmed needs you for a pending advance, a pending revised offer or another live offer', () {
      final adv = _stay('e1', TripEnquiryStatuses.confirmedByBoth, advance: const TripAdvanceModel(status: TripAdvanceStatuses.pending));
      expect(_row(_rows(_plan(), [adv]), _stay1).needsYou, isTrue);
      final rev = _stay('e1', TripEnquiryStatuses.confirmedByBoth, revised: const TripOfferModel(id: 'o1'));
      expect(_row(_rows(_plan(), [rev]), _stay1).needsYou, isTrue);
      final other = [_stay('e1', TripEnquiryStatuses.confirmedByBoth), _stay('e2', TripEnquiryStatuses.offered)];
      final r = _row(_rows(_plan(), other), _stay1);
      expect(r.state, TripRowState.confirmed);
      expect(r.needsYou, isTrue);
    });

    test('only the newest closed row decides the problem', () {
      final rows = [
        _stay('e1', TripEnquiryStatuses.notAvailable, updatedAt: DateTime(2026, 11, 1)),
        _stay('e2', TripEnquiryStatuses.cancelledByTraveller, updatedAt: DateTime(2026, 11, 2)),
      ];
      expect(_row(_rows(_plan(), rows), _stay1).state, TripRowState.todo);
    });

    test('a terminal problem row is attention, a dismissed one is to do', () {
      for (final s in [
        TripEnquiryStatuses.notAvailable,
        TripEnquiryStatuses.expired,
        TripEnquiryStatuses.failed,
        TripEnquiryStatuses.cancelledByOwner,
      ]) {
        expect(_row(_rows(_plan(), [_stay('e1', s)]), _stay1).state, TripRowState.attention, reason: s);
      }
      final gone = _rows(_plan(dismissed: const ['e1']), [_stay('e1', TripEnquiryStatuses.notAvailable)]);
      expect(_row(gone, _stay1).state, TripRowState.todo);
      expect(
          _row(TripEasyRules.rows(_plan(), [_stay('e1', TripEnquiryStatuses.notAvailable)], const [], dismissed: {'e1'}), _stay1)
              .state,
          TripRowState.todo);
    });

    test('a live ask beats an old problem row', () {
      final r = _row(
          _rows(_plan(), [_stay('e1', TripEnquiryStatuses.notAvailable), _stay('e2', TripEnquiryStatuses.asked)]), _stay1);
      expect(r.state, TripRowState.asked);
    });

    test('closed and withdrawn rows leave the row to do', () {
      final r = _row(
          _rows(_plan(), [_stay('e1', TripEnquiryStatuses.closed), _stay('e2', TripEnquiryStatuses.cancelledByTraveller)]),
          _stay1);
      expect(r.state, TripRowState.todo);
    });

    test('a taxi row never counts as a stay', () {
      expect(_row(_rows(_plan(), [_taxiRow('t', TripEnquiryStatuses.asked)]), _stay1).state, TripRowState.todo);
    });
  });

  group('stay rows by city', () {
    test('an ask for the nights of city two lands only on stay:2', () {
      final e = _stay('e1', TripEnquiryStatuses.asked, checkIn: DateTime(2026, 11, 22), checkOut: DateTime(2026, 11, 23));
      final rows = _rows(_plan(legs: 2), [e]);
      expect(_row(rows, _stay1).state, TripRowState.todo);
      expect(_row(rows, _stay2).state, TripRowState.asked);
    });

    test('an ask that spans both cities counts for both', () {
      final e = _stay('e1', TripEnquiryStatuses.asked, checkOut: DateTime(2026, 11, 23));
      final rows = _rows(_plan(legs: 2), [e]);
      expect(_row(rows, _stay1).state, TripRowState.asked);
      expect(_row(rows, _stay2).state, TripRowState.asked);
    });

    test('without trip dates the ask day decides', () {
      final e = TripEnquiryModel(id: 'e1', tripId: 't1', day: 3, serverNights: 1);
      final rows = _rows(_plan(legs: 2, dates: false), [e]);
      expect(_row(rows, _stay1).state, TripRowState.todo);
      expect(_row(rows, _stay2).state, TripRowState.asked);
    });

    test('nightsOf follows check-in against the trip start', () {
      final e = _stay('e1', TripEnquiryStatuses.asked, checkIn: DateTime(2026, 11, 21), checkOut: DateTime(2026, 11, 23));
      expect(TripEasyRules.nightsOf(e, _plan()), {2, 3});
      expect(TripEasyRules.nightsOf(const TripEnquiryModel(id: 'x'), _plan(dates: false)), isEmpty);
    });
  });

  group('taxi row states', () {
    test('nothing asked is to do', () {
      expect(_row(_rows(_plan()), _taxi).state, TripRowState.todo);
    });

    test('marks', () {
      expect(_row(_rows(_plan(taxiMark: const TripRowMark.own())), _taxi).state, TripRowState.own);
      expect(_row(_rows(_plan(taxiMark: const TripRowMark.skipped())), _taxi).state, TripRowState.skipped);
    });

    test('asked is asked, booked by traveller is booked', () {
      expect(_row(_rows(_plan(), [_taxiRow('t1', TripEnquiryStatuses.asked)]), _taxi).state, TripRowState.asked);
      expect(_row(_rows(_plan(), [_taxiRow('t1', TripEnquiryStatuses.bookedByTraveller)]), _taxi).state, TripRowState.booked);
    });

    test('a fare is an offer that needs you', () {
      final r = _row(_rows(_plan(), [_taxiRow('t1', TripEnquiryStatuses.fareSent)]), _taxi);
      expect(r.state, TripRowState.offer);
      expect(r.needsYou, isTrue);
    });

    test('confirmed by both is confirmed and the driver wins over other rows', () {
      final r = _row(
          _rows(_plan(), [_taxiRow('t1', TripEnquiryStatuses.confirmedByBoth, name: 'Mohan'), _taxiRow('t2', TripEnquiryStatuses.fareSent)]),
          _taxi);
      expect(r.state, TripRowState.confirmed);
      expect(r.subtitle, 'Mohan');
    });

    test('a problem is attention until dismissed', () {
      final rows = [_taxiRow('t1', TripEnquiryStatuses.notAvailable)];
      expect(_row(_rows(_plan(), rows), _taxi).state, TripRowState.attention);
      expect(_row(_rows(_plan(dismissed: const ['t1']), rows), _taxi).state, TripRowState.todo);
    });

    test('segment rows of a journey never move the taxi row', () {
      expect(_row(_rows(_plan(), [_segmentRow('s1', TripEnquiryStatuses.confirmedByBoth)]), _taxi).state, TripRowState.todo);
    });

    test('a stay row never moves the taxi row', () {
      expect(_row(_rows(_plan(), [_stay('e1', TripEnquiryStatuses.asked)]), _taxi).state, TripRowState.todo);
    });
  });

  group('getting there and coming back', () {
    test('no step is to do', () {
      final rows = _rows(_plan());
      expect(_row(rows, _going).state, TripRowState.todo);
      expect(_row(rows, _back).state, TripRowState.todo);
    });

    test('own and skipped steps', () {
      final p = _plan(
        steps: const TripSteps(
          gettingThere: TripStep(status: TripStepStatus.own),
          comingBack: TripStep(status: TripStepStatus.skipped),
        ),
      );
      final rows = _rows(p);
      expect(_row(rows, _going).state, TripRowState.own);
      expect(_row(rows, _back).state, TripRowState.skipped);
    });

    test('a saved journey nobody asked is saved', () {
      final p = _plan(steps: const TripSteps(gettingThere: TripStep(status: TripStepStatus.chosen, journeyId: 'j1')));
      final rows = _rows(p, const [], [_journey('j1')]);
      final r = _row(rows, _going);
      expect(r.state, TripRowState.saved);
      expect(r.journeyId, 'j1');
      expect(r.state.isDone, isTrue);
    });

    test('a chosen step whose journey is not loaded is to do', () {
      final p = _plan(steps: const TripSteps(gettingThere: TripStep(status: TripStepStatus.chosen, journeyId: 'j1')));
      expect(_row(_rows(p), _going).state, TripRowState.todo);
    });

    TripJourney askedJourney({String lastKnown = 'Unknown', bool available = true, DateTime? date}) =>
        _journey('j1', date: date ?? DateTime(2026, 11, 23), legs: [
          TripJourneyLeg(
            legIndex: 1,
            fromName: 'Delhi',
            toName: 'Nainital',
            driverName: 'Sunil',
            lastEnquiryId: 'q1',
            lastKnownStatus: lastKnown,
            driverAvailable: available,
          ),
        ]);

    final chosen = _plan(steps: const TripSteps(comingBack: TripStep(status: TripStepStatus.booked, journeyId: 'j1')));

    test('a journey on another date than the plan expects is attention', () {
      final r = _row(_rows(chosen, const [], [askedJourney(date: DateTime(2026, 11, 25))]), _back);
      expect(r.state, TripRowState.attention);
    });

    test('an asked car is asked', () {
      expect(_row(_rows(chosen, const [], [askedJourney()]), _back).state, TripRowState.asked);
    });

    test('a driver who is free is an offer that needs you', () {
      final r = _row(_rows(chosen, const [], [askedJourney(lastKnown: 'Free')]), _back);
      expect(r.state, TripRowState.offer);
      expect(r.needsYou, isTrue);
    });

    test('a booked car is booked, a confirmed car is confirmed', () {
      final booked = _row(_rows(chosen, [_segmentRow('s1', TripEnquiryStatuses.bookedByTraveller)], [askedJourney()]), _back);
      expect(booked.state, TripRowState.booked);
      final done = _row(_rows(chosen, [_segmentRow('s1', TripEnquiryStatuses.confirmedByBoth)], [askedJourney()]), _back);
      expect(done.state, TripRowState.confirmed);
    });

    test('a driver who is not free or paused needs attention', () {
      expect(_row(_rows(chosen, const [], [askedJourney(lastKnown: 'NotFree')]), _back).state, TripRowState.attention);
      expect(_row(_rows(chosen, const [], [askedJourney(available: false)]), _back).state, TripRowState.attention);
    });
  });

  group('between cities', () {
    TripTravel arrival(String id) => TripTravel(fromName: 'Nainital', journeyId: id);

    test('no arrival and no mark is to do', () {
      expect(_row(_rows(_plan(legs: 2)), _between2).state, TripRowState.todo);
    });

    test('marks', () {
      expect(_row(_rows(_plan(legs: 2, travelMark2: const TripRowMark.own())), _between2).state, TripRowState.own);
      expect(_row(_rows(_plan(legs: 2, travelMark2: const TripRowMark.skipped())), _between2).state, TripRowState.skipped);
    });

    test('an arrival whose journey is not loaded yet is asked', () {
      final r = _row(_rows(_plan(legs: 2, arrival2: arrival('j2'))), _between2);
      expect(r.state, TripRowState.asked);
      expect(r.journeyId, 'j2');
    });

    test('a loaded journey nobody asked is saved', () {
      final r = _row(_rows(_plan(legs: 2, arrival2: arrival('j2')), const [], [_journey('j2', date: DateTime(2026, 11, 22))]), _between2);
      expect(r.state, TripRowState.saved);
    });

    test('a confirmed car is confirmed', () {
      final j = _journey('j2', date: DateTime(2026, 11, 22), legs: const [
        TripJourneyLeg(legIndex: 1, fromName: 'Nainital', toName: 'Almora', driverName: 'Mohan', lastEnquiryId: 'q'),
      ]);
      final rows = _rows(
        _plan(legs: 2, arrival2: arrival('j2')),
        [_segmentRow('s1', TripEnquiryStatuses.confirmedByBoth, journeyId: 'j2')],
        [j],
      );
      expect(_row(rows, _between2).state, TripRowState.confirmed);
    });

    test('a single city plan has no between row', () {
      expect(TripEasyRules.rowOf(_rows(_plan()), _between2), isNull);
    });
  });

  group('partial cover', () {
    test('two of three nights asked is asked, partial, uncovered day 3, not done', () {
      final rows = _rows(_plan(), [_stay('e1', TripEnquiryStatuses.asked, checkOut: DateTime(2026, 11, 22))]);
      final r = _row(rows, _stay1);
      expect(r.state, TripRowState.asked);
      expect((r.nightsCovered, r.nightsTotal), (2, 3));
      expect(r.partial, isTrue);
      expect(r.isDone, isFalse);
      expect(r.uncoveredDays, [3]);
      expect(r.subtitle, '${TripStringsV2Easy.pillAsked} · 2 of 3 nights');
      expect(TripEasyRules.progress(rows).done, 0);
    });

    test('confirmed two of three nights is confirmed but not done', () {
      final r = _row(_rows(_plan(), [_stay('e1', TripEnquiryStatuses.confirmedByBoth)]), _stay1);
      expect(r.state, TripRowState.confirmed);
      expect(r.partial, isTrue);
      expect(r.isDone, isFalse);
    });

    test('booked two of three nights is booked but not done', () {
      final r = _row(_rows(_plan(), [_stay('e1', TripEnquiryStatuses.confirmedByTraveller)]), _stay1);
      expect(r.state, TripRowState.booked);
      expect(r.isDone, isFalse);
      expect(r.uncoveredDays, [3]);
    });

    test('night by night asks cover the leg and are not partial', () {
      final r = _row(
        _rows(_plan(), [
          _stay('e1', TripEnquiryStatuses.asked, checkIn: DateTime(2026, 11, 20), checkOut: DateTime(2026, 11, 21)),
          _stay('e2', TripEnquiryStatuses.asked, checkIn: DateTime(2026, 11, 21), checkOut: DateTime(2026, 11, 23)),
        ]),
        _stay1,
      );
      expect(r.partial, isFalse);
      expect(r.uncoveredDays, isEmpty);
    });
  });

  group('progress', () {
    TripEasyRowInfo info(TripRowState s, {bool needsYou = false}) =>
        TripEasyRowInfo(key: _taxi, state: s, title: 't', needsYou: needsYou);

    test('done counts own, saved and confirmed; asked and offer are in progress', () {
      final p = TripEasyRules.progress([
        info(TripRowState.own),
        info(TripRowState.saved),
        info(TripRowState.confirmed),
        info(TripRowState.asked),
        info(TripRowState.offer),
        info(TripRowState.todo),
      ]);
      expect((p.done, p.total, p.percent), (3, 6, 50));
    });

    test('skipped rows leave the total', () {
      final p = TripEasyRules.progress([info(TripRowState.own), info(TripRowState.skipped), info(TripRowState.todo)]);
      expect((p.done, p.total, p.percent), (1, 2, 50));
    });

    test('everything skipped or no rows is complete', () {
      expect(TripEasyRules.progress([info(TripRowState.skipped)]).percent, 100);
      expect(TripEasyRules.progress(const []).percent, 100);
    });

    test('attention is not done', () {
      final p = TripEasyRules.progress([info(TripRowState.attention), info(TripRowState.confirmed)]);
      expect((p.done, p.total), (1, 2));
    });

    test('a fresh plan is 0 of 4 and marks move it', () {
      final fresh = TripEasyRules.progress(_rows(_plan()));
      expect((fresh.done, fresh.total, fresh.percent), (0, 4, 0));
      final marked = TripEasyRules.progress(_rows(_plan(
        stayMark1: const TripRowMark.own(),
        taxiMark: const TripRowMark.skipped(),
        steps: const TripSteps(comingBack: TripStep(status: TripStepStatus.skipped)),
      )));
      expect((marked.done, marked.total, marked.percent), (1, 2, 50));
    });

    test('the server numbers win when it sent a progress', () {
      final rows = _rows(_plan());
      const server = TripProgress(total: 4, done: 3, percent: 75);
      final p = TripEasyRules.progressOf(rows, server);
      expect((p.done, p.total, p.percent), (3, 4, 75));
      final local = TripEasyRules.progressOf(rows, const TripProgress());
      expect(local.total, 4);
      expect(TripEasyRules.progressOf(rows, null).done, 0);
    });

    test('a booked row counts as done', () {
      final p = TripEasyRules.progress([info(TripRowState.booked), info(TripRowState.todo)]);
      expect((p.done, p.total), (1, 2));
    });

    test('allResolved is true with one booked row and the rest skipped', () {
      expect(TripEasyRules.allResolved([info(TripRowState.booked), info(TripRowState.skipped)]), isTrue);
    });

    test('allResolved needs every row done or skipped', () {
      expect(TripEasyRules.allResolved([info(TripRowState.own), info(TripRowState.skipped)]), isTrue);
      expect(TripEasyRules.allResolved([info(TripRowState.own), info(TripRowState.asked)]), isFalse);
      expect(TripEasyRules.allResolved([info(TripRowState.todo)]), isFalse);
    });
  });

  group('own marks promote a draft', () {
    test('no mark and skipped marks do not', () {
      expect(TripEasyRules.hasOwnMark(_plan()), isFalse);
      expect(TripEasyRules.hasOwnMark(_plan(taxiMark: const TripRowMark.skipped())), isFalse);
    });

    test('stay, taxi, between and step own marks do', () {
      expect(TripEasyRules.hasOwnMark(_plan(stayMark1: const TripRowMark.own())), isTrue);
      expect(TripEasyRules.hasOwnMark(_plan(taxiMark: const TripRowMark.own())), isTrue);
      expect(TripEasyRules.hasOwnMark(_plan(legs: 2, travelMark2: const TripRowMark.own())), isTrue);
      expect(
          TripEasyRules.hasOwnMark(_plan(steps: const TripSteps(comingBack: TripStep(status: TripStepStatus.own)))),
          isTrue);
    });
  });

  group('first row in progress', () {
    TripEasyRowInfo info(TripEasyRowKey k, TripRowState s, {bool needsYou = false}) =>
        TripEasyRowInfo(key: k, state: s, title: 't', needsYou: needsYou);

    test('none when nothing is waiting', () {
      expect(TripEasyRules.firstInProgress([info(_taxi, TripRowState.todo), info(_stay1, TripRowState.own)]), isNull);
    });

    test('the first asked or offer row in order', () {
      final r = TripEasyRules.firstInProgress([info(_going, TripRowState.todo), info(_stay1, TripRowState.asked), info(_taxi, TripRowState.offer)]);
      expect(r?.key, _stay1);
    });

    test('a row that needs you comes before one that only waits', () {
      final r = TripEasyRules.firstInProgress([
        info(_stay1, TripRowState.asked),
        info(_taxi, TripRowState.offer, needsYou: true),
      ]);
      expect(r?.key, _taxi);
    });
  });

  group('row info', () {
    test('canMark is for to do, attention, asked and offer rows', () {
      for (final s in TripRowState.values) {
        final r = TripEasyRowInfo(key: _taxi, state: s, title: 't');
        expect(
            r.canMark,
            s == TripRowState.todo || s == TripRowState.attention || s == TripRowState.asked || s == TripRowState.offer,
            reason: s.name);
      }
    });

    test('withState keeps everything else', () {
      const r = TripEasyRowInfo(key: _stay1, state: TripRowState.todo, title: 'Stay in Nainital', subtitle: 's', needsYou: true, journeyId: 'j');
      final n = r.withState(TripRowState.own);
      expect(n.state, TripRowState.own);
      expect(n.key, _stay1);
      expect(n.title, 'Stay in Nainital');
      expect(n.subtitle, 's');
      expect(n.needsYou, isTrue);
      expect(n.journeyId, 'j');
      expect(n.kind, TripEasyRowKind.stay);
      expect(n.legIndex, 1);
    });

    test('marks read back through markOf', () {
      final p = _plan(legs: 2, stayMark2: const TripRowMark.own(), travelMark2: const TripRowMark.skipped(), taxiMark: const TripRowMark.own());
      expect(TripEasyRules.markOf(p, _stay2)?.isOwn, isTrue);
      expect(TripEasyRules.markOf(p, _between2)?.isSkipped, isTrue);
      expect(TripEasyRules.markOf(p, _taxi)?.isOwn, isTrue);
      expect(TripEasyRules.markOf(p, _going), isNull);
      expect(TripEasyRules.markOf(p, _stay1), isNull);
    });
  });
}
