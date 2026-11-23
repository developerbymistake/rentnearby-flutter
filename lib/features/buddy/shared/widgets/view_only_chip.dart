import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';
import '../strings_shared.dart';

class ViewOnlyChip extends StatelessWidget {
  const ViewOnlyChip({super.key, this.label = BuddySharedStrings.viewOnly});

  static const String art = BuddyArt.locked;

  final String label;

  @override
  Widget build(BuildContext context) {
    final iconOnly = MediaQuery.sizeOf(context).width < 360;
    return Semantics(
      label: label,
      container: true,
      child: ExcludeSemantics(
        child: Container(
          height: DS.s(30),
          padding: DS.sym(h: iconOnly ? 8 : 12),
          decoration: BoxDecoration(color: DesignColors.surface.withValues(alpha: Alpha.v25), borderRadius: DS.circular(14)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(art, width: DS.s(18), height: DS.s(18), fit: BoxFit.contain),
              if (!iconOnly) ...[
                Gap.h(6),
                Text(label, maxLines: 1, style: Ink3D.text(12, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
