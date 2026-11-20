import 'package:flutter/services.dart';

import '../../utils/app_toast.dart';
import 'buddy_strings.dart';

abstract final class UsernameActions {
  static Future<void> copy(String username) async {
    await Clipboard.setData(ClipboardData(text: username));
    AppToast.success(BuddyStrings.copied);
  }
}
