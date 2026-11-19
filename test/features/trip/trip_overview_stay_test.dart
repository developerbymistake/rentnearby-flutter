import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/screens/trip_overview_screen.dart';
import 'package:bakhli/features/trip/trip_strings_overview.dart';
import 'package:flutter_test/flutter_test.dart';

TripEnquiryModel _e(String id, String status, {String kind = 'Stay', int day = 1, String? listing}) => TripEnquiryModel.fromJson({
      'id': id,
      'tripId': 't1',
      'kind': kind,
      'listingId': listing ?? 'l$id',
      'listingName': 'Stay $id',
      'day': day,
      'status': status,
    });

String? _city(TripEnquiryModel e) => e.day == 1 ? 'Nainital' : 'Almora';

void main() {
  test('no stay enquiry reads Optional and Find a stay', () {
    final s = TripOverviewStay.of(const []);
    expect(s.state, TripOverviewStayState.notAdded);
    expect(s.chip, TripStringsOverview.optional);
    expect(s.button, TripStringsOverview.addStay);
    expect(s.line, TripStringsOverview.stayLine);
    expect(s.added, isFalse);
  });

  test('taxi enquiries never count as a stay', () {
    expect(TripOverviewStay.of([_e('1', TripEnquiryStatuses.asked, kind: TripEnquiryKinds.taxi)]).added, isFalse);
  });

  test('open stay enquiries read Added with the count and the city', () {
    final s = TripOverviewStay.of([_e('1', TripEnquiryStatuses.asked), _e('2', TripEnquiryStatuses.asked)], cityOf: _city);
    expect(s.state, TripOverviewStayState.requested);
    expect(s.chip, TripStringsOverview.added);
    expect(s.button, TripStringsOverview.viewStays);
    expect(s.line, '2 stays asked in Nainital');
  });

  test('stays in two cities leave the city out of the line', () {
    final s = TripOverviewStay.of([_e('1', TripEnquiryStatuses.asked), _e('2', TripEnquiryStatuses.asked, day: 3)], cityOf: _city);
    expect(s.line, '2 stays asked');
  });

  test('the same stay asked twice counts once', () {
    final s = TripOverviewStay.of([_e('1', TripEnquiryStatuses.asked, listing: 'x'), _e('2', TripEnquiryStatuses.asked, listing: 'x')]);
    expect(s.line, '1 stay asked');
  });

  test('a booked stay reads Booked', () {
    final booked = TripEnquiryStatuses.booked.first;
    final s = TripOverviewStay.of([_e('1', TripEnquiryStatuses.asked), _e('2', booked)]);
    expect(s.state, TripOverviewStayState.booked);
    expect(s.chip, TripStringsOverview.booked);
  });

  test('closed enquiries do not count', () {
    final closed = [
      for (final st in const ['Declined', 'Expired', 'Withdrawn', 'Cancelled'])
        if (!TripEnquiryStatuses.open.contains(st) && !TripEnquiryStatuses.confirmed.contains(st) && !TripEnquiryStatuses.booked.contains(st)) st,
    ];
    expect(TripOverviewStay.of([for (final (i, st) in closed.indexed) _e('$i', st)]).added, isFalse);
  });
}
