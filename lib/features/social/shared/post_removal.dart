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

/// Why a post cannot be removed right now (72-hour lock, delete-alone rule; CONTRACT_SOCIAL 11.9).
sealed class PostRemovalBlock {
  const PostRemovalBlock();

  /// The calm line shown under the disabled menu item and in the notice.
  String get line;

  static PostRemovalBlock? fromRefusal(String? type, Map<String, dynamic> data) => switch (type) {
        SocialErrorTypes.postLocked => PostLockedBlock(BuddyJson.time(data['unlocksAt'])),
        SocialErrorTypes.removeMembersFirst => MembersFirstBlock(BuddyJson.integer(data['count'])),
        _ => null,
      };

  static PostRemovalBlock? fromResult(BuddyResult<Object?> r) => r is BuddyRefused<Object?> ? fromRefusal(r.type, r.data) : null;

  static PostRemovalBlock? fromError(Object e) => fromRefusal(DioErrorMapper.errorType(e), DioErrorMapper.errorData(e));
}

class PostLockedBlock extends PostRemovalBlock {
  const PostLockedBlock(this.unlocksAt);

  final DateTime? unlocksAt;

  @override
  String get line => SocialStrings.postLockedLine(unlocksAt);
}

class MembersFirstBlock extends PostRemovalBlock {
  const MembersFirstBlock(this.count);

  final int count;

  @override
  String get line => SocialStrings.removeMembersFirstLine(count);
}

/// Pure rules the menus use before any tap. The server stays the judge: a missing field never blocks.
abstract final class PostRemovalRule {
  static DateTime? lockedUntil(DateTime? unlocksAt, {DateTime? now}) {
    if (unlocksAt == null) return null;
    return unlocksAt.toUtc().isAfter((now ?? DateTime.now()).toUtc()) ? unlocksAt : null;
  }

  /// Only the 72-hour lock (Make private, and the lock part of a delete when the member count is unknown).
  static PostRemovalBlock? lockOnly(DateTime? unlocksAt, {DateTime? now}) {
    final until = lockedUntil(unlocksAt, now: now);
    return until == null ? null : PostLockedBlock(until);
  }

  /// Delete: the 72-hour lock first (also for an ended trip: trip dates can be edited), then the other travellers of a posted
  /// trip that has not ended.
  static PostRemovalBlock? forDelete({DateTime? unlocksAt, required bool posted, required int otherMembers, required bool ended, DateTime? now}) {
    final until = lockedUntil(unlocksAt, now: now);
    if (until != null) return PostLockedBlock(until);
    if (ended) return null;
    if ((posted || unlocksAt != null) && otherMembers > 0) return MembersFirstBlock(otherMembers);
    return null;
  }
}

abstract final class PostRemovalNotice {
  @visibleForTesting
  static Future<void> Function(String tripId)? debugOpenTravellers;

  static Future<void> show(BuildContext? context, String tripId, PostRemovalBlock block) async {
    final ctx = (context != null && context.mounted) ? context : (Get.overlayContext ?? Get.context);
    if (ctx == null || !ctx.mounted) return;
    switch (block) {
      case PostLockedBlock():
        await BuddyConfirmBox.info(
          ctx,
          art: BuddyArt.alarm,
          title: SocialStrings.postLockedTitle,
          body: '${block.line}.',
          note: SocialStrings.postLockedEditNote,
        );
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
