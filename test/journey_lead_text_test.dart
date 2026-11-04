import 'package:bakhli/features/taxi/leads/journey_leg_tag.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:flutter_test/flutter_test.dart';

TripEnquiryModel lead(String text) => TripEnquiryModel(id: 'e1', context: TripEnquiryContext(text: text));

void main() {
  test('reads car i of n from the lead text', () {
    expect(JourneyLegTag.fromLead(lead('Car 2 of 2: Haridwar to Badrinath, 01 Nov, 4. Comes from Delhi with another driver.')),
        'Car 2 of 2');
    expect(JourneyLegTag.fromLead(lead('Car 1 of 3: Lucknow to Kathgodam, 01 Nov, 2.')), 'Car 1 of 3');
  });

  test('returns null for a single-car or plain lead', () {
    expect(JourneyLegTag.fromLead(lead('Delhi to Badrinath, 01 Nov, 2.')), isNull);
    expect(JourneyLegTag.fromLead(lead('')), isNull);
  });
}
