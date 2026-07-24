import 'package:flutter/material.dart';

/// GlobalKey registry for coach-mark tour targets — see tour_registry.dart for
/// which key belongs to which step. Same shape as tab_keys.dart.
class TourKeys {
  TourKeys._();

  // Home
  static final homeToggle = GlobalKey();
  static final homeManageListingsCard = GlobalKey();
  static final homeCoinBalance = GlobalKey();
  static final homeActionMenu = GlobalKey();
  static final homeRoomsNavIcon = GlobalKey();
  static final homePlotsNavIcon = GlobalKey();
  static final homeServicesNavIcon = GlobalKey();
  static final homeProfileNavIcon = GlobalKey();

  // Rooms
  static final roomsLocationPill = GlobalKey();
  static final roomsRadiusChips = GlobalKey();
  static final roomsSearchToggle = GlobalKey();
  static final roomsFilterPanel = GlobalKey();
  static final roomsAddShortcut = GlobalKey();

  // Plots
  static final plotsLocationPill = GlobalKey();
  static final plotsRadiusChips = GlobalKey();
  static final plotsSearchToggle = GlobalKey();
  static final plotsFilterPanel = GlobalKey();
  static final plotsAddShortcut = GlobalKey();

  // Services
  static final servicesInquiriesButton = GlobalKey();

  // One stable GlobalKey per service category, lazily created and cached —
  // the category list is genuinely dynamic (admin-configurable, no fixed
  // count), so these can't be static fields like the ones above. The map
  // itself must persist across rebuilds (it's a static field, never
  // recreated), while individual keys are created once per category id and
  // reused thereafter.
  static final Map<String, GlobalKey> _serviceCategoryKeys = {};
  static GlobalKey serviceCategoryKey(String categoryId) =>
      _serviceCategoryKeys.putIfAbsent(categoryId, () => GlobalKey());
}
