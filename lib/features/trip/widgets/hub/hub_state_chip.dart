import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

class HubStateChip extends StatelessWidget {
  const HubStateChip({super.key, required this.art, required this.label, required this.colors, this.onTap});

  final String art;
  final String label;
  final List<Color> colors;
  final VoidCallback? onTap;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(14));

  static BorderRadius get _scaledRadius => DS.br(_radius);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: _scaledRadius,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          ),
          child: Padding(
            padding: DS.sym(h: 10, v: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Art3D(asset: art, size: 24, shadowBlur: 0, shadowAlpha: 0),
                Gap.h(6),
                Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(12, FontWeight.w700, Colors.white, letterSpacing: 0)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
