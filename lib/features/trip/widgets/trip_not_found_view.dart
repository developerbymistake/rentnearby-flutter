import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:bakhli/design/extra/travel_icon.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';

class TripNotFoundView extends StatelessWidget {
  final VoidCallback? onMyTrips;

  const TripNotFoundView({super.key, this.onMyTrips});

  @override
  Widget build(BuildContext context) {
    return TripEmpty(
      asset: TravelIcon.route,
      title: TripStrings.tripNotFoundTitle,
      subtitle: TripStrings.tripNotFoundBody,
      retryLabel: TripStrings.myTripsAction,
      onRetry: onMyTrips ?? () => TripNavigation.replaceWithMyTrips(),
    );
  }
}
