import '../../../utils/app_toast.dart';
import '../buddy_error_types.dart';
import '../shared/buddy_result.dart';
import '../shared/strings_shared.dart';
import 'buddies_strings.dart';

typedef BuddyNoteSink = void Function(String text, {bool danger});

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

  static String? acceptLine(String? type) => switch (type) {
        BuddyErrorTypes.buddyLimit => BuddiesStrings.buddyLimit,
        BuddyErrorTypes.cannotAddNow => BuddiesStrings.cannotAddNow,
        _ => null,
      };
}
