import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../config/app_colors.dart';
import '../../../trip/controllers/trip_plan_controller.dart';
import '../../../trip/models/trip_journey_model.dart';
import '../../../trip/trip_colors.dart';
import '../../../trip/trip_navigation.dart';
import '../../../trip/trip_strings_mcb_a3.dart';
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
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: TripColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TripColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.route_rounded, size: 18, color: TripColors.accentDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TripColors.accentDark),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(64, 44), foregroundColor: TripColors.accentDark),
          onPressed: () => TripNavigation.openPlan(tripId: j.tripId),
          child: Text(
            registered ? TripStringsMcbA3.open : TripStringsMcbA3.openTrip,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
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
      final cityLeg = c.plan.value?.segmentLegOf(journey.id);
      if (cityLeg == null) return const SizedBox.shrink();
      final booked = c.carBooking(cityLeg, leg.legIndex) != null;
      if (booked && leg.isBooked) return const SizedBox.shrink();
      return _row(context, booked, cityLeg);
    });
  }

  Widget _row(BuildContext context, bool booked, int cityLeg) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: booked
          ? Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: TripStatusColors.booked),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    TripStringsMcbA3.booked,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: TripStatusColors.booked),
                  ),
                ),
              ]),
            )
          : SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: TripColors.accentDark,
                  side: const BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                onPressed: () => TripTaxiBookingSheet.showForJourneyCar(
                  context,
                  legIndex: cityLeg,
                  journeyId: journey.id,
                  carIndex: leg.legIndex,
                  car: TripJourneyLeg.fromSaved(leg),
                ),
                child: const Text(TripStringsMcbA3.iBooked, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
    );
  }
}
