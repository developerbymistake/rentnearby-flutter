import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../../shared/models/person_models.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_sheet.dart';
import '../../shared/widgets/menu_row.dart';
import '../buddies_strings.dart';

enum BuddyMenuAction { invite, remove, block, report }

class BuddyMenuSheet extends StatelessWidget {
  const BuddyMenuSheet({super.key, required this.person});

  final BuddyPerson person;

  static Future<BuddyMenuAction?> show(BuildContext context, BuddyPerson person) => BuddySheet.show<BuddyMenuAction>(
        context,
        avatar: BuddyAvatar(initial: person.initial, seed: person.userId, size: BuddyAvatarSize.lg, ring: true, photoUrl: person.photoUrl),
        title: person.name,
        subtitle: person.username,
        builder: (c) => BuddyMenuSheet(person: person),
      );

  @override
  Widget build(BuildContext context) {
    void pick(BuddyMenuAction a) => Navigator.of(context).pop(a);
    final rows = [
      MenuRow(art: BuddyArt.luggage, title: BuddiesStrings.inviteToTrip, subtitle: BuddiesStrings.pickTrip, onTap: () => pick(BuddyMenuAction.invite)),
      MenuRow(art: BuddyArt.panda, title: BuddiesStrings.removeBuddy, subtitle: BuddiesStrings.tripsStay, grey: true, onTap: () => pick(BuddyMenuAction.remove)),
      MenuRow(art: BuddyArt.shield, title: BuddiesStrings.block, danger: true, onTap: () => pick(BuddyMenuAction.block)),
      MenuRow(art: BuddyArt.warning, title: BuddiesStrings.report, danger: true, onTap: () => pick(BuddyMenuAction.report)),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: DS.s(1), thickness: DS.s(1), color: BuddyLook.hairline),
          rows[i],
        ],
      ],
    );
  }
}
