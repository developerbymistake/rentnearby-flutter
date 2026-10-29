import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../controllers/auth_controller.dart';
import '../controllers/tab_config_controller.dart';
import '../features/stay/guest/stay_tour_steps.dart';
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
  final TourDialogContent Function()? outroBuilder;

  const TourDefinition({
    required this.tabIndex,
    required this.storageKey,
    required this.label,
    required this.stepsBuilder,
    this.introContent,
    this.outroBuilder,
  });

  TourDialogContent? get outroContent => outroBuilder?.call();

  /// Re-invokes [stepsBuilder] on every access rather than caching — cheap
  /// for the static tours (a trivial closure over a fixed list — not
  /// const, since each TourStep's key is a non-const GlobalKey).
  List<TourStep> get steps => stepsBuilder();
}

/// Built as a function so a future Home step can freely depend on live state
/// without having to change the TourDefinition's shape.
String _joinNames(List<String> names) => names.length <= 1
    ? names.join()
    : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';

List<String> _activeBrowseNames() {
  final tabs = TabConfigController.to;
  return [
    if (tabs.isRoomsActive) 'rooms',
    if (tabs.isPlotsActive) 'plots',
    if (tabs.isStaysActive) 'stays',
    if (tabs.isTaxiActive) 'taxis',
  ];
}

TourDialogContent _buildHomeOutro() {
  final tabs = TabConfigController.to;
  final names = [
    if (tabs.isRoomsActive) tabs.displayNameForIndex(AppTabs.rooms, 'Rooms'),
    if (tabs.isPlotsActive) tabs.displayNameForIndex(AppTabs.plots, 'Plots'),
    if (tabs.isStaysActive) tabs.displayNameForIndex(AppTabs.stays, 'Stays'),
  ];
  final body = switch (names.length) {
    0 => 'Everything you need starts right here on Home.',
    1 => '${names.first} shows you its own quick tour the first time you open it.',
    _ => '${_joinNames(names)} each show you their own quick tour the first time you open them — '
        'try tapping ${names.first} below to see yours.',
  };
  return TourDialogContent(
    phase: TourDialogPhase.outro,
    title: "You're all set on Home! 🎉",
    body: body,
    primaryLabel: 'Start Exploring',
  );
}

List<TourStep> _buildHomeSteps() {
  final auth = Get.find<AuthController>();
  final canRooms = auth.roomsEnabled;
  final canPlots = auth.plotsEnabled;
  final canStays = auth.staysEnabled;
  final canTaxis = auth.taxisEnabled;
  final owner = canRooms || canPlots || canStays || canTaxis;
  final browseNames = _activeBrowseNames();
  return [
    TourStep(
      key: TourKeys.homeManageListingsCard,
      icon: Iconsax.building,
      title: owner ? 'List your own place' : 'Find your next place',
      body: owner
          ? (canRooms
              ? 'Got a room to rent out? Tap this card to list yours and reach genuine tenants in minutes.'
              : canPlots
                  ? 'Got a plot to sell? Tap this card to list yours and reach genuine buyers in minutes.'
                  : canStays
                      ? 'Tap this card to manage your stay.'
                      : 'Tap this card to manage your taxi.')
          : browseNames.length > 1
              ? 'This card slides between ${_joinNames(browseNames)} — tap it to start browsing.'
              : 'Tap this card to start browsing.',
    ),
    if (canRooms)
      TourStep(
        key: TourKeys.homeQuickActionAddRoom,
        icon: Icons.add_rounded,
        title: 'Add a room',
        body: 'Post a new room listing in one tap.',
      ),
    if (canPlots)
      TourStep(
        key: TourKeys.homeQuickActionAddPlot,
        icon: Icons.add_location_alt_rounded,
        title: 'Add a plot',
        body: 'Post a new plot listing in one tap.',
      ),
    if (canStays)
      TourStep(
        key: TourKeys.homeQuickActionAddStay,
        icon: Icons.add_rounded,
        title: 'Add your stay',
        body: 'Set up or finish your stay in one tap.',
      ),
    if (canTaxis)
      TourStep(
        key: TourKeys.homeQuickActionAddTaxi,
        icon: Icons.add_rounded,
        title: 'Add your taxi',
        body: 'Set up or finish your taxi in one tap.',
      ),
    if (canRooms || canPlots || canStays || canTaxis)
      TourStep(
        key: TourKeys.homeQuickActionLeads,
        icon: Icons.bar_chart_rounded,
        title: canStays ? 'My Stays' : 'My Listings',
        body: canRooms
            ? 'Jump straight to the rooms you have posted.'
            : canPlots
                ? 'Jump straight to the plots you have posted.'
                : canStays
                    ? 'Jump straight to your stay.'
                    : 'Jump straight to your taxi.',
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
      key: TourKeys.homeStaysNavIcon,
      icon: Iconsax.building_4,
      title: 'Looking for a stay?',
      body: 'Tap here anytime to browse stays near you.',
    ),
    TourStep(
      key: TourKeys.homeTaxiNavIcon,
      icon: Iconsax.car,
      title: 'Need a taxi?',
      body: 'Find local taxis or search city to city.',
    ),
    TourStep(
      key: TourKeys.homeProfileNavIcon,
      icon: Iconsax.user,
      title: 'Your account lives here',
      body: owner
          ? 'Manage your profile, listings, plan and settings from here.'
          : 'Manage your profile and settings from here.',
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
      body: 'Tap to change your district or city — the list below follows it.',
    ),
    if (rooms
        ? Get.find<AuthController>().roomsEnabled
        : Get.find<AuthController>().plotsEnabled)
      TourStep(
        key: rooms ? TourKeys.roomsLandingTiles : TourKeys.plotsLandingTiles,
        icon: Icons.grid_view_rounded,
        title: 'Quick actions',
        body: 'Add your own $noun, manage yours or open the map — all from this row.',
      ),
    TourStep(
      key: rooms ? TourKeys.roomsLandingFilters : TourKeys.plotsLandingFilters,
      icon: Iconsax.filter,
      title: 'Narrow it down',
      body: rooms
          ? 'Filter by room type — 1BHK, PG, House and more — right from here.'
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
    outroBuilder: _buildHomeOutro,
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
  AppTabs.stays: TourDefinition(
    tabIndex: AppTabs.stays,
    storageKey: AppConstants.tourStaysSeenKey,
    label: 'Stays Tour',
    stepsBuilder: buildStayLandingSteps,
  ),
};
