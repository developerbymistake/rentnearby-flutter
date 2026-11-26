import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/buddy_look.dart';

class SocialSectionCard extends StatelessWidget {
  const SocialSectionCard({super.key, required this.art, required this.title, required this.child, this.hint, this.top = 20});

  final String art;
  final String title;
  final Widget child;
  final Widget? hint;
  final double top;

  static BorderRadius get radius => DS.br(CardRadius.hero);

  @override
  Widget build(BuildContext context) => Container(
        margin: DS.gapInsets(l: 18, t: top, r: 18),
        padding: DS.insets(l: 16, t: 16, r: 16, b: 18),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: radius, boxShadow: BuddyLook.cardShadows(DS.size)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SocialSectionHeader(art: art, title: title, hint: hint),
            Gap.v(10),
            child,
          ],
        ),
      );
}

class SocialSectionHeader extends StatelessWidget {
  const SocialSectionHeader({super.key, required this.art, required this.title, this.hint});

  final String art;
  final String title;
  final Widget? hint;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: DS.s(40),
            height: DS.s(40),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(decoration: BoxDecoration(color: ListingTone.indigo.g2.withValues(alpha: Alpha.tint), borderRadius: DS.br(CardRadius.card))),
                ),
                Positioned(left: -DS.s(1), top: -DS.s(6), child: ExcludeSemantics(child: Art3D(asset: art, size: 44, shadowBlur: 3, shadowOffset: const Offset(2, 4)))),
              ],
            ),
          ),
          Gap.h(10),
          Expanded(child: Semantics(header: true, child: Text(title, style: Ink3D.text(16, FontWeight.w600, Ink3D.title, letterSpacing: 0)))),
          ?hint,
        ],
      );
}
