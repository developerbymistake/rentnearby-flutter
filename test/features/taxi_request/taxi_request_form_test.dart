import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/utils/taxi_request_form.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _sample(String name) =>
    jsonDecode(File('test/features/taxi_request/samples/$name').readAsStringSync()) as Map<String, dynamic>;

const _kathgodam = 6377270;
const _ramnagar = 2738820;
const _days6 = [1, 2, 3, 4, 5, 6];

TaxiPickupPlaces _places() => TaxiPickupPlaces.fromJson(_sample('pickup_places.json'));

TaxiRequestForm _form() => TaxiRequestForm.initial(places: _places(), planDays: _days6);

void main() {
  test('frame_21_all_on_summary_and_disabled', () {
    final f = _form();
    expect(f.summary, 'Choose a pickup, 6 sightseeing days, drop same as pickup');
    expect(f.canSend, isFalse);
    expect(f.block, TaxiFormBlock.pickupMissing);
  });

  test('frame_22_all_off_disables_send', () {
    final f = _form().setPickupOn(false).setSightseeingOn(false).setDropOn(false);
    expect(f.summary, 'Turn on at least one section');
    expect(f.canSend, isFalse);
  });

  test('frame_23_pickup_only', () {
    final f = _form().setSightseeingOn(false).setDropOn(false).choosePickup(_kathgodam);
    expect(f.summary, 'Pickup at Kathgodam');
    expect(f.canSend, isTrue);
  });

  test('frame_24_sightseeing_only', () {
    final f = _form().setPickupOn(false).setDropOn(false);
    expect(f.summary, '6 sightseeing days');
    expect(f.canSend, isTrue);
  });

  test('frame_25_drop_only_needs_a_choice', () {
    final f = _form().setPickupOn(false).setSightseeingOn(false);
    expect(f.summary, 'Choose a drop');
    expect(f.canSend, isFalse);
    expect(f.block, TaxiFormBlock.dropMissing);
    final chosen = f.chooseDrop(_ramnagar);
    expect(chosen.canSend, isTrue);
    expect(chosen.summary, 'Drop at Ramnagar');
  });

  test('frame_26_pickup_and_drop', () {
    final f = _form().setSightseeingOn(false).choosePickup(_kathgodam);
    expect(f.summary, 'Pickup at Kathgodam, drop same as pickup');
    expect(f.canSend, isTrue);
    expect(f.chooseDrop(_ramnagar).summary, 'Pickup at Kathgodam, drop at Ramnagar');
  });

  test('frame_27_ready_send_enabled', () {
    final f = _form().choosePickup(_kathgodam);
    expect(f.summary, 'Pickup at Kathgodam, 6 sightseeing days, drop same as pickup');
    expect(f.canSend, isTrue);
  });

  test('frame_28_empty_pickup_list', () {
    final json = _sample('pickup_places.json')..['pickup'] = <dynamic>[];
    final f = TaxiRequestForm.initial(places: TaxiPickupPlaces.fromJson(json), planDays: _days6)
        .setSightseeingOn(false)
        .setDropOn(false);
    expect(f.summary, 'No pickup available here');
    expect(f.canSend, isFalse);
  });

  test('sightseeing_days_toggle_and_zero_days_counts_as_off', () {
    var f = _form().setPickupOn(false).setDropOn(false);
    f = f.toggleDay(2);
    expect(f.sightseeingDays, [1, 3, 4, 5, 6]);
    expect(f.summary, '5 sightseeing days');
    f = f.toggleDay(2).toggleDay(99);
    expect(f.sightseeingDays.length, 6);
    for (final d in _days6) {
      f = f.toggleDay(d);
    }
    expect(f.canSend, isFalse);
    expect(f.summary, 'Turn on at least one section');
    var one = _form().setPickupOn(false).setDropOn(false);
    for (final d in [2, 3, 4, 5, 6]) {
      one = one.toggleDay(d);
    }
    expect(one.summary, '1 sightseeing day');
  });

  test('seats_preset_from_suggestion_and_only_valid_values', () {
    expect(_form().seats, 4);
    final six = TaxiRequestForm.initial(
        places: TaxiPickupPlaces.fromJson(_sample('pickup_places.json')..['suggestedSeats'] = 6), planDays: _days6);
    expect(six.seats, 6);
    expect(six.setSeats(7).seats, 7);
    expect(six.setSeats(5).seats, 6);
  });

  test('body_equals_taxi_request_create_sample', () {
    final sample = _sample('taxi_request_create.json');
    final f = TaxiRequestForm.initial(places: _places(), planDays: const [1, 2, 3, 4])
        .choosePickup(_kathgodam)
        .toggleDay(3);
    final stats = [
      for (final s in sample['dayStats'] as List)
        TaxiDayStat(day: s['day'] as int, km: s['km'] as int, minutes: s['minutes'] as int),
    ];
    final body = f.toBody(sample['clientRequestId'] as String, stats);
    expect(jsonDecode(jsonEncode(body)), sample);
  });

  test('body_for_off_sections_is_clean', () {
    final body = _form().setPickupOn(false).setSightseeingOn(false).chooseDrop(_ramnagar).toBody('c', const []);
    expect(body['pickup'], {'on': false, 'cityKey': null});
    expect(body['sightseeing'], {'on': false, 'days': <int>[]});
    expect(body['drop'], {'on': true, 'sameAsPickup': false, 'cityKey': _ramnagar});
  });
}
