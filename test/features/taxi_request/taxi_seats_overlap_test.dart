import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/utils/taxi_request_errors.dart';
import 'package:bakhli/features/trip/utils/taxi_request_form.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taxi_request_controller_fakes.dart';

TaxiRequestForm _form(int travellers, {int suggested = 4}) => TaxiRequestForm.initial(
      places: TaxiPickupPlaces.fromJson({...sampleJson('pickup_places.json'), 'travellers': travellers, 'suggestedSeats': suggested}),
      planDays: const [1, 2, 3],
    ).choosePickup(6377270);

TaxiResult<Object> _error(int status, String type, [Map<String, dynamic>? data, String? message]) {
  final req = RequestOptions(path: '/x');
  return TaxiResult.fromError<Object>(DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: status, data: {
      'error': {'type': type, 'message': message ?? 'm'},
      'data': ?data,
    }),
  ));
}

void main() {
  test('seat options are 4, 6, 7, 12', () {
    expect(TaxiSeats.options, [4, 6, 7, 12]);
  });

  test('seats smaller than travellers are disabled and cannot be set', () {
    final f = _form(6);
    expect([for (final s in TaxiSeats.options) f.seatEnabled(s)], [false, true, true, true]);
    expect(f.seats, 6);
    expect(f.setSeats(4).seats, 6);
    expect(f.setSeats(12).seats, 12);
    final seven = _form(7);
    expect([for (final s in TaxiSeats.options) seven.seatEnabled(s)], [false, false, true, true]);
    expect(_form(4).seatEnabled(4), isTrue);
  });

  test('preset seat is raised to fit travellers', () {
    expect(_form(5, suggested: 4).seats, 6);
    expect(_form(9, suggested: 4).seats, 12);
    expect(_form(12, suggested: 12).seats, 12);
  });

  test('12 travellers can send, 13 cannot and the line explains', () {
    expect(_form(12).canSend, isTrue);
    final big = _form(13);
    expect(big.canSend, isFalse);
    expect(big.block, TaxiFormBlock.tooManyTravellers);
    expect(big.summary, 'For groups above 12, please send separate requests.');
    expect(big.seats, 12);
  });

  test('body carries 12 seats', () {
    expect(_form(9).toBody('c', const [])['seats'], 12);
  });

  test('overlap 409 keeps the other trip name', () {
    final r = _error(409, 'OverlappingTaxiRequest', {'tripId': 't9', 'tripName': 'Goa Trip'});
    expect(r, isA<TaxiOverlap<Object>>());
    final o = r as TaxiOverlap<Object>;
    expect(o.tripId, 't9');
    expect(TaxiRequestErrors.overlapMessage(o.tripName), 'You already have a taxi request for these dates in Goa Trip.');
    expect(TaxiRequestErrors.overlapMessage('  '), 'You already have a taxi request for these dates in another trip.');
    expect(TaxiRequestErrors.overlapMessage(null), contains('another trip'));
  });

  test('seat errors map to clear messages', () {
    final few = _error(400, 'SeatsTooFew') as TaxiRefused<Object>;
    final many = _error(400, 'TooManyTravellers') as TaxiRefused<Object>;
    expect(TaxiRequestErrors.isSeatsError(few.type), isTrue);
    expect(TaxiRequestErrors.isSeatsError(many.type), isTrue);
    expect(TaxiRequestErrors.isSeatsError('BadRequest'), isFalse);
    expect(TaxiRequestErrors.seatsMessage(few.type), 'Choose a taxi with a seat for everyone.');
    expect(TaxiRequestErrors.seatsMessage(many.type), 'For groups above 12, please send separate requests.');
  });
}
