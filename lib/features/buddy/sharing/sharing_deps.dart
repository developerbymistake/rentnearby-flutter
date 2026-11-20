import 'package:get/get.dart';

import '../../../utils/app_toast.dart';
import '../buddies/data/buddies_api.dart';
import '../ledger/data/ledger_api.dart';
import '../shared/buddy_result.dart';
import '../shared/strings_shared.dart';
import 'data/trip_members_api.dart';

abstract final class SharingDeps {
  static TripMembersApi get members => Get.isRegistered<TripMembersApi>() ? Get.find<TripMembersApi>() : const TripMembersApi();

  static BuddiesApi get buddies => Get.isRegistered<BuddiesApi>() ? Get.find<BuddiesApi>() : const BuddiesApi();

  static LedgerApi get ledger => Get.isRegistered<LedgerApi>() ? Get.find<LedgerApi>() : const LedgerApi();

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
}
