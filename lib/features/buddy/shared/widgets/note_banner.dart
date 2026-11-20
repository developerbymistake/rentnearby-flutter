import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';

enum NoteTone { indigo, teal, rose, danger, amber }

class NoteBanner extends StatelessWidget {
  const NoteBanner({super.key, this.art, required this.text, this.tone = NoteTone.indigo, this.action, this.margin});

  final String? art;
  final String text;
  final NoteTone tone;
  final Widget? action;
  final EdgeInsets? margin;

  static BorderRadius get radius =>
      DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(32), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = BuddyLook.note[NoteToneColor.values[tone.index]]!;
    final a = art;
    return Container(
      margin: margin ?? DS.insets(l: 18, t: 24, r: 18),
      constraints: BoxConstraints(minHeight: DS.s(64)),
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (a != null)
            Positioned(
              left: DS.s(14),
              top: -DS.s(8),
              child: ExcludeSemantics(child: Art3D(asset: a, size: 52, shadowBlur: 3, shadowOffset: const Offset(2, 3))),
            ),
          Padding(
            padding: DS.insets(l: a == null ? 16 : 80, t: 14, r: 16, b: 14),
            child: Row(
              children: [
                Expanded(child: Text(text, style: Ink3D.text(13, FontWeight.w600, fg, height: 1.45, letterSpacing: 0))),
                if (action != null) ...[Gap.h(10), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
