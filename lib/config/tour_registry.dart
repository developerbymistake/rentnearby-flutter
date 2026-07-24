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

/// Services' category catalog (ServiceCatalogController.activeCategories) is
/// genuinely dynamic — admin-configurable, no fixed app-compile-time count
/// (see CLAUDE.md: "an admin-added category needs no app release"). So its
/// tour can't be a fixed step list like the other 3 — this builds one step
/// per currently-active category, plus the static Inquiries step, evaluated
/// fresh each time TourController reads TourDefinition.steps.
///
/// Accepted edge case: if the live category list changes between one
/// TourController retry attempt and a later one (spanning a real delay),
/// the tour could end a step early or show a briefly-stale step count —
/// never a crash or stuck spotlight, since every index TourController uses
/// is validated against a freshly-read length in the same synchronous
/// statement that uses it. Requires an admin catalog edit landing in the
/// same ~1s window as one specific user's step transition — rare enough not
/// to warrant a second frozen-snapshot source of truth.
List<TourStep> _buildServicesSteps() {
  final categories = Get.find<ServiceCatalogController>().activeCategories;
  return [
    TourStep(
      key: TourKeys.servicesInquiriesButton,
      icon: Iconsax.clipboard_text,
      title: 'Track your requests here',
      body: "Every enquiry you've submitted — and its status — lives in Inquiries, with a live count.",
    ),
    for (final category in categories)
      TourStep(
        key: TourKeys.serviceCategoryKey(category.id),
        icon: Iconsax.call,
        title: category.name,
        body: "Tap to talk to a local expert about ${category.name} — submit a request and they'll reach out to you.",
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
    stepsBuilder: () => [
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
        body: "Got a room or plot to rent out? Manage everything you've listed right here.",
      ),
      TourStep(
        key: TourKeys.homeCoinBalance,
        icon: Iconsax.coin,
        title: 'This is your coin balance',
        body: 'Coins are how you make a listing go live. Tap here anytime to top up.',
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
    ],
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
        body: 'Pick 1, 5 or 10 km — the map redraws instantly around your location.',
      ),
      TourStep(
        key: TourKeys.roomsSearchToggle,
        icon: Iconsax.search_normal,
        title: 'Or search a specific place',
        body: 'Type an area, locality or landmark to jump straight there — input-based, different from the area picker above.',
      ),
      TourStep(
        key: TourKeys.roomsFilterPanel,
        icon: Iconsax.filter,
        title: 'Narrow it down',
        body: 'Filter by room type — 1BHK, PG, Shop and more — right from here.',
      ),
      TourStep(
        key: TourKeys.roomsAddShortcut,
        icon: Iconsax.add_circle,
        title: 'List your own room',
        body: 'Tap here anytime to post a room for rent, right from this map.',
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
      TourStep(
        key: TourKeys.plotsFilterPanel,
        icon: Iconsax.filter,
        title: 'Narrow it down',
        body: 'Filter by plot type right from here to find exactly what you need.',
      ),
      TourStep(
        key: TourKeys.plotsAddShortcut,
        icon: Iconsax.add_circle,
        title: 'List your own plot',
        body: 'Post a plot for sale or rent directly from here, priced by area.',
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
