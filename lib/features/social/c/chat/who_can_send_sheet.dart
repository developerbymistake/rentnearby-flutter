import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_sheet.dart';
import '../../../buddy/shared/widgets/menu_row.dart';
import '../../b/widgets/social_widgets_b.dart';
import '../social_strings_c.dart';

abstract final class WhoCanSendSheet {
  static const Key everyoneKey = ValueKey('who_can_send_everyone');
  static const Key onlyMeKey = ValueKey('who_can_send_only_me');

  /// Resolves true for "Only me", false for "Everyone", null when closed.
  static Future<bool?> show(BuildContext context, {required bool onlyOwner}) => BuddySheet.show<bool>(
        context,
        art: ListingArt.crown,
        title: SocialStringsC.whoCanSend,
        subtitle: SocialStringsC.whoCanSendLine,
        tone: ListingTone.indigo,
        builder: (c) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MenuRow(
              key: everyoneKey,
              art: ListingArt.panda,
              title: SocialStringsC.everyone,
              subtitle: SocialStringsC.everyoneLine,
              trailing: RadioMark(selected: !onlyOwner, tone: ListingTone.indigo),
              onTap: () => Navigator.of(c).pop(false),
            ),
            Divider(height: DS.s(1), thickness: DS.s(1), color: BuddyLook.hairline),
            MenuRow(
              key: onlyMeKey,
              art: ListingArt.crown,
              title: SocialStringsC.onlyMe,
              subtitle: SocialStringsC.onlyMeLine,
              trailing: RadioMark(selected: onlyOwner, tone: ListingTone.indigo),
              onTap: () => Navigator.of(c).pop(true),
            ),
          ],
        ),
      );
}
