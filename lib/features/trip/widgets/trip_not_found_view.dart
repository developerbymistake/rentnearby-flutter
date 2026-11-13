import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';

class TripNotFoundView extends StatelessWidget {
  final VoidCallback? onMyTrips;

  const TripNotFoundView({super.key, this.onMyTrips});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: StateCard(
        asset: ListingArt.luggage,
        title: TripStrings.tripNotFoundTitle,
        message: TripStrings.tripNotFoundBody,
        actionLabel: TripStrings.myTripsAction,
        onAction: onMyTrips ?? () => TripNavigation.replaceWithMyTrips(),
        layout: StateLayout.plain,
      ),
    );
  }
}
