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
    if (tabs.isStaysActive) 'stays',
    if (tabs.isTaxiActive) 'taxis',
  ];
}

TourDialogContent _buildHomeOutro() {
  final tabs = TabConfigController.to;
  final names = [
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
  final canStays = auth.staysEnabled;
  final canTaxis = auth.taxisEnabled;
  final owner = canStays || canTaxis;
  final browseNames = _activeBrowseNames();
  return [
    TourStep(
      key: TourKeys.homeManageListingsCard,
      icon: Iconsax.building,
      title: owner ? 'List your own place' : 'Find your next place',
      body: owner
          ? (canStays ? 'Tap this card to manage your stay.' : 'Tap this card to manage your taxi.')
          : browseNames.length > 1
              ? 'This card slides between ${_joinNames(browseNames)} — tap it to start browsing.'
              : 'Tap this card to start browsing.',
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
    if (canStays || canTaxis)
      TourStep(
        key: TourKeys.homeQuickActionLeads,
        icon: Icons.bar_chart_rounded,
        title: canStays ? 'My Stays' : 'My Taxi',
        body: canStays ? 'Jump straight to your stay.' : 'Jump straight to your taxi.',
      ),
    TourStep(
      key: TourKeys.homeInstagramCard,
      icon: Iconsax.camera,
      title: 'Stay in the loop',
      body: 'Follow us on Instagram for travel ideas, tips and updates — just one tap away.',
    ),
    TourStep(
      key: TourKeys.homeActionMenu,
      icon: Iconsax.notification_bing,
      title: 'Notifications & Messages',
      body: 'Keep track of updates and chat with owners or seekers, straight from Home.',
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
          ? 'Manage your profile, plan and settings from here.'
          : 'Manage your profile and settings from here.',
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
  AppTabs.stays: TourDefinition(
    tabIndex: AppTabs.stays,
    storageKey: AppConstants.tourStaysSeenKey,
    label: 'Stays Tour',
    stepsBuilder: buildStayLandingSteps,
  ),
};
