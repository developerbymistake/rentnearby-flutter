import 'package:flutter/material.dart';

/// GlobalKey registry for coach-mark tour targets — see tour_registry.dart for
/// which key belongs to which step. Same shape as tab_keys.dart.
class TourKeys {
  TourKeys._();

  // Home
  static final homeManageListingsCard = GlobalKey();
  static final homeQuickActionAddRoom = GlobalKey();
  static final homeQuickActionAddPlot = GlobalKey();
  static final homeQuickActionLeads = GlobalKey();
  static final homeInstagramCard = GlobalKey();
  static final homeActionMenu = GlobalKey();
  static final homeRoomsNavIcon = GlobalKey();
  static final homePlotsNavIcon = GlobalKey();
  static final homeProfileNavIcon = GlobalKey();

  // Rooms landing
  static final roomsLandingLocation = GlobalKey();
  static final roomsLandingSearch = GlobalKey();
  static final roomsLandingTiles = GlobalKey();
  static final roomsLandingFilters = GlobalKey();
  static final roomsLandingSort = GlobalKey();
  static final roomsLandingList = GlobalKey();
  static final roomsLandingMapPill = GlobalKey();

  // Plots landing
  static final plotsLandingLocation = GlobalKey();
  static final plotsLandingSearch = GlobalKey();
  static final plotsLandingTiles = GlobalKey();
  static final plotsLandingFilters = GlobalKey();
  static final plotsLandingSort = GlobalKey();
  static final plotsLandingList = GlobalKey();
  static final plotsLandingMapPill = GlobalKey();

  // Rooms map
  static final roomsLocationPill = GlobalKey();
  static final roomsRadiusChips = GlobalKey();
  static final roomsSearchToggle = GlobalKey();
  static final roomsFilterPanel = GlobalKey();
  static final roomsFindNearest = GlobalKey();
  static final roomsViewListButton = GlobalKey();
  static final roomsLocationFab = GlobalKey();

  // Plots map
  static final plotsLocationPill = GlobalKey();
  static final plotsRadiusChips = GlobalKey();
  static final plotsSearchToggle = GlobalKey();
  static final plotsFilterPanel = GlobalKey();
  static final plotsFindNearest = GlobalKey();
  static final plotsViewListButton = GlobalKey();
  static final plotsLocationFab = GlobalKey();
}
