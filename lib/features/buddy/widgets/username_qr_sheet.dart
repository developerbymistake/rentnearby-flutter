import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../design/extra/ext_buddy.dart';
import '../buddy_strings.dart';

class UsernameQrSheet extends StatelessWidget {
  const UsernameQrSheet({super.key, required this.username, required this.name});

  final String username;
  final String name;

  static const double _closeFont = 17;

  static Future<void> show(BuildContext context, {required String username, required String name}) =>
      SheetFrame.show<void>(context, builder: (_) => UsernameQrSheet(username: username, name: name));

  @override
  Widget build(BuildContext context) {
    final fullName = name.trim();
    return SheetFrame(
      title: BuddyStrings.qrTitle,
      subtitle: BuddyStrings.qrSubtitle,
      tone: BuddyInk.tone,
      footer: Center(
        child: SizedBox(
          width: DS.s(160),
          child: GradientPillButton(tone: BuddyInk.tone, label: BuddyStrings.close, fontSize: _closeFont, onTap: () => Navigator.of(context).pop()),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Gap.v(10),
          UsernameQrCard(username: username, initial: BuddyStrings.initialOf(name), semanticsLabel: BuddyStrings.qrLabel),
          Gap.v(10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(username, maxLines: 1, style: Ink3D.text(19, FontWeight.w700, DesignColors.tealDeep, letterSpacing: 0.3)),
          ),
          if (fullName.isNotEmpty)
            Padding(
              padding: DS.insets(t: 2),
              child: Text(
                fullName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(13, FontWeight.w400, Ink3D.copy, letterSpacing: 0),
              ),
            ),
        ],
      ),
    );
  }
}
