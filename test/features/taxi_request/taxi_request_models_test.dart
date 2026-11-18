import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _sample(String name) =>
    jsonDecode(File('test/features/taxi_request/samples/$name').readAsStringSync()) as Map<String, dynamic>;

void main() {
  const snapshots = [
    'taxi_request_finding.json',
    'taxi_request_waiting.json',
    'taxi_request_no_reply.json',
    'taxi_request_collecting.json',
    'taxi_request_selected.json',
    'taxi_request_booked.json',
    'taxi_request_in_progress.json',
    'taxi_request_rate.json',
    'taxi_request_busy.json',
  ];

  for (final name in snapshots) {
    test('snapshot_round_trip_$name', () {
      final json = _sample(name);
      final model = TaxiRequest.fromJson(json);
      expect(jsonDecode(jsonEncode(model.toJson())), json);
      expect(model.view, isNot(RequestView.unknown));
      expect(model.state, isNot(RequestState.unknown));
    });
  }

  test('snapshot_fields_are_typed', () {
    final r = TaxiRequest.fromJson(_sample('taxi_request_in_progress.json'));
    expect(r.state, RequestState.inProgress);
    expect(r.view, RequestView.inProgress);
    expect(r.booking!.state, BookingState.inProgress);
    expect(r.booking!.canEnd, isTrue);
    expect(r.drivers.single.state, OfferState.confirmed);
    expect(r.drivers.single.ratingAverage, 4.8);
    expect(r.from, DateTime(2026, 12, 18));
    expect(TaxiRequest.fromJson(_sample('taxi_request_busy.json')).endReason, RequestEndReason.allDriversBusy);
    expect(TaxiRequest.fromJson(_sample('taxi_request_rate.json')).drivers.single.phone, isNull);
  });

  test('pickup_places_parses_and_round_trips', () {
    final json = _sample('pickup_places.json');
    final p = TaxiPickupPlaces.fromJson(json);
    expect(p.paused, isFalse);
    expect(p.firstCity.name, 'Nainital');
    expect(p.pickup.map((e) => e.name), ['Kathgodam', 'Haldwani']);
    expect(p.drop.last.drivers, 7);
    expect(p.suggestedSeats, 4);
    expect(p.pickupByKey(2552100)!.name, 'Haldwani');
    expect(p.pickupByKey(1), isNull);
    expect(jsonDecode(jsonEncode(p.toJson())), json);
  });

  test('unknown_enum_text_becomes_unknown_and_keeps_raw', () {
    final json = _sample('taxi_request_finding.json')
      ..['state'] = 'Frozen'
      ..['view'] = 'Sparkling'
      ..['endReason'] = 'Mystery';
    final r = TaxiRequest.fromJson(json);
    expect(r.state, RequestState.unknown);
    expect(r.view, RequestView.unknown);
    expect(r.endReason, RequestEndReason.unknown);
    expect(r.stateText, 'Frozen');
    expect(r.toJson()['view'], 'Sparkling');
    expect(OfferState.parse(null), OfferState.unknown);
    expect(BookingState.parse('x'), BookingState.unknown);
    expect(ReasonChip.parse('ChangedPlan'), ReasonChip.changedPlan);
  });

  test('seats_snap', () {
    expect(TaxiSeats.forTravellers(2), 4);
    expect(TaxiSeats.forTravellers(5), 6);
    expect(TaxiSeats.forTravellers(9), 7);
    expect(TaxiSeats.snap(6), 6);
    expect(TaxiSeats.snap(5), 6);
  });
}
