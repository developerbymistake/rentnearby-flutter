import 'package:flutter/material.dart';

/// GlobalKey registry for coach-mark tour targets — see tour_registry.dart for
/// which key belongs to which step. Same shape as tab_keys.dart.
class TourKeys {
  TourKeys._();

  // Home
  static final homeManageListingsCard = GlobalKey();
  static final homeQuickActionAddStay = GlobalKey();
  static final homeQuickActionAddTaxi = GlobalKey();
  static final homeQuickActionLeads = GlobalKey();
  static final homeInstagramCard = GlobalKey();
  static final homeActionMenu = GlobalKey();
  static final homeStaysNavIcon = GlobalKey();
  static final homeTaxiNavIcon = GlobalKey();
  static final homeProfileNavIcon = GlobalKey();

  // Stays landing
  static final staysLandingLocation = GlobalKey();
  static final staysLandingSearch = GlobalKey();
  static final staysLandingTiles = GlobalKey();
  static final staysLandingFilters = GlobalKey();
  static final staysLandingSort = GlobalKey();
  static final staysLandingList = GlobalKey();
  static final staysLandingMapPill = GlobalKey();
}
