import 'package:flutter/widgets.dart';

import '../../config/tour_registry.dart';
import '../../navigation/tour_keys.dart';

abstract final class SeekerTourKeys {
  static final homeTripCard = GlobalKey();
}

List<TourStep> seekerHomeTourSteps() => seekerStepsFrom(todayHomeTourSteps());

List<TourStep> seekerStepsFrom(List<TourStep> today) {
  final ownerTiles = {TourKeys.homeQuickActionAddStay, TourKeys.homeQuickActionAddTaxi, TourKeys.homeQuickActionLeads};
  return [
    for (final s in today)
      if (!ownerTiles.contains(s.key))
        identical(s.key, TourKeys.homeManageListingsCard)
            ? TourStep(key: SeekerTourKeys.homeTripCard, title: s.title, body: s.body, icon: s.icon)
            : s,
  ];
}
