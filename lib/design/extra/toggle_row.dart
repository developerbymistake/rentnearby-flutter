import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';

class Switch3D extends StatelessWidget {
  const Switch3D({super.key, required this.tone, required this.value, required this.onChanged, this.onGradient = false, this.semanticsLabel});

  final ListingTone tone;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool onGradient;
  final String? semanticsLabel;

  static const double width = 50;
  static const double height = 28;

  @override
  Widget build(BuildContext context) {
    final live = onChanged != null;
    const fast = Duration(milliseconds: 160);
    final track = AnimatedContainer(
      duration: fast,
      width: width,
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: onGradient ? (value ? Colors.white : Colors.white.withValues(alpha: 0.35)) : (value ? null : Form3D.switchOff),
        gradient: !onGradient && value ? tone.gradient : null,
      ),
      child: AnimatedAlign(
        duration: fast,
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle, color: onGradient && value ? tone.button : Colors.white, boxShadow: Form3D.knob),
        ),
      ),
    );
    return Semantics(
      toggled: value,
      enabled: live,
      label: semanticsLabel,
      onTap: live ? () => onChanged!(!value) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: live ? () => onChanged!(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: live ? track : Opacity(opacity: 0.5, child: track),
        ),
      ),
    );
  }
}

class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.tone,
    required this.label,
    required this.value,
    required this.onChanged,
    this.art,
    this.sublabel,
    this.divider = false,
    this.filled = false,
    this.enabled = true,
  });

  final ListingTone tone;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? art;
  final String? sublabel;
  final bool divider;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final live = enabled && onChanged != null;
    final a = art;
    final s = sublabel;
    final row = Row(
      children: [
        if (a != null) ...[
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Form3D.wash(tone, 0.13))),
                Positioned(left: -3, top: -8, child: Art3D(asset: a, size: 50, shadowBlur: 3, shadowOffset: const Offset(2, 4))),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(filled ? 15 : 14.5, filled ? FontWeight.w600 : FontWeight.w500, Ink3D.body, letterSpacing: 0, height: 1.35)),
              if (s != null && s.isNotEmpty) Text(s, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Form3D.muted, letterSpacing: 0, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ExcludeSemantics(child: IgnorePointer(child: Switch3D(tone: tone, value: value, onChanged: live ? (_) {} : null))),
      ],
    );
    final Widget body;
    if (filled) {
      body = Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.fromLTRB(18, 4, 12, 4),
        decoration: BoxDecoration(color: Form3D.fill, borderRadius: BorderRadius.circular(30)),
        child: row,
      );
    } else {
      body = Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: EdgeInsets.symmetric(vertical: a == null ? 2 : 9),
        decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: Form3D.limit))) : null,
        child: row,
      );
    }
    return Semantics(
      toggled: value,
      enabled: live,
      label: label,
      excludeSemantics: true,
      onTap: live ? () => onChanged!(!value) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: live ? () => onChanged!(!value) : null,
        child: body,
      ),
    );
  }
}
