import 'package:flutter/material.dart';

import '../design.dart';

class ToneSegmentControl extends StatelessWidget {
  const ToneSegmentControl({
    super.key,
    required this.labels,
    required this.selected,
    required this.onTap,
    required this.tone,
    this.semanticLabels,
    this.cellHeight = 40,
    this.margin = EdgeInsets.zero,
  });

  final List<String> labels;
  final List<String>? semanticLabels;
  final int selected;
  final ValueChanged<int> onTap;
  final ListingTone tone;
  final double cellHeight;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: DS.all(4),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.circular(cellHeight / 2 + 4),
          boxShadow: [BoxShadow(color: DesignColors.textStrong.withValues(alpha: Alpha.tint), offset: DS.shadowOffset(const Offset(0, 2)), blurRadius: DS.shadowBlur(8))],
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: _Cell(
                  key: ValueKey('segment-$i'),
                  label: labels[i],
                  semantics: semanticLabels?[i] ?? labels[i],
                  on: i == selected,
                  tone: tone,
                  height: cellHeight,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      );
}

class _Cell extends StatelessWidget {
  const _Cell({super.key, required this.label, required this.semantics, required this.on, required this.tone, required this.height, required this.onTap});

  final String label;
  final String semantics;
  final bool on;
  final ListingTone tone;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tap3D(
        onTap: onTap,
        selected: on,
        label: semantics,
        exclude: true,
        child: Container(
          constraints: BoxConstraints(minHeight: DS.s(height)),
          alignment: Alignment.center,
          padding: DS.sym(h: 6),
          decoration: on
              ? BoxDecoration(
                  gradient: tone.gradient,
                  borderRadius: DS.circular(height / 2),
                  boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: Alpha.scrim), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(8))],
                )
              : null,
          child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, on ? DesignColors.onPrimary : Ink3D.body, letterSpacing: 0)),
        ),
      );
}
