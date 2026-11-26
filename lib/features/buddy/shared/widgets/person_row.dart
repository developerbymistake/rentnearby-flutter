import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';

enum PersonLineTone { amber, grey, teal, danger }

class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.avatar,
    required this.title,
    this.titleWidget,
    this.titleBadge,
    this.subtitle,
    this.line2,
    this.line2Tone = PersonLineTone.amber,
    this.trailing,
    this.onTap,
    this.padding,
  });

  final Widget avatar;
  final String title;
  final Widget? titleWidget;
  final Widget? titleBadge;
  final String? subtitle;
  final String? line2;
  final PersonLineTone line2Tone;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  static Color lineColor(PersonLineTone tone) => switch (tone) {
        PersonLineTone.amber => BuddyLook.amberText,
        PersonLineTone.grey => BuddyLook.greyText,
        PersonLineTone.teal => BuddyLook.tealEnd,
        PersonLineTone.danger => BuddyLook.dangerText,
      };

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    final l2 = line2;
    final badge = titleBadge;
    final name = titleWidget ??
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0));
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: DS.s(72)),
      child: Padding(
        padding: padding ?? DS.sym(h: 16, v: 12),
        child: Row(
          children: [
            avatar,
            Gap.h(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  badge == null ? name : Row(children: [Flexible(child: name), Gap.h(8), badge]),
                  if (sub != null && sub.isNotEmpty)
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                  if (l2 != null && l2.isNotEmpty)
                    Text(
                      l2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(12.5, line2Tone == PersonLineTone.grey ? FontWeight.w500 : FontWeight.w600, lineColor(line2Tone), letterSpacing: 0),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[Gap.h(8), trailing!],
          ],
        ),
      ),
    );
    return onTap == null ? row : Tap3D(onTap: onTap, child: row);
  }
}

class PersonListCard extends StatelessWidget {
  const PersonListCard({super.key, required this.children, this.margin});

  final List<Widget> children;
  final EdgeInsets? margin;

  static BorderRadius get radius =>
      DS.br(CardRadius.tile);

  @override
  Widget build(BuildContext context) => Container(
        margin: margin ?? DS.insets(l: 18, r: 18),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: radius, boxShadow: BuddyLook.cardShadows(DS.size)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: DS.s(1), thickness: DS.s(1), color: BuddyLook.hairline),
              children[i],
            ],
          ],
        ),
      );
}
