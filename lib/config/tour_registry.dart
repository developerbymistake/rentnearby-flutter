import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../controllers/service_catalog_controller.dart';
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
  /// for the 3 static tours (a trivial closure over a fixed list — not
  /// const, since each TourStep's key is a non-const GlobalKey), and the
  /// only way Services' step count can ever reflect the live category
  /// catalog (see _buildServicesSteps below).
  List<TourStep> get steps => stepsBuilder();
}

/// Built as a function (like _buildServicesSteps below), even though this
/// list is currently fixed, for consistency with the other per-tab builders
/// and so a future Home step can freely depend on live state again without
/// having to change the TourDefinition's shape.
List<TourStep> _buildHomeSteps() {
  return [
    TourStep(
      key: TourKeys.homeToggle,
      icon: Iconsax.arrow_swap_horizontal,
      title: 'Rooms & Plots are separate',
      body: 'Switch between the two anytime — each has its own listings, pricing and posting limit.',
    ),
    TourStep(
      key: TourKeys.homeManageListingsCard,
      icon: Iconsax.building,
      title: 'List your own place',
      body: 'Got a room or plot to rent out? List it here and reach genuine tenants in minutes.',
    ),
    TourStep(
      key: TourKeys.homeQuickActionAdd,
      icon: Icons.add_rounded,
      title: 'Post in one tap',
      body: "Quickly add a new room or plot listing — this always matches whichever tab you're on.",
    ),
    TourStep(
      key: TourKeys.homeQuickActionFind,
      icon: Icons.search_rounded,
      title: 'Jump to search',
      body: 'Straight to the Rooms or Plots map, whichever matches this toggle.',
    ),
    TourStep(
      key: TourKeys.homeQuickActionLeads,
      icon: Icons.bar_chart_rounded,
      title: 'Views & Leads',
      body: 'See how many people viewed and enquired about your listings — coming soon.',
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
      body: 'Tap here anytime to search rooms nearby.',
    ),
    TourStep(
      key: TourKeys.homePlotsNavIcon,
      icon: Icons.landscape_rounded,
      title: 'Looking for a plot?',
      body: 'Tap here anytime to search plots nearby.',
    ),
    TourStep(
      key: TourKeys.homeServicesNavIcon,
      icon: Iconsax.briefcase,
      title: 'Trip plans, wellness & more',
      body: 'From trip planning to diet & wellness — submit a request and the right person reaches out to you.',
    ),
    TourStep(
      key: TourKeys.homeProfileNavIcon,
      icon: Iconsax.user,
      title: 'Your account lives here',
      body: 'Manage your profile, listings, wallet and settings from here.',
    ),
  ];
}

List<TourStep> _buildServicesSteps() {
  final categories = Get.find<ServiceCatalogController>().activeCategories;
  return [
    TourStep(
      key: TourKeys.servicesEnquiriesButton,
      icon: Iconsax.clipboard_text,
      title: 'Track your requests here',
      body: "Every enquiry you've submitted — and its status — lives in Enquiries, with a live count.",
    ),
    if (categories.isNotEmpty)
      TourStep(
        key: TourKeys.serviceCategoryKey(categories.first.id),
        icon: Iconsax.call,
        title: categories.first.name,
        body: "Tap to talk to a local expert about ${categories.first.name} — submit a request and they'll reach out to you.",
      ),
  ];
}

