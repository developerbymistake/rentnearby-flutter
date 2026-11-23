import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';

class SegmentTabs extends StatelessWidget {
  const SegmentTabs({super.key, required this.labels, required this.selected, required this.onTap, required this.tone, this.counts = const {}, this.margin});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onTap;
  final ListingTone tone;
  final Map<int, int> counts;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin ?? DS.insets(l: 18, t: 18, r: 18),
        padding: DS.all(4),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.circular(24),
          boxShadow: [BoxShadow(color: DesignColors.textStrong.withValues(alpha: Alpha.tint), offset: DS.shadowOffset(const Offset(0, 2)), blurRadius: DS.shadowBlur(8))],
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(child: _Cell(label: labels[i], on: i == selected, count: counts[i] ?? 0, tone: tone, onTap: () => onTap(i))),
          ],
        ),
      );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.on, required this.count, required this.tone, required this.onTap});

  final String label;
  final bool on;
  final int count;
  final ListingTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = on ? DesignColors.onPrimary : BuddyLook.subText;
    return Tap3D(
      onTap: onTap,
      selected: on,
      label: count > 0 ? '$label, $count' : label,
      exclude: true,
      child: Container(
        constraints: BoxConstraints(minHeight: DS.s(40)),
        alignment: Alignment.center,
        padding: DS.sym(h: 6),
        decoration: on
            ? BoxDecoration(
                gradient: tone.gradient,
                borderRadius: DS.circular(20),
                boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: Alpha.scrim), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(8))],
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, textColor, letterSpacing: 0))),
            if (count > 0) ...[
              Gap.h(6),
              Container(
                constraints: BoxConstraints(minWidth: DS.s(20), minHeight: DS.s(20)),
                padding: DS.sym(h: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: BuddyLook.countBadge, borderRadius: DS.circular(10)),
                child: Text('$count',
                    maxLines: 1, textScaler: TextScaler.noScaling, style: Ink3D.text(11, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
