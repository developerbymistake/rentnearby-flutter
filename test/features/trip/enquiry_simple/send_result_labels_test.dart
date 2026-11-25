import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/trip_strings_enquiry_simple.dart';
import 'package:bakhli/features/trip/trip_strings_shortlist.dart';
import 'package:bakhli/features/trip/widgets/trip_send_result_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shortlist send labels name the real reason, not Try again', () {
    expect(TripStringsShortlist.statusLabel('OpenForOtherNights'), TripStringsEnq.otherNights);
    expect(TripStringsShortlist.statusLabel('AlreadyBooked'), TripStringsEnq.alreadyBooked);
    expect(TripStringsShortlist.statusLabel('OpenInAnotherTrip'), 'Asked in another trip');
    expect(TripStringsShortlist.statusLabel('Failed'), 'Try again');
  });

  test('skip reasons map to their own labels', () {
    expect(TripSendResultSheet.reasonLabel(TripSkipReasons.openInAnotherTrip), 'Asked in another trip');
    expect(TripSendResultSheet.reasonLabel(TripSkipReasons.openForOtherNights), TripStringsEnq.otherNights);
  });

  test('other trip title shows when the server sends it', () {
    expect(TripStringsEnq.askedOtherTrip('Goa trip'), 'Asked in another trip: Goa trip');
    expect(TripStringsEnq.askedOtherTrip(''), 'Asked in another trip');
    expect(TripStringsEnq.askedOtherTrip(null), 'Asked in another trip');
  });
}
