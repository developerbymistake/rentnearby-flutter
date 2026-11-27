import '../../../utils/app_toast.dart';
import '../shared/buddy_result.dart';
import '../shared/strings_shared.dart';

abstract final class BuddyFeedback {
  static void writeFailed(BuddyResult<Object?> r) {
    switch (r) {
      case BuddyOffline():
        AppToast.error(BuddySharedStrings.needOnline);
      case BuddyRefused(:final statusCode) when statusCode == 429:
        AppToast.error(BuddySharedStrings.tooManyTries);
      case BuddyRefused(:final message):
        AppToast.error(message ?? BuddySharedStrings.somethingWrong);
      case BuddyFailed():
        AppToast.error(BuddySharedStrings.somethingWrong);
      case BuddyOk():
        break;
    }
  }
}
