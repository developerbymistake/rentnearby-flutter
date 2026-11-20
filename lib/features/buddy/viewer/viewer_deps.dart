import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../utils/app_toast.dart';
import '../buddy_navigation.dart';
import '../expenses/data/expenses_api.dart';
import '../ledger/data/ledger_api.dart';
import '../shared/buddy_result.dart';
import '../shared/strings_shared.dart';
import '../shared/widgets/buddy_snack.dart';
import '../sharing/data/trip_members_api.dart';
import 'data/trip_viewer_api.dart';

abstract final class ViewerDeps {
  static TripViewerApi get viewer => Get.isRegistered<TripViewerApi>() ? Get.find<TripViewerApi>() : const TripViewerApi();

  static TripMembersApi get members => Get.isRegistered<TripMembersApi>() ? Get.find<TripMembersApi>() : const TripMembersApi();

  static LedgerApi get ledger => Get.isRegistered<LedgerApi>() ? Get.find<LedgerApi>() : const LedgerApi();

  static ExpensesApi get expenses => Get.isRegistered<ExpensesApi>() ? Get.find<ExpensesApi>() : const ExpensesApi();

  static void Function() toMyTrips = BuddyNavigation.backToMyTrips;

  static BuildContext? _insideOverlay() {
    BuildContext? found;
    void visit(Element e, int depth) {
      if (found != null || depth > 8) return;
      if (Overlay.maybeOf(e, rootOverlay: true) != null) {
        found = e;
        return;
      }
      e.visitChildElements((c) => visit(c, depth + 1));
    }

    final root = Get.key.currentState?.overlay?.context;
    if (root is Element) visit(root, 0);
    return found;
  }

  static void snack(String text, {String? actionLabel, VoidCallback? onAction}) {
    final ctx = _insideOverlay();
    if (ctx == null) return;
    BuddySnack.show(ctx, text, actionLabel: actionLabel, onAction: onAction);
  }

  static void toastError(BuddyResult<Object?> r) {
    switch (r) {
      case BuddyOffline():
        AppToast.error(BuddySharedStrings.needOnline);
      case BuddyRefused(:final rateLimited, :final message):
        AppToast.error(rateLimited ? BuddySharedStrings.tooManyTries : (message ?? BuddySharedStrings.somethingWrong));
      case BuddyFailed():
        AppToast.error(BuddySharedStrings.somethingWrong);
      case BuddyOk():
        break;
    }
  }

  static void debugReset() => toMyTrips = BuddyNavigation.backToMyTrips;
}
