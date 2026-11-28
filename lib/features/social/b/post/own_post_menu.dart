import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/buddy_navigation.dart';
import '../../../buddy/sharing/widgets/trip_delete_flow.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_sheet.dart';
import '../../../buddy/shared/widgets/menu_row.dart';
import '../../shared/post_removal.dart';
import '../../shared/social_live.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../social_strings_b.dart';

abstract final class OwnPostMenu {
  static const Key editKey = ValueKey('own_post_edit');
  static const Key membersKey = ValueKey('own_post_members');
  static const Key deleteKey = ValueKey('own_post_delete');

  @visibleForTesting
  static Future<bool> Function(BuildContext context, String tripId)? debugDelete;

  static const int _edit = 0;
  static const int _members = 1;
  static const int _delete = 2;

  static Future<void> show(BuildContext context, {required PublicTrip trip, VoidCallback? onChanged, VoidCallback? onDeleted}) async {
    final block = PostRemovalRule.forDelete(otherMembers: trip.members ?? 0);
    Widget line() => Divider(height: DS.s(1), thickness: DS.s(1), color: BuddyLook.hairline);
    final picked = await BuddySheet.show<int>(
      context,
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuRow(
            key: editKey,
            art: ListingArt.memo,
            title: SocialStringsB.editPost,
            subtitle: SocialStringsB.editPostLine,
            onTap: () => Navigator.of(c).pop(_edit),
          ),
          line(),
          MenuRow(
            key: membersKey,
            art: ListingArt.panda,
            title: SocialStringsB.membersN(trip.members ?? 0),
            subtitle: SocialStringsB.membersLine,
            onTap: () => Navigator.of(c).pop(_members),
          ),
          line(),
          MenuRow(
            key: deleteKey,
            art: BuddyArt.warning,
            title: SocialStringsB.deleteTrip,
            subtitle: block == null ? null : SocialStringsB.deleteTripBlocked,
            danger: true,
            onTap: () => Navigator.of(c).pop(_delete),
          ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    switch (picked) {
      case _edit:
        await SocialNav.openEditPost(trip.tripId);
        onChanged?.call();
      case _members:
        await BuddyNavigation.openTravellers(trip.tripId);
        SocialLive.posts.value++;
        onChanged?.call();
      case _delete:
        if (block != null) {
          await PostRemovalNotice.show(context, trip.tripId, block);
          SocialLive.posts.value++;
          onChanged?.call();
          return;
        }
        final ok = await (debugDelete ?? TripDeleteFlow.startById)(context, trip.tripId);
        if (!ok) return;
        onDeleted?.call();
        SocialLive.posts.value++;
    }
  }
}
