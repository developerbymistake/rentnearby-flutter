import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_sheet.dart';
import '../../shared/widgets/menu_row.dart';
import '../models/sharing_models.dart';
import '../sharing_strings.dart';

enum TravellerAction { remove }

abstract final class TravellerMenu {
  static Future<TravellerAction?> show(BuildContext context, JoinedMember member) => BuddySheet.show<TravellerAction>(
        context,
        avatar: BuddyAvatar(initial: member.initial, seed: member.userId, size: BuddyAvatarSize.lg),
        title: member.name,
        subtitle: member.username,
        builder: (c) => Padding(
          padding: DS.insets(b: 8),
          child: MenuRow(
            key: const ValueKey('traveller_menu_remove'),
            art: BuddyArt.warning,
            title: SharingStrings.removeFromTrip,
            danger: true,
            onTap: () => Navigator.of(c).pop(TravellerAction.remove),
          ),
        ),
      );
}
