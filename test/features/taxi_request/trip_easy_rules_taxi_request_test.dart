import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_strings_dayplan.dart';
import 'package:bakhli/features/trip/utils/trip_easy_rules.dart';
import 'package:bakhli/features/trip/utils/trip_parts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taxi_request_controller_fakes.dart';

const _taxiKey = TripEasyRowKey(TripEasyRowKind.taxi);

TripPlan _plan({TripRowMark? taxiMark}) => TripPlan(
      legs: const [TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29, longitude: 79)],
      days: const [TripDay(day: 1), TripDay(day: 2), TripDay(day: 3)],
      settings: TripSettings(startDate: DateTime(2030, 12, 18)),
      taxiMark: taxiMark,
    );

TripEnquiryModel _legacy(String status) => TripEnquiryModel(
      id: 'legacy-1',
      kind: TripEnquiryKinds.taxi,
      day: 1,
      days: const [1, 2],
      status: status,
      listingName: 'Pradeep',
    );

TripTaxiRequestRef _ref(String state, String view) => TripTaxiRequestRef(requestId: 'r1', state: state, view: view, version: 4);

TripEasyRowInfo _row(TripTaxiRequestRef? ref, {List<TripEnquiryModel> legacy = const [], TripRowMark? mark}) =>
    TripEasyRules.rowOf(TripEasyRules.rows(_plan(taxiMark: mark), legacy, const [], taxiRequest: ref), _taxiKey)!;

void main() {
  test('no_request_is_todo', () {
    final r = _row(null);
    expect(r.state, TripRowState.todo);
    expect(r.fromTaxiRequest, isFalse);
  });

  test('open_is_asked', () {
    final r = _row(_ref('Open', 'Finding'));
    expect(r.state, TripRowState.asked);
    expect(r.subtitle, TripStringsDayplan.taxiFinding);
    expect(r.needsYou, isFalse);
    expect(r.fromTaxiRequest, isTrue);
  });

  test('collecting_is_offer_and_needs_you', () {
    final r = _row(_ref('Collecting', 'Collecting'));
    expect(r.state, TripRowState.offer);
    expect(r.needsYou, isTrue);
    expect(r.subtitle, TripStringsDayplan.taxiChoose);
  });

  test('selected_waits_for_the_driver_and_is_not_done', () {
    final r = _row(_ref('Selected', 'Selected'));
    expect(r.state, TripRowState.asked);
    expect(r.state, isNot(TripRowState.booked));
    expect(r.isDone, isFalse);
    expect(r.pill, TripStringsDayplan.pillWaiting);
    expect(r.subtitle, TripStringsDayplan.taxiWaitingConfirm);
    expect(TripParts.arranged(r.state), isTrue);
  });

  test('only_selected_carries_a_pill_override', () {
    for (final s in ['Open', 'Collecting', 'Booked', 'InProgress', 'Completed']) {
      expect(_row(_ref(s, s)).pill, isNull, reason: s);
    }
    expect(_row(null, legacy: [_legacy(TripEnquiryStatuses.bookedByTraveller)]).pill, isNull);
  });

  test('pill_override_drops_when_the_state_changes', () {
    final r = _row(_ref('Selected', 'Selected'));
    expect(r.withState(TripRowState.asked).pill, TripStringsDayplan.pillWaiting);
    expect(r.withState(TripRowState.own).pill, isNull);
  });

  test('booked_and_in_progress_are_confirmed', () {
    expect(_row(_ref('Booked', 'Booked')).state, TripRowState.confirmed);
    expect(_row(_ref('Booked', 'Booked')).subtitle, TripStringsDayplan.taxiBooked);
    expect(_row(_ref('InProgress', 'InProgress')).state, TripRowState.confirmed);
    expect(_row(_ref('InProgress', 'InProgress')).subtitle, TripStringsDayplan.taxiInProgress);
  });

  test('completed_is_confirmed_with_rate_or_done_text', () {
    final rate = _row(_ref('Completed', 'Rate'));
    expect(rate.state, TripRowState.confirmed);
    expect(rate.isDone, isTrue);
    expect(rate.subtitle, TripStringsDayplan.taxiRate);
    expect(_row(_ref('Completed', 'Done')).subtitle, TripStringsDayplan.taxiDone);
  });

  test('cancelled_and_expired_are_todo', () {
    for (final r in [_row(_ref('Cancelled', 'Ended')), _row(_ref('Expired', 'Busy')), _row(_ref('Expired', 'Ended'))]) {
      expect(r.state, TripRowState.todo);
      expect(r.fromTaxiRequest, isFalse);
    }
  });

  test('trip_fields_sample_drives_the_row', () {
    final trip = TripModel.fromJson({
      'id': 't1',
      'title': 'Uttarakhand Hills Trip',
      'status': 'Planned',
      'cityKey': 1,
      'cityName': 'Nainital',
      'cityLatitude': 29.4,
      'cityLongitude': 79.4,
      'dayCount': 3,
      'spotCount': 0,
      'plan': _plan().toJson(),
      'createdAt': '2026-11-01T00:00:00Z',
      'updatedAt': '2026-11-01T00:00:00Z',
      ...sampleJson('trip_taxi_fields.json'),
    });
    final r = _row(trip.taxiRequest);
    expect(r.state, TripRowState.offer);
    expect(r.taxiRequest?.requestId, '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101');
  });

  test('active_request_wins_over_a_legacy_row_and_the_mark', () {
    final r = _row(_ref('Open', 'Finding'), legacy: [_legacy(TripEnquiryStatuses.confirmedByBoth)], mark: const TripRowMark.own());
    expect(r.state, TripRowState.asked);
    expect(r.fromTaxiRequest, isTrue);
  });

  test('mark_wins_over_an_ended_request', () {
    expect(_row(_ref('Cancelled', 'Ended'), mark: const TripRowMark.own()).state, TripRowState.own);
  });

  test('unknown_state_falls_back_to_legacy_rows', () {
    expect(_row(_ref('Paused', 'Weird'), legacy: [_legacy(TripEnquiryStatuses.asked)]).state, TripRowState.asked);
  });

  test('legacy_fallback_without_a_request', () {
    expect(_row(null, legacy: [_legacy(TripEnquiryStatuses.asked)]).state, TripRowState.asked);
    expect(_row(null, legacy: [_legacy(TripEnquiryStatuses.fareSent)]).state, TripRowState.offer);
    expect(_row(null, legacy: [_legacy(TripEnquiryStatuses.bookedByTraveller)]).state, TripRowState.booked);
    expect(_row(null, legacy: [_legacy(TripEnquiryStatuses.confirmedByBoth)]).state, TripRowState.confirmed);
    expect(_row(null, legacy: [_legacy(TripEnquiryStatuses.asked)]).fromTaxiRequest, isFalse);
  });

  test('request_active_helper_matches_the_contract_active_states', () {
    for (final s in ['Open', 'Collecting', 'Selected', 'Booked', 'InProgress']) {
      expect(TripEasyRules.taxiRequestActive(_ref(s, s)), isTrue, reason: s);
    }
    for (final s in ['Completed', 'Cancelled', 'Expired', '']) {
      expect(TripEasyRules.taxiRequestActive(_ref(s, s)), isFalse, reason: s);
    }
    expect(TripEasyRules.taxiRequestActive(null), isFalse);
  });
}
