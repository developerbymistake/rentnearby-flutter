import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../notice_copy.dart';

class SocialNoticeCard extends StatelessWidget {
  const SocialNoticeCard({super.key, required this.view, required this.time, required this.isRead, this.onTap});

  final NoticeView view;
  final String time;
  final bool isRead;
  final VoidCallback? onTap;

  static const Color unreadFill = Color(0xFFF5F6FF);
  static const Key dotKey = ValueKey('social_notice_dot');

  static List<TextSpan> _rest(String text, String? place, TextStyle strong) {
    if (place == null || place.isEmpty) return [TextSpan(text: text)];
    final at = text.lastIndexOf(place);
    if (at < 0) return [TextSpan(text: text)];
    final end = at + place.length;
    return [
      if (at > 0) TextSpan(text: text.substring(0, at)),
      TextSpan(text: place, style: strong),
      if (end < text.length) TextSpan(text: text.substring(end)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final name = view.actorName;
    final line = view.title;
    final bold = name != null && line.startsWith(name);
    final initial = (name ?? '').trim().isEmpty ? '' : name!.trim().substring(0, 1).toUpperCase();
    final lineStyle = Ink3D.text(14.5, FontWeight.w400, Ink3D.title, height: 1.4, letterSpacing: 0);
    final row = Container(
      padding: DS.insets(l: 16, t: 14, r: 16, b: 14),
      decoration: BoxDecoration(
        color: isRead ? DesignColors.surface : unreadFill,
        borderRadius: DS.circular(18),
        boxShadow: DS.shadows(Form3D.cardShadow),
      ),
      child: Row(
        children: [
          BuddyAvatar(initial: initial, seed: view.actorSeed, photoUrl: view.actorPhotoUrl),
          Gap.h(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(children: [
                    if (bold) TextSpan(text: name, style: lineStyle.copyWith(fontWeight: FontWeight.w600)),
                    ..._rest(bold ? line.substring(name!.length) : line, view.place, lineStyle.copyWith(fontWeight: FontWeight.w600)),
                  ]),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: lineStyle,
                ),
                if (view.body.isNotEmpty)
                  Padding(
                    padding: DS.insets(t: 2),
                    child: Text(view.body, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                  ),
              ],
            ),
          ),
          Gap.h(10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(time, maxLines: 1, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
              if (!isRead) ...[
                Gap.v(8),
                Container(
                  key: dotKey,
                  width: DS.s(10),
                  height: DS.s(10),
                  decoration: BoxDecoration(color: BuddyLook.indigo.g2, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    return Padding(
      padding: DS.gapInsets(l: 14, t: 10, r: 14),
      child: Tap3D(onTap: onTap, label: view.body.isEmpty ? line : '$line. ${view.body}', exclude: true, child: row),
    );
  }
}
