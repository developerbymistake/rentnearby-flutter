import 'package:bakhli/features/taxi/ways/models/ask_models.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('batch parses results and keeps every id', () {
    final b = TripEnquiryBatch.fromJson({
      'items': [],
      'skipped': [],
      'results': [
        {'listingId': 'a', 'status': 'Sent', 'enquiryId': 'e1'},
        {'listingId': 'b', 'status': 'LimitReached', 'reason': 'LimitReached'},
      ],
    });
    expect(b.perRecipient.map((r) => r.listingId), ['a', 'b']);
    expect(b.perRecipient.first.ok, isTrue);
    expect(b.perRecipient.last.ok, isFalse);
  });

  test('old server without results falls back to skipped reasons', () {
    final b = TripEnquiryBatch.fromJson({
      'items': [],
      'skipped': [
        {'listingId': 'x', 'reason': 'Blocked'},
      ],
    });
    expect(b.perRecipient.single.status, 'Blocked');
  });

  test('ask request carries clientRequestId, stepKey and a single leg of at most the given ids', () {
    const leg = AskLegRequest(
      legIndex: 1,
      legKey: 'k',
      fromName: 'A',
      toName: 'B',
      listedFare: null,
      taxiIds: ['1', '2', '3', '4'],
      carOf: 1,
    );
    final req = AskDriversRequest(
      date: DateTime(2026, 12, 1),
      people: 2,
      journeyId: 'j',
      fromName: 'A',
      toName: 'B',
      legs: const [leg],
    ).guided(clientRequestId: 'rid', stepKey: 'gettingThere', taxiIds: ['1', '2']);
    final json = req.toJson();
    expect(json['clientRequestId'], 'rid');
    expect(json['stepKey'], 'gettingThere');
    expect(((json['legs'] as List).single as Map)['taxiIds'], ['1', '2']);
  });

  test('ask result parses results with taxiId key', () {
    final r = AskResult.fromJson({
      'items': [],
      'skipped': [],
      'results': [
        {'taxiId': 't1', 'status': 'Sent'},
      ],
    });
    expect(r.results.single.listingId, 't1');
  });
}
