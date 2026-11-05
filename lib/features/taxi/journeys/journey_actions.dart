import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../trip/trip_strings_mcb_a3.dart';
import '../../trip/trip_strings_steps_a3.dart';
import '../ways/ask_drivers_sheet.dart';
import '../ways/change_driver_sheet.dart';
import '../ways/taxi_ways_strings.dart';
import 'journey_models.dart';
import 'journey_strings.dart';
import 'journey_way_bridge.dart';
import 'journeys_controller.dart';

class JourneyActions {
  const JourneyActions._();

  static Future<bool> ask(BuildContext context, SavedJourney j) async {
    if (j.legs.isEmpty) return false;
    final result = await AskDriversSheet.show(
      context,
      plan: j.toWayPlan(),
      chosen: j.chosenDrivers(),
      date: j.date,
      people: j.people,
      journeyId: j.id,
      fromName: j.fromName,
      toName: j.toName,
    );
    if (result == null) return false;
    JourneysController.ensure().recordAsk(j.id, result);
    return true;
  }

  static Future<void> changeDriver(BuildContext context, SavedJourney j, SavedJourneyLeg leg) async {
    final picked = await ChangeDriverSheet.show(
      context,
      leg: j.wayLeg(leg),
      people: j.people,
      current: j.wayDriver(leg, leg.driver),
    );
    if (picked == null || picked.taxiId == leg.driver.taxiId) return;
    await JourneysController.ensure().replaceDriver(j.id, leg.legIndex, picked.taxiId);
  }

  static Future<bool> confirmDelete(BuildContext context, SavedJourney j) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(TaxiWaysStrings.deleteJourney),
        content: Text(
          j.tripId == null
              ? JourneyStrings.deleteBody
              : '${JourneyStrings.deleteBody} ${j.isSegment ? TripStringsMcbA3.alsoRemovedFromTravel(j.toName) : TripStringsStepsA3.alsoRemovedFromTrip}',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(JourneyStrings.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44), foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(TaxiWaysStrings.deleteJourney),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    return JourneysController.ensure().remove(j.id);
  }

  static Future<void> openSaved(String id) async {
    await Get.toNamed(AppRoutes.savedJourney, arguments: {'journeyId': id});
  }
}
