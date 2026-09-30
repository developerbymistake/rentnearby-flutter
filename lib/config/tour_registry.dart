import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../navigation/tour_keys.dart';
import 'app_constants.dart';
import 'app_tabs.dart';

class TourStep {
  final GlobalKey key;
  final String title;
  final String body;
  final IconData icon;

  const TourStep({
    required this.key,
    required this.title,
    required this.body,
    required this.icon,
  });
}

enum TourDialogPhase { intro, outro }

class TourDialogContent {
  final TourDialogPhase phase;
  final String title;
  final String body;
  final String primaryLabel;
  final String? secondaryLabel; // null => one button only (outro)

  const TourDialogContent({
    required this.phase,
    required this.title,
    required this.body,
    required this.primaryLabel,
    this.secondaryLabel,
  });
}

class TourDefinition {
  final int tabIndex;
  final String storageKey;
  final String label;
  final List<TourStep> Function() stepsBuilder;
  final TourDialogContent? introContent;
  final TourDialogContent? outroContent;

  const TourDefinition({
    required this.tabIndex,
    required this.storageKey,
    required this.label,
    required this.stepsBuilder,
    this.introContent,
    this.outroContent,
  });

  /// Re-invokes [stepsBuilder] on every access rather than caching — cheap
  /// for the static tours (a trivial closure over a fixed list — not
  /// const, since each TourStep's key is a non-const GlobalKey).
  List<TourStep> get steps => stepsBuilder();
}

/// Built as a function so a future Home step can freely depend on live state
/// without having to change the TourDefinition's shape.
List<TourStep> _buildHomeSteps() {
  return [
    TourStep(
      key: TourKeys.homeManageListingsCard,
      icon: Iconsax.building,
      title: 'List your own place',
      body: 'Got a room or plot to rent out? This card slides between the two — tap it to list yours and reach genuine tenants in minutes.',
    ),
    TourStep(
      key: TourKeys.homeQuickActionAddRoom,
      icon: Icons.add_rounded,
      title: 'Add a room',
      body: 'Post a new room listing in one tap.',
    ),
    TourStep(
      key: TourKeys.homeQuickActionAddPlot,
      icon: Icons.add_location_alt_rounded,
      title: 'Add a plot',
      body: 'Post a new plot listing in one tap.',
    ),
    TourStep(
      key: TourKeys.homeQuickActionLeads,
      icon: Icons.bar_chart_rounded,
      title: 'My Listings',
      body: 'Jump straight to the rooms and plots you have posted.',
    ),
    TourStep(
      key: TourKeys.homeInstagramCard,
      icon: Iconsax.camera,
      title: 'Stay in the loop',
      body: 'Follow us on Instagram for new listings, tips and updates — just one tap away.',
    ),
    TourStep(
      key: TourKeys.homeActionMenu,
      icon: Iconsax.notification_bing,
      title: 'Notifications & Messages',
      body: 'Keep track of updates and chat with owners or seekers, straight from Home.',
    ),
    TourStep(
      key: TourKeys.homeRoomsNavIcon,
      icon: Iconsax.home,
      title: 'Looking for a room?',
      body: 'Tap here anytime to browse rooms near you.',
    ),
    TourStep(
      key: TourKeys.homePlotsNavIcon,
      icon: Icons.landscape_rounded,
      title: 'Looking for a plot?',
      body: 'Tap here anytime to browse plots near you.',
    ),
    TourStep(
      key: TourKeys.homeProfileNavIcon,
      icon: Iconsax.user,
      title: 'Your account lives here',
      body: 'Manage your profile, listings, wallet and settings from here.',
    ),
  ];
}

List<TourStep> _buildLandingSteps({required bool rooms}) {
  final noun = rooms ? 'room' : 'plot';
  final nouns = rooms ? 'rooms' : 'plots';
  return [
    TourStep(
      key: rooms ? TourKeys.roomsLandingSearch : TourKeys.plotsLandingSearch,
      icon: Iconsax.search_normal,
      title: 'Search a specific place',
      body: 'Tap the search icon to look up an area, locality or landmark and see $nouns around it.',
    ),
    TourStep(
      key: rooms ? TourKeys.roomsLandingLocation : TourKeys.plotsLandingLocation,
      icon: Iconsax.location,
      title: 'Switch your city',
      body: 'Tap to change your district or city — the list below follows it, shared across Rooms and Plots.',
    ),
    TourStep(
      key: rooms ? TourKeys.roomsLandingTiles : TourKeys.plotsLandingTiles,
      icon: Icons.grid_view_rounded,
      title: 'Quick actions',
      body: 'Add your own $noun, manage yours, open the map or find the nearest listings — all from this row.',
    ),
    TourStep(
      key: rooms ? TourKeys.roomsLandingFilters : TourKeys.plotsLandingFilters,
      icon: Iconsax.filter,
      title: 'Narrow it down',
      body: rooms
          ? 'Filter by room type — 1BHK, PG, Shop and more — right from here.'
          : 'Filter by plot type right from here to find exactly what you need.',
    ),
    TourStep(
      key: rooms ? TourKeys.roomsLandingSort : TourKeys.plotsLandingSort,
      icon: Icons.tune_rounded,
      title: 'Filter & Sort',
      body: 'Sort by newest or ${rooms ? 'price' : 'area'}, and refine results further.',
    ),
    TourStep(
      key: rooms ? TourKeys.roomsLandingList : TourKeys.plotsLandingList,
      icon: Icons.view_agenda_rounded,
      title: 'Listings near you',
      body: 'Scroll to keep browsing — more $nouns load automatically. Tap any card for full details.',
    ),
    TourStep(
      key: rooms ? TourKeys.roomsLandingMapPill : TourKeys.plotsLandingMapPill,
      icon: Icons.map_rounded,
      title: 'Prefer a map?',
      body: 'Switch to the map to see every $noun pinned around you.',
    ),
  ];
}

/// Single source of truth for all 3 tours — one map entry per tab. Adding a
/// 4th tour later means adding one more entry here, nowhere else.
final Map<int, TourDefinition> tourRegistry = {
  AppTabs.home: TourDefinition(
    tabIndex: AppTabs.home,
    storageKey: AppConstants.tourHomeSeenKey,
    label: 'Home Tour',
    introContent: const TourDialogContent(
      phase: TourDialogPhase.intro,
      title: 'Welcome to Bakhli 👋',
      body: "Let's take a quick 20-second tour so you always know exactly where everything is.",
      primaryLabel: 'Start Tour',
      secondaryLabel: 'Skip for now',
    ),
    outroContent: const TourDialogContent(
      phase: TourDialogPhase.outro,
      title: "You're all set on Home! 🎉",
      body: 'Rooms and Plots each show you their own quick tour the first time you open them — try tapping Rooms below to see yours.',
      primaryLabel: 'Start Exploring',
    ),
    stepsBuilder: _buildHomeSteps,
  ),
  AppTabs.rooms: TourDefinition(
    tabIndex: AppTabs.rooms,
    storageKey: AppConstants.tourRoomsSeenKey,
    label: 'Rooms Tour',
    stepsBuilder: () => _buildLandingSteps(rooms: true),
  ),
  AppTabs.plots: TourDefinition(
    tabIndex: AppTabs.plots,
    storageKey: AppConstants.tourPlotsSeenKey,
    label: 'Plots Tour',
    stepsBuilder: () => _buildLandingSteps(rooms: false),
  ),
};
