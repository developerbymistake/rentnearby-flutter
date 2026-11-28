import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../trip_strings_overview.dart';

class TripExitConfirm {
  static const Key exitKey = ValueKey('trip-exit-confirm');
  static const Key stayKey = ValueKey('trip-exit-stay');

  static Future<bool> ask(BuildContext context) async {
    final leave = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.indigo,
        art: ListingArt.luggage,
        title: TripStringsOverview.exitTitle,
        body: TripStringsOverview.exitBody,
        tight: true,
        secondaryLabel: TripStringsOverview.keepPlanning,
        secondaryKey: stayKey,
        onSecondary: () => Navigator.pop(ctx, false),
        primaryLabel: TripStringsOverview.exit,
        primaryKey: exitKey,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    return leave == true;
  }
}
