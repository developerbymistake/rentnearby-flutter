import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../utils/dio_error_mapper.dart';
import '../../buddy/buddy_navigation.dart';
import '../../buddy/shared/buddy_json.dart';
import '../../buddy/shared/buddy_look.dart';
import '../../buddy/shared/buddy_result.dart';
import '../../buddy/shared/strings_shared.dart';
import '../../buddy/shared/widgets/buddy_confirm_box.dart';
import 'social_error_types.dart';
import 'social_strings.dart';

/// Why a trip cannot be deleted right now: other travellers are still on it.
sealed class PostRemovalBlock {
  const PostRemovalBlock();

  /// The calm line shown under the disabled menu item and in the notice.
  String get line;

  static PostRemovalBlock? fromRefusal(String? type, Map<String, dynamic> data) => switch (type) {
        SocialErrorTypes.removeMembersFirst => MembersFirstBlock(BuddyJson.integer(data['count'])),
        _ => null,
      };

  static PostRemovalBlock? fromResult(BuddyResult<Object?> r) => r is BuddyRefused<Object?> ? fromRefusal(r.type, r.data) : null;

  static PostRemovalBlock? fromError(Object e) => fromRefusal(DioErrorMapper.errorType(e), DioErrorMapper.errorData(e));
}

class MembersFirstBlock extends PostRemovalBlock {
  const MembersFirstBlock(this.count);

  final int count;

  @override
  String get line => SocialStrings.removeMembersFirstLine(count);
}

/// Pure rules the menus use before any tap. The server stays the judge: a missing field never blocks.
abstract final class PostRemovalRule {
  /// Delete: any trip (normal, posted or ended) waits until its other travellers are removed or have left.
  static PostRemovalBlock? forDelete({required int otherMembers}) {
    if (otherMembers <= 0) return null;
    return MembersFirstBlock(otherMembers);
  }
}

abstract final class PostRemovalNotice {
  @visibleForTesting
  static Future<void> Function(String tripId)? debugOpenTravellers;

  static Future<void> show(BuildContext? context, String tripId, PostRemovalBlock block) async {
    final ctx = (context != null && context.mounted) ? context : (Get.overlayContext ?? Get.context);
    if (ctx == null || !ctx.mounted) return;
    switch (block) {
      case MembersFirstBlock():
        final open = await BuddyConfirmBox.ask(
          ctx,
          art: BuddyArt.luggage,
          title: SocialStrings.removeMembersFirstTitle,
          body: '${block.line}.',
          note: SocialStrings.removeMembersFirstNote,
          cancelLabel: BuddySharedStrings.close,
          confirmLabel: SocialStrings.seeTravellers,
        );
        if (!open) return;
        final debug = debugOpenTravellers;
        if (debug != null) {
          await debug(tripId);
        } else {
          await BuddyNavigation.openTravellers(tripId);
        }
    }
  }
}
