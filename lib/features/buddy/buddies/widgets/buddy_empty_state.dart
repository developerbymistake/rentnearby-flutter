import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/small_pill.dart';

class BuddyEmptyState extends StatelessWidget {
  const BuddyEmptyState({super.key, required this.art, required this.title, this.line, this.red = false, this.actionLabel, this.onAction});

  final String art;
  final String title;
  final String? line;
  final bool red;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final l = line;
    final halo = (red ? BuddyLook.dangerEnd : BuddyLook.tealStart).withValues(alpha: red ? Alpha.tint : Alpha.v14);
    return Padding(
      padding: DS.insets(l: 30, t: 40, r: 30, b: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              width: DS.s(150),
              height: DS.s(150),
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: halo),
              child: Art3D(asset: art, size: 108, shadowBlur: 7, shadowOffset: const Offset(6, 9)),
            ),
          ),
          Gap.v(18),
          Text(title, textAlign: TextAlign.center, style: Ink3D.text(22, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          if (l != null)
            Padding(
              padding: EdgeInsets.only(top: DS.s(4)),
              child: Text(l, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w400, BuddyLook.subText, height: 1.5, letterSpacing: 0)),
            ),
          if (actionLabel != null)
            Padding(
              padding: EdgeInsets.only(top: DS.s(20)),
              child: IntrinsicWidth(child: SmallPill(label: actionLabel!, onTap: onAction, kind: SmallPillKind.teal, tall: true)),
            ),
        ],
      ),
    );
  }
}
