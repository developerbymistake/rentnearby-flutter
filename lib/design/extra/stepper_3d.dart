import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';

class StepperField extends StatelessWidget {
  const StepperField({
    super.key,
    required this.tone,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.label,
    this.leadingArt,
    this.filled = false,
    this.minusKey,
    this.plusKey,
    this.semanticsLabel,
  });

  final ListingTone tone;
  final int value;
  final ValueChanged<int>? onChanged;
  final int min;
  final int max;
  final String? label;
  final String? leadingArt;
  final bool filled;
  final Key? minusKey;
  final Key? plusKey;
  final String? semanticsLabel;

  Widget _button(bool plus, double size) {
    final live = onChanged != null && (plus ? value < max : value > min);
    final tip = plus ? 'Increase' : 'Decrease';
    return Tooltip(
      message: tip,
      excludeFromSemantics: true,
      child: Tap3D(
        tapKey: plus ? plusKey : minusKey,
        onTap: live ? () => onChanged!(plus ? value + 1 : value - 1) : null,
        label: tip,
        exclude: true,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: live ? null : Form3D.limit,
            gradient: live ? tone.gradient : null,
            boxShadow: live ? Form3D.glow(tone, offset: const Offset(1.1, 4), blur: 8) : null,
          ),
          child: Icon(plus ? Icons.add_rounded : Icons.remove_rounded, size: size * 0.5, color: live ? Colors.white : Form3D.hint),
        ),
      ),
    );
  }

  Widget _value() => Text('$value', maxLines: 1, style: Ink3D.text(17, FontWeight.w700, Ink3D.title, letterSpacing: 0));

  @override
  Widget build(BuildContext context) {
    final l = label;
    final a = leadingArt;
    final Widget body;
    if (filled) {
      body = Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: EdgeInsets.fromLTRB(a == null ? 18 : 10, 8, 10, 8),
        decoration: BoxDecoration(color: Form3D.fill, borderRadius: BorderRadius.circular(30)),
        child: Row(
          children: [
            if (a != null) ...[Art3D(asset: a, size: 40, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.22), const SizedBox(width: 12)],
            Expanded(child: Text(l ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.body, letterSpacing: 0))),
            _button(false, 38),
            SizedBox(width: 46, child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _value()))),
            _button(true, 38),
          ],
        ),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (l != null && l.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
              child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w600, Form3D.label, letterSpacing: 0)),
            ),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: Ink3D.softShadow),
            child: Row(
              children: [
                _button(false, 44),
                Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _value()))),
                _button(true, 44),
              ],
            ),
          ),
        ],
      );
    }
    return Semantics(container: true, label: semanticsLabel ?? l, value: '$value', child: body);
  }
}
