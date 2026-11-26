import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';

class MoneyHero extends StatelessWidget {
  const MoneyHero({super.key, required this.label, required this.amount, this.cells = const [], this.footer, this.margin});

  final String label;
  final String amount;
  final List<(String, String)> cells;
  final Widget? footer;
  final EdgeInsets? margin;

  static BorderRadius get radius =>
      DS.br(CardRadius.hero);

  static BorderRadius get cellRadius =>
      DS.br(CardRadius.card);

  @override
  Widget build(BuildContext context) {
    final shadow = [Shadow(color: DesignColors.textStrong.withValues(alpha: Alpha.v22), offset: DS.shadowOffset(const Offset(0, 1)), blurRadius: DS.shadowBlur(3))];
    return Container(
      margin: margin ?? DS.insets(l: 18, t: 20, r: 18),
      padding: DS.sym(h: 20, v: 18),
      decoration: BoxDecoration(
        gradient: BuddyLook.rose.gradient,
        borderRadius: radius,
        boxShadow: [BoxShadow(color: BuddyLook.roseGlow.withValues(alpha: Alpha.v45), offset: DS.shadowOffset(const Offset(1.1, 6)), blurRadius: DS.shadowBlur(14))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Ink3D.text(12.5, FontWeight.w600, DesignColors.onPrimary, letterSpacing: 0).copyWith(shadows: shadow)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(amount, maxLines: 1, style: Ink3D.text(34, FontWeight.w700, DesignColors.onPrimary, height: 1.2, letterSpacing: 0).copyWith(shadows: shadow)),
          ),
          if (cells.isNotEmpty) ...[
            Gap.v(12),
            Row(
              children: [
                for (var i = 0; i < cells.length; i++) ...[
                  if (i > 0) Gap.h(10),
                  Expanded(
                    child: Container(
                      padding: DS.sym(h: 12, v: 8),
                      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: cellRadius),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cells[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
                          Text(cells[i].$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w600, BuddyLook.subText, letterSpacing: 0)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (footer != null) ...[Gap.v(12), footer!],
        ],
      ),
    );
  }
}
