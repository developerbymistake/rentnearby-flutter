import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _sample(String name) =>
    jsonDecode(File('test/features/taxi_request/samples/$name').readAsStringSync()) as Map<String, dynamic>;

Object? _again(Map<String, dynamic> json) => jsonDecode(jsonEncode(json));

void main() {
  test('offer_list_sample_round_trips', () {
    final json = _sample('driver_offer_list.json');
    final list = DriverOfferList.fromJson(json);
    expect(_again(list.toJson()), json);
    expect(list.counts.newCount, 1);
    expect(list.items.map((e) => e.bucket), [OfferBucket.newOffers, OfferBucket.booked, OfferBucket.earlier, OfferBucket.earlier]);
    expect(list.items.map((e) => e.state), [OfferState.ringing, OfferState.confirmed, OfferState.missed, OfferState.notSelected]);
    expect(list.items[2].endReason, OfferEndReason.expired);
    expect(list.items.every((e) => e.trip == null), isTrue);
    expect(list.items[0].traveller, isNull);
    expect(list.items[1].traveller!.name, 'Aarav Sharma');
    expect(list.items[0].expiresAtInstant, DateTime.utc(2026, 12, 10, 9, 46, 7));
    expect(list.clockOffset(DateTime.utc(2026, 12, 10, 9, 42, 0)), const Duration(minutes: 1));
  });

  for (final name in ['driver_offer_detail_ringing.json', 'driver_offer_detail_selected.json']) {
    test('offer_detail_round_trips_$name', () {
      final json = _sample(name);
      final offer = DriverOffer.fromJson(json);
      expect(_again(offer.toJson()), json);
      expect(offer.trip!.days.length, 4);
      expect(offer.trip!.days[2].taxi, isFalse);
      expect(offer.trip!.drop.sameAsPickup, isTrue);
      expect(offer.trip!.cities.first.nights, 3);
    });
  }

  test('selected_detail_carries_traveller_and_conflict', () {
    final offer = DriverOffer.fromJson(_sample('driver_offer_detail_selected.json'));
    expect(offer.state, OfferState.selected);
    expect(offer.confirmByInstant, DateTime.utc(2026, 12, 10, 10, 1));
    expect(offer.datesConflict!.from, '2026-12-20');
    expect(offer.datesConflict!.toDay, DateTime(2026, 12, 24));
    expect(offer.traveller!.phone, '+919876543210');
  });

  test('bookings_sample_round_trips', () {
    final json = _sample('driver_bookings.json');
    final b = DriverBookings.fromJson(json);
    expect(_again(b.toJson()), json);
    expect(b.occupied.single.fromDay, DateTime(2026, 12, 18));
    expect(b.items.first.state, BookingState.booked);
    expect(b.items.first.canWithdraw, isTrue);
    expect(b.items.last.state, BookingState.completed);
    expect(b.items.last.travellerPhone, isNull);
  });

  test('rating_sample_round_trips', () {
    final json = _sample('driver_rating.json');
    final r = DriverRating.fromJson(json);
    expect(_again(r.toJson()), json);
    expect(r.average, 4.8);
    expect(r.latest.length, 4);
    expect(DriverRating.fromJson({'average': null, 'ratingCount': 0, 'ridesCompleted': 0, 'latest': []}).average, isNull);
  });

  test('readiness_sample_round_trips', () {
    final json = _sample('driver_readiness.json');
    final r = DriverReadiness.fromJson(json);
    expect(_again(r.toJson()), json);
    expect(r.ringReady, isTrue);
    expect(r.missedRings, isFalse);
  });

  test('device_state_sample_round_trips_with_ring_tested', () {
    final json = _sample('driver_device_state.json');
    final s = DriverDeviceState.fromJson(json);
    expect(_again(s.toJson()), json);
    expect(s.ringTested, isFalse);
    expect(s.copyWith(ringTested: true).toJson()['ringTested'], isTrue);
  });

  test('unknown_state_parses_to_unknown_and_keeps_raw', () {
    final json = _sample('driver_offer_detail_ringing.json')
      ..['state'] = 'Frozen'
      ..['bucket'] = 'Sideways'
      ..['endReason'] = 'Mystery';
    final offer = DriverOffer.fromJson(json);
    expect(offer.state, OfferState.unknown);
    expect(offer.bucket, OfferBucket.unknown);
    expect(offer.endReason, OfferEndReason.unknown);
    expect(offer.toJson()['state'], 'Frozen');
    expect(BookingState.parse('x'), BookingState.unknown);
    expect(OfferState.parse(null), OfferState.unknown);
  });

  test('copy_with_state_changes_only_state', () {
    final offer = DriverOffer.fromJson(_sample('driver_offer_detail_ringing.json'));
    final missed = offer.copyWith(state: OfferState.missed);
    expect(missed.state, OfferState.missed);
    expect(missed.trip, same(offer.trip));
  });
}
