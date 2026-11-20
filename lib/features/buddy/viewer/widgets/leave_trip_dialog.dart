import 'package:flutter/widgets.dart';

import '../../shared/buddy_look.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_confirm_box.dart';
import '../viewer_strings.dart';

abstract final class LeaveTripDialog {
  static Future<bool> ask(BuildContext context) => BuddyConfirmBox.ask(
        context,
        art: BuddyArt.luggage,
        title: ViewerStrings.leaveTitle,
        body: ViewerStrings.leaveBody,
        cancelLabel: BuddySharedStrings.cancel,
        confirmLabel: ViewerStrings.leave,
        confirmKind: ConfirmKind.danger,
      );
}
