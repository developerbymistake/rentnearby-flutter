import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../trip_strings_shortlist.dart';
import 'trip_list_look.dart';

class TripShortlistToggle extends StatelessWidget {
  const TripShortlistToggle({
    super.key,
    required this.selected,
    required this.onTap,
    this.busy = false,
    this.tone = KitTone.stay,
    this.height = 44,
  });

  final bool selected;
  final bool busy;
  final VoidCallback? onTap;
  final KitTone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = tripListTone(tone);
    final action = busy ? null : onTap;
    final ink = selected ? t.g2 : DesignColors.textInverse;
    final label = selected ? TripStringsShortlist.shortlisted : TripStringsShortlist.shortlist;
    return Semantics(
      button: true,
      selected: selected,
      enabled: action != null,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        enabled: action != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: action,
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: Container(
              constraints: BoxConstraints(minHeight: DS.s(height)),
              padding: DS.sym(h: 12, v: 8),
              decoration: BoxDecoration(
                borderRadius: DS.circular(22),
                color: selected ? DesignColors.surface : null,
                gradient: selected ? null : t.gradient,
                boxShadow: selected ? DS.shadows(Ink3D.softShadow) : t.glow(blur: 8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox(width: DS.s(16), height: DS.s(16), child: CircularProgressIndicator(strokeWidth: 2, color: ink))
                  else
                    Icon(selected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, size: DS.s(18), color: ink),
                  Gap.h(8),
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, ink, letterSpacing: 0))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
