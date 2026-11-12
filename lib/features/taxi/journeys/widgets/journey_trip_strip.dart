import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
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
    return Container(
      decoration: TripLook.card(),
      child: ClipRRect(
        borderRadius: TripLook.softRadius,
        child: Container(
          color: TripLook.surface,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(children: [
            const TravelIcon(TravelIcon.route, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FitnessAppTheme.title.copyWith(fontSize: 13.5, color: DesignColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 44), foregroundColor: DesignColors.primary),
              onPressed: () => TripNavigation.openPlan(tripId: j.tripId),
              child: Text(
                registered ? TripStringsMcbA3.open : TripStringsMcbA3.openTrip,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TripKit.text(13, weight: FontWeight.w700, color: DesignColors.primary),
              ),
            ),
          ]),
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: booked
          ? Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: TripLook.booked),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    TripStringsMcbA3.booked,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TripKit.text(12.5, weight: FontWeight.w700, color: TripLook.booked),
                  ),
                ),
              ]),
            )
          : SizedBox(
              width: double.infinity,
              child: JourneyButton(
                label: TripStringsMcbA3.iBooked,
                kind: JourneyButtonKind.outline,
                onPressed: () => TripTaxiBookingSheet.showForJourneyCar(
                  context,
                  role: role,
                  legIndex: cityLeg,
                  journeyId: journey.id,
                  carIndex: leg.legIndex,
                  car: TripJourneyLeg.fromSaved(leg),
                ),
              ),
            ),
    );
  }
}
