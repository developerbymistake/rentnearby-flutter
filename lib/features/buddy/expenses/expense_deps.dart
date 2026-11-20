import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../utils/app_toast.dart';
import '../buddy_navigation.dart';
import '../shared/strings_shared.dart';
import '../shared/widgets/buddy_snack.dart';
import 'data/expenses_api.dart';

abstract final class ExpenseDeps {
  static ExpensesApi get api => Get.isRegistered<ExpensesApi>() ? Get.find<ExpensesApi>() : const ExpensesApi();

  static Future<dynamic>? Function(String tripId, String expenseId) openExpense = _openExpense;
  static void Function(String tripId) openMyShare = _openMyShare;
  static void Function(String tripId) openSettleUp = _openSettleUp;
  static void Function(String tripId) openSummary = _openSummary;

  static Future<dynamic>? _openExpense(String tripId, String expenseId) => BuddyNavigation.openExpense(tripId, expenseId);
  static void _openMyShare(String tripId) => BuddyNavigation.openMyShare(tripId, replace: true);
  static void _openSettleUp(String tripId) => BuddyNavigation.openSettleUp(tripId);
  static void _openSummary(String tripId) => BuddyNavigation.openMoneySummary(tripId);

  static void snack(BuildContext? context, String text) {
    final ctx = context ?? Get.overlayContext ?? Get.context;
    if (ctx == null) return;
    BuddySnack.show(ctx, text);
  }

  static void toast(String text) => AppToast.error(text);

  static void offline() => AppToast.error(BuddySharedStrings.needOnline);

  static void debugReset() {
    openExpense = _openExpense;
    openMyShare = _openMyShare;
    openSettleUp = _openSettleUp;
    openSummary = _openSummary;
  }
}
