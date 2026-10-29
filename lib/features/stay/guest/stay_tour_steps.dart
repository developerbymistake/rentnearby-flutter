import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/tour_registry.dart';
import '../../../controllers/auth_controller.dart';
import '../../../navigation/tour_keys.dart';

List<TourStep> buildStayLandingSteps() {
  return [
    TourStep(
      key: TourKeys.staysLandingSearch,
      icon: Iconsax.search_normal,
      title: 'Search a specific place',
      body: 'Tap the search icon to look up an area, locality or landmark and see stays around it.',
    ),
    TourStep(
      key: TourKeys.staysLandingLocation,
      icon: Iconsax.location,
      title: 'Switch your city',
      body: 'Tap to change your district or city — the list below follows it, shared across Rooms, Plots and Stays.',
    ),
    if (Get.find<AuthController>().canListStays.value)
      TourStep(
        key: TourKeys.staysLandingTiles,
        icon: Icons.grid_view_rounded,
        title: 'Quick actions',
        body: 'Add your stay, manage it or open the map — all from this row.',
      ),
    TourStep(
      key: TourKeys.staysLandingFilters,
      icon: Iconsax.filter,
      title: 'Narrow it down',
      body: 'Filter by meals right from here to find exactly what you need.',
    ),
    TourStep(
      key: TourKeys.staysLandingSort,
      icon: Icons.tune_rounded,
      title: 'Filter & Sort',
      body: 'Sort by newest or price per night, and refine results further.',
    ),
    TourStep(
      key: TourKeys.staysLandingList,
      icon: Icons.view_agenda_rounded,
      title: 'Stays near you',
      body: 'Scroll to keep browsing — more stays load automatically. Tap any card for full details.',
    ),
    TourStep(
      key: TourKeys.staysLandingMapPill,
      icon: Icons.map_rounded,
      title: 'Prefer a map?',
      body: 'Switch to the map to see every stay pinned around you.',
    ),
  ];
}
