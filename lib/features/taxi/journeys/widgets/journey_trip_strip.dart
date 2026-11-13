import 'package:flutter/material.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import 'package:get/get.dart';
import '../../../trip/controllers/trip_plan_controller.dart';
import '../../../trip/models/trip_journey_model.dart';
import '../../../trip/models/trip_plan_model.dart';
import '../../../trip/trip_navigation.dart';
import '../../../trip/trip_strings_mcb_a3.dart';
import '../../../trip/utils/trip_travel_rules.dart';
import '../../../trip/widgets/trip_taxi_booking_sheet.dart';
import '../journey_models.dart';

TripPlanController? tripControllerFor(SavedJourney j) {
  final id = j.tripId;
  if (id == null || !Get.isRegistered<TripPlanController>()) return null;
  final c = Get.find<TripPlanController>();
  return c.trip.value?.id == id ? c : null;
}

class JourneyTripStrip extends StatelessWidget {
  final SavedJourney journey;

  const JourneyTripStrip({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    final j = journey;
    final day = j.tripTravelDay;
    final title = (j.tripTitle ?? '').trim();
    final text = day == null
        ? TripStringsMcbA3.partOfTrip
        : TripStringsMcbA3.partOf(title.isEmpty ? TripStringsMcbA3.partOfTrip : title, day);
    final registered = tripControllerFor(j) != null;
    return JourneyTripCard3D(
      text: text.replaceAll('Day ', 'Day\u00A0'),
      actionLabel: registered ? TripStringsMcbA3.open : TripStringsMcbA3.openTrip,
      onAction: () => TripNavigation.openPlan(tripId: j.tripId),
    );
  }
}

class JourneyCarBookRow extends StatelessWidget {
  final SavedJourney journey;
  final SavedJourneyLeg leg;

  const JourneyCarBookRow({super.key, required this.journey, required this.leg});

  @override
  Widget build(BuildContext context) {
    final c = tripControllerFor(journey);
    if (c == null || leg.driver.taxiId.isEmpty || journey.isCompleted) return const SizedBox.shrink();
    return Obx(() {
      c.enquiryList.length;
      c.plan.value;
      final cityLeg = c.plan.value?.segmentLegOf(journey.id);
      final role = cityLeg != null
          ? null
          : TripStepRole.values.firstWhereOrNull((r) => c.journeyIdOf(role: r) == journey.id);
      if (cityLeg == null && role == null) return const SizedBox.shrink();
      final rows = c.journeyRowsOf(role: role, legIndex: cityLeg);
      final booked = TripTravelRules.carBooking(leg.legIndex, rows) != null;
      if (booked && leg.isBooked) return const SizedBox.shrink();
      return _row(context, booked, role, cityLeg);
    });
  }

  Widget _row(BuildContext context, bool booked, TripStepRole? role, int? cityLeg) {
    if (booked) return const JourneyBookRow3D(label: TripStringsMcbA3.booked, booked: true);
    return JourneyBookRow3D(
      label: TripStringsMcbA3.iBooked,
      onTap: () => TripTaxiBookingSheet.showForJourneyCar(
        context,
        role: role,
        legIndex: cityLeg,
        journeyId: journey.id,
        carIndex: leg.legIndex,
        car: TripJourneyLeg.fromSaved(leg),
      ),
    );
  }
}
