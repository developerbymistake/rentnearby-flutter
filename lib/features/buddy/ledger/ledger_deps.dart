import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../utils/app_toast.dart';
import '../buddy_navigation.dart';
import '../shared/strings_shared.dart';
import '../shared/widgets/buddy_snack.dart';
import 'data/ledger_api.dart';

abstract final class LedgerDeps {
  static LedgerApi get api => Get.isRegistered<LedgerApi>() ? Get.find<LedgerApi>() : const LedgerApi();

  static String Function() newOpId = _uuid;
  static void Function(String tripId, {String? tab, int? day}) openExpenses = _openExpenses;
  static void Function(String tripId) openSettleUp = _openSettleUp;
  static void Function(String tripId) openSummary = _openSummary;
  static void Function() openPlanATrip = BuddyNavigation.openPlanATrip;

  static String _uuid() => const Uuid().v4();
  static void _openExpenses(String tripId, {String? tab, int? day}) => BuddyNavigation.openExpenses(tripId, tab: tab, day: day);
  static void _openSettleUp(String tripId) => BuddyNavigation.openSettleUp(tripId);
  static void _openSummary(String tripId) => BuddyNavigation.openMoneySummary(tripId);

  static void snack(BuildContext? context, String text) {
    final ctx = (context != null && context.mounted) ? context : (Get.overlayContext ?? Get.context);
    if (ctx == null) return;
    BuddySnack.show(ctx, text);
  }

  static void toast(String text) => AppToast.error(text);

  static void offline() => AppToast.error(BuddySharedStrings.needOnline);

  static void debugReset() {
    newOpId = _uuid;
    openExpenses = _openExpenses;
    openSettleUp = _openSettleUp;
    openSummary = _openSummary;
    openPlanATrip = BuddyNavigation.openPlanATrip;
  }
}
