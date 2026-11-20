import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';

enum BuddyBadgeTone { teal, grey, view, owner, pending, ok, danger }

class BuddyBadge extends StatelessWidget {
  const BuddyBadge(this.label, {super.key, this.tone = BuddyBadgeTone.grey, this.large = false});

  final String label;
  final BuddyBadgeTone tone;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = BuddyLook.badge[BuddyBadgeColor.values[tone.index]]!;
    final h = large ? 32.0 : 24.0;
    return Container(
      constraints: BoxConstraints(minHeight: DS.s(h)),
      padding: DS.sym(h: large ? 16 : 10),
      decoration: BoxDecoration(color: bg, borderRadius: DS.circular(h / 2)),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(large ? 13 : 11.5, FontWeight.w700, fg, letterSpacing: 0)),
      ),
    );
  }
}