/// Single source of truth for all 4 tours — one map entry per tab. Adding a
/// 5th tour later means adding one more entry here, nowhere else.
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
    stepsBuilder: () => [
      TourStep(
        key: TourKeys.roomsLocationPill,
        icon: Iconsax.location,
        title: 'This is your area',
        body: 'Tap to manually switch your district or city — pick from a list, sets where you browse from.',
      ),
      TourStep(
        key: TourKeys.roomsRadiusChips,
        icon: Iconsax.radar,
        title: 'Search by radius',
        body: 'Pick 1, 6 or 12 km — the map redraws instantly around your location. Starting a place search temporarily widens this to 12 km.',
      ),
      TourStep(
        key: TourKeys.roomsSearchToggle,
        icon: Iconsax.search_normal,
        title: 'Or search a specific place',
        body: 'Type an area, locality or landmark to jump straight there — input-based, different from the area picker above.',
      ),
      // Order below is the actual on-screen top-to-bottom sweep: header (location/radius/
      // search above) -> ViewList+FAB row (right under the header) -> the Find Nearest/Add
      // button pair -> filter panel (screen bottom). ViewList/FAB moved up here from after
      // AddShortcut/FilterPanel to match where they actually render post-redesign — visiting
      // them last used to jump the spotlight back up to the top of the screen.
      TourStep(
        key: TourKeys.roomsViewListButton,
        icon: Icons.format_list_bulleted_rounded,
        title: 'Prefer a list?',
        body: 'Switch to a scrollable list of everything currently pinned on the map.',
      ),
      TourStep(
        key: TourKeys.roomsLocationFab,
        icon: Icons.my_location_rounded,
        title: 'Lost your spot?',
        body: 'Tap to snap the map back to your current GPS location.',
      ),
      TourStep(
        key: TourKeys.roomsFindNearest,
        icon: Icons.travel_explore_rounded,
        title: 'Nothing in this radius?',
        body: 'Find Nearest instantly shows the closest listings anyway, even outside your selected radius.',
      ),
      TourStep(
        key: TourKeys.roomsAddShortcut,
        icon: Iconsax.add_circle,
        title: 'List your own room',
        body: 'Tap here to manage and post your rooms — one more tap from there starts a new listing.',
      ),
      TourStep(
        key: TourKeys.roomsFilterPanel,
        icon: Iconsax.filter,
        title: 'Narrow it down',
        body: 'Filter by room type — 1BHK, PG, Shop and more — right from here.',
      ),
    ],
  ),
  AppTabs.plots: TourDefinition(
    tabIndex: AppTabs.plots,
    storageKey: AppConstants.tourPlotsSeenKey,
    label: 'Plots Tour',
    stepsBuilder: () => [
      TourStep(
        key: TourKeys.plotsLocationPill,
        icon: Iconsax.location,
        title: 'This is your area',
        body: 'Tap to manually switch your district or city — same picker as Rooms, shared across both tabs.',
      ),
      TourStep(
        key: TourKeys.plotsRadiusChips,
        icon: Iconsax.radar,
        title: 'Search plots by radius',
        body: 'Same idea as Rooms, but scoped only to Plots — its own map, own results.',
      ),
      TourStep(
        key: TourKeys.plotsSearchToggle,
        icon: Iconsax.search_normal,
        title: 'Or search a specific place',
        body: 'Type an area, locality or landmark to jump straight there — input-based, unlike the picker above.',
      ),
      // See the matching comment in the Rooms tour above — same reorder reasoning.
      TourStep(
        key: TourKeys.plotsViewListButton,
        icon: Icons.format_list_bulleted_rounded,
        title: 'Prefer a list?',
        body: 'Switch to a scrollable list of everything currently pinned on the map.',
      ),
      TourStep(
        key: TourKeys.plotsLocationFab,
        icon: Icons.my_location_rounded,
        title: 'Lost your spot?',
        body: 'Tap to snap the map back to your current GPS location.',
      ),
      TourStep(
        key: TourKeys.plotsFindNearest,
        icon: Icons.travel_explore_rounded,
        title: 'Nothing in this radius?',
        body: 'Find Nearest instantly shows the closest listings anyway, even outside your selected radius.',
      ),
      TourStep(
        key: TourKeys.plotsAddShortcut,
        icon: Iconsax.add_circle,
        title: 'List your own plot',
        body: 'Post a plot for rent or sale directly from here, right from this map.',
      ),
      TourStep(
        key: TourKeys.plotsFilterPanel,
        icon: Iconsax.filter,
        title: 'Narrow it down',
        body: 'Filter by plot type right from here to find exactly what you need.',
      ),
    ],
  ),
  AppTabs.services: TourDefinition(
    tabIndex: AppTabs.services,
    storageKey: AppConstants.tourServicesSeenKey,
    label: 'Services Tour',
    stepsBuilder: _buildServicesSteps,
  ),
};
