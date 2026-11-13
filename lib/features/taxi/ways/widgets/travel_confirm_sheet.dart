import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../trip_strings_mcb_a2.dart';

class TravelConfirmSheet {
  static Future<bool> show(BuildContext context, {required String title, required String body, required String confirm}) async {
    final tone = ListingTone.coral;
    final ok = await Sheet3D.show<bool>(
      context,
      builder: (sheetCtx) => Sheet3D(
        tone: tone,
        art: ListingArt.taxi,
        title: title,
        subtitle: body,
        footer: PillButtonRow(children: [
          WhitePillButton(tone: tone, label: TripStringsMcbA2.keep, height: 52, fontSize: 15, onTap: () => Navigator.pop(sheetCtx, false)),
          GradientPillButton(tone: tone, label: confirm, height: 52, fontSize: 15, onTap: () => Navigator.pop(sheetCtx, true)),
        ]),
        child: const SizedBox(height: 4),
      ),
    );
    return ok == true;
  }

  static Future<bool> removeTravel(BuildContext context, int bookedCars) => show(
        context,
        title: TripStringsMcbA2.removeTravelQ,
        body: TripStringsMcbA2.bookedCarsCancelled(bookedCars),
        confirm: TripStringsMcbA2.cancelAndRemove,
      );

  static Future<bool> replaceTravel(BuildContext context, int bookedCars) => show(
        context,
        title: TripStringsMcbA2.replaceTravelQ,
        body: TripStringsMcbA2.bookedCarsCancelled(bookedCars),
        confirm: TripStringsMcbA2.replace,
      );
}
