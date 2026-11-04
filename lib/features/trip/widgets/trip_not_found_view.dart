import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../widgets/empty_state_view.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';

class TripNotFoundView extends StatelessWidget {
  final VoidCallback? onMyTrips;

  const TripNotFoundView({super.key, this.onMyTrips});

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Iconsax.routing_2,
      title: TripStrings.tripNotFoundTitle,
      subtitle: TripStrings.tripNotFoundBody,
      retryLabel: TripStrings.myTripsAction,
      onRetry: onMyTrips ?? () => TripNavigation.replaceWithMyTrips(),
      palette: TripColors.palette,
    );
  }
}
