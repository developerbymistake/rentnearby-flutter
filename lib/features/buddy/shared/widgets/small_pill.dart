import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';

enum SmallPillKind { white, teal, green, rose, indigo, dangerOutline, off }

class SmallPill extends StatelessWidget {
  const SmallPill({super.key, required this.label, required this.onTap, this.kind = SmallPillKind.white, this.busy = false, this.expand = false, this.tall = false});

  final String label;
  final VoidCallback? onTap;
  final SmallPillKind kind;
  final bool busy;
  final bool expand;
  final bool tall;

  ListingTone? get _tone => switch (kind) {
        SmallPillKind.teal => BuddyLook.teal,
        SmallPillKind.green => BuddyLook.green,
        SmallPillKind.rose => BuddyLook.rose,
        SmallPillKind.indigo => BuddyLook.indigo,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final enabled = onTap != null && !busy && kind != SmallPillKind.off;
    final fg = switch (kind) {
      SmallPillKind.white => BuddyLook.indigoText,
      SmallPillKind.dangerOutline => BuddyLook.dangerText,
      SmallPillKind.off => BuddyLook.greyText,
      _ => DesignColors.onPrimary,
    };
    final h = tall ? 44.0 : 40.0;
    final decoration = switch (kind) {
      SmallPillKind.white => BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.circular(h / 2),
          boxShadow: [BoxShadow(color: DesignColors.textStrong.withValues(alpha: Alpha.v18), offset: DS.shadowOffset(const Offset(2, 4)), blurRadius: DS.shadowBlur(8))],
        ),
      SmallPillKind.dangerOutline => BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.circular(h / 2),
          border: Border.all(color: BuddyLook.dangerBorder, width: DS.s(1.5)),
        ),
      SmallPillKind.off => BoxDecoration(color: BuddyLook.pillOff, borderRadius: DS.circular(h / 2)),
      _ => BoxDecoration(
          gradient: tone!.gradient,
          borderRadius: DS.circular(h / 2),
          boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: Alpha.v40), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(8))],
        ),
    };
    final body = Container(
      constraints: BoxConstraints(minHeight: DS.s(h)),
      padding: DS.sym(h: 16),
      alignment: Alignment.center,
      decoration: decoration,
      child: busy
          ? SizedBox(width: DS.s(16), height: DS.s(16), child: CircularProgressIndicator(strokeWidth: DS.s(2), color: fg))
          : Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Ink3D.text(tall ? 13.5 : 12.5, FontWeight.w700, fg, letterSpacing: 0)),
    );
    final pill = Tap3D(onTap: enabled ? onTap : null, label: label, exclude: true, child: body);
    return expand ? SizedBox(width: double.infinity, child: pill) : pill;
  }
}
