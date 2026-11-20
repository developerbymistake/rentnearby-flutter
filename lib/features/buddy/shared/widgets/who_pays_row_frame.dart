import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';

class WhoPaysRowFrame extends StatelessWidget {
  const WhoPaysRowFrame({
    super.key,
    required this.fromAvatar,
    required this.toAvatar,
    required this.title,
    this.subtitle,
    required this.amount,
    this.amountColor,
    this.footerLeft,
    this.footerRight = const [],
    this.margin,
  });

  static const String arrow = '→';

  final Widget fromAvatar;
  final Widget toAvatar;
  final Widget title;
  final Widget? subtitle;
  final String amount;
  final Color? amountColor;
  final Widget? footerLeft;
  final List<Widget> footerRight;
  final EdgeInsets? margin;

  static BorderRadius get radius =>
      DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));

  @override
  Widget build(BuildContext context) {
    final hasFooter = footerLeft != null || footerRight.isNotEmpty;
    return Container(
      margin: margin ?? DS.insets(l: 18, t: 12, r: 18),
      padding: DS.sym(h: 16, v: 14),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: radius, boxShadow: BuddyLook.cardShadows(DS.size)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              fromAvatar,
              Padding(
                padding: DS.sym(h: 4),
                child: Text(arrow, style: Ink3D.text(18, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
              ),
              toAvatar,
              Gap.h(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [title, ?subtitle],
                ),
              ),
              Gap.h(8),
              Text(amount, maxLines: 1, style: Ink3D.text(17, FontWeight.w700, amountColor ?? Ink3D.title, letterSpacing: 0)),
            ],
          ),
          if (hasFooter)
            Container(
              margin: EdgeInsets.only(top: DS.s(12)),
              padding: EdgeInsets.only(top: DS.s(12)),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: BuddyLook.hairline, width: DS.s(1)))),
              child: Row(
                children: [
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: footerLeft ?? const SizedBox.shrink())),
                  for (var i = 0; i < footerRight.length; i++) ...[if (i > 0) Gap.h(8), footerRight[i]],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
