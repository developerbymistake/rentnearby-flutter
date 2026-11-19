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
}
