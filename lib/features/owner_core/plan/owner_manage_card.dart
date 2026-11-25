import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../look/owner_look.dart';

class OwnerManageCard extends StatelessWidget {
  const OwnerManageCard({super.key, required this.eyebrow, this.chip, required this.title, this.sub, this.actions = const [], this.margin, this.footer, this.muted = false});

  final String eyebrow;
  final String? chip;
  final String title;
  final String? sub;
  final List<Widget> actions;
  final EdgeInsets? margin;
  final Widget? footer;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final radius = OwnerLook.cardRadius();
    return Padding(
      padding: margin ?? DS.insets(l: 18, t: 14, r: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, borderRadius: radius, boxShadow: DS.shadows(Ink3D.softShadow)),
        child: Padding(
          padding: DS.insets(l: 16, t: 14, r: 16, b: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(eyebrow, style: Ink3D.text(11, FontWeight.w700, Ink3D.grey, letterSpacing: 0.6))),
                  if (chip != null) ...[
                    Gap.h(8),
                    DecoratedBox(
                      decoration: BoxDecoration(color: OwnerLook.greySoft, borderRadius: DS.circular(10)),
                      child: Padding(
                        padding: DS.sym(h: 8, v: 3),
                        child: Text(chip!, style: Ink3D.text(11, FontWeight.w600, Ink3D.grey, letterSpacing: 0)),
                      ),
                    ),
                  ],
                ],
              ),
              Padding(
                padding: EdgeInsets.only(top: DS.gv(6)),
                child: Text(title, style: Ink3D.text(15, FontWeight.w700, muted ? Ink3D.grey : Ink3D.title, letterSpacing: 0)),
              ),
              if (sub != null)
                Padding(
                  padding: EdgeInsets.only(top: DS.gv(2)),
                  child: Text(sub!, style: Ink3D.text(12.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                ),
              if (footer != null) Padding(padding: EdgeInsets.only(top: DS.gv(8)), child: footer),
              if (actions.isNotEmpty) ...[
                Gap.v(12),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) Gap.h(8),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
