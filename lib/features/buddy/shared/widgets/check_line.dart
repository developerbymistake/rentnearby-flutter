import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';

class CheckLine extends StatelessWidget {
  const CheckLine({
    super.key,
    this.leading,
    required this.title,
    this.titleWidget,
    this.subtitle,
    required this.checked,
    this.enabled = true,
    this.trailingBadge,
    this.onTap,
    this.tone,
    this.round = false,
  });

  static const String tick = '✔';

  final Widget? leading;
  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final bool checked;
  final bool enabled;
  final Widget? trailingBadge;
  final VoidCallback? onTap;
  final ListingTone? tone;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? BuddyLook.rose;
    final sub = subtitle;
    final box = Container(
      width: DS.s(26),
      height: DS.s(26),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: DS.circular(round ? 13 : 8),
        gradient: checked ? t.gradient : null,
        border: checked ? null : Border.all(color: BuddyLook.checkOff, width: DS.s(2)),
      ),
      child: checked ? Icon(Icons.check_rounded, size: DS.s(18), color: DesignColors.onPrimary) : null,
    );
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: DS.s(50)),
      child: Padding(
        padding: DS.sym(v: 6),
        child: Row(
          children: [
            if (leading != null) ...[leading!, Gap.h(12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  titleWidget ?? Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                  if (sub != null && sub.isNotEmpty)
                    Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                ],
              ),
            ),
            if (trailingBadge != null) ...[Gap.h(8), trailingBadge!],
            Gap.h(12),
            box,
          ],
        ),
      ),
    );
    return Opacity(
      opacity: enabled ? Alpha.full : Alpha.v55,
      child: Tap3D(onTap: enabled ? onTap : null, toggled: checked, label: title, exclude: true, child: row),
    );
  }
}
