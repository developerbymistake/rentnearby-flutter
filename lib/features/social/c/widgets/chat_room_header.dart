import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
import 'package:bakhli/widgets/profile_avatar.dart';

import '../../../buddy/shared/buddy_look.dart';
import 'icon_title_header.dart';

/// Back, avatar, name + subtitle and the menu in one compact row; no decorative art.
class ChatRoomHeader extends StatelessWidget {
  const ChatRoomHeader({
    super.key,
    required this.tone,
    required this.initial,
    required this.name,
    required this.subtitle,
    required this.onBack,
    required this.onMore,
    this.moreKey,
    this.photoUrl,
    this.avatarGradient,
    this.leading,
    this.nameTrailing,
    this.subtitleLead,
  });

  static const double avatar = 46;
  static const double ring = 2;

  final ListingTone tone;
  final String initial;
  final String name;
  final String subtitle;
  final VoidCallback? onBack;
  final ChatMenuTap? onMore;
  final Key? moreKey;
  final String? photoUrl;
  final Gradient? avatarGradient;
  final Widget? leading;
  final Widget? nameTrailing;
  final Widget? subtitleLead;

  static Widget tripArt({Key? key, required String art, required Gradient gradient}) => Container(
        key: key,
        width: DS.s(avatar),
        height: DS.s(avatar),
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: gradient, borderRadius: DS.br(CardRadius.card), border: Border.all(color: DesignColors.surface, width: DS.s(ring))),
        child: Image.asset(art, width: DS.s(32), height: DS.s(32)),
      );

  Widget _avatar() => Container(
        key: const ValueKey('chat_room_header_avatar'),
        width: DS.s(avatar),
        height: DS.s(avatar),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: avatarGradient ?? tone.gradient,
          border: Border.all(color: DesignColors.surface, width: DS.s(ring)),
        ),
        child: ProfileAvatar(
          photoUrl: photoUrl,
          size: DS.s(avatar) - 2 * DS.s(ring),
          fallback: Text(initial, textScaler: TextScaler.noScaling, style: Ink3D.text(23, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final nameText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(name, maxLines: 1, softWrap: false, style: Ink3D.text(21, FontWeight.w700, Ink3D.title, letterSpacing: 0.4)),
    );
    final lead = subtitleLead;
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(10), DS.s(18), DS.s(10)),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DS.s(IconTitleHeader.button)),
        child: Row(
          children: [
            ChatRoundButton3D(icon: Icons.chevron_left_rounded, onTap: onBack, tooltip: 'Back', tone: tone, size: IconTitleHeader.button),
            Gap.h(12),
            leading ?? _avatar(),
            Gap.h(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: nameTrailing == null
                        ? nameText
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [Flexible(child: nameText), Gap.h(6), ExcludeSemantics(child: nameTrailing!)],
                          ),
                  ),
                  if (subtitle.isNotEmpty || lead != null)
                    Row(
                      children: [
                        if (lead != null) ...[ExcludeSemantics(child: lead), Gap.h(5)],
                        Expanded(
                          child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Gap.h(10),
            Builder(
              builder: (c) => ChatRoundButton3D(
                icon: Icons.more_vert_rounded,
                onTap: onMore == null ? null : () => onMore!(chatRectOf(c)),
                tooltip: 'More',
                tone: tone,
                size: IconTitleHeader.button,
                tapKey: moreKey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
