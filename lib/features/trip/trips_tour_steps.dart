import 'package:iconsax/iconsax.dart';
import '../../config/tour_registry.dart';
import '../../navigation/tour_keys.dart';
import 'trip_strings_hub.dart';

List<TourStep> tripsTourSteps() => [
      TourStep(
        key: TourKeys.tripsWhereTile,
        icon: Iconsax.location,
        title: TripStringsHub.tourWhereTitle,
        body: TripStringsHub.tourWhereBody,
      ),
      TourStep(
        key: TourKeys.tripsBuddyTile,
        icon: Iconsax.people,
        title: TripStringsHub.tourBuddyTitle,
        body: TripStringsHub.tourBuddyBody,
      ),
    ];
