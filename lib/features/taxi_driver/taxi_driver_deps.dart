import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../../config/app_tabs.dart';
import '../../controllers/auth_controller.dart';

abstract final class TaxiDriverDeps {
  static Widget _none() => const SizedBox.shrink();
  static Future<void> _noRefresh() async {}
  static List<DateTime> _noDays(DateTime from, DateTime to) => const [];

  static Widget Function() upcomingCard = _none;
  static Widget Function() planCard = _none;
  static Widget Function() appBookings = _none;
  static void Function(String entryId) openEntry = _openEntry;
  static void Function(String bookingId) openBooking = _openBooking;
  static List<DateTime> Function(DateTime from, DateTime to) manualTripDays = _noDays;
  static void Function() openChooseRoute = _openChooseRoute;
  static void Function({String? section}) openHub = _openHub;
  static Future<void> Function() refreshHome = _noRefresh;

  static void _openEntry(String entryId) => Get.toNamed(AppRoutes.taxiCalendarEntry, arguments: {'id': entryId});

  static void _openBooking(String bookingId) {
    if (Get.isRegistered<AuthController>()) {
      Get.find<AuthController>().openTab(AppTabs.fourth, intent: {'bookingId': bookingId});
    }
  }

  static void _openChooseRoute() => Get.toNamed(AppRoutes.taxiPlanVisible);

  static void _openHub({String? section}) {
    if (Get.isRegistered<AuthController>()) {
      Get.find<AuthController>().openTab(AppTabs.hub, intent: {'section': ?section});
    }
  }

  static void debugReset() {
    upcomingCard = _none;
    planCard = _none;
    appBookings = _none;
    openEntry = _openEntry;
    openBooking = _openBooking;
    manualTripDays = _noDays;
    openChooseRoute = _openChooseRoute;
    openHub = _openHub;
    refreshHome = _noRefresh;
  }
}
