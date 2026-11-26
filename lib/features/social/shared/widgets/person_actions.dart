import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/buddies/widgets/block_dialog.dart';
import '../../../buddy/buddies/widgets/report_sheet.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../../buddy/shared/widgets/buddy_sheet.dart';
import '../../../buddy/shared/widgets/menu_row.dart';
import '../social_models.dart';
import '../social_strings.dart';

class PersonMenuItem {
  const PersonMenuItem({required this.art, required this.title, this.subtitle, this.danger = false, required this.onSelected});

  final String art;
  final String title;
  final String? subtitle;
  final bool danger;
  final Future<void> Function() onSelected;
}

abstract final class PersonActions {
  static Future<void> showMenu(
    BuildContext context, {
    required SocialPerson person,
    required String contextName,
    VoidCallback? onBlocked,
    List<PersonMenuItem> extra = const [],
  }) async {
    final items = <PersonMenuItem>[
      ...extra,
      PersonMenuItem(
        art: BuddyArt.warning,
        title: SocialStrings.report,
        subtitle: SocialStrings.reportSub,
        danger: true,
        onSelected: () async {
          final outcome = await ReportDialog.show(context, person: person.asBuddyPerson, contextName: contextName);
          if (outcome == ReportOutcome.reportedAndBlocked) onBlocked?.call();
        },
      ),
      PersonMenuItem(
        art: BuddyArt.shield,
        title: '${SocialStrings.block} ${person.shortName}',
        subtitle: SocialStrings.blockSub,
        danger: true,
        onSelected: () async {
          final ok = await BlockDialog.show(context, person: person.asBuddyPerson, contextName: contextName);
          if (ok) onBlocked?.call();
        },
      ),
    ];
    final picked = await BuddySheet.show<int>(
      context,
      avatar: BuddyAvatar(initial: person.initial, seed: person.userId, size: BuddyAvatarSize.lg, ring: true, photoUrl: person.photoUrl),
      title: person.name,
      subtitle: person.username,
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: DS.s(1), thickness: DS.s(1), color: BuddyLook.hairline),
            MenuRow(
              art: items[i].art,
              title: items[i].title,
              subtitle: items[i].subtitle,
              danger: items[i].danger,
              onTap: () => Navigator.of(c).pop(i),
            ),
          ],
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    await items[picked].onSelected();
  }
}
