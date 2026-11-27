import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../../config/app_tabs.dart';
import '../../controllers/auth_controller.dart';
import '../owner_core/data/owner_args.dart';

abstract final class StayOwnerDeps {
  static Widget _none() => const SizedBox.shrink();
  static Future<void> _noRefresh() async {}

  static Widget Function() upcomingCard = _none;
  static Widget Function() planCard = _none;
  static Widget Function() quotationsCard = _none;
  static Widget Function() hubCalendarRow = _none;
  static Widget Function() hubSpecialPricesRow = _none;
  static Widget Function() reminderRow = _none;
  static Widget Function() quietWeekBanner = _none;
  static void Function({String? dateFrom, String? dateTo, String? festivalId}) openSpecialPrice = _openSpecialPrice;
  static void Function(String entryId) openEntry = _openEntry;
  static void Function(String enquiryId) openEnquiry = _openEnquiry;
  static void Function() openEditPrices = _openEditPrices;
  static Future<void> Function() refreshHome = _noRefresh;
  static Future<void> Function() refreshCalendar = _noRefresh;
  static void Function() afterStayDeleted = _nothing;

  static void _nothing() {}

  static void _openSpecialPrice({String? dateFrom, String? dateTo, String? festivalId}) =>
      Get.toNamed(AppRoutes.staySpecialPrices, arguments: {'dateFrom': ?dateFrom, 'dateTo': ?dateTo, 'festivalId': ?festivalId});

  static void _openEntry(String entryId) => Get.toNamed(AppRoutes.stayCalendarEntry, arguments: {'id': entryId});

  static void _openEnquiry(String enquiryId) {
    if (Get.isRegistered<AuthController>()) {
      Get.find<AuthController>().openTab(AppTabs.centre, intent: {'enquiryId': enquiryId});
    }
  }

  static void _openEditPrices() => Get.toNamed(AppRoutes.stayRooms, arguments: OwnerArgs.manage);

  static void debugReset() {
    upcomingCard = _none;
    planCard = _none;
    quotationsCard = _none;
    hubCalendarRow = _none;
    hubSpecialPricesRow = _none;
    reminderRow = _none;
    quietWeekBanner = _none;
    openSpecialPrice = _openSpecialPrice;
    openEntry = _openEntry;
    openEnquiry = _openEnquiry;
    openEditPrices = _openEditPrices;
    refreshHome = _noRefresh;
    refreshCalendar = _noRefresh;
    afterStayDeleted = _nothing;
  }
}
