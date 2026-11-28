import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../social_strings.dart';

class FollowLimitSheet extends StatelessWidget {
  const FollowLimitSheet({super.key});

  static const Key sheetKey = ValueKey('follow_limit_sheet');
  static const Key okKey = ValueKey('follow_limit_ok');

  static Future<void> show(BuildContext context) => Sheet3D.show<void>(context, builder: (_) => const FollowLimitSheet());

  @override
  Widget build(BuildContext context) {
    return Sheet3D(
      key: sheetKey,
      tone: BuddyLook.teal,
      art: ListingArt.alarmClock,
      title: SocialStrings.tryLaterTitle,
      subtitle: SocialStrings.tryLaterLine,
      child: GradientPillButton(
        key: okKey,
        tone: BuddyLook.teal,
        label: SocialStrings.ok,
        onTap: () => Navigator.of(context).pop(),
      ),
    );
  }
}
