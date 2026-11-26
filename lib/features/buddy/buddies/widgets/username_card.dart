import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../buddy_strings.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../buddies_strings.dart';
import '../buddy_me.dart';

class UsernameCard extends StatelessWidget {
  const UsernameCard({super.key, required this.me, required this.actionLabel, required this.onAction, this.extraLabel, this.onExtra, this.margin});

  final BuddyMe me;
  final String actionLabel;
  final VoidCallback? onAction;
  final String? extraLabel;
  final VoidCallback? onExtra;
  final EdgeInsets? margin;

  static BorderRadius get radius =>
      DS.br(CardRadius.card);

  @override
  Widget build(BuildContext context) {
    final username = me.username ?? '';
    return Container(
      margin: margin ?? DS.insets(l: 18, t: 20, r: 18),
      padding: DS.sym(h: 18, v: 16),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: radius, boxShadow: BuddyLook.cardShadows(DS.size)),
      child: Row(
        children: [
          BuddyAvatar(initial: me.initial, seed: me.userId, photoUrl: me.photoUrl),
          Gap.h(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(BuddiesStrings.yourUsername, style: Ink3D.text(12, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
                Text(username,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(18, FontWeight.w700, BuddyLook.tealEnd, letterSpacing: 0.3)),
                Padding(
                  padding: EdgeInsets.only(top: DS.s(2)),
                  child: Text(BuddyStrings.usernameHelper, style: Ink3D.text(11, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
                ),
              ],
            ),
          ),
          Gap.h(14),
          if (extraLabel != null) ...[
            _pill(extraLabel!, username.isEmpty ? null : onExtra),
            Gap.h(8),
          ],
          _pill(actionLabel, username.isEmpty ? null : onAction),
        ],
      ),
    );
  }

  Widget _pill(String label, VoidCallback? onTap) => Tap3D(
        onTap: onTap,
        label: label,
        exclude: true,
        child: Container(
          constraints: BoxConstraints(minHeight: DS.s(40)),
          padding: DS.sym(h: extraLabel != null ? 12 : 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: BuddyLook.badge[BuddyBadgeColor.teal]!.$1, borderRadius: DS.circular(20)),
          child: Text(label, style: Ink3D.text(13, FontWeight.w700, BuddyLook.tealEnd, letterSpacing: 0)),
        ),
      );
}
