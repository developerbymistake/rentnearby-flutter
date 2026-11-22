import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../../shared/models/person_models.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_sheet.dart';
import '../../shared/widgets/menu_row.dart';
import '../buddies_strings.dart';

enum PersonMenuAction { block, report }

class PersonMenuSheet extends StatelessWidget {
  const PersonMenuSheet({super.key, required this.person});

  final BuddyPerson person;

  static Future<PersonMenuAction?> show(BuildContext context, BuddyPerson person) => BuddySheet.show<PersonMenuAction>(
        context,
        avatar: BuddyAvatar(initial: person.initial, seed: person.userId, size: BuddyAvatarSize.lg, ring: true, photoUrl: person.photoUrl),
        title: person.name,
        subtitle: person.username,
        builder: (c) => PersonMenuSheet(person: person),
      );

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuRow(
            art: BuddyArt.shield,
            title: BuddiesStrings.blockName(person.name),
            subtitle: BuddiesStrings.notTold,
            danger: true,
            onTap: () => Navigator.of(context).pop(PersonMenuAction.block),
          ),
          Divider(height: DS.s(1), thickness: DS.s(1), color: BuddyLook.hairline),
          MenuRow(
            art: BuddyArt.warning,
            title: BuddiesStrings.report,
            subtitle: BuddiesStrings.reportLine,
            danger: true,
            onTap: () => Navigator.of(context).pop(PersonMenuAction.report),
          ),
        ],
      );
}
