import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';

class BuddyBottomBar extends StatelessWidget {
  const BuddyBottomBar({super.key, required this.children, this.line, this.lineDanger = false});

  final List<Widget> children;
  final String? line;
  final bool lineDanger;

  @override
  Widget build(BuildContext context) {
    final l = line;
    return Container(
      padding: DS.insets(l: 16, t: 12, r: 16, b: 16).copyWith(bottom: DS.s(16) + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
        boxShadow: [BoxShadow(color: Ink3D.soft.withValues(alpha: Alpha.scrim), offset: DS.shadowOffset(const Offset(0, -2)), blurRadius: DS.shadowBlur(16))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (children.length == 1)
            children.first
          else
            Row(
              children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) Gap.h(14), Expanded(child: children[i])],
              ],
            ),
          if (l != null && l.isNotEmpty)
            Container(
              constraints: BoxConstraints(minHeight: DS.s(40)),
              margin: EdgeInsets.only(top: DS.s(6)),
              alignment: Alignment.center,
              child: Text(l,
                  textAlign: TextAlign.center,
                  style: Ink3D.text(13, FontWeight.w700, lineDanger ? BuddyLook.dangerText : BuddyLook.indigoText, letterSpacing: 0)),
            ),
        ],
      ),
    );
  }
}
