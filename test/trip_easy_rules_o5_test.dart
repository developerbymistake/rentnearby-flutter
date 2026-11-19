import 'package:bakhli/features/trip/utils/trip_parts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_easy_rules.dart';

TripPlan _plan({TripRowMark? stayMark, TripRowMark? taxiMark, DateTime? start}) => TripPlan(
      legs: [
        TripCityLeg(
          index: 1,
          cityKey: 1,
          cityName: 'Nainital',
          latitude: 29,
          longitude: 79,
          stayMark: stayMark,
        ),
      ],
      days: const [TripDay(day: 1), TripDay(day: 2), TripDay(day: 3)],
      settings: TripSettings(startDate: start),
      taxiMark: taxiMark,
    );

TripEnquiryModel _stay(String status, {int day = 1, int nights = 2, String id = 's1'}) => TripEnquiryModel(
      id: id,
      kind: TripEnquiryKinds.stay,
      day: day,
      serverNights: nights,
      status: status,
      listingName: 'Deodar',
    );

TripEnquiryModel _taxi(String status, {String id = 't1'}) => TripEnquiryModel(
      id: id,
      kind: TripEnquiryKinds.taxi,
      day: 1,
      days: const [1, 2],
      status: status,
      listingName: 'Pradeep',
    );

TripEasyRowInfo _row(List<TripEasyRowInfo> rows, TripEasyRowKey k) => TripEasyRules.rowOf(rows, k)!;

const _stayKey = TripEasyRowKey(TripEasyRowKind.stay, 1);
const _taxiKey = TripEasyRowKey(TripEasyRowKind.taxi);

void main() {
  test('single city has a stay row and the taxi row', () {
    final rows = TripEasyRules.rows(_plan(), const [], const []);
    expect([for (final r in rows) r.key.id], ['stay:1', 'taxi']);
    expect(rows.every((r) => r.state == TripRowState.todo), isTrue);
  });

  test('multi city adds one stay row per city', () {
    final p = TripPlan(
      legs: const [
        TripCityLeg(index: 1, cityKey: 1, cityName: 'A', latitude: 1, longitude: 1),
        TripCityLeg(index: 2, cityKey: 2, cityName: 'B', latitude: 2, longitude: 2),
      ],
      days: const [TripDay(day: 1), TripDay(day: 2, leg: 2)],
    );
    final ids = [for (final r in TripEasyRules.rows(p, const [], const []))  r.key.id];
    expect(ids, ['stay:1', 'stay:2', 'taxi']);
  });

  test('marks give own and skipped, own wins over enquiries', () {
    final rows = TripEasyRules.rows(
      _plan(stayMark: const TripRowMark.own(), taxiMark: const TripRowMark.skipped()),
      [_stay(TripEnquiryStatuses.asked)],
      const [],
    );
    expect(_row(rows, _stayKey).state, TripRowState.own);
    expect(_row(rows, _taxiKey).state, TripRowState.skipped);
  });

  test('stay states from enquiries', () {
    TripRowState of(List<TripEnquiryModel> e) => _row(TripEasyRules.rows(_plan(), e, const []), _stayKey).state;
    expect(of([_stay(TripEnquiryStatuses.asked)]), TripRowState.asked);
    expect(of([_stay(TripEnquiryStatuses.offered)]), TripRowState.offer);
    expect(of([_stay(TripEnquiryStatuses.confirmedByBoth)]), TripRowState.confirmed);
    expect(of([_stay(TripEnquiryStatuses.notAvailable)]), TripRowState.attention);
    expect(of([_stay(TripEnquiryStatuses.asked, day: 9, nights: 1)]), TripRowState.todo);
  });

  test('offer needs you, asked does not', () {
    final rows = TripEasyRules.rows(_plan(), [_stay(TripEnquiryStatuses.offered)], const []);
    expect(_row(rows, _stayKey).needsYou, isTrue);
    final asked = TripEasyRules.rows(_plan(), [_stay(TripEnquiryStatuses.asked)], const []);
    expect(_row(asked, _stayKey).needsYou, isFalse);
  });

  test('dismissed red row returns to todo', () {
    final e = [_stay(TripEnquiryStatuses.expired)];
    final rows = TripEasyRules.rows(_plan(), e, const [], dismissed: {'s1'});
    expect(_row(rows, _stayKey).state, TripRowState.todo);
  });

  test('taxi states', () {
    TripRowState of(String s) => _row(TripEasyRules.rows(_plan(), [_taxi(s)], const []), _taxiKey).state;
    expect(of(TripEnquiryStatuses.asked), TripRowState.asked);
    expect(of(TripEnquiryStatuses.fareSent), TripRowState.offer);
    expect(of(TripEnquiryStatuses.bookedByTraveller), TripRowState.booked);
    expect(of(TripEnquiryStatuses.confirmedByBoth), TripRowState.confirmed);
    expect(of(TripEnquiryStatuses.expired), TripRowState.attention);
  });

  test('taxi states without a taxi request still come from legacy enquiries', () {
    TripEasyRowInfo of(String s) =>
        _row(TripEasyRules.rows(_plan(), [_taxi(s)], const [], taxiRequest: null), _taxiKey);
    expect(of(TripEnquiryStatuses.fareSent).state, TripRowState.offer);
    expect(of(TripEnquiryStatuses.fareSent).fromTaxiRequest, isFalse);
  });

  test('an active taxi request wins over legacy taxi enquiries and the taxi mark', () {
    const ref = TripTaxiRequestRef(requestId: 'r1', state: 'Booked', view: 'Booked', version: 3);
    final row = _row(
      TripEasyRules.rows(_plan(taxiMark: const TripRowMark.skipped()), [_taxi(TripEnquiryStatuses.asked)], const [], taxiRequest: ref),
      _taxiKey,
    );
    expect(row.state, TripRowState.confirmed);
    expect(row.taxiRequest, same(ref));
  });

  test('skipped taxi and own stay are both handled parts', () {
    final rows = TripEasyRules.rows(
      _plan(stayMark: const TripRowMark.own(), taxiMark: const TripRowMark.skipped()),
      const [],
      const [],
    );
    final p = TripParts.from(hasItinerary: true, rows: [for (final r in rows) (r.kind, r.state)]);
    expect(p.handled, 3);
    expect(p.percent, 100);
  });

  test('first in progress prefers rows that need you', () {
    final rows = TripEasyRules.rows(
      _plan(),
      [_stay(TripEnquiryStatuses.asked), _taxi(TripEnquiryStatuses.fareSent)],
      const [],
    );
    expect(TripEasyRules.firstInProgress(rows)!.key, _taxiKey);
    final none = TripEasyRules.rows(_plan(), const [], const []);
    expect(TripEasyRules.firstInProgress(none), isNull);
  });

  test('nights follow the check-in date when dates exist', () {
    final p = _plan(start: DateTime(2026, 11, 20));
    final e = TripEnquiryModel(
      id: 'x',
      kind: TripEnquiryKinds.stay,
      day: 1,
      checkIn: DateTime(2026, 11, 21),
      checkOut: DateTime(2026, 11, 23),
    );
    expect(TripEasyRules.nightsOf(e, p), {2, 3});
  });
}
