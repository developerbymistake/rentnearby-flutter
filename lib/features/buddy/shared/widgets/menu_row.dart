import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';

class MenuRow extends StatelessWidget {
  const MenuRow({super.key, required this.art, required this.title, this.subtitle, this.danger = false, this.grey = false, this.onTap, this.trailing, this.subtitleLines = 1});

  static const String chevron = '›';

  final String art;
  final String title;
  final String? subtitle;
  final bool danger;
  final bool grey;
  final VoidCallback? onTap;
  final Widget? trailing;
  final int subtitleLines;

  @override
  Widget build(BuildContext context) {
    final tileColor = danger
        ? BuddyLook.dangerEnd.withValues(alpha: Alpha.tint)
        : (grey ? BuddyLook.pillOff : ListingPalette.indigo.g2.withValues(alpha: Alpha.v14));
    final sub = subtitle;
    return Tap3D(
      onTap: onTap,
      label: title,
      exclude: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DS.s(64)),
        child: Padding(
          padding: DS.sym(h: 2, v: 8),
          child: Row(
            children: [
              SizedBox(
                width: DS.s(48),
                height: DS.s(48),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: tileColor, borderRadius: DS.circular(16)))),
                    Positioned(left: DS.s(2), top: -DS.s(6), child: Art3D(asset: art, size: 44, shadowBlur: 3, shadowOffset: const Offset(2, 4))),
                  ],
                ),
              ),
              Gap.h(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, danger ? BuddyLook.dangerText : Ink3D.title, letterSpacing: 0)),
                    if (sub != null && sub.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: DS.s(1)),
                        child: Text(sub, maxLines: subtitleLines, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                      ),
                  ],
                ),
              ),
              trailing ?? Text(chevron, style: Ink3D.text(22, FontWeight.w400, BuddyLook.chevron, letterSpacing: 0)),
            ],
          ),
        ),
      ),
    );
  }
}
