import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _err(String type, Object? data) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 409,
        data: {
          'error': {'type': type, 'message': 'raw server text'},
          'data': ?data,
        },
      ),
      type: DioExceptionType.badResponse,
    );

void main() {
  test('total case reads counts and the quiet asks with names', () {
    final full = TripStepFull.of(_err('StepFull', {
      'case': 'total',
      'counted': 3,
      'quiet': 3,
      'shortlisted': 0,
      'free': 0,
      'maxCounted': 3,
      'maxTotal': 6,
      'nextQuietAt': null,
      'quietAsks': [
        {'enquiryId': 'q1', 'listingId': 'l1', 'listingName': 'Lakeside Rooms', 'askedAt': '2026-11-24T04:30:00Z'},
        {'enquiryId': 'q2', 'listingId': 'l2', 'listingName': 'Pine Nest', 'askedAt': '2026-11-24T05:30:00Z'},
      ],
      'waitingAsks': [
        {'enquiryId': 'w1', 'listingId': 'l3', 'listingName': 'Deodar', 'askedAt': '2026-11-25T03:00:00Z'},
      ],
    }))!;
    expect(full.totalLimit, isTrue);
    expect((full.counted, full.quiet, full.free), (3, 3, 0));
    expect([for (final a in full.quietAsks) a.listingName], ['Lakeside Rooms', 'Pine Nest']);
    expect(full.quietAsks.first.askedAt, DateTime.utc(2026, 11, 24, 4, 30));
    expect(full.waitingAsks.single.enquiryId, 'w1');
  });

  test('waiting case keeps the waiting asks', () {
    final full = TripStepFull.of(_err('StepFull', {
      'case': 'waiting',
      'counted': 3,
      'nextQuietAt': '2026-11-25T15:00:00Z',
      'waitingAsks': [
        {'enquiryId': 'w1', 'listingId': 'l1', 'listingName': 'A'},
      ],
    }))!;
    expect(full.totalLimit, isFalse);
    expect(full.kind, TripStepFull.waitingCase);
    expect(full.nextQuietAt, DateTime.utc(2026, 11, 25, 15));
    expect(full.waitingAsks, hasLength(1));
  });

  test('old server without data falls back to waiting with empty lists', () {
    final full = TripStepFull.of(_err('StepFull', null))!;
    expect(full.kind, TripStepFull.waitingCase);
    expect(full.quietAsks, isEmpty);
    expect(full.waitingAsks, isEmpty);
  });

  test('other errors are not StepFull', () {
    expect(TripStepFull.of(_err('ShortlistFull', {'case': 'total'})), isNull);
    expect(TripStepFull.of(StateError('x')), isNull);
  });

  test('shortlist steps parse free places per step', () {
    final steps = TripStepSlots.mapOf([
      {'stepKey': 'stay:1', 'counted': 2, 'quiet': 1, 'shortlisted': 0, 'free': 1},
      {'stepKey': 'stay:2'},
      {'counted': 1},
    ]);
    expect(steps.keys, ['stay:1', 'stay:2']);
    expect(steps['stay:1']!.free, 1);
    expect(steps['stay:2']!.free, 3);
  });
}
