import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

class HubStateChip extends StatelessWidget {
  const HubStateChip({super.key, required this.art, required this.label, required this.colors, this.onTap});

  final String art;
  final String label;
  final List<Color> colors;
  final VoidCallback? onTap;

  static const BorderRadius _radius = BorderRadius.only(
    topLeft: Radius.circular(14),
    topRight: Radius.circular(22),
    bottomLeft: Radius.circular(14),
    bottomRight: Radius.circular(14),
  );

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
            borderRadius: _radius,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Art3D(asset: art, size: 24, shadowBlur: 0, shadowAlpha: 0),
                const SizedBox(width: 6),
                Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(12, FontWeight.w700, Colors.white, letterSpacing: 0)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
